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

Para las preguntas que hace `init.sh` (en el API):
- Database host, user, password, name
- JWT_SECRET_KEY (generar automáticamente si no se proporciona)
- Credenciales del superadmin

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
```

Prueba accediendo a `http://localhost:{ADMIN_PORT}` e intenta:
1. Login con las credenciales del superadmin
2. Navegar a módulos (Usuarios, Archivos, Auditoría)
3. Crear un registro de prueba

### 5. Proporcionar Resumen

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
7. Mostrar resumen con credenciales y próximos pasos
```

**Duración estimada**: 5-10 minutos (depende de instalación de composer/npm)  
**Comandos requeridos**: `git`, `php`, `composer`, `npm`, `mysql` (o BD configurada)
