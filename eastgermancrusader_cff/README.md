# EastGermanCrusader CFF (Call For Fire) System

## Version 2.0 - Optimiert für Mehrspieler

Artillerie- und Flak-System für Star Wars RP Server mit 20-50 Spielern.

---

## 🔧 BUG-FIXES

### ❌ BEHOBEN: Kreisende Flak-Schüsse
**Problem:** Im Flak-Modus flogen die Projektile im Kreis statt geradeaus zum Ziel.

**Ursache:** Die `GetTarget`-Funktion gab das Projektil selbst zurück (`return missile`), was dazu führte, dass das Projektil sich selbst verfolgte.

**Lösung:** 
- `GetTarget` gibt jetzt `nil` zurück (keine Zielverfolgung)
- Projektil erhält eine feste Velocity direkt zum Ziel
- Gravity ist deaktiviert für gerade Flugbahn
- Automatische Selbstzerstörung nach Flugzeit + 2 Sekunden

```lua
-- Vorher (FEHLERHAFT):
projectile.GetTarget = function(missile) 
    return missile  -- Verfolgt sich selbst!
end

-- Nachher (KORREKT):
projectile.GetTarget = function(missile)
    return nil  -- Keine Zielverfolgung
end
local phys = projectile:GetPhysicsObject()
phys:EnableGravity(false)
phys:SetVelocity(dir * speed)  -- Gerade Flugbahn
```

---

## ⚡ PERFORMANCE-OPTIMIERUNGEN

### Server-Optimierungen
| Änderung | Vorher | Nachher | Verbesserung |
|----------|--------|---------|--------------|
| Think() Intervall | 0.5s | 1.0s | -50% CPU |
| Flak-Scan Intervall | 1.0s | 2.0s | -50% Scans |
| AV-7 Suche | Jedes Mal | Gecacht (3s) | -90% Aufrufe |
| Spieler-Benachrichtigung | player.GetAll() | GetPlayersInRadius() | Nur nahe Spieler |

### Client-Optimierungen
| Änderung | Vorher | Nachher | Verbesserung |
|----------|--------|---------|--------------|
| Menü-Update | 0.5s | 1.0s | -50% Updates |
| 3D Text Distanz | 200 Units | 150 Units | -25% Render-Calls |
| AV-7 Zählung (Draw) | Jeden Frame | Gecacht (2s) | -99% Aufrufe |
| DistToSqr statt Distance | Nein | Ja | Keine Wurzelberechnung |

---

## 📁 DATEISTRUKTUR

```
eastgermancrusader_cff/
├── addon.json
├── lua/
│   ├── autorun/
│   │   └── sh_cff_init.lua          # Globale Config & Network-Strings
│   ├── entities/
│   │   ├── sw_rep_command_center/   # Republic Command Center
│   │   │   ├── shared.lua
│   │   │   ├── init.lua             # Server mit Bug-Fix
│   │   │   └── cl_init.lua          # Client optimiert
│   │   └── sw_kus_command_center/   # KUS Command Center
│   │       ├── shared.lua
│   │       ├── init.lua
│   │       └── cl_init.lua
│   └── weapons/
│       ├── sw_artillery_binocular/  # Republic Binocular
│       │   ├── shared.lua
│       │   ├── init.lua
│       │   └── cl_init.lua
│       └── sw_kus_binocular/        # KUS Binocular
│           ├── shared.lua
│           ├── init.lua
│           └── cl_init.lua
├── materials/                        # Binocular Texturen
└── models/                           # Binocular Model
```

---

## ⚙️ KONFIGURATION

Alle Einstellungen in `lua/autorun/sh_cff_init.lua`:

```lua
CFF_CONFIG = {
    -- Performance
    FlakCheckInterval = 2.0,      -- Sekunden zwischen Flak-Scans
    ThinkInterval = 1.0,          -- Server Think-Intervall
    AV7CacheTime = 3.0,           -- AV-7 Cache-Dauer
    MenuUpdateInterval = 1.0,     -- Client-Menü Updates
    Draw3DDistance = 150,         -- 3D Text Sichtweite
    
    -- Gameplay
    RequestTimeout = 60,          -- Anfrage-Timeout
    RequestCooldown = 5,          -- Cooldown zwischen Anfragen
    ShotsPerAV7 = 3,              -- Schüsse pro AV-7
    ShotDelay = 3,                -- Sekunden zwischen Schüssen
    NotifyRadius = 200,           -- Benachrichtigungs-Radius
    
    -- Flak
    FlakHeightMultiplier = 500,   -- Units pro Höhenstufe
    FlakDamage = 550,             -- Schaden
    FlakRadius = 350,             -- Explosionsradius
    FlakProjectileSpeed = 4000,   -- Projektilgeschwindigkeit
}
```

---

## 🎮 VERWENDUNG

### Artillerie anfordern
1. **Artillerie Binocular** ausrüsten
2. **Rechtsklick (RMB)** oder **Z** für Zoom
3. Ziel anvisieren
4. **Linksklick (LMB)** oder **F** für Anfrage

### Anfrage bearbeiten (Command Center)
1. Command Center benutzen (**E**)
2. Anfragen in der Liste sehen
3. **Linksklick** = Annehmen
4. **Rechtsklick** = Ablehnen

### Flak-Modus aktivieren
1. Command Center öffnen
2. **Flak: EIN** klicken
3. Höhenstufe wählen (Schicht 1-4)
4. Automatische Flugzeug-Verfolgung aktiv

---

## 📋 ANFORDERUNGEN

- Garry's Mod Server
- **LVS (Land Vehicle Simulator)** mit AV-7 Artillerie
- EastGermanCrusader Base (optional, für Kategorie)

---

## 🔄 MIGRATION VON ALTER VERSION

1. Altes `eastgermancrusader_cff` Addon löschen
2. Neues Addon in `addons/` kopieren
3. Server neustarten

**Hinweis:** Network-Strings wurden von `sw_artillery_*` zu `cff_*` geändert für bessere Trennung.

---

## 📊 KATEGORIEN

Alle Entities und Waffen erscheinen unter:
- **Spawnmenü:** `EastGermanCrusader`
- **Utilities:** `EastGermanCrusader`

---

## 🐛 BEKANNTE EINSCHRÄNKUNGEN

- Flak-Modus erfordert mindestens eine unbemannte AV-7
- LVS Fahrzeuge müssen `GetVehicleType()` unterstützen für Flak-Tracking
- Projektile werden nach Flugzeit + 2s automatisch entfernt (falls Ziel verfehlt)

---

## 📝 CHANGELOG

### v2.0
- ✅ **FLAK BUG BEHOBEN:** Projektile fliegen jetzt geradeaus
- ✅ Think() Intervall optimiert (0.5s → 1.0s)
- ✅ Flak-Scan Intervall reduziert (1s → 2s)
- ✅ AV-7 Caching implementiert (Server & Client)
- ✅ 3D Text Render-Distanz reduziert
- ✅ DistToSqr statt Distance für Performance
- ✅ Kategorie auf EastGermanCrusader angepasst
- ✅ Separate KUS-Version mit eigenen Network-Strings
