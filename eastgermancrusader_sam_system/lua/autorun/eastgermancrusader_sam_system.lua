-- EastGermanCrusader SAM System - Hauptinitialisierung
-- Surface-to-Air Missile System (VLS) - Kompatibel mit LVS Framework
if SERVER and not _LVS_NodeOK then return end

-- LVS ist optional - VLS funktioniert auch ohne, aber braucht LVS-Ziele zum Tracken
if not LVS then 
    print("[EGC SAM System] INFO: LVS Framework nicht gefunden. VLS wird Ziele nur tracken wenn LVS geladen ist.")
end

print("============================================")
print("[EGC SAM System] Surface-to-Air Missile System")
print("[EGC SAM System] Version 1.0 by EastGermanCrusader")
print("============================================")

-- Globale SAM Konfiguration
EGC_SAM = EGC_SAM or {}

EGC_SAM.Config = {
    -- Radar-Einstellungen
    RadarRange = 15000,
    RadarSweepInterval = 0.5,
    
    -- Lock-On Einstellungen
    LockOnTime = 2.0,
    LockBreakAngle = 60,
    
    -- Raketen-Einstellungen
    MissileSpeed = 4000,
    MissileMaxSpeed = 6000,
    MissileDamage = 500,
    MissileSplashDamage = 300,
    MissileSplashRadius = 400,
    MissileLifetime = 15,
    
    -- Tracking-Einstellungen
    TrackingConeAngle = 45,
    FlareDeflectionChance = 0.8,
    MinHeatSignature = 5,
    
    -- Debug
    Debug = false,
}

-- Hilfsfunktionen
function EGC_SAM.GetConfig(key)
    return EGC_SAM.Config[key]
end

function EGC_SAM.SetConfig(key, value)
    if EGC_SAM.Config[key] ~= nil then
        EGC_SAM.Config[key] = value
        print("[EGC SAM System] Config '" .. key .. "' auf " .. tostring(value) .. " gesetzt")
    end
end

-- Debug-Funktion
function EGC_SAM.DebugPrint(msg)
    if EGC_SAM.Config.Debug then
        print("[EGC SAM Debug] " .. msg)
    end
end

-- ConCommands
if SERVER then
    concommand.Add("sam_debug", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        EGC_SAM.Config.Debug = not EGC_SAM.Config.Debug
        print("[EGC SAM System] Debug-Modus: " .. (EGC_SAM.Config.Debug and "AN" or "AUS"))
    end)
    
    concommand.Add("sam_config", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        
        if #args == 0 then
            print("=== EGC SAM System Konfiguration ===")
            for k, v in pairs(EGC_SAM.Config) do
                print("  " .. k .. " = " .. tostring(v))
            end
        elseif #args == 2 then
            local key = args[1]
            local value = tonumber(args[2]) or args[2]
            if value == "true" then value = true end
            if value == "false" then value = false end
            EGC_SAM.SetConfig(key, value)
        else
            print("Verwendung: sam_config [key] [value]")
        end
    end)
end

print("[EGC SAM System] Hauptmodul geladen!")
