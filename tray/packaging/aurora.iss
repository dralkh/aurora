#ifndef AppVersion
  #define AppVersion "1.1.1"
#endif
#define AppName "Aurora"
#define AppPublisher "Dralk"
#define AppExeName "Aurora.exe"

[Setup]
AppId={{2F0F1A0E-7A2E-4E3D-9E2A-9B0B5C6D7E8F}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=..\dist
OutputBaseFilename=Aurora-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Files]
Source: "..\dist\Aurora\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autostart}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: autostart

[Tasks]
Name: "autostart"; Description: "Start Aurora when I sign in"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\{#AppExeName}"; Parameters: "--uninstall-autostart"; Flags: runhidden; RunOnceId: "RemoveAutostart"
