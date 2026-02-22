--[[
    eastgermancrusade_Ship_systems
    Konfiguration & Netzwerk-Strings
    Venator Shield-System | Power Distribution | Breach-Mechanik
]]

if SERVER and AddCSLuaFile then
    AddCSLuaFile()
    AddCSLuaFile("vgui/egc_ship_power_terminal.lua")
end

EGC_SHIP = EGC_SHIP or {}

EGC_SHIP.Config = {
    -- ===================
    -- REAKTOR & ENERGIE
    -- ===================
    ReactorTotalOutput = 1000,        -- R_total: Gesamtleistung (arb. Einheiten)
    MaxPowerPerSector = 150,          -- Max. zuweisbare Energie pro Sektor
    OverloadThreshold = 1.0,          -- 100% = Normal; >1 = Überlastung
    OverloadDamageRate = 2,           -- Schaden an Emittern pro Sekunde bei Überlast
    BaseRegenPerUnit = 1.5,           -- Regeneration pro Energieeinheit (%-Punkte/s)

    -- ===================
    -- SCHILDE
    -- ===================
    ShieldMaxHealth = 100,            -- Max. Schildstärke pro Sektor (%)
    HullMaxHealth = 100,              -- Max. Hüllen-Integrität pro Sektor (%)
    GateBreachThreshold = 0,          -- Schild auf 0% = Hangar-Breach möglich
    BreachRepairTime = 30,            -- Sekunden für Techniker-Reparatur pro Sektor
    EmitterHealth = 200,              -- HP pro Emitter-Entity (Überlast-Schaden)

    -- ===================
    -- MESH / POLYGON (navmesh-ähnlich: Kontrollpunkte → Form, Kanten passen sich der Map an)
    -- ===================
    MaxVerticesPerMesh = 64,          -- Pro Polygon-Mesh (Kontrollpunkte)
    MaxMeshesPerSector = 8,          -- Hull + Gate pro Sektor
    MeshAdaptStepSize = 40,          -- Ein Punkt alle X Units entlang der Kante (Anpassung an Map)
    MeshAdaptTraceDist = 500,        -- Trace-Reichweite zum Anheften an Oberflächen (Units)
    MeshCollisionGroup = COLLISION_GROUP_WORLD,
    ShieldTraceMask = MASK_SHOT,
    -- Kollision: Geschosse & Props
    ShieldBlockBullets = true,           -- Geschosse an aktiven Schilden blockieren
    ShieldBulletDamageScale = 1,         -- Faktor auf Bullet.Damage
    ShieldSectorDamagePerPoint = 0.15,   -- Sektor-Schaden in % pro 1 Bullet.Damage (z.B. 20 Dmg → 3%)
    ShieldMaxTraceDist = 50000,         -- Max. Ray-Distanz für Treffer
    GateBlockProps = true,              -- Props an nicht gebrochenen Gates abweisen
    GatePropPushForce = 800,             -- Kraft beim Rausdrücken (bei Breach kein Push)
    GatePropCheckRadius = 200,          -- Um welchen Punkt (Mesh-Mitte) nach Entities suchen
    GatePropThinkInterval = 0.15,       -- Sekunden zwischen Prop-Checks (Performance)

    -- ===================
    -- PERSISTENZ
    -- ===================
    DataFolder = "egc_ship_systems",  -- Unter garrysmod/data/
    MapDataFile = "shield_data.json",

    -- ===================
    -- WIREMOD
    -- ===================
    WireShieldOutputs = true,         -- Schild-% pro Sektor als Output
    WireBreachOutputs = true,         -- Breach-Status (0/1) pro Sektor
    WireAlarmOnBreach = true,         -- Alarm-Trigger bei Breach

    -- ===================
    -- VISUELL
    -- ===================
    ShieldFlickerThreshold = 25,     -- Unter diesem % flackert der Schild
    HitParticleHexScale = 1.0,
    LowEnergyColor = Color(255, 80, 80),
    FullEnergyColor = Color(80, 180, 255),

    -- ===================
    -- SICHERHEIT (Anbindung eastgermancrusader_base)
    -- ===================
    -- Erlaubte Sektor-IDs für Net-Input (Whitelist, verhindert Injection)
    AllowedSectorIds = {
        bow = true, stern = true, hangar_port = true, hangar_starboard = true,
        hull_port = true, hull_starboard = true, bridge = true, engine = true, custom = true,
    },
    MaxSectorIdLen = 32,
    MaxMeshIdLen = 128,
    MaxVertexDistance = 50000,        -- Max. Abstand eines Vertex vom Weltmittelpunkt (Anti-Crash)
}

-- Sektor-Typen (für Zuordnung)
EGC_SHIP.SectorTypes = {
    "bow",           -- Bug
    "stern",         -- Heck
    "hangar_port",   -- Hangar Steuerbord
    "hangar_starboard",
    "hull_port",
    "hull_starboard",
    "bridge",
    "engine",
    "custom",
}

-- Netzwerk-Strings (Server)
if SERVER then
    util.AddNetworkString("EGC_Ship_ShieldData")
    util.AddNetworkString("EGC_Ship_PowerState")
    util.AddNetworkString("EGC_Ship_SectorDamage")
    util.AddNetworkString("EGC_Ship_BreachState")
    util.AddNetworkString("EGC_Ship_RequestFullState")
    util.AddNetworkString("EGC_Ship_ToolVertex")
    util.AddNetworkString("EGC_Ship_ToolFinishMesh")
    util.AddNetworkString("EGC_Ship_PowerSlider")
    util.AddNetworkString("EGC_Ship_RepairSector")
    util.AddNetworkString("EGC_Ship_DiagnosticRequest")
    util.AddNetworkString("EGC_Ship_DiagnosticResult")
end
