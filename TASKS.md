# TASKS — ci4-kickstart

> Fuente de verdad para trabajo en este repo.
> Historial de completadas: ver `TASKS_ARCHIVE.md`.
> Cross-repo: ver `../TASKS.md`.
> Última actualización: 2026-05-07

---

## 🔴 En progreso

*(vacío)*

---

## 🟡 Próximo

- **[CORE-007]** Actualizar referencias en `new-project.sh` y AI prompts (`AI_NEW_PROJECT_PROMPT.{en,es}.md`) para reflejar `dcardenasl/ci4-api-core` v1.0.0 publicado en Packagist. Bloqueado por CORE-006 (publicación).

---

## ⚪ Backlog

- [KICK-002] Script de actualización `update-project.sh` — aplica patches de versiones nuevas del kit a proyectos ya creados
- [KICK-003] Soporte múltiples domain starters en `new-project.sh` — permitir N domain apps en el scaffolding inicial
- [KICK-004] AI prompts actualizados para incluir domain starter en flujo de onboarding

---

## 🏗️ Contratos de arquitectura

- **Scripts bash puro** — sin dependencias externas más allá de `git`, `composer`, `node/npm`. Funcionar en macOS, Linux y Windows (WSL2).
- **Siempre probar en los 3 entornos** antes de considerar un script completo.
- **`new-project.sh` es el entry point principal** — mantener retrocompatibilidad. Cambios breaking requieren nota en el README.
- **Clonar desde GitHub** (no copiar local) — `new-project.sh` usa `git clone` de los repos públicos.
- **AI prompts sincronizados:** `AI_NEW_PROJECT_PROMPT.{en,es}.md` deben reflejar siempre el estado actual de `new-project.sh`.
