#!/bin/bash
# Sync-Skript: Repo im aktuellen Ordner mit GitHub abgleichen (Pull + Push)
# Nutzung: Im Repo-Ordner ausführen → ./sync.sh   oder   bash sync.sh

set -e
cd "$(dirname "$0")"

if [ ! -d .git ]; then
    echo "Fehler: Hier ist kein Git-Repo (.git nicht gefunden)."
    echo "Wechsle in den AN_Addons-Ordner und führe sync.sh dort aus."
    exit 1
fi

echo "=== AN_Addons Sync ==="
echo "Ordner: $(pwd)"
echo ""

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
echo "--- Änderungen von GitHub holen (pull) ---"
git pull origin "$BRANCH" --rebase 2>/dev/null || git pull origin "$BRANCH"
echo ""

echo "--- Lokale Änderungen hochladen (push) ---"
if git diff --staged --quiet 2>/dev/null && git diff --quiet 2>/dev/null; then
    echo "Keine lokalen Änderungen zum Pushen."
else
    echo "Hinweis: Du hast uncommittete Änderungen."
    echo "         Erst 'git add' und 'git commit' ausführen, dann Sync erneut starten."
fi
git push origin "$BRANCH"
echo ""

echo "--- Fertig. Repo ist synchron. ---"
git status -s
