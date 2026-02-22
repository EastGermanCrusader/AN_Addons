# EastGermanCrusader LVS Overhaul - Server Edition

## ✅ SERVER-READY!
Dieses Addon ist jetzt vollständig für Server-Betrieb optimiert!

## Was wurde geändert?
1. **Dedizierte Flare-Dateien** für jedes Fahrzeug (wie beim ARC-170)
2. **RWS erweitert** für alle Luftfahrzeuge inkl. Space-Varianten
3. **addon.json** für Server-Kompatibilität hinzugefügt

## Unterstützte Fahrzeuge

### ✅ Flares + RWS aktiviert für:

**Starfighter:**
- lvs_starfighter_vwing (V-Wing)
- lvs_starfighter_n1 (N1 Starfighter)
- lvs_starfighter_arc170 (ARC-170) [bereits vorhanden]

**LAAT/Gunships:**
- lvs_repulsorlift_gunship (LAAT/i Gunship)
- lvs_repulsorlift_dropship (LAAT/c Dropship)

**Rho-Class Shuttles (alle Varianten):**
- lvs_repulsorlift_rho_class_imperial
- lvs_repulsorlift_rho_class
- lvs_repulsorlift_rho_class_medical_2
- lvs_repulsorlift_rho_class_medical
- lvs_repulsorlift_rho_class_republic
- lvs_repulsorlift_rho_class_republic_2

**Space-Varianten:**
- lvs_space_laat_arc (LAAT ARC Space)
- lvs_space_laat (LAAT Space)

## Features

### 🎯 Flares (Täuschkörper)
- Automatisch zu Fahrzeugen hinzugefügt beim Spawnen
- Individuelle Konfigurationen pro Fahrzeugtyp
- Heat Signature System integriert
- Burst-Modus für effektive Verteidigung

### 📡 RWS (Radar Warning System)
- **Automatische Erkennung** aller Luftfahrzeuge
- **3 Warnstufen:**
  - CLEAR (grün) - Keine Bedrohung
  - CONTACT (gelb) - Feindliche Fahrzeuge in der Nähe
  - RADAR LOCK (orange) - Rakete anvisiert
  - MISSILE (rot, blinkend) - Rakete im Anflug!
- **HUD-Anzeige** mit Raketen-Markierungen
- **Sound-Warnungen** (Contact, Radar, Missile)

### 🤖 AI Waffen-System (NEU!)
- **Distanz-basierte Waffenwahl:**
  - < 5000 Units: Nur Primärwaffe
  - 5000-8000 Units: Primär & Sekundär abwechselnd
  - ≥ 7000 Units: Auch Raketen/Torpedos
- **Intelligentes Hitze-Management**
- **Automatischer Waffenwechsel**
- Siehe `AI_WEAPONS_GUIDE.md` für Details

### 🚀 Weitere Features
- Buzzdroid Missiles
- Sunstrike Weapon
- Heat Signature System
- AI Flares & Weapons
- Missile Flare Redirection

## Installation auf Server

### Workshop:
1. Addon in deiner Steam Workshop Collection veröffentlichen
2. Collection-ID in server.cfg eintragen:
   ```
   workshop_collection_id "DEINE_COLLECTION_ID"
   ```

### FastDL/Manual:
1. Ordner `eastgermancrusader_lvs_overhaul` in `garrysmod/addons/` kopieren
2. Server neustarten
3. Clients laden Dateien automatisch herunter

## Fehlerbehebung

### Fahrzeuge haben keine Flares?
1. Console-Befehl: `egc_flares_debug` - Zeigt Status aller Fahrzeuge
2. Force-Setup: `egc_flares_force` - Erzwingt Flare-Installation

### RWS funktioniert nicht?
- RWS aktiviert sich automatisch für alle Luftfahrzeuge
- Überprüfe ob du im Fahrzeug sitzt (nur Pilot sieht RWS)
- Sound-Dateien müssen geladen sein (contact.wav, radar.wav, missile.wav)

## Abhängigkeiten
- **LVS Base** (Lenny's Vehicle System)
- **Unity Flares** (für Flare-Entities)
- **Star Wars Vehicles Pack** (für die Fahrzeuge)

## Changelog

### v2.1 (Server Edition + AI Update)
- ✅ **AI Waffen-System überarbeitet**
  - Distanz-basierte Waffenwahl (< 5000 / 5000-8000 / ≥ 7000 Units)
  - Intelligenter Primär/Sekundär Wechsel
  - Präzise Raketen-Nutzung ab 7000 Units
- ✅ Dedizierte Flare-Dateien pro Fahrzeug
- ✅ RWS für alle gewünschten Fahrzeuge
- ✅ Space-Fahrzeugtyp Support
- ✅ Server-Kompatibilität verbessert
- ✅ Alte vehicle_flares.lua deaktiviert

### v1.0 (Original)
- ARC-170 Flares
- RWS System
- Heat Signature
- Buzzdroid Missiles

## Credits
- **EastGermanCrusader** - Original Addon & Entwicklung
- **Lenny** - LVS Framework
- **Unity** - Flare System

## Support
Bei Problemen oder Fragen:
1. Console-Logs prüfen
2. Debug-Befehle nutzen
3. GitHub Issues erstellen
