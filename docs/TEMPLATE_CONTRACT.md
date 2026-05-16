# Template Contract — ci4-kickstart

> Versión del contrato: **1.0**
> Última actualización: 2026-05-16

---

## Qué es un domain template

Un **domain template** es un repositorio `ci4-domain-starter` pre-construido con lógica de negocio real. En lugar de clonar el domain-starter vanilla y scaffoldear entidades con `make:crud`, `new-project.sh` clona el template directamente y lo inicializa con el mismo `init.sh` estándar.

El template declara su contrato en un archivo `template.json` en la raíz del repo. `new-project.sh` lee ese archivo después de clonar para configurar el resto del stack (módulos de admin, BFF si corresponde, etc.).

---

## Dos archivos, dos responsabilidades

| Archivo | Dónde vive | Para qué sirve |
|---|---|---|
| `ci4-kickstart/templates.json` | Repo kickstart | Catálogo de templates disponibles — se muestra en el menú de selección |
| `[repo-del-template]/template.json` | Raíz de cada template repo | Contrato completo — entidades, permisos, módulos admin, configuración |

El flujo: `templates.json` le dice a `new-project.sh` qué repos existen → usuario elige → kickstart clona el repo → lee `template.json` → configura el stack.

---

## Especificación de `template.json`

### Campos obligatorios

```json
{
  "name": "string",
  "slug": "string",
  "version": "string",
  "entities": [],
  "permissions": [],
  "admin_modules": []
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `name` | string | Nombre legible para humanos. Ej: `"Multi-Subscription Domain"` |
| `slug` | string | Identificador máquina, snake-case. Debe coincidir con el sufijo del repo. Ej: `"domain-multi-subscriptions"` |
| `version` | string | Semver del template. Ej: `"1.0.0"` |
| `entities` | array | Entidades del dominio. Ver esquema abajo. |
| `permissions` | array | Permisos a registrar vía `domain:sync-permissions`. Formato: `"recurso.accion"` con punto como separador. |
| `admin_modules` | array | Módulos a generar en `ci4-admin-starter` con `make-module.sh`. Ver esquema abajo. |

#### Esquema de `entities[]`

```json
{
  "name": "Plan",
  "table": "plans",
  "description": "Opcional — descripción breve para el skill"
}
```

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `name` | string | ✅ | PascalCase. Ej: `"Plan"`, `"BillingCycle"` |
| `table` | string | ✅ | snake_case. Ej: `"plans"`, `"billing_cycles"` |
| `description` | string | ❌ | Ayuda al skill a hacer template matching. |

#### Esquema de `permissions[]`

Array de strings. Formato: `"recurso.accion"`. Separador obligatorio: punto (`.`), no dos puntos.

```json
[
  "plans.read",
  "plans.write",
  "plans.delete",
  "subscriptions.read",
  "subscriptions.write",
  "subscriptions.cancel"
]
```

#### Esquema de `admin_modules[]`

```json
{
  "name": "Plans",
  "entity": "Plan",
  "service": "domain"
}
```

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `name` | string | ✅ | Nombre del módulo en el panel. Ej: `"Plans"` |
| `entity` | string | ✅ | Entidad que gestiona. Debe estar en `entities[]`. |
| `service` | string | ✅ | `"hub"` o `"domain"` — determina qué cliente HTTP usa `make-module.sh`. |

---

### Campos opcionales

```json
{
  "description": "string",
  "keywords": [],
  "domain_category": "string",
  "requires_bff": false,
  "public_endpoints": [],
  "init_env": {}
}
```

| Campo | Tipo | Default | Descripción |
|---|---|---|---|
| `description` | string | `""` | Descripción del template. Aparece en el menú de selección y en el skill. |
| `keywords` | array de strings | `[]` | Palabras clave para template matching en el skill `ci4-new-project`. Ej: `["saas", "billing", "subscriptions"]` |
| `domain_category` | string | `""` | Categoría de negocio. Ej: `"billing"`, `"cms"`, `"ecommerce"`, `"auth"`. Para agrupar templates en el catálogo. |
| `requires_bff` | boolean | `false` | Si `true`, `new-project.sh` sugiere activar el BFF cuando se selecciona este template. |
| `public_endpoints` | array de strings | `[]` | Patrones de ruta que el BFF debe exponer sin autenticación. Solo relevante si `requires_bff: true`. Ej: `["/api/v1/plans", "/api/v1/plans/*"]` |
| `init_env` | object | `{}` | Variables de entorno adicionales que `init.sh` del template necesita, más allá del set estándar. Clave: nombre de la variable; valor: hint o default. Ej: `{ "STRIPE_KEY": "sk_test_..." }` |

---

## Especificación de `templates.json` (catálogo del kickstart)

Objeto wrapper con un campo `templates` que contiene el array de entradas. El wrapper deja espacio para metadata futura (versión del esquema, comentarios) sin romper a los consumidores.

```json
{
  "$schema_doc": "See docs/TEMPLATE_CONTRACT.md for the full templates.json contract.",
  "$comment": "Empty catalog. Add template entries here when their repos are published.",
  "templates": [
    {
      "slug": "domain-multi-subscriptions",
      "repo": "dcardenasl/domain-multi-subscriptions",
      "name": "Multi-Subscription Domain",
      "description": "SaaS subscription management: plans, subscriptions, billing cycles, invoices.",
      "keywords": ["subscriptions", "billing", "saas", "plans", "invoices"]
    }
  ]
}
```

Los consumidores leen el catálogo con `jq '.templates'` (o `jq '.templates[] | ...'` para iterar). Un catálogo vacío es `{ "templates": [] }`.

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `slug` | string | ✅ | Debe coincidir con el `slug` en el `template.json` del repo. |
| `repo` | string | ✅ | `owner/repo` de GitHub. Kickstart clona `https://github.com/{repo}`. |
| `name` | string | ✅ | Nombre para el menú interactivo. |
| `description` | string | ✅ | Una línea. Se muestra bajo el nombre en el menú. |
| `keywords` | array | ❌ | Copia de los keywords del template — para que el skill pueda hacer matching sin clonar. |

