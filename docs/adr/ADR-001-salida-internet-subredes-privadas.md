# ADR-001 — Salida a internet desde las subredes privadas

- **Estado:** Aceptada
- **Fecha:** 2026-07-27
- **Ámbito:** `envs/dev` y `envs/prod` del repositorio `platform`
- **Decide:** Dylan

---

## Contexto

La VPC de `dev` tiene dos subredes privadas (`10.0.11.0/24` en `us-east-1a` y
`10.0.12.0/24` en `us-east-1b`) sin ninguna ruta de salida. El Internet Gateway
existente solo está asociado a las route tables de las subredes públicas, y
agregarle una ruta a las privadas las convertiría en públicas de hecho: el IGW
permite tráfico entrante, que es precisamente lo que este diseño evita.

A partir de la Fase 3, las tareas de ECS Fargate corren en esas subredes
privadas y requieren tráfico saliente en dos categorías:

**Plataforma** — ocurre antes de que se ejecute código de la aplicación; su
ausencia impide que la tarea arranque:

- Pull de imágenes desde ECR
- Escritura de logs a CloudWatch Logs
- Lectura del secreto de webhook desde Secrets Manager

**Aplicación** — el servicio es un receptor de webhooks: valida HMAC-SHA256,
verifica anti-replay y responde. No inicia conexiones salientes. La lista está
vacía en v1.

**Observación central:** todos los destinos identificados son servicios de AWS.
No existe ningún requisito de alcanzar internet abierto.

Restricciones que condicionan la decisión:

- Presupuesto objetivo <$10/mes, techo $15/mes (Sección 3 del documento maestro).
- D6: `dev` se destruye por completo cuando no se usa, lo que reduce el impacto
  de los cargos por hora pero no el de cargos fijos mensuales.
- `prod` corre con una sola tarea, de forma permanente.

---

## Alternativas consideradas

Costos calculados a 730 horas/mes en `us-east-1`, julio 2026.

### A. VPC endpoints (PrivateLink) — $29.20/AZ ; $58.40 en dos AZs

Requiere cuatro endpoints Interface a $0.01/hora cada uno ($7.30/mes):
`ecr.api`, `ecr.dkr`, `logs` y `secretsmanager`. El endpoint Gateway de S3
—necesario porque las capas de las imágenes de ECR se almacenan allí— no tiene
costo. El cargo es por endpoint **y por AZ**, lo que duplica el total en una
arquitectura de dos zonas.

Es la única opción en la que el tráfico hacia servicios de AWS nunca abandona la
red interna del proveedor.

### B. NAT Gateway administrado — $32.85/AZ ; $65.70 en dos AZs, más $0.045/GB

Servicio completamente administrado: AWS se ocupa de parches, disponibilidad
interna dentro de la AZ y escalado de ancho de banda. Es la opción estándar de
la industria y la que menos trabajo operativo genera. También la más cara.

### C. Instancia NAT (`t4g.nano`) — ~$7.50/mes

Una EC2 mínima configurada para reenviar tráfico: $3.07 de cómputo, ~$0.80 de
volumen EBS y $3.65 de dirección IPv4 pública (cargo vigente desde 2024, aplica
esté la IP en uso o no). Replica la función del NAT Gateway a una fracción del
costo, a cambio de convertirse en un recurso que hay que operar.

### Efecto de D6 sobre la comparación

Los tres cargos son por hora, de modo que destruir `dev` cuando no se usa
(~40 h/mes estimadas) reduce el costo de ese ambiente a cifras despreciables en
cualquiera de las tres opciones. El ranking relativo no cambia, pero la decisión
pasa a estar determinada casi por completo por `prod`, que corre de forma
permanente.

---

## Decisión

Instancia NAT `t4g.nano` (opción C), una sola, ubicada en la subred pública de
`us-east-1a` y sirviendo a ambas subredes privadas.

---

## Trade-offs

### Lo que se gana

Aproximadamente $25/mes frente a las alternativas administradas, lo que mantiene
el proyecto dentro del presupuesto declarado sin recortar funcionalidad.

