$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$installerRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Split-Path -Path $installerRoot -Parent
$projectRoot = $repoRoot
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
  $projectRoot = Join-Path $repoRoot "source"
  $pubspecPath = Join-Path $projectRoot "pubspec.yaml"
}

if (-not (Test-Path $pubspecPath)) {
  throw "pubspec.yaml introuvable: $pubspecPath"
}

$pubspecContent = Get-Content -Path $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspecContent, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?')
if (-not $versionMatch.Success) {
  throw "Impossible de lire la version depuis pubspec.yaml"
}

$appVersion = $versionMatch.Groups[1].Value
$appBuild = if ($versionMatch.Groups[2].Success) { $versionMatch.Groups[2].Value } else { "0" }

$flutterCmd = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
} else {
  "flutter"
}

$releaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$outputDir = Join-Path $installerRoot "output"
$issFile = Join-Path $installerRoot "Militant.iss"

Push-Location $projectRoot
try {
  & $flutterCmd config --enable-windows-desktop | Out-Null
  & $flutterCmd pub get
  & $flutterCmd build windows --release
} finally {
  Pop-Location
}

$exePath = Join-Path $releaseDir "Militant.exe"
if (-not (Test-Path $exePath)) {
  throw "Binaire Windows introuvable après build: $exePath"
}

$isccCandidates = @()
if ($env:INNO_SETUP_COMPILER) {
  $isccCandidates += $env:INNO_SETUP_COMPILER
}
if (${env:ProgramFiles(x86)}) {
  $isccCandidates += (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe")
}
if ($env:ProgramFiles) {
  $isccCandidates += (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
}
if ($env:LOCALAPPDATA) {
  $isccCandidates += (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
}
try {
  $isccFromPath = (Get-Command "ISCC.exe" -ErrorAction Stop).Source
  if ($isccFromPath) {
    $isccCandidates += $isccFromPath
  }
} catch {
}

$isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique -First 1
if (-not $isccPath) {
  throw "ISCC.exe introuvable. Installe Inno Setup 6 ou définis INNO_SETUP_COMPILER."
}
if (-not $env:INNO_SETUP_COMPILER) {
  $env:INNO_SETUP_COMPILER = $isccPath
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

& $isccPath `
  "/DAppVersion=$appVersion" `
  "/DAppBuild=$appBuild" `
  "/DSourceDir=$releaseDir" `
  "/DOutputDir=$outputDir" `
  $issFile

Write-Host ""
Write-Host "Build Windows OK"
Write-Host "Installer genere dans: $outputDir"
