# ADR-001 — Salida a internet desde las subredes privadas

- **Estado:** Aceptada
- **Fecha:** 2026-07-27
- **Actualizada:** 2026-07-29 (tipo de instancia y costos, por restricción del plan Free de AWS)
- **Ámbito:** `envs/dev` y `envs/prod` del repositorio `platform`
- **Decide:** Dylan

## Contexto

La VPC de `dev` tiene dos subredes privadas (`10.0.11.0/24` en `us-east-1a` y
`10.0.12.0/24` en `us-east-1b`) sin ninguna ruta de salida. El Internet Gateway
existente solo está asociado a las route tables de las públicas. Agregarle una
ruta a las privadas las convertiría en públicas de hecho, porque el IGW permite
tráfico entrante: exactamente lo que este diseño evita.

A partir de la Fase 3 las tareas de ECS Fargate corren en esas subredes privadas
y necesitan tráfico saliente en dos categorías.

**Plataforma.** Ocurre antes de que se ejecute código de la aplicación, y si
falla la tarea no arranca:

- Pull de imágenes desde ECR
- Escritura de logs a CloudWatch Logs
- Lectura del secreto de webhook desde Secrets Manager

**Aplicación.** El servicio es un receptor de webhooks: valida HMAC-SHA256,
verifica anti-replay y responde. No inicia conexiones salientes.

Lo importante es que todos esos destinos son servicios de AWS. No hay ningún
requisito de alcanzar internet abierto.

Restricciones que condicionan la decisión:

- Presupuesto objetivo <$10/mes, techo $15/mes (Sección 3 del documento maestro).
- D6: `dev` se destruye por completo cuando no se usa. Eso reduce el impacto de
  los cargos por hora, no el de los cargos fijos mensuales.
- `prod` corre con una sola tarea, de forma permanente.
- La cuenta opera bajo el plan Free de AWS, que **no permite exceder los límites
  del free tier**: los tipos de instancia no elegibles son rechazados por la API,
  no facturados. El plan dura seis meses desde la creación de la cuenta, o hasta
  agotar los créditos.

## Alternativas consideradas

Costos calculados a 730 horas/mes en `us-east-1`, julio 2026.

### A. VPC endpoints (PrivateLink) — $29.20/AZ ; $58.40 en dos AZs

Hacen falta cuatro endpoints Interface a $0.01/hora cada uno ($7.30/mes):
`ecr.api`, `ecr.dkr`, `logs` y `secretsmanager`. El de S3 también es necesario,
porque ahí se almacenan las capas de las imágenes de ECR, pero al ser tipo
Gateway no cuesta nada. El cargo es por endpoint **y por AZ**, así que en una
arquitectura de dos zonas el total se duplica.

Es la única opción en la que el tráfico hacia servicios de AWS nunca abandona la
red interna del proveedor.

### B. NAT Gateway administrado — $32.85/AZ ; $65.70 en dos AZs, más $0.045/GB

Servicio completamente administrado: AWS se ocupa de parches, disponibilidad
interna dentro de la AZ y escalado de ancho de banda. Es la opción estándar de la
industria y la que menos trabajo operativo genera. También la más cara.

### C. Instancia NAT sobre EC2 — $0/mes bajo el plan Free ; ~$10.58/mes en on-demand

Una EC2 mínima configurada para reenviar tráfico, con la AMI pública de `fck-nat`
(ARM64/Graviton).

El tipo de instancia lo determinó el plan Free. La elección natural era
`t4g.nano` (~$7.50/mes: $3.07 de cómputo, ~$0.80 de EBS y $3.65 de IPv4 pública,
cargo que aplica esté la IP en uso o no), pero no figura entre los tipos
elegibles y la API la rechaza. De las que sí lo son, `t4g.micro` es la más chica
que conserva ARM64, así que la AMI de `fck-nat` no cambia. Mientras dure el plan
Free su costo es cero; en on-demand serían ~$6.13 de cómputo ($0.0084/hora) más
EBS e IPv4, unos $10.58/mes. Más caro que la nano original.

### Efecto de D6 sobre la comparación

Los tres cargos son por hora, así que destruir `dev` cuando no se usa (~40 h/mes
estimadas) vuelve su costo despreciable en cualquiera de las tres opciones. El
ranking relativo no cambia, pero la decisión pasa a depender casi por completo de
`prod`, que corre siempre.

## Decisión

Instancia NAT `t4g.micro` con AMI de `fck-nat`, una sola, en la subred pública de
`us-east-1a`, sirviendo a ambas subredes privadas.

## Trade-offs

### Lo que se gana

Costo cero mientras dure el plan Free, y entre $19 y $55 mensuales de ahorro
frente a las alternativas administradas incluso pagando on-demand. El proyecto se
mantiene dentro del presupuesto sin recortar funcionalidad.

