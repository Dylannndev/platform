## Fase actual: FASE 1 — Fundación: Terraform + red (en progreso)

## Completado
- Fase 0: entorno (WSL2 + herramientas), AWS (IAM + MFA + Budget $10),
  GitHub (SSH + 2 repos), app dummy verificada y pusheada.
- Bootstrap del state remoto (`platform/bootstrap/`): bucket S3
  `plataforma-interna-tfstate-3020` con versionado, cifrado AES256
  (SSE-S3) y acceso público bloqueado. State de este proyecto queda
  local a propósito (resuelve el problema de huevo-y-gallina: no se
  puede guardar el state del bucket dentro del bucket que aún no existe).
- `envs/dev/` conectado como backend remoto al bucket de bootstrap
  (`key = dev/terraform.tfstate`), con `default_tags` en el provider
  (Project/Environment=dev/ManagedBy) heredados por todo recurso nuevo.
- Módulo de red completo en `envs/dev/`, aplicado: VPC (`10.0.0.0/16`),
  4 subredes (públicas `10.0.1.0/24` y `10.0.2.0/24`, privadas
  `10.0.11.0/24` y `10.0.12.0/24`), emparejadas por AZ en `us-east-1a`
  y `us-east-1b`. Internet Gateway + 1 route table pública (ruta
  `0.0.0.0/0` → IGW) + 2 asociaciones. Las privadas quedan sin ruta de
  salida a internet a propósito — pendiente de ADR-001.
- Commit y push del repo `platform` con bootstrap + backend de dev
  (`.gitignore` cubriendo `.terraform/`, `*.tfstate`, `*.tfvars`).

## Decisiones fuera del documento maestro
- La app dummy no es un stub trivial: receptor de webhooks con HMAC,
  anti-replay y endpoints de operación protegidos. Razón: el secreto de
  Secrets Manager (Fase 3) pasa a ser necesario de verdad, y el tráfico
  a ráfagas le da sustancia real a los SLOs de la Fase 4.
- Sin tabla DynamoDB para state locking: Terraform 1.15.8 soporta lock
  nativo en S3 (`use_lockfile = true`), estable desde la 1.11. Una
  pieza menos que mantener, sin costo adicional. El documento maestro
  (Sección 2/4) menciona DynamoDB; ese punto queda obsoleto por versión.
- Convención `Environment = "global"` para recursos compartidos entre
  ambientes (no son ni dev ni prod) — usada en el bucket de bootstrap.
  Amplía la convención original de Sección 3 (`dev | prod`).

## Pendiente inmediato
- ADR-001: salida a internet de las subredes privadas (NAT Gateway
  administrado ~$32/mes, instancia fck-nat ~$3/mes, o VPC endpoints).
  Se retoma con números reales, próxima sesión.

## Ojo con esto
- Node no está instalado en WSL; los comandos npm corren dentro de un
  contenedor descartable de node:22.11.0-alpine3.20.
- Email principal de GitHub: falta marcar el personal como "Primary".
