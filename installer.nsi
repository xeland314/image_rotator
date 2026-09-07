; Rotador de Imágenes — Instalador NSIS
; Adaptado de chat_analyzer_ui/installer.nsi, corregido: sin StartMenu plugin, sin fallo si LICENSE faltante, BINARY_NAME correcto
!include "MUI2.nsh"
!include "x64.nsh"

; --- ConfiguraciOn de Producto ---
!define PRODUCT_NAME "Rotador de Imágenes"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "Christopher Villamarin - @xeland314"
!define PRODUCT_WEB_SITE "https://xeland314.github.io/rotador-imagenes/"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\image_rotator.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define BINARY_NAME "image_rotator.exe"

; --- Configuracion del Instalador ---
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "RotadorImagenes-Setup-v${PRODUCT_VERSION}.exe"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation"
ShowInstDetails show
ShowUnInstDetails show
RequestExecutionLevel admin
Unicode True

; Informacion de Version
VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey ProductName "${PRODUCT_NAME}"
VIAddVersionKey ProductVersion "${PRODUCT_VERSION}"
VIAddVersionKey CompanyName "${PRODUCT_PUBLISHER}"
VIAddVersionKey FileVersion "${PRODUCT_VERSION}"
VIAddVersionKey FileDescription "Rotador de Imagenes - Herramienta educativa de razonamiento abstracto"
VIAddVersionKey LegalCopyright "© 2026 Christopher Villamarin"
VIAddVersionKey OriginalFilename "RotadorImagenes-Setup-v${PRODUCT_VERSION}.exe"

; Interfaz MUI
!define MUI_ABORTWARNING
!define MUI_ICON "windows\runner\resources\app_icon.ico"
!define MUI_UNICON "windows\runner\resources\app_icon.ico"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${BINARY_NAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Ejecutar ${PRODUCT_NAME}"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${Else}
    MessageBox MB_OK "Este instalador requiere Windows de 64 bits."
    Abort
  ${EndIf}
FunctionEnd

Section "Instalar" SEC01
  SetOutPath "$INSTDIR"
  SetOverwrite try

  ; Binario principal + dependencias Flutter
  ; Estructura generada por: flutter build windows --release
  ; -> build\windows\x64\runner\Release\image_rotator.exe + *.dll + data\
  File "build\windows\x64\runner\Release\${BINARY_NAME}"
  File /nonfatal "LICENSE"
  File /r /x "*.pdb" /x "*.lib" "build\windows\x64\runner\Release\*.*"

  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Accesos directos (sin depender de StartMenu plugin — fix chat_analyzer_ui que fallaba si faltaba Plugins\StartMenu.dll)
  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\${BINARY_NAME}" "" "$INSTDIR\${BINARY_NAME}" 0 SW_SHOWNORMAL "" "${PRODUCT_NAME}"
  CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\Desinstalar.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

  CreateShortcut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\${BINARY_NAME}" "" "$INSTDIR\${BINARY_NAME}" 0 SW_SHOWNORMAL "" "${PRODUCT_NAME}"

  ; Registro
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\${BINARY_NAME}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME} ${PRODUCT_VERSION}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\${BINARY_NAME}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWord HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWord HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1
  WriteRegDWord HKLM "${PRODUCT_UNINST_KEY}" "EstimatedSize" 150000
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\${PRODUCT_NAME}"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
  DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
SectionEnd
