# Estado del Proyecto

Última actualización: 2026-07-24

## Fase actual: FASE 0 — Preparación (casi completa)

### Completado
- [x] MFA activado en root
- [x] Usuario IAM `dylan-admin` creado, grupo `Admins` con `AdministratorAccess`
- [x] MFA activado en `dylan-admin`
- [x] AWS Budgets: $10/mes, alertas 85% / 100% / proyectado
- [x] AWS CLI configurado en WSL con `dylan-admin` (región us-east-1, output json)
- [x] SSH configurado entre WSL y GitHub
- [x] Repos `platform` y `sample-app` creados (públicos) y clonados en
      `~/proyectos/plataforma-interna/`

### Pendiente (para cerrar Fase 0)
- [ ] Activar integración Docker Desktop <-> WSL
- [ ] Generar app dummy (TypeScript + Fastify) vía Claude Code, según D3
- [ ] Probar app local: /health, /work, /crash, /, docker build

## Decisiones tomadas fuera del documento maestro
(ninguna todavía — todo lo hecho hasta ahora es configuración base, no
decisiones de arquitectura; las ADRs arrancan en Fase 1)

## Notas / cosas a revisar más adelante
- Email principal de GitHub: personal ya verificado, falta marcarlo como
  "Primary" cuando se quiera
