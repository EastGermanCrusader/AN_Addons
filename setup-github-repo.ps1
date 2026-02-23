# Einmal ausführen nach: gh auth login (und Anmeldung im Browser)
# Erstellt das GitHub-Repo AN_Addons und pusht den Inhalt

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$git = "C:\Program Files\Git\bin\git.exe"
$gh = "C:\Program Files\GitHub CLI\gh.exe"

Write-Host "Prüfe GitHub-Anmeldung..."
& $gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host "Bitte zuerst anmelden: gh auth login -h github.com -p https -w"
    exit 1
}

Write-Host "Erstelle Repository AN_Addons auf GitHub und pushe..."
& $gh repo create AN_Addons --public --source=. --remote=origin --push
if ($LASTEXITCODE -eq 0) {
    Write-Host "Fertig. Dein Repo: https://github.com/EastGermanCrusader/AN_Addons"
} else {
    Write-Host "Falls das Repo schon existiert, nur pushen:"
    Write-Host "  git remote add origin https://github.com/EastGermanCrusader/AN_Addons.git"
    Write-Host "  git push -u origin main"
}
