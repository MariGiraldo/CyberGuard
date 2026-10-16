<#
.SYNOPSIS
    Genera automaticamente el contenido de un README.md para el proyecto de la
    raiz actual, usando opencode como motor de redaccion.

.DESCRIPTION
    Herramienta de automatizacion invocable desde opencode. Recibe el prompt de
    generacion como argumento (no esta hardcodeado), delega la redaccion en el
    CLI de opencode en modo no interactivo (opencode run --format json), escribe
    el resultado como archivo .md en la carpeta de documentacion de la raiz del
    proyecto (por defecto docs/, se crea si no existe) y verifica el archivo
    antes de confirmar su ruta.

    El agente que redacta el README inspecciona el codigo real del proyecto y
    marca con **[PENDIENTE: ...]** cualquier informacion que no pueda
    verificarse en el repositorio, para no inventar comandos, rutas ni
    dependencias.

.PARAMETER Prompt
    Prompt de generacion que se pasa a opencode. Obligatorio.

.PARAMETER Carpeta
    Carpeta destino, relativa a la raiz del proyecto. Por defecto: docs.
    Se crea si no existe.

.PARAMETER Nombre
    Nombre del archivo generado. Por defecto: README.md

.PARAMETER Raiz
    Raiz del proyecto a documentar. Por defecto: la carpeta que contiene este
    script (la raiz del proyecto donde vive scripts/).

.EXAMPLE
    .\scripts\generar-readme.ps1 -Prompt "Genera el README de CyberGuard: descripcion, proposito educativo, mecanicas, dinamica, arquitectura Supabase y Looker Studio, e instalacion"

.EXAMPLE
    .\scripts\generar-readme.ps1 "Genera el README tecnico" -Carpeta doc -Nombre README.md
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Prompt = "",

    [string]$Carpeta = "docs",

    [string]$Nombre = "README.md",

    [string]$Raiz = ""
)

$ErrorActionPreference = "Stop"

function Mostrar-Uso {
    Write-Output "Uso:"
    Write-Output '  powershell -File .\scripts\generar-readme.ps1 -Prompt "<prompt de generacion>" [-Carpeta docs] [-Nombre README.md] [-Raiz <ruta>]'
    Write-Output ""
    Write-Output "Ejemplo:"
    Write-Output '  .\scripts\generar-readme.ps1 -Prompt "Genera el README del proyecto con descripcion, proposito educativo, mecanicas, arquitectura Supabase/Looker e instalacion"'
}

function Fallar([string]$Mensaje) {
    Write-Output "[ERROR] $Mensaje"
    exit 1
}

# ------------------------------------------------------------------
# 0) Validacion de argumentos
# ------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Prompt)) {
    Write-Output "[ERROR] Falta el argumento -Prompt: el prompt de generacion debe pasarse como argumento (no esta hardcodeado)."
    Mostrar-Uso
    exit 1
}

# ------------------------------------------------------------------
# 1) Raiz del proyecto
# ------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Raiz)) {
    $Raiz = Split-Path -Parent $PSScriptRoot
}
try {
    $Raiz = [System.IO.Path]::GetFullPath($Raiz)
}
catch {
    Fallar "La raiz del proyecto no es una ruta valida: $Raiz"
}
if (-not (Test-Path -LiteralPath $Raiz -PathType Container)) {
    Fallar "No existe la raiz del proyecto: $Raiz"
}

# ------------------------------------------------------------------
# 2) CLI de opencode disponible
# ------------------------------------------------------------------
if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Fallar "No se encontro el CLI 'opencode' en el PATH. Instalalo antes de usar este script: https://opencode.ai"
}

