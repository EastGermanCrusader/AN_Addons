--[[
    EastGermanCrusader Ship Shield System
    =====================================
    
    KONZEPT:
    - Schildgenerator-Entity als physische Quelle des Schilds
    - Hull-Punkte (LMB): Definieren die Außengrenze des Schilds
    - Gate-Punkte (RMB): Markieren Durchlass-Zonen (Hangar-Tore)
    
    FUNKTIONSWEISE:
    - Schild blockiert Geschosse und Props von außen
    - Gate-Bereiche lassen Props durch (auch bei aktivem Schild)
    - System scannt automatisch die Map-Geometrie
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
    ScanResolution = 50,                -- Units zwischen Scan-Punkten
    ScanHeight = 500,                   -- Vertikale Scan-Reichweite
    MaxHullPoints = 128,                -- Max. Punkte für Hull-Mesh
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
    CollisionCheckInterval = 0.1,       -- Sekunden zwischen Kollisions-Checks
    RegenTickInterval = 0.5,            -- Sekunden zwischen Regen-Ticks
    BroadcastInterval = 0.25,           -- Sekunden zwischen Client-Updates
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

-- Netzwerk-Strings
if SERVER then
    util.AddNetworkString("EGC_Shield_FullSync")
    util.AddNetworkString("EGC_Shield_Update")
    util.AddNetworkString("EGC_Shield_Hit")
    util.AddNetworkString("EGC_Shield_ToolPoint")
    util.AddNetworkString("EGC_Shield_ToolFinish")
    util.AddNetworkString("EGC_Shield_ToolClear")
    util.AddNetworkString("EGC_Shield_ScanResult")
    util.AddNetworkString("EGC_Shield_RequestSync")
end
