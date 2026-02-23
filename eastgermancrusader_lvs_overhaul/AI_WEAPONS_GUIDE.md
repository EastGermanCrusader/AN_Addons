# 🤖 AI WAFFEN-SYSTEM - Dokumentation

## ✅ NEUE DISTANZ-BASIERTE WAFFENWAHL

Die AI nutzt jetzt intelligente, distanzbasierte Waffenwahl für realistisches Kampfverhalten!

### 📏 Distanz-Regeln (in GMod Units)

| Distanz | Waffen-Verhalten | Beschreibung |
|---------|------------------|--------------|
| **< 5000 Units** | 🎯 Nur Primärwaffe (Waffe 1) | Nahkampf - Fokus auf Hauptwaffe |
| **5000-8000 Units** | 🔄 Primär & Sekundär abwechselnd | Mittlere Distanz - Wechsel zwischen Waffe 1 & 2 |
| **≥ 7000 Units** | 🚀 Auch Raketen/Torpedos | Lange Distanz - Alle Waffen verfügbar |

### 🎮 Waffen-Typen

#### 1. Primärwaffe (Waffe 1)
- Meistens Schnellfeuer-Laser
- Immer verfügbar
- Standard-Waffe für alle Distanzen

#### 2. Sekundärwaffe (Waffe 2)
- Schwere Laser oder alternative Waffensysteme
- Ab 5000 Units im Wechsel mit Primärwaffe
- Automatischer Wechsel alle 3 Sekunden

#### 3. Raketen/Torpedos (Waffe 3+)
- Homing Missiles, Proton Torpedos, etc.
- Nur ab 7000 Units Distanz
- Automatisches Locken und Abfeuern

## ⚙️ TECHNISCHE DETAILS

### Primär/Sekundär Wechsel-Logik (5000-8000 Units)

```lua
-- Wechsel alle 3 Sekunden zwischen Waffe 1 und 2
-- ODER bei Überhitzung sofort wechseln
if Hitze > 85% then
    Sofort wechseln!
else
    Alle 3 Sekunden wechseln
end
```

### Raketen-Abschuss-Logik (≥ 7000 Units)

```lua
Bedingungen für Raketen:
✅ Distanz ≥ 7000 Units
✅ Winkel zum Ziel ≤ 45°
✅ Cooldown abgelaufen (4 Sekunden)
✅ Raketen-Munition vorhanden
✅ 70% Chance (zufällig)

Ablauf:
1. Wechsel zu Raketen-Waffe
2. Lade/Locke Rakete (1.2-3.0 Sekunden)
3. Feuer!
4. Zurück zu Primärwaffe
```

## 📊 KONFIGURIERBARE WERTE

Alle Werte in der Datei `eastgermancrusader_lvs_ai_weapons.lua`:

```lua
AI_WEAPON_CONFIG = {
    -- Distanz-Schwellwerte
    PrimaryOnlyDistance = 5000,      -- Unter 5000: nur Primär
    SecondaryStartDistance = 5000,   -- Ab 5000: + Sekundär
    SecondaryEndDistance = 8000,     -- Bis 8000: Primär/Sekundär
    MissileStartDistance = 7000,     -- Ab 7000: + Raketen
    
    -- Wechsel-Einstellungen
    AlternatingInterval = 3.0,       -- Sekunden zwischen Waffe 1<->2
    WeaponSwitchCooldown = 1.5,      -- Min. Cooldown für Wechsel
    HeatThresholdHigh = 0.85,        -- Bei 85% Hitze -> sofort wechseln
    
    -- Raketen-Einstellungen
    MissileTargetAngle = 45,         -- Max. Winkel für Abschuss
    MissileCooldown = 4.0,           -- Sekunden zwischen Raketen
    MissileChance = 0.7,             -- 70% Chance
    MissileLoadTime = 1.2,           -- Min. Ladezeit
    MissileMaxLoadTime = 3.0,        -- Max. Ladezeit
}
```

## 🔧 DEBUG-MODUS

Aktiviere den Debug-Modus für detaillierte Console-Ausgaben:

**Console-Befehl:** `lvs_ai_weapon_debug`

**Debug-Ausgaben zeigen:**
- Waffenwechsel mit Begründung
- Distanz-Entscheidungen
- Raketen-Ladevorgang
- Überhitzungs-Wechsel

**Beispiel:**
```
[AI Weapons] Distanz 6543 (5000-8000) -> Wechsel zu Waffe 2
[AI Weapons] Überhitzt! Wechsel zu Waffe 1
[AI Weapons] Distanz 7823 >= 7000 -> Lade Rakete (Waffe 3)...
[AI Weapons] Rakete abgefeuert! (Lock: true, LoadTime: 1.8s)
```

## 📈 BEISPIEL-SZENARIO

**Luftkampf zwischen zwei Vulture Droids:**

1. **Start (10000 Units Distanz)**
   - Beide feuern Raketen ab (≥ 7000)
   - Ausweichmanöver

2. **Annäherung (6000 Units)**
   - Wechsel zu Laser-Kombination
   - Primär (Schnellfeuer) ↔ Sekundär (Schwer)
   - Alle 3 Sekunden automatischer Wechsel

3. **Nahkampf (3000 Units)**
   - Nur noch Primärwaffe (Schnellfeuer-Laser)
   - Maximales DPS
   - Enge Manöver

4. **Flucht (8000+ Units)**
   - Zurück zu Raketen wenn verfügbar
   - Oder Primär/Sekundär-Kombo

## 🎯 VORTEILE DES SYSTEMS

✅ **Realistisches Kampfverhalten**
- Raketen für Fernkampf
- Laser-Wechsel für Mitteldistanz
- Fokussiertes Feuer im Nahkampf

✅ **Hitze-Management**
- Automatischer Wechsel bei Überhitzung
- Keine Waffen-Downtime

✅ **Munitions-Effizienz**
- Raketen nur wenn sinnvoll
- Laser als Hauptwaffen

✅ **Performance**
- Nur aktiv für AI-gesteuerte Fahrzeuge
- Optimierte Prüfungen (alle 0.1s)
- Minimale Server-Last

## 🚁 UNTERSTÜTZTE FAHRZEUGE

Das System funktioniert mit **allen LVS Luftfahrzeugen** die über:
- Mehrere Waffen verfügen
- AI-Steuerung aktiviert haben
- `RunAI` Funktion besitzen

**Besonders effektiv bei:**
- Vulture Droids (3+ Waffen)
- ARC-170 (Laser + Raketen)
- V-Wing (Laser + Torpedos)
- LAAT Gunships (Laser + Missiles)
- Alle anderen Multi-Waffen Starfighter

## ⚠️ WICHTIG

- **Nur Server-seitig** - Client braucht die Datei nicht
- **Automatisch aktiviert** - Keine Konfiguration nötig
- **Kompatibel** mit allen anderen AI-Addons
- **Funktioniert NUR bei AI-Fahrzeugen** - Spieler nicht betroffen

## 🔄 ÄNDERUNGEN vs. VORHER

### VORHER:
- Feste Distanz-Regeln (800-5000 Units für Raketen)
- Hitze-basierter Wechsel
- Weniger vorhersagbar

### JETZT:
- **Klare 3-Stufen-Logik**
- **Distanz-optimiert** für jede Kampfphase
- **Intelligenter Primär/Sekundär Wechsel**
- **Präzise Raketen-Nutzung**

---

**Bei Fragen oder Problemen:** Debug-Modus aktivieren und Console prüfen!
