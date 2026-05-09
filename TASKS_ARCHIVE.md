# TASKS_ARCHIVE — ci4-kickstart

> Historial de tareas completadas.
> Última actualización: 2026-05-07

---

## ✅ Completadas

| ID | Descripción | Fecha |
|---|---|---|
| KICK-000 | `new-project.sh` v1.0.0 + v1.0.1: estable en macOS, Linux y Windows (WSL2). Clona api + admin desde GitHub, inicializa repos git, delega a `init.sh` y `install.sh`. Fix paths absolutos en v1.0.1. | 2026-05-03 |
| KICK-001 | Domain starter opcional en `new-project.sh`: 3 prompts nuevos (incluir domain, app code, port). Orquesta bootstrap hub completo: `apps:bootstrap --create-api-key`, `spark serve` background, login → JWT, `domain init.sh --skip-server` no-TTY. `cleanup_on_error` extendido. Docs sincronizadas: CLAUDE.md, README, AI prompts, CHANGELOG. | 2026-05-07 |

---

## ✅ Hardening new-project.sh + CI (2026-05-08)

| ID | Descripción | Estado |
|---|---|---|
| KICK-002a | `--reset-db` flag en `new-project.sh` — permite recuperarse de un setup parcial sin eliminar el directorio a mano. | ✅ |
| KICK-002b | Validación de prerrequisitos: PHP 8.2+, Composer 2.x, npm, mysql — con mensaje de error explícito y abort temprano. | ✅ |
| KICK-002c | CI: workflows de `release` (tag → GitHub Release) y `e2e` (smoke test del script completo). | ✅ |
| KICK-002d | PR template para el repo ci4-kickstart orientado a bash orchestrator. | ✅ |
| KICK-002e | Diagramas Mermaid en README (arquitectura + flujo) para reemplazar el diagrama ASCII. | ✅ |

---

*TASKS_ARCHIVE · ci4-kickstart · 2026-05-08*
