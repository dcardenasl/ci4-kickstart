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

### [KICK-001] Actualizar `new-project.sh` para incluir domain starter opcional
**Bloqueado por:** DOM-002 (ci4-domain-starter debe estar funcional primero)
**Ver especificación completa en:** `../TASKS.md` sección DOM-001

**Objetivo:** Que `new-project.sh` ofrezca al usuario incluir un ci4-domain-starter como componente opcional al crear un nuevo proyecto.

**Criterios de aceptación (preliminares):**
- [ ] `new-project.sh` pregunta: "¿Incluir domain starter? (s/N)"
- [ ] Si sí: clona `ci4-domain-starter`, configura `.env` apuntando al hub recién creado, corre `init.sh` del domain starter
- [ ] Si no: flujo actual sin cambios
- [ ] Compatible con macOS, Linux y Windows (WSL2)

---

## ⚪ Backlog

- [KICK-002] Script de actualización de proyectos existentes — `update-project.sh` que aplica patches de versiones nuevas del kit a proyectos ya creados
- [KICK-003] Soporte para múltiples domain starters en `new-project.sh` — permitir añadir N domain apps al scaffolding inicial
- [KICK-004] Template de prompts para IA actualizados para incluir domain starter en flujo de onboarding

---

## ✅ Completadas recientes

- **[KICK-000] v1.0.0 + v1.0.1** (2026-05-03) — `new-project.sh` estable en macOS, Linux y Windows (WSL2). Clona api + admin desde GitHub, inicializa repos git, delega a `init.sh` y `install.sh`. Fix paths absolutos en v1.0.1.

---

## 🏗️ Contratos de arquitectura

> Restricciones que se deben respetar siempre al tocar este repo. No negociables.

- **Scripts bash puro** — sin dependencias externas más allá de `git`, `composer`, `node/npm`. Funcionar en macOS, Linux y Windows (WSL2) sin instalaciones adicionales.
- **Siempre probar en los 3 entornos** antes de considerar un script completo.
- **`new-project.sh` es el entry point principal** — mantener retrocompatibilidad. Cambios breaking requieren nota en el README.
- **Clonar desde GitHub** (no copiar local) — `new-project.sh` usa `git clone` de los repos públicos. Los paths locales son solo para desarrollo del kit en sí.
- **Prompts de IA**: los archivos `AI_NEW_PROJECT_PROMPT.{en,es}.md` deben mantenerse sincronizados con los cambios en `new-project.sh`.
