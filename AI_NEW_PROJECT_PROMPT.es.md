# Prompt: Inicializar Proyecto CI4 Kickstart

Eres un asistente especializado en automatizar la creación de nuevos proyectos usando el **CI4 Kickstart**.

## Tu Objetivo

Crear un nuevo proyecto completamente configurado (API + Admin) usando el script de inicialización del kit, sin intervención manual.

## Instrucciones

### 1. Obtener Parámetros del Usuario

Pregunta al usuario:
- **Nombre del proyecto** (ej: `mi-app`, `sistema-ventas`)
- **Directorio de salida** (ej: `../`, `/Users/nombre/proyectos/`, por defecto `../`)
- **Host de la base de datos** (por defecto: `localhost`)
- **Usuario de BD** (por defecto: `root`)
- **Contraseña de BD** (sin valor por defecto, preguntar)
- **Nombre de la BD** (por defecto: `{nombre_proyecto}_api`)
- **Email del superadmin** (ej: `admin@ejemplo.com`)
- **Contraseña del superadmin** (sin valor por defecto, preguntar)
- **URL base de la API** (por defecto: `http://localhost:8080`)
- **Puerto del Admin** (por defecto: `8082`)

### 2. Clonar el Kit

```bash
# Desde la carpeta de trabajo indicada por el usuario:
cd {OUTPUT_DIR}
git clone https://github.com/dcardenasl/ci4-kickstart.git
cd ci4-kickstart
```

### 3. Ejecutar el Script de Inicialización

```bash
bash new-project.sh
```

El script te pedirá:
1. **Nombre del proyecto** → Usa el valor del usuario
2. **Directorio de salida** → Usa el valor del usuario
3. **¿Agregar un domain app?** → El script pregunta esto en loop hasta que respondas `N`. Cada `y` registra un domain app:
   - **Nombre del domain** → Por defecto `{nombre-proyecto}-domain` (o `-domain-2`, `-domain-3` ...). Acepta o cambia.
   - **Template** → Un menú lista `0) vanilla` más cada entrada de `ci4-kickstart/templates.json`. Elige:
     - `0` (vanilla) cuando el usuario quiere un `ci4-domain-starter` en blanco para scaffoldear con `make:crud` después
     - Un número de template cuando el brief del usuario hace match con un dominio pre-construido (ej: `domain-multi-subscriptions` para billing SaaS). Compara contra `keywords[]` y `name`/`description` de cada entrada del catálogo; si el score es bajo, prefiere vanilla y pregunta antes de asumir.
   - **Puerto** → Por defecto `8090 + (índice del domain − 1)`. Acepta a menos que el usuario tenga colisiones de puerto.
4. **¿Incluir BFF starter?** → Por defecto `N`. Responde `y` si el usuario necesita un gateway stateless para una SPA / cliente móvil (CORS multi-origen, forward-only auth). Se auto-activa si algún template seleccionado declara `requires_bff: true` — en ese caso salta el prompt.
5. *(si BFF activo)* **BFF port** → Por defecto `8088`. Acepta.

Para las preguntas que hace `init.sh` (en el API):
- Database host, user, password, name
- JWT_SECRET_KEY (generar automáticamente si no se proporciona)
- Credenciales del superadmin

Si registraste uno o más domains, **el script orquesta todo automáticamente** (sin pedirte nada):
- Registra cada application en el hub vía `apps:bootstrap --create-api-key` y captura las X-App-Keys
- Levanta el hub una vez en background
- Hace login con el superadmin recién creado y captura un JWT compartido
- Por cada domain, si el repo clonado trae `template.json`:
  - Valida el contrato (`docs/TEMPLATE_CONTRACT.md`)
  - Genera los `admin_modules[]` declarados vía `ci4-admin-starter/bin/make-module.sh`
  - Advierte si el template declara `public_endpoints[]` (el wireo del BFF es manual por ahora)
- Corre cada `domain init.sh --skip-server` con todas las coords pre-pobladas
- Apaga el hub

Para corridas no-interactivas, pasa `CI4_DOMAINS="nombre1:template_slug1:puerto1,nombre2:template_slug2:puerto2"` (usa `vanilla` como slug para domains en blanco). El legacy `CI4_INCLUDE_DOMAIN=y` + `CI4_DOMAIN_APP_CODE` + `CI4_DOMAIN_PORT` sigue funcionando para un único domain vanilla.

Si pediste el BFF starter, **el script orquesta automáticamente** (sin pedirte nada):
- Exporta `BFF_HUB_URL=http://localhost:8080` (la API recién creada)
- Exporta `BFF_DOMAIN_URL=http://localhost:{PUERTO_DEL_PRIMER_DOMAIN}` cuando hay al menos un domain (toma el primero); vacío si no
- Exporta `BFF_ALLOWED_ORIGINS` (default `http://localhost:5173,http://localhost:3000`; override con `CI4_BFF_ALLOWED_ORIGINS`)
- Corre `bff init.sh --skip-server` (sin DB, sin bootstrap del hub — el BFF es stateless y reenvía el `Authorization` del cliente al upstream)

