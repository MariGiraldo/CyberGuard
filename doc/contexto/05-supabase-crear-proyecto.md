# T10 — Crear el proyecto Supabase y las credenciales en `.env` local

> **Tarea:** T10 del plan (Fase 1 — walking skeleton).
> **Responsables:** `constructor` + **usuario** (requiere crear la cuenta con tus propios datos).
> **Depende de:** T03 (arquitectura / contrato Supabase).
> **Desbloquea:** T11 (`schema.sql`), T12 (`rls.sql` + RPC), T13 (`seed.sql`).
> **Criterio de aceptación:** `SUPABASE_URL` y `SUPABASE_ANON_KEY` disponibles en `.env` local (**nunca** en el repo); orígenes Web (HTML5) permitidos en CORS; `.env.example` solo con placeholders.

Esta guía está pensada para **persona sin experiencia previa en Supabase**. Sigue los pasos en orden. Cada paso indica dónde hacer clic en el panel de Supabase (dashboard).

---

## 1. Crear la cuenta en Supabase

1. Abre <https://supabase.com> en el navegador.
2. Pulsa **Start your project** (o **Sign up**).
3. Regístrate con GitHub (botón **Continue with GitHub**) o con correo electrónico. **Este correo es tuyo y privado: no se guarda en el repositorio ni en el juego** (el proyecto no maneja PII de jugadores; tu correo de desarrollador no forma parte del dato del juego).
4. Confirma el correo si te lo pide y acepta los términos.
5. Ya dentro del panel, verás el listado de proyectos (vacío la primera vez).

## 2. Crear el proyecto

