## Fase actual: FASE 1 — Fundación: Terraform + red (en progreso)

## Completado
- Fase 0: entorno (WSL2 + herramientas), AWS (IAM + MFA + Budget $10),
  GitHub (SSH + 2 repos), app dummy verificada y pusheada.
- Bootstrap del state remoto (`platform/bootstrap/`): bucket S3
  `plataforma-interna-tfstate-3020` con versionado, cifrado AES256
  (SSE-S3) y acceso público bloqueado. El state de este proyecto queda
  local a propósito (resuelve el problema de huevo-y-gallina: no se
  puede guardar el state del bucket dentro del bucket que aún no existe).
- `envs/dev/` conectado como backend remoto al bucket de bootstrap
  (`key = dev/terraform.tfstate`), con `default_tags` en el provider
  (Project / Environment=dev / ManagedBy) heredados por todo recurso nuevo.
- Red completa aplicada: VPC (`10.0.0.0/16`), 4 subredes (públicas
  `10.0.1.0/24` y `10.0.2.0/24`, privadas `10.0.11.0/24` y `10.0.12.0/24`)
  emparejadas por AZ en `us-east-1a` y `us-east-1b`, Internet Gateway,
  route table pública (`0.0.0.0/0` → IGW) con sus 2 asociaciones.
- ADR-001 escrita, decidida e implementada: instancia NAT `t4g.micro` con
  AMI de `fck-nat` en la subred pública de `us-east-1a`, `source_dest_check`
  desactivado, security group restringido a los CIDR privados, route table
  privada apuntando a su interfaz de red, y sus 2 asociaciones. Las
  subredes privadas ya tienen salida a internet.
- Refactor a módulo: toda la red vive ahora en `modules/network/`
  (`main.tf`, `variables.tf` con 6 variables, `outputs.tf`). `envs/dev/`
  solo invoca el módulo con valores explícitos. La migración implicó
  destruir y recrear los 13 recursos existentes (cambiaron de dirección
  en el state: `aws_vpc.x` → `module.network.aws_vpc.x`), así que todos
  los IDs de AWS son nuevos respecto a sesiones anteriores.

## Decisiones fuera del documento maestro
- La app dummy no es un stub trivial: receptor de webhooks con HMAC,
  anti-replay y endpoints de operación protegidos. Razón: el secreto de
  Secrets Manager (Fase 3) pasa a ser necesario de verdad, y el tráfico
  a ráfagas le da sustancia real a los SLOs de la Fase 4.
- Sin tabla DynamoDB para state locking: Terraform 1.15.8 soporta lock
  nativo en S3 (`use_lockfile = true`), estable desde la 1.11. Una pieza
  menos que mantener, sin costo adicional. El documento maestro
  (Sección 2/4) menciona DynamoDB; ese punto queda obsoleto por versión.
- Convención `Environment = "global"` para recursos compartidos entre
  ambientes (no son ni dev ni prod) — usada en el bucket de bootstrap.
  Amplía la convención original de Sección 3 (`dev | prod`).
- Instancia NAT `t4g.micro` en lugar de `t4g.nano`: la `nano` no es
  elegible para free tier y el plan Free de la cuenta rechaza su creación.
  Ver ADR-001 para el análisis completo. La `micro` conserva ARM64, así
  que la AMI de `fck-nat` no cambia.
- ADR-001 extiende `fck-nat` a `prod` de forma permanente, no solo a `dev`
  (D7 lo planteaba como transitorio).

## Pendiente inmediato (cierre de Fase 1)
- Auto Scaling Group con `min = max = desired = 1` para la instancia NAT.
- Endpoint Gateway de S3 (gratuito, reduce tráfico por el NAT).
- Verificar funcionalmente que una subred privada alcanza internet a
  través del NAT — configurado no es lo mismo que funcionando.
- `terraform destroy` + `apply` limpios dos veces seguidas (criterio de
  salida de la fase, base de D6).
- Diagrama de red en el README del repo `platform`.

## Ojo con esto
- **Plan Free de AWS**: la cuenta no puede exceder los límites del free
  tier; los recursos no elegibles son rechazados por la API, no
  facturados. El plan termina a los 6 meses de crear la cuenta o al
  agotar los créditos ($100 de alta + hasta $100 adicionales por
  actividades), lo que ocurra primero. Esto es una restricción de diseño
  dura, no una guía de costos.
- **Correr `terraform destroy` al terminar cada sesión** (D6). La
  instancia NAT y todo lo demás son cargos por hora; dejarlos vivos
  consume free tier sin dar nada a cambio.
- Node no está instalado en WSL; los comandos npm corren dentro de un
  contenedor descartable de `node:22.11.0-alpine3.20`.
- Email principal de GitHub: falta marcar el personal como "Primary".