# build_windows.ps1 — Empaqueta Rotador de Imágenes para Windows con NSIS
# Basado en el flujo de chat_analyzer_ui pero corregido y parametrizado.
# Requisitos: Flutter, NSIS 3.x (makensis en PATH o C:\Program Files (x86)\NSIS)
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1 -Version 1.0.0
#   powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1 -Version 1.0.0 -SkipBuild
# Salida: RotadorImagenes-Setup-v1.0.0.exe (en la raíz del proyecto)

param(
    [string]$Version = "1.0.0",
    [switch]$SkipBuild,
    [string]$Configuration = "Release",
    [string]$NsisPath = "C:\Program Files (x86)\NSIS"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $ProjectRoot

Write-Host "==> Rotador de Imágenes — Build Windows v$Version ($Configuration)" -ForegroundColor Cyan

# 1. NSIS en PATH (fix para tu PS: $env:Path += ";C:\Program Files (x86)\NSIS")
if (-not (Get-Command makensis -ErrorAction SilentlyContinue)) {
    if (Test-Path "$NsisPath\makensis.exe") {
        $env:Path += ";$NsisPath"
        Write-Host "==> Agregado NSIS al PATH: $NsisPath" -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: makensis no encontrado. Instala NSIS 3.12+ desde https://nsis.sourceforge.io/" -ForegroundColor Red
        Write-Host "Esperado en: $NsisPath\makensis.exe"
        exit 1
    }
}
try { makensis /VERSION } catch { Write-Host "WARN: no se pudo verificar makensis /VERSION: $_" -ForegroundColor Yellow }

# 2. Version sync: actualiza installer.nsi si difiere (no toca pubspec.yaml)
$installerNsi = Join-Path $ProjectRoot "installer.nsi"
if (Test-Path $installerNsi) {
    $content = Get-Content $installerNsi -Raw
    if ($content -match '!define PRODUCT_VERSION "([^"]+)"') {
        $current = $Matches[1]
        if ($current -ne $Version) {
            Write-Host "==> Actualizando PRODUCT_VERSION $current -> $Version en installer.nsi" -ForegroundColor Yellow
            (Get-Content $installerNsi) -replace '!define PRODUCT_VERSION "[^"]+"', "!define PRODUCT_VERSION `"$Version`"" | Set-Content $installerNsi -Encoding UTF8
        }
    }
}

# 3. Flutter build windows
if (-not $SkipBuild) {
    Write-Host "==> flutter build windows --$($Configuration.ToLower())" -ForegroundColor Cyan
    flutter clean 2>&1 | Out-String | Write-Host
    if ($LASTEXITCODE -ne 0) { Write-Host "WARN: flutter clean fallo, continuando..." -ForegroundColor Yellow }
    flutter pub get 2>&1 | Out-String | Write-Host
    if ($Configuration -eq "Release") {
        flutter build windows --release 2>&1 | Out-String | Write-Host
    } else {
        flutter build windows --debug 2>&1 | Out-String | Write-Host
    }
    if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter build windows fallo" -ForegroundColor Red; exit 1 }
} else {
    Write-Host "==> SkipBuild: omitiendo flutter build" -ForegroundColor Yellow
}

# 4. Verificar artefacto
$exe = "build\windows\x64\runner\Release\image_rotator.exe"
if (-not (Test-Path $exe)) {
    # Fallback por si BINARY_NAME cambiara
    $alt = Get-ChildItem "build\windows\x64\runner\Release\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($alt) { $exe = $alt.FullName; Write-Host "==> Detectado exe alternativo: $exe" -ForegroundColor Yellow }
    else { Write-Host "ERROR: No se encontró $exe . Ejecuta flutter build windows --release primero." -ForegroundColor Red; exit 1 }
}
Write-Host "==> Binario OK: $exe ($( [math]::Round((Get-Item $exe).Length/1MB,2) ) MB)" -ForegroundColor Green
if (-not (Test-Path "LICENSE")) { Write-Host "WARN: LICENSE no existe, NSIS usará página igual pero File /nonfatal lo tolera" -ForegroundColor Yellow }

# 5. Compilar instalador NSIS
Write-Host "==> makensis installer.nsi" -ForegroundColor Cyan
# Limpia salida previa
$outExe = "RotadorImagenes-Setup-v$Version.exe"
if (Test-Path $outExe) { Remove-Item $outExe -Force }
makensis /V2 "installer.nsi" 2>&1 | Out-String | Write-Host
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: makensis fallo" -ForegroundColor Red; exit 1 }

if (Test-Path $outExe) {
    $size = [math]::Round((Get-Item $outExe).Length/1MB,2)
    Write-Host "==> OK: $outExe ($size MB)" -ForegroundColor Green
    Write-Host "Prueba: .\$outExe  (o click derecho -> Ejecutar)" -ForegroundColor Cyan
} else {
    # NSIS OutFile puede ser relativo al .nsi dir; buscar
    $found = Get-ChildItem -Recurse -Filter "RotadorImagenes-Setup-v*.exe" | Select-Object -First 1
    if ($found) { Write-Host "==> OK: $($found.FullName) ($([math]::Round($found.Length/1MB,2)) MB)" -ForegroundColor Green }
    else { Write-Host "ERROR: No se generó el instalador esperado $outExe" -ForegroundColor Red; exit 1 }
}

# 6. Resumen para GitHub Release
Write-Host ""
Write-Host "=== Resumen Release GitHub ===" -ForegroundColor Cyan
Write-Host "Sube a https://github.com/xeland314/image_rotator/releases/new :"
Write-Host " - $outExe  (Windows installer)"
$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) { Write-Host " - $apk  (APK ya compilado)" -ForegroundColor Green } else { Write-Host " - (APK no encontrado) -> flutter build apk --release  => $apk" -ForegroundColor Yellow }
$appImage = "RotadorImagenes-$Version-x86_64.AppImage"
Write-Host " - $appImage  (compílalo en Linux con: ./scripts/build_appimage.sh --version $Version)"
Write-Host ""
Write-Host "Tag sugerido: v$Version  |  Title: Rotador de Imagenes v$Version" -ForegroundColor Yellow
