@echo off
chcp 65001 >nul
REM Sync: Repo mit GitHub abgleichen (Pull mit Rebase + Push)
REM Wenn du direkt auf GitHub commitet hast, holt dieses Skript die Änderungen.

cd /d "%~dp0"

if not exist ".git" (
    echo Fehler: Hier ist kein Git-Repo (.git nicht gefunden).
    pause
    exit /b 1
)

echo === AN_Addons Sync ===
echo Ordner: %CD%
echo.

for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set BRANCH=%%b
if "%BRANCH%"=="" set BRANCH=main

REM Uncommittete Änderungen zwischenspeichern (damit Pull funktioniert)
git diff --quiet 2>nul
if errorlevel 1 (
    echo --- Uncommittete Änderungen werden gestasht ---
    git stash push -u -m "sync vor pull"
    set DID_STASH=1
) else (
    git diff --cached --quiet 2>nul
    if errorlevel 1 (
        echo --- Gestagte Änderungen werden gestasht ---
        git stash push -u -m "sync vor pull"
        set DID_STASH=1
    ) else (
        set DID_STASH=0
    )
)

echo --- Änderungen von GitHub holen (fetch + pull --rebase) ---
git fetch origin
if errorlevel 1 (
    echo Fetch fehlgeschlagen.
    if "%DID_STASH%"=="1" git stash pop
    pause
    exit /b 1
)

git pull origin %BRANCH% --rebase
if errorlevel 1 (
    echo.
    echo Pull/Rebase fehlgeschlagen - evtl. Konflikte. Bitte manuell beheben.
    if "%DID_STASH%"=="1" git stash pop
    pause
    exit /b 1
)

if "%DID_STASH%"=="1" (
    echo --- Stash wieder anwenden ---
    git stash pop
)

echo.
echo --- Lokale Commits hochladen (push) ---
git push origin %BRANCH%
if errorlevel 1 (
    echo Push fehlgeschlagen - siehe Meldung oben.
    pause
    exit /b 1
)

echo.
echo --- Fertig. Repo ist mit GitHub synchron. ---
git status -s
echo.
pause
