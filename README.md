# CyberGuard: Mision Ciberseguridad

**CyberGuard: Mision Ciberseguridad** es un videojuego 2D de enfoque educativo, desarrollado en **pixel art**, que enseña buenas practicas de seguridad digital. El jugador encarna a un **analista de seguridad** que debe inspeccionar la red de una empresa ficticia y protegerla de amenazas.

## Descripcion del proyecto

CyberGuard es un juego 2D de estilo Top-Down / Point & Click ambientado en las terminales de una empresa ficticia. El objetivo del analista es identificar amenazas, descifrar mensajes y reparar servidores infectados antes de que expire un temporizador.

Actualmente, la mayor parte del codigo de juego se encuentra **pendiente de implementacion**: los directorios `codigo/game`, `codigo/database` y `codigo/backend` existen en el repositorio pero estan vacios. Por ello, este documento describe la arquitectura y las intenciones del proyecto segun lo establecido por la documentacion contractual del repositorio, marcando con `**[PENDIENTE: ...]**` cualquier detalle que todavia no exista en el codigo.

## Proposito educativo

El proposito del proyecto es formar a estudiantes (y al publico general) en ciberseguridad mediante la prctica lúdica:

- **Identificacion de phishing:** reconocer correos de origen fraudulento, enlaces manipulados y intentos de ingeniería social.
- **Contrasena segura:** conocer los requisitos para una contrasena robusta y los riesgos de reutilizar contrasenas.
- **Gestion de vulnerabilidades:** localizar, clasificar y reparar fallos en los servidores de la empresa ficticia.

Todo el contenido educativo se basa en conceptos publicados de referencia sobre ciberseguridad y es 100% simulado: los correos y escenarios presentados son ficticios y no apuntan a sitios reales.

## Mecanicas

- El jugador controla a un **analista de seguridad** en un mapa 2D (estilo Top-Down o Point & Click, segun la implementacion).
- El analista **inspecciona terminales** de la empresa ficticia: lee el correo entrante, examina archivos y sistemas.
- Las amenazas detectadas se clasifican por tipo (por ejemplo, phishing, contrasena debil, mala configuracion), y el historial de errores por tipo de amenaza se registra para su analisis posterior.
- El progreso del jugador y los resultados obtenidos se almacenan para poder calcular metricas en Looker Studio.
- El motor del juego es **Godot 4.x con GDScript tipado**. La resolucion base es de **320x180** (escalada a ventana) con `Texture Filter = Nearest` y snap a pixel; los assets se trabajan en multiples de **16x16**.

Las mecanicas concretas (numero de niveles, objetivos exactos, sistema de puntos, etc.) **aún están por definir**:

> **[PENDIENTE: numero de niveles, objetivos exactos por nivel y sistema de puntuacion]**

## Dinamica de partida

La partida transcurre sobre un tiempo limitado: el analista debe completar su investigacion antes de que expire un **temporizador**. Durante ese tiempo debe:

1. Analizar los **correos entrantes** y detectar los intentos de phishing.
2. **Descifrar mensajes encriptados** para recuperar informacion relevante.
3. **Reparar servidores infectados** antes de que el fallo se extienda a otros sistemas.
4. Registrar sus decisiones para que el historial quede disponible en el analisis posterior.

> **[PENDIENTE: comportamiento exacto del temporizador, duracion total de la partida y consecuencias de que expire]**

## Arquitectura de la integracion con Supabase y Looker Studio

El proyecto prevé dos integraciones externas. En este punto solo existe documentacion contractual: la implementacion real de estas piezas **aún no se ha construido**. Las siguientes secciones describen la arquitectura planificada y lo que el repositorio documenta hasta ahora.

### Flujo de datos planificado

1. **Registro de eventos (cliente del juego -> Supabase).** El cliente del juego inserta en Supabase un historial de errores por tipo de amenaza: por ejemplo, los usuarios que cayeron en phishing frente a aquellos que utilizaron contrasenas debiles. Cada evento registra el identificador del jugador, la partida y la amenaza detectada, y se crea de forma **append-only** (solo `INSERT`, sin `UPDATE` ni `DELETE`, con políticas de acceso restringidas).
2. **Visualizacion (Supabase -> Looker Studio).** Las tablas de eventos se consumen por un dashboard en Looker Studio, que muestra, entre otras metricas:
   - Vulnerabilidades comunes de los jugadores.
   - Tasa de efectividad por nivel.
   - Tiempo de respuesta por tipo de amenaza.
3. **Consultas (Looker Studio -> Supabase).** El dashboard se conecta a Supabase en **solo lectura** a traves de vistas SQL restringidas, sin exponer datos personales de los jugadores.

### Detalles verificados en el repositorio

- El motor del juego es **Godot 4.x con GDScript tipado** (segun la documentacion contractual de `agentes/`). Prohibido Godot 3.x.
- La conexion del juego con Supabase se realiza por **HTTP REST** (`HTTPRequest`), con los headers `apikey` y `Authorization: Bearer <anon_key>`; no se asume un SDK nativo oficial de Godot.
- La persistencia se basa en **PostgreSQL** mediante **Supabase**.
- El esquema documentado (aunque todavia no existe implementado en `codigo/database/`) incluye las tablas `jugadores`, `partidas`, `eventos_phishing` y `eventos_password`, con las columnas previstas por el agente de dominio (identificador seudonomo, alias, `creado_en`, y atributos de cada decision de phishing o intento de contrasena).
- La conexion con Looker Studio se alimenta mediante **vistas SQL** (`v_*`) y se restringe mediante **RLS** (Row Level Security) con un rol de solo lectura (`looker_lectura`).
- Las vistas previstas para el dashboard son, entre otras: `v_ranking_jugadores`, `v_metricas_phishing`, `v_metricas_password` y `v_progreso_nivel`.

