# REDMOOT

Sitio inmobiliario para Cali con fichas individuales, catálogo conectado a Supabase, agenda de visitas y panel privado de administración en `/admin`.

## Conectar Supabase

1. Creá un proyecto en Supabase.
2. En **Authentication → Sign In / Providers**, habilitá Email/Password. En **Authentication → Users**, creá el usuario administrador con el UUID `eccc1615-3791-405f-a866-9a2a62f0ea2e` en este mismo proyecto.
3. En **SQL Editor**, ejecutá `supabase.sql`. Crea las tablas, el bucket de imágenes, las políticas, carga cuatro propiedades de muestra y autoriza ese UUID. El usuario de Auth debe existir antes de correr el script.
4. Abrí `config.js`. En `REDMOOT_SUPABASE_URL` pegá la Project URL y en `REDMOOT_SUPABASE_PUBLISHABLE_KEY` pegá la clave publishable del proyecto (la clave pública). Ambas están en **Connect** o **Settings → API Keys**.

La clave publishable está diseñada para el navegador y las reglas de Row Level Security limitan los datos que puede leer o cambiar cada usuario. Nunca pongas una clave `secret` o `service_role` en `config.js` ni en el frontend. Supabase recomienda usar claves publishable en el frontend con RLS activa ([seguridad de datos de Supabase](https://supabase.com/docs/guides/database/secure-data)).

## Entrar y usar el panel

Una vez desplegado, abrí `https://TU-DOMINIO.vercel.app/admin` e ingresá con el email y la contraseña del usuario autorizado en `admin_users`. El panel permite crear, editar, publicar u ocultar propiedades; subir imágenes a Supabase Storage; revisar citas y cambiar su estado; y revisar las consultas recibidas. Si el usuario inicia sesión pero no figura en `admin_users`, el panel le deniega el acceso.

Las propiedades publicadas se leen desde `properties`. Las reservas se guardan en `appointments` con propiedad, fecha y horario; aparecen inicialmente como `pending` y el equipo confirma o cancela la cita desde el panel. Las solicitudes de publicación se guardan en `property_inquiries` y los mensajes en `contact_inquiries`.

## Desplegar en Vercel

1. Subí la carpeta `redmoot` a un repositorio de Git o conectá el repositorio que la contiene.
2. En Vercel, importá el repositorio. Si el repositorio contiene otras carpetas, configurá **Root Directory** en `outputs/redmoot` (o en la carpeta `redmoot` si la subiste sola).
3. Elegí el preset **Other**. No hace falta comando de compilación; usá `.` como directorio de salida.
4. Desplegá. El archivo `vercel.json` reescribe `/admin` a la página del panel sin cambiar la dirección que ve el usuario ([rewrites de Vercel](https://vercel.com/docs/routing/rewrites)).
5. Comprobá la página principal y `https://TU-DOMINIO.vercel.app/admin` después del despliegue.

`config.js` se sirve al navegador, por eso contiene únicamente la URL y la clave publishable. La seguridad real del panel la aplican Supabase Auth y las políticas de RLS, no el hecho de que la ruta sea difícil de adivinar.

## Antes de lanzar

- Cambiá el teléfono de WhatsApp y correo de muestra por los datos reales de REDMOOT.
- Reemplazá o revisá las cuatro propiedades y sus imágenes de ejemplo.
- Configurá Supabase y autorizá al primer administrador antes de usar `/admin`.
