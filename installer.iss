#define MyAppName "Shadja"
#define MyAppVersion "1.0.5 270826001"
#define MyAppPublisher "PT Coding Aja Indonesia"
#define MyAppExeName "shadja.exe"

[Setup]
AppId={{YOUR-APP-GUID-HERE}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

OutputDir=installer
OutputBaseFilename={#MyAppName}-Setup-{#MyAppVersion}

Compression=lzma
SolidCompression=yes

ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"

Name: "{autodesktop}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Jalankan {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent