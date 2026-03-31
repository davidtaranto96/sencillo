@echo off
cd /d C:\dev\finanzas-app
echo [1/2] Verificando local.properties...
if not exist android\local.properties (
    echo sdk.dir=C:\\Users\\david\\AppData\\Local\\Android\\Sdk > android\local.properties
    echo Creado: android\local.properties
) else (
    echo OK: android\local.properties existe
)
echo [2/2] Iniciando expo run:android...
npx expo run:android