1. Pulsa **New project** (o **Create a new project**).
2. **Organization:** usa la organización personal que se creó automáticamente (p. ej. *tus-iniciales's projects*). No necesitas plan de pago: el **Free Plan** es suficiente para el walking skeleton.
3. **Project name:** `cyberguard` (o `cyberguard-mision-ciberseguridad`).
4. **Database Password:** genera una contraseña fuerte con el botón **Generate a password**.
   - **Guárdala en tu gestor de contraseñas.** Es la contraseña *de la base de datos*, distinta de cualquier clave del juego.
   - **Nunca** la escribas en el repo ni en `.env` de este proyecto (el contrato solo admite `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` como claves de cliente/servicio; la contraseña de BD no se usa desde el juego).
5. **Region (Región):** elige la región más cercana a tu público objetivo para minimizar la latencia de los eventos de telemetría:
   - España/Europa → **Europe (Madrid)** si está disponible en el desplegable; si no, **Europe (Frankfurt)** o **Europe (London)**.
   - Américas → **East North Virginia (US East)** u **Oregon (US West)**.
   - La región **no se puede cambiar** después de crear el proyecto (hay que recrearlo), así que elígela con calma.
6. Pulsa **Create new project** y **espera 1–2 minutos** a que termine el aprovisionamiento (aparecerá el mensaje de que el proyecto está *Active* / *Running*).

## 3. Obtener la Project URL y la anon key

1. En el menú lateral izquierdo del proyecto, ve a **Project Settings** (icono de engranaje ⚙️, al final) → sección **API** (en versiones recientes se llama **API Keys** / **Data API**).
2. Localiza dos valores:
   - **Project URL** (también llamado *Project URL / REST endpoint*): tiene forma `https://<identificador-proyecto>.supabase.co`.
   - **anon public** key (también llamada *Publishable key* en paneles recientes): una cadena larga tipo `eyJhbGciOi...`.
3. Copia ambos valores. **No los pegues todavía en ningún archivo del repo**: van directamente a tu `.env` local (paso 6).
4. Nota sobre la **service_role key**: aparece en la misma pantalla, marcada como *secret*. **No la necesitas para el juego.** El cliente Godot solo usará la `anon`. La `service_role` solo se usa —si acaso— desde tu entorno local para operaciones administrativas puntuales (p. ej. ejecutar migraciones desde el panel SQL Editor), y **jamás** se guarda en el repo ni se envía desde el cliente (Contrato CyberGuard §3.2).

## 4. Configurar Authentication → Providers (anónimo)

El juego no pide registro con correo ni contraseña (eso sería PII): usa un **alias seudónimo** con identificador `uuid`. Si en el futuro se habilita el inicio de sesión anónimo de Supabase, el paso es:

1. Menú lateral → **Authentication** → **Sign In / Providers** (en algunos paneles: **Providers → Anonymous sign-ins**).
2. Activa el interruptor **Anonymous** (si viene desactivado).
3. Guarda los cambios.

Si el walking skeleton decide no usar Authentication de Supabase y solo insertar filas con la clave `anon` mediante RLS (decisión válida para T11/T12), **puedes dejar este paso sin tocar**: las políticas `rls.sql` permiten `INSERT` al rol `anon` sin necesidad de sesión. Este paso queda documentado por si se adopta el login anónimo.

## 5. Configurar CORS / orígenes permitidos (obligatorio para el build Web)

La decisión 1a del plan es **Web (HTML5) + Windows**. El export Web ejecuta en el navegador y las peticiones a `https://<proyecto>.supabase.co` desde otra origen serán bloqueadas si los orígenes no están permitidos (error típico: *CORS policy: ... origin ... not allowed* o `Failed to fetch`).

1. En el panel del proyecto: **Project Settings** ⚙️ → **API** (sección *API Settings* / *General*).
2. Busca el campo **Additional Headers** / **Extra allowed origins** (CORS). En algunos paneles está en **Database** → **Settings** → **API**; si no lo localizas, revisa <https://supabase.com/docs/guides/platform/cors> para la ubicación exacta en la versión actual del panel.
3. Añade estos orígenes (uno por línea o separados por comas, según el campo):
   - `http://localhost:8000` — servidor local típico de `godot --headless`/`python -m http.server` al probar el export Web.
   - `http://127.0.0.1:8000` — variante en localhost con IP literal.
   - `http://localhost:8080` y `http://127.0.0.1:8080` — por si sirves el build en otro puerto.
   - El **origen de export real** cuando publiques: por ejemplo `https://<tu-usuario>.github.io` (GitHub Pages) o el dominio de tu hosting. Déjalo añadido cuando lo tengas.
4. Guarda los cambios (puede tardar unos segundos en aplicarse).
5. **Verificación:** carga el build Web en el navegador, abre la consola (F12) y comprueba que no aparece un error de CORS al hacer la primera petición REST. Si aparece, revisa que el origen exacto (incluido esquema `http/https` y puerto) esté en la lista.

> El escritorio (Windows exportado) **no** pasa por CORS: este paso solo afecta al build Web.

## 6. Crear el `.env` local a partir de `.env.example`

1. En la raíz del repositorio existe `.env.example` con este formato exacto (solo placeholders):

   ```
   SUPABASE_URL=
   SUPABASE_ANON_KEY=
   SUPABASE_SERVICE_ROLE_KEY=
   ```

2. Crea una copia llamada **`.env`** en la misma raíz (no renombres el original; `.env.example` se versiona y `.env` no):

   ```powershell
   Copy-Item .env.example .env
   ```

3. Abre `.env` y rellena con **tus** valores reales:

   ```
   SUPABASE_URL=https://<identificador-proyecto>.supabase.co
   SUPABASE_ANON_KEY=<tu anon key / publishable key>
   SUPABASE_SERVICE_ROLE_KEY=<tu service_role key — opcional, solo uso local>
   ```

4. Comprueba que `.gitignore` excluye `.env` (ya incluido en este repo):

   ```powershell
   git check-ignore -v .env
   ```

   Debe devolver la regla que lo ignora. Si `git status` muestra `.env` como pendiente de commit, **detente** y revisa `.gitignore` antes de continuar.

## 7. Recordatorio final — reglas duras de secretos

1. **Ningún valor real se versiona jamás.** En el repo solo puede existir `.env.example` con claves vacías (Contrato CyberGuard §3.2).
2. `.env` está en `.gitignore`; si alguna vez se coló un secreto en la historia de git, hay que rotarlo (regenerar la clave en Supabase) y limpiar la historia — repórtalo al `@guardian`.
3. El juego carga las claves **en runtime** desde `.env`; nunca dentro de escenas `.tscn` ni recursos `.tres` versionados.
4. La clave **`service_role` no se envía nunca al cliente Godot** (ni a builds Web): es la llave maestra que bypasea RLS.
5. PII prohibida: el juego solo guarda `alias` seudónimo + `uuid` de jugador. No introduzcas nombres reales ni correos en los datos de prueba.

---

## Checklist de la T10

- [ ] Cuenta Supabase creada y proyecto `cyberguard` activo (estado *Running*).
- [ ] Región elegida (la más cercana al público) y contraseña de BD guardada fuera del repo.
- [ ] **Project URL** y **anon key** copiadas.
- [ ] Provider *Anonymous* revisado/activado si se usará Authentication.
- [ ] Orígenes CORS configurados: `http://localhost:8000`, `http://127.0.0.1:8000` y el origen de export.
- [ ] `.env` local creado desde `.env.example` y verificado con `git check-ignore -v .env`.
- [ ] `git status` **no** muestra `.env` ni ningún secreto como pendiente de commit.

**Siguiente:** T11 → ejecutar `codigo/database/schema.sql` en el SQL Editor de Supabase.
