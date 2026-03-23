# Militant Windows Installer

<p align="center">
  <img src="../assets/logo.svg" alt="Militant Logo" width="160"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows%20x64-0078D6?style=flat&logo=windows" alt="Windows x64">
  <img src="https://img.shields.io/badge/Flutter-Desktop-02569B?style=flat&logo=flutter" alt="Flutter Desktop">
  <img src="https://img.shields.io/badge/Installer-Inno%20Setup-6A1B9A?style=flat" alt="Inno Setup">
  <img src="https://img.shields.io/badge/Script-PowerShell-5391FE?style=flat&logo=powershell" alt="PowerShell">
  <img src="https://img.shields.io/badge/App-Militant-BE1E1E?style=flat" alt="Militant">
</p>

<p align="center">
  Dossier de build et de packaging pour generer un installateur Windows de <strong>Militant</strong> avec logo, icone et assistant d'installation.
</p>

---

## Contenu

- `Militant.iss` : script Inno Setup pour generer l'installateur `.exe`
- `build_windows_installer.ps1` : script principal de build Windows
- `build_windows_installer.bat` : lanceur rapide pour Windows
- `assets/` : icone de l'installateur et images de l'assistant
- `output/` : dossier de sortie des installateurs generes

## Prerequis

- Windows 10 ou 11
- Flutter SDK installe et accessible via `flutter`
- Visual Studio 2022 avec `Desktop development with C++`
- Inno Setup 6

## Build

Depuis Windows :

```bat
cd militant_flutter\windows_installer
build_windows_installer.bat
```

Le script :

1. active le support Windows desktop si necessaire
2. lance `flutter pub get`
3. lance `flutter build windows --release`
4. genere l'installateur `.exe` avec Inno Setup

## Sortie

L'installateur final est genere dans :

```text
windows_installer\output\
```

## Assets visuels

- logo principal : `../assets/logo.svg`
- icone installateur : `assets/militant-installer.ico`
- image assistant : `assets/wizard.bmp`
- petite image assistant : `assets/wizard-small.bmp`

## Notes

- Le build final Windows doit etre lance depuis une machine Windows.
- L'icone de l'application Windows est configuree dans `windows/runner/resources/app_icon.ico`.
- Le script Inno Setup installe l'application dans `%LocalAppData%\Programs\Militant`.