### Detalles pendientes

> **[PENDIENTE: nombres exactos de tablas, columnas, claves foraneas, funciones RPC y endpoints de acceso]** (por ejemplo, como se identifican los intentos de phishing o contrasena debil en los registros). Los nombres de tablas y columnas descritos arriba provienen de la documentacion contractual, pero **no existen implementados** en `codigo/database/`.
>
> **[PENDIENTE: credenciales y variables de entorno (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`)**; todavia no existe un archivo `.env.example` versionado ni un `.env` local configurado.
>
> **[PENDIENTE: conexion de Looker Studio]**; no existe ninguna vista ni dashboard implementado en el repositorio.
>
> **[PENDIENTE: mecanismo de acceso en solo lectura y el rol dedicado (`looker_lectura`)** para Looker Studio.

## Instalacion y ejecucion

No existe todavia un proyecto Godot listo para ejecutar en esta raiz. En concreto:

- **Proyecto Godot:** el directorio `codigo/game` esta vacio, por lo que todavia **no hay un proyecto `.godot` ni escenas `.tscn` que puedan abrirse**. La configuracion del proyecto (escenas, sistema de escenas y autoloads) **esta pendiente de implementar**.
- **Motor y dependencias:** el contrato documental fija **Godot 4.x con GDScript**, pero **no se ha versionado ningun manifiesto de dependencias** ni se ha indicado la version exacta. La instalacion del motor es responsabilidad del desarrollador.
- **Script auxiliar:** existe el script `scripts/generar-readme.ps1`, util para regenerar este documento a partir de un prompt. No constituye la ejecucion del juego.
- **Credenciales y entorno:** no existe un archivo `.env` ni `.env.example` versionado; la configuracion de las claves de Supabase **esta pendiente de implementar**.

> **[PENDIENTE: instrucciones de instalacion y ejecucion del juego]** (dependencias, configuracion del proyecto Godot, ejecucion en escritorio o Web). No se anaden instrucciones que no puedan verificarse en el repositorio.

## Estructura del proyecto

La raiz del repositorio contiene los siguientes elementos:

```text
CyberGuard-MisionCiberseguridad/
├── codigo/
│   ├── backend/     # (vacio: funciones y logica del servidor)
│   ├── database/    # (vacio: esquema SQL y vistas)
│   └── game/        # (vacio: escenas y codigo del juego Godot)
├── doc/             # (vacio: documentacion contractual pendiente)
├── docs/            # README.md actual (documentacion contractual del repositorio)
├── scripts/
│   └── generar-readme.ps1   # script PowerShell para regenerar este README
└── agentes/         # (documentacion contractual de los agentes del proyecto)
    ├── contexto/
    ├── razonamiento/
    ├── ejecucion/
    └── operacion/
```

Estado real del proyecto:

- Los directorios `codigo/*` y `doc/` estan **completamente vacios**; no existe codigo fuente, esquema de base de datos ni documentacion tecnica adicional.
- `scripts/generar-readme.ps1` es el unico fichero de codigo funcional presente en el repositorio.
- `agentes/` contiene la documentacion contractual (stack, restricciones, flujo de trabajo y entregables esperados), que es la base con la que se ha redactado este documento.
- `.opencode/skills/` esta vacio y no aporta contenido funcional.

> **[PENDIENTE: contenido de `codigo/backend`, `codigo/database` y `codigo/game`** una vez iniciada la fase de construccion.
> **[PENDIENTE: documentacion tecnica adicional bajo `doc/`**, actualmente ausente del repositorio.

## Pendientes

1. **Implementacion del juego en Godot 4.x.** Crear el proyecto (`codigo/game`) con las escenas, el sistema de terminales y la logica de analisis de correos.
2. **Esquema de base de datos en Supabase.** Definir el esquema SQL (`codigo/database/schema.sql`) con las tablas `jugadores`, `partidas` y de eventos (`eventos_phishing`, `eventos_password`), sus columnas, claves y las politicas de RLS. Actualmente no existe ningun archivo SQL.
3. **Vistas para Looker Studio.** Implementar las vistas SQL (`v_*`) y el dashboard que consuma los eventos. Todavia no existe ninguna vista implementada.
4. **Configuracion de credenciales.** Versionar `.env.example` con los placeholders de `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`, y configurar `.env` local sin subirse al repositorio.
5. **Definir las metricas de negocio y su calculo** (tasa de efectividad por nivel, tiempo de respuesta, vulnerabilidades comunes), junto con el mecanismo de servidor para calcularlos.
6. **Definir el alcance del juego:** numero de niveles, sistema de puntuacion, control de dificultad y mecanicas de progresion.
7. **Verificacion y pruebas:** establecer un flujo de ejecucion del juego (Godot, escritorio o Web) y pruebas automatizadas de la logica educativa.
8. **Completar la documentacion tecnica** en `doc/` (misión, requisitos, estilo pixel art, guia de estilo) y el registro de licencias de los assets.
