--[[
    EastGermanCrusader Ship Shield System (Hull-Wrapping)
    =====================================================
    
    KONZEPT "Hull-Wrapping":
    - Mit dem Tool setzt du nur die Eckpunkte der Schild-Segmente.
    - Das Tool / der Mesh-Generator verbindet diese Punkte zu einem Prisma.
    - Node-Entity (N): Kleines Hilfs-Entity an der Hülle (Eckpunkt).
    - Sektor-Entity: Liest Node-Positionen und erstellt unsichtbares
      PhysicsInitMultiConvex-Entity → fängt Projektile vor der Map ab.
    
    - Hull-Punkte (LMB): Orientierung + Sektor aus diesen Punkten (min. 4).
    - Gate-Punkte (RMB): Durchlass-Zonen (Hangar-Tore).
    
    Nur Nodes + Gate-Flächen:
    - Nodes (LMB) geben Form und Volumen der Venator vor.
    - Schild orientiert sich grob und klobig an den Nodes (ein Convex um alle).
    - Gates = Flächen mit 4–8 Knoten = gültige Form (Durchlass, z. B. Hangar).
]]

if SERVER then
    AddCSLuaFile()
end

EGC_SHIP = EGC_SHIP or {}

EGC_SHIP.Config = {
    -- ===================
    -- GENERATOR
    -- ===================
    GeneratorModel = "models/generator-wall/generator-wall.mdl",
    GeneratorHealth = 500,              -- HP des Generators
    GeneratorRechargeDelay = 5,         -- Sekunden bis Schild nach 0% wieder lädt
    
    -- ===================
    -- SCHILD
    -- ===================
    ShieldMaxPercent = 100,             -- Max. Schildstärke
    ShieldRegenRate = 2,                -- % pro Sekunde Regeneration
    ShieldRegenPowerMult = 0.5,         -- Regen-Multiplikator basierend auf Energie
    
    -- ===================
    -- ENERGIE
    -- ===================
    MaxPowerOutput = 1000,              -- Maximale Energie des Generators
    PowerDrainPerHit = 5,               -- Energie-Verlust pro Treffer
    PowerRegenRate = 10,                -- Energie-Regeneration pro Sekunde
    
    -- ===================
    -- SCHADEN
    -- ===================
    BulletDamageToShield = 0.5,         -- Multiplikator: Bullet-Damage → Schild-%
    ExplosionDamageToShield = 2.0,      -- Multiplikator: Explosion → Schild-%
    ShieldDownDuration = 10,            -- Sekunden bis Schild nach Kollaps wieder hochfährt
    -- Zonen: realistisches Schadensverhalten – alles wirkt, aber unterschiedlich stark (Schüsse wenig → Explosionen mehr → Nuke am meisten)
    ZoneBulletDamageMin = 2,            -- Mindest-Rohschaden pro Kugel (falls Weapon 0 liefert), wird mit Multiplikator verrechnet
    ZoneBulletDamageMultiplier = 0.08, -- Kugeln: sehr wenig Schaden (z. B. AR2 10 → ~0.8, Min 2 → ~0.16)
    ZoneExplosionDamageMin = 5,         -- Kleine Explosions-Ticks (Gbomb-Shockwave 1–20) mind. so viel
    ZoneExplosionDamageMultiplier = 1,  -- Basis-Multiplikator für Explosionen
    ZoneExplosionScaleByAmount = true,  -- true = größere Explosionen schaden dem Schild proportional mehr (RPG < Nuke)
    ZoneExplosionScaleRef = 300,        -- Referenzwert: Schaden 300 ≈ Faktor 1, darunter weniger, darüber mehr
    
    -- ===================
    -- GATES (Durchlass-Zonen)
    -- ===================
    GateAllowProps = true,              -- Props durch Gates durchlassen
    GateAllowPlayers = true,            -- Spieler durch Gates durchlassen
    GateAllowVehicles = true,           -- Fahrzeuge durch Gates durchlassen
    GateVisualAlpha = 100,              -- Transparenz der Gate-Visualisierung (0-255)
    
    -- ===================
    -- AUTO-SCAN
    -- ===================
    ScanResolution = 50,                -- Units zwischen Scan-Punkten (kleiner = feiner)
    ScanHeight = 500,                   -- Vertikale Scan-Reichweite
    MaxHullPoints = 256,               -- Max. Punkte für Hull-Mesh (nach Optimierung)
    MaxGatePoints = 32,                 -- Max. Punkte pro Gate
    MaxGatesPerGenerator = 8,           -- Max. Gates pro Generator
    
    -- ===================
    -- VISUALISIERUNG
    -- ===================
    ShieldColor = Color(60, 150, 255, 80),      -- Normale Schildfarbe
    ShieldHitColor = Color(255, 100, 100, 150), -- Farbe bei Treffer
    ShieldLowColor = Color(255, 200, 50, 100),  -- Farbe bei niedrigem Schild
    GateColor = Color(100, 255, 100, 60),       -- Gate-Bereich Farbe
    HullLineColor = Color(60, 200, 255, 200),   -- Hull-Linien Vorschau
    GateLineColor = Color(255, 180, 60, 200),   -- Gate-Linien Vorschau
    
    -- ===================
    -- PERSISTENZ
    -- ===================
    DataFolder = "egc_ship_shields",
    AutoSave = true,
    AutoSaveInterval = 300,             -- Sekunden
    
    -- ===================
    -- PERFORMANCE
    -- ===================
    DrawShieldSectors = false,          -- true = Sektor-Entities im Editor sichtbar (Debug)
    SectorNodeRadius = 5000,            -- Radius zum Finden von Schild-Nodes (Sektor aus Nodes)
    CollisionCheckInterval = 0.1,       -- Sekunden zwischen Kollisions-Checks
    RegenTickInterval = 0.5,            -- Sekunden zwischen Regen-Ticks
    BroadcastInterval = 0.25,           -- Sekunden zwischen Client-Updates
    ZoneExplosionRadius = 450,           -- Radius für Explosionen: Zonen in dieser Reichweite werden getroffen (DMG_BLAST)
    ZoneDamageToleranceRadius = 80,     -- Für alle Schadenstypen: Zonen in dieser Reichweite um Trefferpunkt gelten als getroffen (Area/Nahbereich)
    -- Projektile: Klassen, die als fliegende Geschosse abgefangen werden (durch Zonen). Wert = Schaden bei Treffer.
    -- HL2 RPG (rpg_rocket/rpg_missile) NICHT in der Liste: Rakete soll am Ziel aufschlagen und dort explodieren;
    -- der Explosionsschaden wird über EntityTakeDamage (DMG_BLAST + ZoneExplosionRadius) an die Zonen angewendet.
    ProjectileClasses = {
        -- HL2 (ohne RPG – siehe Kommentar oben)
        ["crossbow_bolt"] = 75,
        ["grenade_ar2"] = 80,
        ["npc_grenade_frag"] = 100,
        ["ar2_combine_ball"] = 20,
        -- LVS (Lenny's Vehicle System)
        ["lvs_sam_torpedo"] = 200,
        -- Gbomb (g&h_bombs)
        ["gb5_proj_howitzer_shell_frag"] = 120,
        ["gb5_proj_howitzer_shell_he"] = 150,
        ["gb5_proj_howitzer_shell_in"] = 100,
        ["gb5_proj_howitzer_shell_cl"] = 80,
        ["gb5_proj_icbm"] = 300,
        ["gb5_light_peldumb"] = 90,
        ["gb5_m_clustermine_blet_ad"] = 60,
        ["gb5_m_clustermine_bomblet"] = 70,
        ["gb5_heavy_cbu_bomblet"] = 65,
        ["gb5_light_schrapnel_bomb"] = 50,
        -- Hbomb (g&h_bombs)
        ["hb_proj_v2_small"] = 180,
        ["hb_main_clusterbomblet"] = 70,
        ["hb_main_bigjdam"] = 100,
        ["hb_misc_grenade"] = 80,
        -- ArcCW (Projektil-Waffen; viele ArcCW-Waffen nutzen EntityFireBullets = werden bereits abgefangen)
        ["arccw_apex_ball"] = 25,
        ["arccw_proj_he"] = 90,
        ["arccw_proj_he_ubgl"] = 90,
        ["arccw_proj_slug"] = 40,
        ["arccw_frag"] = 85,
    },
    ProjectileCheckInterval = 0.04,      -- Sekunden zwischen Projektil-Checks (25 Hz)
}

-- Sektor-Typen für Organisation
EGC_SHIP.SectorTypes = {
    "bow",              -- Bug
    "stern",            -- Heck
    "port",             -- Backbord
    "starboard",        -- Steuerbord
    "bridge",           -- Brücke
    "hangar_main",      -- Haupthangar
    "hangar_aux",       -- Nebenhangar
    "engine",           -- Antrieb
}

-- ===================
-- DAMAGE-ZONEN (Flächen)
-- ===================
EGC_SHIP.MinZoneVertices = 3   -- Mindest-Knoten pro Fläche
EGC_SHIP.DamageZones = EGC_SHIP.DamageZones or {}  -- Wird auf Server geführt, an Clients gesynct

-- Netzwerk-Strings
if SERVER then
    util.AddNetworkString("EGC_Shield_FullSync")
    util.AddNetworkString("EGC_Shield_Update")
    util.AddNetworkString("EGC_Shield_Hit")
    util.AddNetworkString("EGC_Shield_ScanResult")
    util.AddNetworkString("EGC_Shield_RequestSync")
    util.AddNetworkString("EGC_Shield_SectorMesh")
    -- Damage-Zonen (Flächen)
    util.AddNetworkString("EGC_DamageZone_Finish")
    util.AddNetworkString("EGC_DamageZones_FullSync")
    util.AddNetworkString("EGC_DamageZones_RequestSync")
    util.AddNetworkString("EGC_ZoneConfig_Update")  -- Zone umbenennen, Gruppe, Schild/Hüllen-HP
    util.AddNetworkString("EGC_ZoneShieldHit")      -- Treffer auf Zone mit Schild-HP (Ring-Effekt)
    util.AddNetworkString("EGC_ZoneShieldDepleted")  -- Schild-HP der Zone auf 0 → Zone leuchtet kurz weiß
    util.AddNetworkString("EGC_ZoneHPUpdate")        -- Sofortige HP-Aktualisierung einer Zone (Schild/Hülle)
end
