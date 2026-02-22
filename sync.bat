@echo off
chcp 65001 >nul
REM Sync-Skript: Repo im aktuellen Ordner mit GitHub abgleichen (Pull + Push)
REM Nutzung: Doppelklick auf sync.bat ODER im Repo-Ordner: sync.bat

cd /d "%~dp0"

if not exist ".git" (
    echo Fehler: Hier ist kein Git-Repo (.git nicht gefunden).
    echo Wechsle in den AN_Addons-Ordner und führe sync.bat dort aus.
    pause
    exit /b 1
)

echo === AN_Addons Sync ===
echo Ordner: %CD%
echo.

for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set BRANCH=%%b
if "%BRANCH%"=="" set BRANCH=main

echo --- Änderungen von GitHub holen (pull) ---
git pull origin %BRANCH%
if errorlevel 1 (
    echo Pull fehlgeschlagen.
    pause
    exit /b 1
)
echo.

echo --- Lokale Änderungen hochladen (push) ---
git push origin %BRANCH%
if errorlevel 1 (
    echo.
    echo Hinweis: Push fehlgeschlagen - evtl. uncommittete Änderungen.
    echo          Erst "git add" und "git commit" ausführen, dann Sync erneut.
    pause
    exit /b 1
)
echo.

echo --- Fertig. Repo ist synchron. ---
git status -s
echo.
pause
