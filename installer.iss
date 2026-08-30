; =========================================================================
; Monster Word - Windows installer script (Inno Setup 6)
; Build from repo root:  ISCC.exe installer.iss
; Sources resolved relative to this script's directory (= repo root), so
; both local runs and GitHub Actions (workspace root) produce the same
; MonsterWord_Setup_vX.Y.Z.exe.
; =========================================================================

#define MyAppName "Monster Word"
; 版本可由命令行覆盖：ISCC.exe /DMyAppVersion=X.Y.Z installer.iss
; （CI 从 pubspec.yaml 读取后传入；未传入时用下方默认值）
#ifndef MyAppVersion
#define MyAppVersion "2.1.0"
#endif
#define MyAppPublisher "MonsterWord"
#define MyAppExeName "MonsterWord.exe"

[Setup]
AppId={{41783361-6863-42E7-B051-929B3ADA2A6A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=build\installer
OutputBaseFilename=MonsterWord_Setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
