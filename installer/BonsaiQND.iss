#ifndef AppVersion
  #define AppVersion "0.1.0-pre.1"
#endif

[Setup]
AppId={{6C87F0E7-8A29-4BD0-92D4-4B784D70E13A}
AppName=Bonsai QND
AppVersion={#AppVersion}
AppPublisher=QND
AppPublisherURL=https://github.com/quendae/bonsai-qnd
DefaultDirName={localappdata}\BonsaiQND
DefaultGroupName=Bonsai QND
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=BonsaiQND-Setup-v{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
UninstallDisplayName=Bonsai QND
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\qnd.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\upstream.lock.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\start-nvidia-lan.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\start-cpu-lan.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\harness\*"; DestDir: "{app}\harness"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Bonsai QND PowerShell"; Filename: "powershell.exe"; Parameters: "-NoExit -ExecutionPolicy Bypass -Command ""Set-Location -LiteralPath '{app}'; .\qnd.ps1 help"""; WorkingDir: "{app}"
Name: "{group}\Bonsai QND README"; Filename: "notepad.exe"; Parameters: """{app}\README.md"""; WorkingDir: "{app}"
Name: "{userdesktop}\Bonsai QND"; Filename: "powershell.exe"; Parameters: "-NoExit -ExecutionPolicy Bypass -Command ""Set-Location -LiteralPath '{app}'; .\qnd.ps1 help"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-NoExit -ExecutionPolicy Bypass -Command ""Set-Location -LiteralPath '{app}'; .\qnd.ps1 help"""; WorkingDir: "{app}"; Description: "Open Bonsai QND PowerShell"; Flags: postinstall nowait skipifsilent