# ------------------------------------------------------------------
# 3) Instruccion = plantilla de documentacion tecnica + prompt recibido
#    (la instruccion se pasa en una sola linea y sin comillas dobles,
#     para que el CLI la reciba como un unico argumento)
# ------------------------------------------------------------------
$plantilla = @'
Eres un desarrollador senior de software con experiencia en documentacion tecnica de proyectos de codigo abierto. Tu tarea es generar el contenido completo, en espanol, del archivo README.md del proyecto situado en la raiz actual del repositorio. Reglas obligatorias: 1) Antes de redactar, inspecciona la estructura real del proyecto (raiz actual) y lee con tus herramientas de lectura los ficheros de codigo, configuracion y base de datos que existan; todas las secciones tecnicas deben basarse en lo que realmente encuentres en el repositorio: no inventes comandos, rutas, dependencias, endpoints, variables de entorno ni esquemas de tablas que no existan. 2) Si falta un dato necesario (dependencias, comandos de instalacion o ejecucion, esquema de tablas, claves de entorno, motor del juego, credenciales), no lo supongas: inserta en su lugar este marcador claro, adaptando el motivo: marcador de ejemplo: > **[PENDIENTE: motivo por el que falta la informacion]**; coloca un marcador en cada hueco, justo donde iria la informacion que falta. 3) No incluyas instrucciones de instalacion o ejecucion que no puedas verificar en el repositorio; explica en su lugar que esa parte esta pendiente de implementar o configurar. 4) Secciones obligatorias con encabezados markdown (# y ##): Descripcion del proyecto; Proposito educativo; Mecanicas; Dinamica de partida; Arquitectura de la integracion con Supabase y Looker Studio; Instalacion y ejecucion; Estructura del proyecto; Pendientes. 5) En la seccion de arquitectura, describe el flujo de datos planificado: el cliente del juego registra eventos en Supabase (historial de errores por tipo de amenaza, por ejemplo usuarios que cayeron en phishing frente a contrasenas debiles) y Supabase alimenta un dashboard en Looker Studio (vulnerabilidades comunes de los jugadores, tasa de efectividad por nivel y tiempo de respuesta); declara con el marcador PENDIENTE cualquier detalle concreto que no exista aun en el codigo (nombres de tablas, columnas, endpoints o credenciales) en lugar de inventarlo. 6) No crees ni modifiques ningun archivo: limitate a devolver el contenido Markdown en tu respuesta final. 7) Responde UNICAMENTE con el contenido Markdown del README: empieza por el titulo H1 (# ...), sin comentarios previos ni posdata, y sin envolver todo el documento en un bloque de codigo.
'@

$instruccion = (($plantilla -replace '\s+', ' ').Trim() + ' ' + $Prompt.Trim())

# ------------------------------------------------------------------
# 4) Invocacion de opencode en modo no interactivo
# ------------------------------------------------------------------
$fichErr = Join-Path ([System.IO.Path]::GetTempPath()) ("opencode-readme-" + [Guid]::NewGuid().ToString("N") + ".log")
$encodingUtf8 = New-Object System.Text.UTF8Encoding($false)
$encodingPrevia = $null
$salida = $null
$codigoUltimo = -1
$excepcion = $null

Write-Output "Invocando opencode (opencode run --format json) para generar el contenido del README..."
Write-Output ("  Raiz inspeccionada: " + $Raiz)

Push-Location -LiteralPath $Raiz
try {
    try {
        $encodingPrevia = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    }
    catch { }

    $salida = & opencode run --format json --auto --title "Generacion README" $instruccion 2> $fichErr
    $codigoUltimo = $LASTEXITCODE
}
catch {
    $excepcion = $_
}
finally {
    Pop-Location
    if ($null -ne $encodingPrevia) {
        try { [Console]::OutputEncoding = $encodingPrevia } catch { }
    }
}

if ($null -ne $excepcion) {
    Fallar ("Fallo al ejecutar opencode: " + $excepcion.Exception.Message)
}
if ($codigoUltimo -ne 0) {
    $detalle = ""
    if (Test-Path -LiteralPath $fichErr) {
        $detalle = [System.IO.File]::ReadAllText($fichErr)
    }
    Fallar (("opencode termino con el codigo " + $codigoUltimo + ". " + $detalle).Trim())
}

# ------------------------------------------------------------------
# 5) Extraccion del Markdown de los eventos NDJSON (type = text)
# ------------------------------------------------------------------
if (-not $salida) {
    Fallar "opencode no devolvio ninguna salida."
}

$eventosTexto = @()
foreach ($linea in $salida) {
    if ([string]::IsNullOrWhiteSpace($linea)) { continue }
    $objeto = $null
    try { $objeto = $linea | ConvertFrom-Json } catch { continue }
    if ($null -eq $objeto) { continue }
    if ($objeto.type -ne 'text') { continue }
    if ($null -eq $objeto.part) { continue }
    $eventosTexto += $objeto
}
if ($eventosTexto.Count -eq 0) {
    Fallar "La respuesta de opencode no contiene bloques de texto (formato inesperado)."
}

# Se queda con el ultimo mensaje del asistente (la respuesta final) y une
# sus bloques de texto respetando el orden (mismo part.id => fragmentos).
$ultimoMensaje = ($eventosTexto | Select-Object -Last 1).part.messageID
$bloques = [ordered]@{}
foreach ($evento in $eventosTexto) {
    if ($evento.part.messageID -ne $ultimoMensaje) { continue }
    $id = $evento.part.id
    $texto = [string]$evento.part.text
    if ($bloques.Contains($id)) {
        $bloques[$id] = [string]$bloques[$id] + $texto
    }
    else {
        $bloques[$id] = $texto
    }
}
$md = (($bloques.Values | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne "" }) -join "`n`n").Trim()