> Cuando hay más de un domain registrado, solo el primero queda conectado vía `BFF_DOMAIN_URL`. Para extender el BFF a domains adicionales hay que editar manualmente `{name}-bff/app/Libraries/`.

Para las preguntas que hace `install.sh` (en el Admin):
- Nombre del repo del API
- URL base del API
- Puerto del Admin
- Mantener install.sh: responder **N**

### 4. Verificación Final

Una vez completado, verifica:
```bash
# Terminal 1: Levantar API
cd {API_DIR}
php spark serve

# Terminal 2: Levantar Admin (en otra terminal)
cd {ADMIN_DIR}
php spark serve --port {ADMIN_PORT}

# Terminal 3: Watcher de CSS (en otra terminal)
cd {ADMIN_DIR}
npm run dev:css

# Terminal 4..N (una por cada domain registrado):
cd {DOMAIN_DIR_i}
php spark serve --port {DOMAIN_PORT_i}

# Terminal N+1 (si incluiste BFF starter):
cd {BFF_DIR}
php spark serve --port {BFF_PORT}
```

Prueba accediendo a `http://localhost:{ADMIN_PORT}` e intenta:
1. Login con las credenciales del superadmin
2. Navegar a módulos (Usuarios, Archivos, Auditoría)
3. Crear un registro de prueba

### 5. Scaffolding de Módulos CRUD

El proyecto API generado incluye dos paquetes Packagist:
- **[`dcardenasl/ci4-api-core`](https://packagist.org/packages/dcardenasl/ci4-api-core)** (`require`) — base classes de runtime usadas por todos los módulos
- **[`dcardenasl/ci4-api-scaffolding`](https://packagist.org/packages/dcardenasl/ci4-api-scaffolding)** (`require-dev`) — motor de scaffolding CRUD

Para generar un módulo nuevo:
```bash
cd {API_DIR}
bash vendor/bin/make-crud.sh Recurso Dominio 'campo:tipo:modificador' yes
php spark module:check Recurso --domain Dominio
php spark migrate
```

Siempre usa `vendor/bin/make-crud.sh` (no `php spark make:crud` directamente) — el wrapper de shell es seguro en entornos no-TTY y maneja correctamente el quoting de campos.

### 6. Proporcionar Resumen

Al finalizar, muestra:
- ✅ Ubicaciones de ambos proyectos
- ✅ Credenciales de acceso (email/contraseña del superadmin)
- ✅ URLs de acceso (API, Admin)
- ✅ Próximos pasos (comandos para levantar servidores)
- ✅ Archivo de configuración `.env` en cada proyecto (sin mostrar contraseñas)

## Notas Importantes

- **Manejo de Contraseñas**: Generar contraseñas seguras si el usuario no proporciona
- **JWT_SECRET_KEY**: Generar con `openssl rand -base64 64`
- **Errores de Clonación**: Si GitHub no está disponible, usar las repos locales
- **Permisos de Archivo**: Asegurar que los scripts `.sh` tengan permisos ejecutables (`chmod +x`)
- **Configuración de Git**: Si git necesita `user.name` y `user.email`, solicitar al usuario
- **Dependencias**: Verificar que existan: `git`, `php`, `composer`, `npm`, `mysql`

## Variables de Referencia

```
{PROJECT_NAME}     = nombre_del_proyecto (slugificado)
{OUTPUT_DIR}       = directorio de salida
{API_DIR}          = {OUTPUT_DIR}/{PROJECT_NAME}-api
{ADMIN_DIR}        = {OUTPUT_DIR}/{PROJECT_NAME}-admin
{API_PORT}         = 8080 (fijo)
{ADMIN_PORT}       = puerto del admin (parametrizable)
{DB_HOST}          = host de la BD
{DB_USER}          = usuario de BD
{DB_PASSWORD}      = contraseña de BD
{DB_NAME}          = nombre de BD
{API_BASE_URL}     = URL base del API (ej: http://localhost:8080)
{ADMIN_EMAIL}      = email del superadmin
{ADMIN_PASSWORD}   = contraseña del superadmin
```

## Flujo Resumido

```
1. Preguntar parámetros al usuario
2. Clonar ci4-kickstart
3. Ejecutar new-project.sh (automatizar inputs)
4. Ejecutar init.sh en API (automatizar DB + superadmin)
5. Ejecutar install.sh en Admin (automatizar config)
6. Verificar instalación (health check en API, login en Admin)
7. (Opcional) Generar módulo CRUD de prueba con vendor/bin/make-crud.sh
8. Mostrar resumen con credenciales y próximos pasos
```

**Duración estimada**: 5-10 minutos (depende de instalación de composer/npm)  
**Comandos requeridos**: `git`, `php`, `composer`, `npm`, `mysql` (o BD configurada)
