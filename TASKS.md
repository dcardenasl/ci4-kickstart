# TASKS — ci4-kickstart

> Fuente de verdad para trabajo en este repo.
> Gestionado desde Cowork/VentureOS. Ejecutado desde Claude Code.
> Última actualización: 2026-05-06

---

## 🔴 En progreso

*(vacío — ninguna tarea activa)*

---

## 🟡 Próximo (ordenado por prioridad)

*(vacío — KICK-001 bloqueado, ver abajo)*

---

## ⏳ Bloqueadas

*(vacío)*

---

## ⚪ Backlog

- [KICK-002] Script de actualización de proyectos existentes — `update-project.sh` que aplica patches de versiones nuevas del kit a proyectos ya creados
- [KICK-003] Soporte para múltiples domain starters en `new-project.sh` — permitir añadir N domain apps al scaffolding inicial
- [KICK-004] Template de prompts para IA actualizados para incluir domain starter en flujo de onboarding

---

## ✅ Completadas recientes

- **[KICK-001] Domain starter opcional en `new-project.sh`** (2026-05-07) — `new-project.sh` ofrece tres prompts nuevos: incluir domain (`y/N`), application code (`{name}-domain`), domain port (`8090`). Si y, clona `ci4-domain-starter` desde GitHub como tercer repo, y entre el `init.sh` del API y el `install.sh` del Admin orquesta el bootstrap del hub: corre `apps:bootstrap <code> --create-api-key` (consume API-007 en api-starter), captura `API_KEY=apk_...` con awk, levanta `php spark serve --port 8080` en background, hace login con `CI4_SA_EMAIL`/`CI4_SA_PASSWORD` para capturar el JWT, exporta `CI4_DOMAIN_*` env vars, corre `domain init.sh --skip-server` no-TTY, y mata el proceso del hub. `cleanup_on_error` extendido con `HUB_PID` kill + `DOMAIN_DIR` rm. `domain init.sh` modificado para respetar env vars (`CI4_DOMAIN_HUB_URL`, `_APP_CODE`, `_API_KEY`, `_ADMIN_TOKEN`, `_DB_*`) cuando se invoca no-TTY. Docs sincronizadas: CLAUDE.md, README.md, AI_NEW_PROJECT_PROMPT.{en,es}.md, CHANGELOG.md.
- **[KICK-000] v1.0.0 + v1.0.1** (2026-05-03) — `new-project.sh` estable en macOS, Linux y Windows (WSL2). Clona api + admin desde GitHub, inicializa repos git, delega a `init.sh` y `install.sh`. Fix paths absolutos en v1.0.1.

---

## 🏗️ Contratos de arquitectura

> Restricciones que se deben respetar siempre al tocar este repo. No negociables.

- **Scripts bash puro** — sin dependencias externas más allá de `git`, `composer`, `node/npm`. Funcionar en macOS, Linux y Windows (WSL2) sin instalaciones adicionales.
- **Siempre probar en los 3 entornos** antes de considerar un script completo.
- **`new-project.sh` es el entry point principal** — mantener retrocompatibilidad. Cambios breaking requieren nota en el README.
- **Clonar desde GitHub** (no copiar local) — `new-project.sh` usa `git clone` de los repos públicos. Los paths locales son solo para desarrollo del kit en sí.
- **Prompts de IA**: los archivos `AI_NEW_PROJECT_PROMPT.{en,es}.md` deben mantenerse sincronizados con los cambios en `new-project.sh`.
