; Monster Word App - Inno Setup 安装包脚本
; 由 Aion CLI 生成

#define MyAppName "Monster Word"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Lange Team"
#define MyAppExeName "MonsterWord.exe"
#define MyAppOutputDir "..\build\installer"
#define MyAppSourceDir "..\build\windows\x64\runner\Release"

[Setup]
; 注意：AppId 唯一标识此应用。不要在其他安装程序中使用相同的 AppId 值。
AppId={{B8A3C9D1-4E5F-4A6B-9C7D-8E2F1A3B5C7D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
InfoBeforeFile=..\README.md
OutputDir={#MyAppOutputDir}
OutputBaseFilename=MonsterWord_Setup_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; 支持 64 位系统
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; 允许用户选择是否创建桌面快捷方式
AllowNoIcons=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 主程序文件
Source: "{#MyAppSourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; DLL 文件
Source: "{#MyAppSourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; 数据目录
Source: "{#MyAppSourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 开始菜单快捷方式
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; 桌面快捷方式（可选）
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 安装完成后是否运行程序
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent


