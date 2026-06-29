@echo off
cd /d "%~dp0"
if exist "C:\Program Files\LOVE\love.exe" (
    start "" "C:\Program Files\LOVE\love.exe" .
    exit
) else (
    echo Love2D no encontrado en la ruta predeterminada.
    pause
)
