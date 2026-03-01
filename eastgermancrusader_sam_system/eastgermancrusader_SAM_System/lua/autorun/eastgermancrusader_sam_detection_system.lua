-- EastGermanCrusader SAM System - Detection System
-- Globale Funktionen für Transponder/Radar-Status
-- Kompatibel mit Auras Addons

if SERVER then
    -- Cache Entity-Listen (reduziert ents.FindByClass-Aufrufe)
    local cachedReceivers = {}
    local cachedRadars = {}

    timer.Create("EGC_SAM_UpdateEntities", 1, 0, function()
        cachedReceivers = ents.FindByClass("lvs_transponder_receiver")
        cachedRadars = ents.FindByClass("lvs_radar")
    end)

    -- Prüft ob mindestens ein Transponder-Receiver aktiv ist
    function EGC_SAM_HasTransponderReceiver()
        for _, ent in pairs(cachedReceivers) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false  -- Alle zerstört oder inaktiv
    end

    -- Prüft ob mindestens ein Radar aktiv ist
    function EGC_SAM_HasRadar()
        for _, ent in pairs(cachedRadars) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false  -- Alle zerstört oder inaktiv
    end

    -- Gibt zurück, ob Fahrzeug-Identifikation verfügbar ist
    function EGC_SAM_CanIdentifyVehicles()
        return EGC_SAM_HasTransponderReceiver()
    end

    -- Gibt zurück, ob Fahrzeuge erfasst werden können
    function EGC_SAM_CanDetectVehicles()
        return EGC_SAM_HasRadar()
    end

    -- Gibt zurück, ob Fahrzeug-Informationen angezeigt werden können
    -- (Name, etc.) - benötigt Transponder
    function EGC_SAM_CanShowVehicleInfo()
        return EGC_SAM_HasTransponderReceiver()
    end

    -- Gibt zurück, ob Fahrzeuge überhaupt erfasst werden können
    -- (Position, etc.) - benötigt Radar
    function EGC_SAM_CanShowVehiclePosition()
        return EGC_SAM_HasRadar()
    end
end

if CLIENT then
    -- Client-seitige Funktionen (für Display-Updates)
    -- Cache, damit nicht bei jedem Aufruf ents.FindByClass ausgeführt wird
    local cachedReceivers = {}
    local cachedRadars = {}

    timer.Create("EGC_SAM_UpdateEntities_Client", 1, 0, function()
        cachedReceivers = ents.FindByClass("lvs_transponder_receiver")
        cachedRadars = ents.FindByClass("lvs_radar")
    end)

    function EGC_SAM_HasTransponderReceiver()
        if #cachedReceivers == 0 then return false end
        for _, ent in pairs(cachedReceivers) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false
    end

    function EGC_SAM_HasRadar()
        if #cachedRadars == 0 then return false end
        for _, ent in pairs(cachedRadars) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false
    end

    function EGC_SAM_CanIdentifyVehicles()
        return EGC_SAM_HasTransponderReceiver()
    end

    function EGC_SAM_CanDetectVehicles()
        return EGC_SAM_HasRadar()
    end

    function EGC_SAM_CanShowVehicleInfo()
        return EGC_SAM_HasTransponderReceiver()
    end

    function EGC_SAM_CanShowVehiclePosition()
        return EGC_SAM_HasRadar()
    end
end
