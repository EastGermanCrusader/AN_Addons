#!/bin/bash
# Bind-Mount: Repo unter /media/sf_transit/AN_Addons einhängen
# Einmal im Terminal ausführen: ./mount-AN_Addons-here.sh (oder: bash mount-AN_Addons-here.sh)

set -e
MOUNT_POINT="/media/sf_transit/AN_Addons"
REPO_DIR="/home/admin/AN_Addons"

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Bereits gemountet: $MOUNT_POINT"
    exit 0
fi

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Fehler: Kein Git-Repo in $REPO_DIR gefunden."
    exit 1
fi

echo "Mounte $REPO_DIR nach $MOUNT_POINT ..."
sudo mount --bind "$REPO_DIR" "$MOUNT_POINT"
echo "Fertig. Ordner 'AN_Addons' liegt jetzt unter /media/sf_transit/AN_Addons und Git funktioniert dort."
echo ""
echo "Hinweis: Nach einem Neustart musst du dieses Skript erneut ausführen,"
echo "oder den Mount dauerhaft einrichten mit: sudo ./mount-AN_Addons-here.sh --fstab"

if [ "$1" = "--fstab" ]; then
    FSTAB_LINE="/home/admin/AN_Addons /media/sf_transit/AN_Addons none bind 0 0"
    if grep -qF "/media/sf_transit/AN_Addons" /etc/fstab 2>/dev/null; then
        echo "Eintrag für $MOUNT_POINT existiert bereits in /etc/fstab."
    else
        echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
        echo "Eintrag in /etc/fstab hinzugefügt."
    fi
    sudo mount "$MOUNT_POINT" 2>/dev/null || true
    echo "Mount dauerhaft eingerichtet."
fi