Costear las tres opciones con precios reales también desmintió un supuesto del
propio documento maestro: que los VPC endpoints son la salida económica al
problema del NAT. En esta arquitectura son la opción más cara.

### Lo que se pierde

**Responsabilidad operativa.** La instancia es infraestructura propia. Parches
del sistema operativo, monitoreo y recuperación quedan a cargo del proyecto; con
NAT Gateway o endpoints eso lo resuelve AWS.

**Disponibilidad.** Una sola instancia es un punto único de falla: si muere,
ambas subredes privadas pierden toda salida hasta que se reemplace. Se mitiga
poniéndola en un Auto Scaling Group con `min = max = 1`, que la reemplaza sola al
cabo de unos minutos. No es redundancia, es auto-recuperación con interrupción.

**Resiliencia multi-AZ.** Al vivir en `us-east-1a`, una caída de esa zona deja
sin salida también a la subred privada de `us-east-1b`. El diseño multi-AZ queda
cubierto para cómputo pero no para conectividad. Es aceptable porque `prod` corre
con una sola tarea: si cae la AZ, el servicio se interrumpe de todos modos.

**Postura de red.** El tráfico hacia ECR, CloudWatch y Secrets Manager sale a
internet público y vuelve por los endpoints públicos de esos servicios. Va
cifrado con TLS, pero no puede afirmarse que nunca abandona la red de AWS, una
propiedad que sí ofrecen los VPC endpoints y que pesa en entornos con requisitos
de cumplimiento.

**Margen de costo a futuro.** Los ~$10.58/mes post-free-tier consumen casi todo
el objetivo de $10, sin dejar espacio para el resto de la plataforma. Hoy no
importa porque el cargo es cero; importará cuando el plan Free termine.

## Consecuencias

### Implementado (Fase 1)

- Instancia EC2 `t4g.micro` en la subred pública de `us-east-1a`, con la AMI de
  `fck-nat` resuelta vía `data "aws_ami"` filtrando por owner (`568608671756`),
  nombre (`fck-nat-al2023-*`) y arquitectura (`arm64`).
- `source_dest_check = false` en la instancia. Sin esto el reenvío no funciona:
  EC2 descarta por defecto los paquetes que no la tienen como origen o destino.
- Security group con entrada permitida solo desde los CIDR de las subredes
  privadas, nunca desde `0.0.0.0/0`, y salida sin restricción.
- Route table propia para las privadas, con ruta `0.0.0.0/0` apuntando a la
  interfaz de red de la instancia (`network_interface_id`, no `gateway_id`: el
  atributo difiere del que se usa con el IGW), más sus dos asociaciones.

### Pendiente antes de cerrar la Fase 1

- Auto Scaling Group con `min = max = desired = 1`. Sin esto, la mitigación de
  disponibilidad descrita arriba todavía no existe.
- Endpoint Gateway de S3. Es gratuito y reduce el tráfico que atraviesa el NAT,
  así que conviene aunque ya haya salida por instancia.
- Verificación funcional: comprobar que un recurso en subred privada alcanza
  internet a través de la instancia. Estar bien configurado no prueba que el
  reenvío funcione.

### Condiciones que obligarían a revisar esta decisión

- **Fin del plan Free** (seis meses desde la creación de la cuenta, o
  agotamiento de créditos). Ahí conviene evaluar bajar a `t4g.nano`, que deja de
  estar bloqueada bajo un plan Paid y ahorra unos $3 al mes.
- Que el tráfico saliente supere ~150 GB/mes. A partir de ahí el cargo por datos
  del NAT Gateway empieza a compensar su costo fijo y la brecha se cierra.
- Que `prod` pase a correr más de una tarea, o que la disponibilidad se vuelva un
  requisito real. El punto único de falla dejaría de ser aceptable.
- Que aparezca un requisito de cumplimiento que exija tráfico fuera de internet
  público. En ese caso los VPC endpoints son la única opción válida, cueste lo
  que cueste.
- Que mantener la instancia (parches, incidentes) consuma tiempo suficiente como
  para que la diferencia de costo se justifique.

### Ajustes al documento maestro

- **D7** planteaba `fck-nat` como solución transitoria, "solo mientras dev está
  vivo". Esta decisión la extiende a `prod` de forma permanente, dentro del techo
  declarado.
- **Sección 3** presenta los VPC endpoints como la alternativa económica al NAT
  Gateway. El costeo lo desmiente para esta arquitectura: cuatro endpoints
  Interface en dos AZs cuestan $58.40/mes, casi ocho veces la instancia NAT. La
  orientación original sigue valiendo donde el volumen de datos es alto y el
  cargo por GB del NAT domina; no acá.
- **Sección 3** también describe el free tier bajo el esquema viejo, donde
  exceder los límites generaba cargos. Bajo el plan Free actual excederlos es
  imposible: la API rechaza el recurso. Eso convierte la elegibilidad para free
  tier en una restricción de diseño dura, no en una guía de costos.