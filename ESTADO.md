## Fase actual: FASE 1 — Fundación: Terraform + red (por arrancar)

## Completado
- Fase 0: entorno (WSL2 + herramientas), AWS (IAM + MFA + Budget $10),
  GitHub (SSH + 2 repos), app dummy verificada y pusheada.

## Decisiones fuera del documento maestro
- La app dummy no es un stub trivial: receptor de webhooks con HMAC,
  anti-replay y endpoints de operación protegidos. Razón: el secreto de
  Secrets Manager (Fase 3) pasa a ser necesario de verdad, y el tráfico
  a ráfagas le da sustancia real a los SLOs de la Fase 4.

## Ojo con esto
- Node no está instalado en WSL; los comandos npm corren dentro de un
  contenedor descartable de node:22.11.0-alpine3.20.
- Email principal de GitHub: falta marcar el personal como "Primary".
