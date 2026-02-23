-- EastGermanCrusader SAM System - Detection System
-- Globale Funktionen für Transponder/Radar-Status
-- Kompatibel mit Auras Addons

if SERVER then
    -- Prüft ob mindestens ein Transponder-Receiver aktiv ist
    -- Wenn keine Entities vorhanden sind, wird false zurückgegeben (wie zerstört)
    function EGC_SAM_HasTransponderReceiver()
        local receivers = ents.FindByClass("lvs_transponder_receiver")
        if #receivers == 0 then return false end  -- Keine vorhanden = wie zerstört
        
        for _, ent in pairs(receivers) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false  -- Alle zerstört oder inaktiv
    end
    
    -- Prüft ob mindestens ein Radar aktiv ist
    -- Wenn keine Entities vorhanden sind, wird false zurückgegeben (wie zerstört)
    function EGC_SAM_HasRadar()
        local radars = ents.FindByClass("lvs_radar")
        if #radars == 0 then return false end  -- Keine vorhanden = wie zerstört
        
        for _, ent in pairs(radars) do
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
    -- Wenn keine Entities vorhanden sind, wird false zurückgegeben (wie zerstört)
    function EGC_SAM_HasTransponderReceiver()
        local receivers = ents.FindByClass("lvs_transponder_receiver")
        if #receivers == 0 then return false end  -- Keine vorhanden = wie zerstört
        
        for _, ent in pairs(receivers) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false  -- Alle zerstört oder inaktiv
    end
    
    function EGC_SAM_HasRadar()
        local radars = ents.FindByClass("lvs_radar")
        if #radars == 0 then return false end  -- Keine vorhanden = wie zerstört
        
        for _, ent in pairs(radars) do
            if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                return true
            end
        end
        return false  -- Alle zerstört oder inaktiv
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