El análisis además obligó a costear las tres opciones con precios reales y
desmintió un supuesto presente en el propio documento maestro: que los VPC
endpoints son la salida económica al problema del NAT. En esta arquitectura son
la opción más cara.

### Lo que se pierde

**Responsabilidad operativa.** La instancia es infraestructura propia: parches
del sistema operativo, monitoreo y recuperación quedan a cargo del proyecto. Con
NAT Gateway o endpoints, eso es responsabilidad de AWS.

**Disponibilidad.** Una sola instancia es un punto único de falla: si muere,
ambas subredes privadas pierden toda salida hasta que se reemplace. Se mitiga
—no se elimina— colocándola en un Auto Scaling Group con `min = max = 1`, que la
reemplaza automáticamente al cabo de unos minutos. No es redundancia; es
auto-recuperación con interrupción.

**Resiliencia multi-AZ.** Al vivir en `us-east-1a`, una caída de esa zona deja
sin salida también a la subred privada de `us-east-1b`. El diseño multi-AZ queda
cubierto para cómputo pero no para conectividad. Se considera aceptable porque
`prod` corre con una sola tarea: una caída de AZ interrumpe el servicio de todos
modos.

**Postura de red.** El tráfico hacia ECR, CloudWatch y Secrets Manager sale a
internet público y vuelve por los endpoints públicos de esos servicios. Va
cifrado con TLS, pero no puede afirmarse que nunca abandona la red de AWS —una
propiedad que sí ofrecen los VPC endpoints y que resulta relevante en entornos
con requisitos de cumplimiento.

---

## Consecuencias

### A construir en Terraform antes de cerrar la Fase 1

- Instancia EC2 `t4g.nano` en la subred pública de `us-east-1a`, con AMI
  preparada para NAT (`fck-nat` o Amazon Linux con reenvío IP configurado).
- `source_dest_check = false` en la instancia. Sin esto el reenvío no funciona:
  EC2 descarta por defecto los paquetes que no tienen a la instancia como origen
  o destino.
- Security group que permita tráfico entrante únicamente desde los CIDR de las
  subredes privadas (`10.0.11.0/24`, `10.0.12.0/24`), nunca desde `0.0.0.0/0`.
- Route table propia para las subredes privadas, con ruta `0.0.0.0/0` apuntando
  a la interfaz de red de la instancia (`network_interface_id`, no `gateway_id`
  — el atributo difiere del usado con el IGW).
- Auto Scaling Group con `min = max = desired = 1` para reemplazo automático
  ante fallo.
- Endpoint Gateway de S3: es gratuito y reduce el tráfico que atraviesa el NAT,
  de modo que conviene aunque exista salida por instancia.

### Condiciones que obligarían a revisar esta decisión

- Que el tráfico saliente supere ~150 GB/mes: a partir de ahí el cargo por datos
  del NAT Gateway administrado empieza a compensar su costo fijo y la brecha se
  cierra.
- Que `prod` pase a correr más de una tarea o a tener disponibilidad como
  requisito real: el punto único de falla dejaría de ser aceptable.
- Que aparezca un requisito de cumplimiento que exija tráfico que no transite
  por internet público: en ese escenario los VPC endpoints pasan a ser la única
  opción válida, con independencia del costo.
- Que el mantenimiento de la instancia (parches, incidentes) consuma tiempo
  suficiente como para que los ~$25/mes de diferencia se justifiquen.

### Ajustes al documento maestro

- **D7** planteaba `fck-nat` como solución transitoria, "solo mientras dev está
  vivo". Esta decisión la extiende también a `prod` de forma permanente. El
  costo permanece dentro del techo declarado.
- **Sección 3** presenta los VPC endpoints como la alternativa económica frente
  al NAT Gateway. El costeo realizado aquí lo desmiente para esta arquitectura:
  cuatro endpoints Interface en dos AZs cuestan $58.40/mes, casi ocho veces la
  instancia NAT. La orientación original sigue siendo válida en arquitecturas
  con alto volumen de datos, donde el cargo por GB del NAT domina; no en esta.