if ([string]::IsNullOrWhiteSpace($md)) {
    Fallar "El contenido extraido de la respuesta esta vacio."
}

# ------------------------------------------------------------------
# 6) Limpieza defensiva del contenido
# ------------------------------------------------------------------
# Secuencias ANSI (por si acaso).
$md = [regex]::Replace($md, "\x1b\[[0-9;]*[A-Za-z]", "")
$md = $md.Trim()

# Bloque de codigo envolvente (si el modelo envuelve todo el documento).
if ($md -match '^[`~]{3,}[A-Za-z0-9_+#.-]*\r?\n(?<cuerpo>[\s\S]*?)\r?\n[`~]{3,}\s*$') {
    $md = $Matches['cuerpo'].Trim()
}

# Preamble previo al titulo H1 (si el modelo anade una linea introductoria).
if ($md -notmatch '^(#|---|<!--)') {
    $coincidencia = [regex]::Match($md, '(?m)^# .+$')
    if ($coincidencia.Success -and $coincidencia.Index -gt 0) {
        $md = $md.Substring($coincidencia.Index).Trim()
    }
}

if ([string]::IsNullOrWhiteSpace($md)) {
    Fallar "El contenido extraido quedo vacio tras la limpieza."
}
if ($md -notmatch '(?m)^#') {
    Write-Output "[AVISO] El contenido no contiene encabezados markdown; se guarda igualmente."
}

# ------------------------------------------------------------------
# 7) Escritura del archivo .md (UTF-8 sin BOM), creando la carpeta si no existe
# ------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Carpeta)) { $Carpeta = "docs" }
try {
    $dirDestino = [System.IO.Path]::GetFullPath((Join-Path $Raiz $Carpeta))
}
catch {
    Fallar "La carpeta destino no es una ruta valida: $Carpeta"
}
if (-not (Test-Path -LiteralPath $dirDestino -PathType Container)) {
    New-Item -ItemType Directory -Path $dirDestino -Force | Out-Null
    Write-Output ("Carpeta creada: " + $dirDestino)
}

try {
    $ruta = [System.IO.Path]::GetFullPath((Join-Path $dirDestino $Nombre))
}
catch {
    Fallar "El nombre de archivo no es valido: $Nombre"
}

[System.IO.File]::WriteAllText($ruta, $md + "`n", $encodingUtf8)

# ------------------------------------------------------------------
# 8) Verificacion del archivo escrito
# ------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ruta -PathType Leaf)) {
    Fallar "No se pudo escribir el archivo: $ruta"
}
$bytes = (Get-Item -LiteralPath $ruta).Length
if ($bytes -eq 0) {
    Fallar "El archivo se creo pero esta vacio: $ruta"
}
$relectura = [System.IO.File]::ReadAllText($ruta, $encodingUtf8)
if ([string]::IsNullOrWhiteSpace($relectura)) {
    Fallar "La relectura del archivo devolvio contenido vacio: $ruta"
}
if ($relectura.Trim() -ne $md.Trim()) {
    Fallar "La verificacion fallo: el contenido leido no coincide con el generado en $ruta"
}
$lineas = ($relectura -split "\r?\n").Count
$titulo = ""
foreach ($linea in ($relectura -split "\r?\n")) {
    if ($linea -match '^#\s+\S') { $titulo = $linea.Trim(); break }
}

if (Test-Path -LiteralPath $fichErr) {
    Remove-Item -LiteralPath $fichErr -Force -ErrorAction SilentlyContinue
}

Write-Output "[OK] README generado y verificado correctamente."
Write-Output ("     Ruta: " + $ruta)
Write-Output ("     Tamano: " + $bytes + " bytes | " + $lineas + " lineas")
if ($titulo -ne "") {
    Write-Output ("     Titulo: " + $titulo)
}
exit 0
