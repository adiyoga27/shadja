@echo off
setlocal
cd /d "%~dp0"

rem --- Buat shortcut di Desktop ---
powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Shadja POS.lnk'); $s.TargetPath='%~dp0shadja.exe'; $s.WorkingDirectory='%~dp0'; $s.Save()"

rem --- Jalankan aplikasi ---
start "" "%~dp0shadja.exe"
exit /b