> **Nota de sincronización:** `keywords` en `templates.json` es una copia de lo que está en `template.json` del repo. Si el template actualiza sus keywords, hay que actualizar el catálogo también. Esto se documenta en el proceso de publicación de templates (TMPL-005).

---

## Ejemplo completo — `domain-multi-subscriptions`

```json
{
  "name": "Multi-Subscription Domain",
  "slug": "domain-multi-subscriptions",
  "version": "1.0.0",
  "description": "Domain app para gestión de suscripciones SaaS: planes, suscripciones, ciclos de facturación e invoices.",
  "keywords": ["subscriptions", "billing", "saas", "plans", "invoices", "mrr", "stripe"],
  "domain_category": "billing",
  "requires_bff": false,
  "entities": [
    { "name": "Plan",         "table": "plans",          "description": "Planes de suscripción disponibles" },
    { "name": "Subscription", "table": "subscriptions",   "description": "Suscripción activa de un usuario a un plan" },
    { "name": "BillingCycle", "table": "billing_cycles",  "description": "Ciclo de facturación de una suscripción" },
    { "name": "Invoice",      "table": "invoices",        "description": "Invoice generado por un ciclo de facturación" }
  ],
  "permissions": [
    "plans.read", "plans.write", "plans.delete",
    "subscriptions.read", "subscriptions.write", "subscriptions.cancel",
    "billing-cycles.read",
    "invoices.read", "invoices.write"
  ],
  "admin_modules": [
    { "name": "Plans",         "entity": "Plan",         "service": "domain" },
    { "name": "Subscriptions", "entity": "Subscription", "service": "domain" },
    { "name": "Invoices",      "entity": "Invoice",      "service": "domain" }
  ],
  "public_endpoints": [],
  "init_env": {}
}
```

---

## Cómo usa `new-project.sh` el contrato

Después de que el usuario selecciona un template:

1. Kickstart clona el repo del template en lugar de `ci4-domain-starter` vanilla.
2. Lee `template.json` del repo clonado.
3. Si `requires_bff: true` → activa automáticamente `CI4_INCLUDE_BFF=y` (o sugiere al usuario).
4. Corre `init.sh` del repo clonado — mismo proceso que domain-starter vanilla.
5. Con el output de `apps:bootstrap` + `domain:sync-permissions`:
   - Registra los `permissions[]` en el hub.
6. Para cada módulo en `admin_modules[]`:
   - Corre `make-module.sh --service={service} {entity}` en `ci4-admin-starter`.
7. Si `public_endpoints[]` no está vacío + BFF activo:
   - Agrega las rutas al BFF como endpoints sin filtro de auth.

---

## Cómo usa el skill `ci4-new-project` el contrato

El skill lee `ci4-kickstart/templates.json` (o lo recibe pre-cargado) y hace **template matching** contra el brief del usuario:

```
score = intersección(brief_entities, template.entities) / len(template.entities)
threshold = 0.6  →  si score ≥ 0.6, proponer el template
```

Los `keywords` de cada template se incluyen en el matching. Si ningún template supera el threshold, el skill opera en modo vanilla sin informar al usuario.

---

## Validación mínima antes de publicar un template

Un template es compatible con el contrato si:

- [ ] `template.json` existe en la raíz del repo
- [ ] Todos los campos obligatorios presentes y no vacíos
- [ ] `slug` es snake-case y coincide con el sufijo del nombre del repo
- [ ] Cada `entity.name` es PascalCase
- [ ] Cada permiso en `permissions[]` usa punto como separador (no dos puntos)
- [ ] Cada `admin_modules[].service` es `"hub"` o `"domain"`
- [ ] El repo tiene `init.sh` en la raíz y es ejecutable
- [ ] `init.sh` respeta las mismas env vars estándar que `ci4-domain-starter/init.sh`

> El proceso de publicación de templates (TMPL-005) documentará cómo agregar un template al catálogo del kickstart.
