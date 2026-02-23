-- EastGermanCrusader SAM System - Aura Addons Kompatibilität
-- Diese Datei modifiziert die Anzeige in Auras Addons, ohne deren Dateien zu ändern

if CLIENT then
    -- Cache für Original-Namen
    local vehicleNameCache = {}
    local lastCheck = 0
    local cachedStatus = {hasRadar = true, hasTransponder = true}
    
    -- Funktion zum Prüfen des Status
    local function CheckDetectionStatus()
        local T = CurTime()
        if T - lastCheck < 0.1 then 
            return cachedStatus.hasRadar, cachedStatus.hasTransponder
        end
        lastCheck = T
        
        -- Prüfe ob Transponder verfügbar ist
        local hasTransponder = false
        if EGC_SAM_HasTransponderReceiver then
            hasTransponder = EGC_SAM_HasTransponderReceiver()
        else
            local receivers = ents.FindByClass("lvs_transponder_receiver")
            if #receivers > 0 then
                for _, ent in pairs(receivers) do
                    if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                        hasTransponder = true
                        break
                    end
                end
            end
        end
        
        -- Prüfe ob Radar verfügbar ist
        local hasRadar = false
        if EGC_SAM_HasRadar then
            hasRadar = EGC_SAM_HasRadar()
        else
            local radars = ents.FindByClass("lvs_radar")
            if #radars > 0 then
                for _, ent in pairs(radars) do
                    if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                        hasRadar = true
                        break
                    end
                end
            end
        end
        
        cachedStatus.hasRadar = hasRadar
        cachedStatus.hasTransponder = hasTransponder
        return hasRadar, hasTransponder
    end
    
    -- Hook der direkt nach dem Erstellen von cached_vehicle_info läuft
    -- und die Namen modifiziert für aura_lvs_display_panel
    -- WICHTIG: Dieser Hook läuft NACH dem Rendering der Torpedostation, um sie nicht zu beeinflussen
    -- Verwende niedrige Priorität damit er nach anderen Hooks läuft
    hook.Add("PostDrawOpaqueRenderables", "EGC_SAM_ModifyAuraCachedInfo", function()
        -- Prüfe ob aura_lvs_display_panel vorhanden ist
        local lvsPanels = ents.FindByClass("aura_lvs_display_panel")
        if #lvsPanels == 0 then return end
        
        -- Prüfe ob fight_display_panel vorhanden ist (sollte nicht modifiziert werden)
        local fightPanels = ents.FindByClass("aura_lfs_fight_display_panel")
        local isFightPanelActive = #fightPanels > 0
        
        -- Wenn fight_panel aktiv, nicht modifizieren
        if isFightPanelActive then return end
        
        local hasRadar, hasTransponder = CheckDetectionStatus()
        
        -- Modifiziere cached_vehicle_info direkt
        -- Diese Variable wird von aura_lvs_display_handler verwendet
        -- WICHTIG: Nur modifizieren wenn die Variable existiert (von Auras Addons erstellt)
        if cached_vehicle_info and type(cached_vehicle_info) == "table" then
            for idx, info in pairs(cached_vehicle_info) do
                if info and info.name then
                    -- Wenn kein Radar, entferne Fahrzeug aus der Liste
                    if not hasRadar then
                        cached_vehicle_info[idx] = nil
                    -- Wenn kein Transponder, ändere Name zu "UNBEKANNTES FAHRZEUG"
                    elseif not hasTransponder then
                        -- Speichere Original-Name wenn noch nicht gespeichert
                        if not info._originalName then
                            info._originalName = info.name
                        end
                        info.name = "UNBEKANNTES FAHRZEUG"
                    else
                        -- Stelle Original-Name wieder her wenn Transponder vorhanden
                        if info._originalName then
                            info.name = info._originalName
                            info._originalName = nil
                        end
                    end
                end
            end
        end
        
        -- Modifiziere auch aura_lvs_display_vehicles Liste
        -- WICHTIG: Nur modifizieren wenn die Variable existiert (von Auras Addons erstellt)
        if aura_lvs_display_vehicles and type(aura_lvs_display_vehicles) == "table" then
            if not hasRadar then
                -- Leere Liste wenn kein Radar
                aura_lvs_display_vehicles = {}
                if aura_lvs_display_vehicle_count then
                    aura_lvs_display_vehicle_count = 0
                end
            else
                -- Modifiziere Fahrzeugnamen wenn kein Transponder
                if not hasTransponder then
                    for _, vehicle in ipairs(aura_lvs_display_vehicles) do
                        if IsValid(vehicle) then
                            local entIndex = vehicle:EntIndex()
                            
                            -- Speichere Original-Name beim ersten Mal
                            if not vehicleNameCache[entIndex] then
                                vehicleNameCache[entIndex] = vehicle.PrintName or vehicle:GetClass()
                            end
                            
                            -- Ändere Name zu "UNBEKANNTES FAHRZEUG"
                            vehicle.PrintName = "UNBEKANNTES FAHRZEUG"
                        end
                    end
                else
                    -- Stelle Original-Namen wieder her wenn Transponder vorhanden
                    for _, vehicle in ipairs(aura_lvs_display_vehicles) do
                        if IsValid(vehicle) then
                            local entIndex = vehicle:EntIndex()
                            if vehicleNameCache[entIndex] then
                                vehicle.PrintName = vehicleNameCache[entIndex]
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Hook für aura_lfs_fight_display_panel - stelle Original-Namen wieder her
    -- Dieses Panel soll immer die echten Namen zeigen
    hook.Add("PostDrawOpaqueRenderables", "EGC_SAM_RestoreNamesForFightPanel", function()
        local fightPanels = ents.FindByClass("aura_lfs_fight_display_panel")
        if #fightPanels > 0 then
            -- Stelle Original-Namen für alle Fahrzeuge wieder her
            if LVS and LVS.GetVehicles then
                local vehicles = LVS:GetVehicles()
                for _, vehicle in pairs(vehicles) do
                    if IsValid(vehicle) then
                        local entIndex = vehicle:EntIndex()
                        if vehicleNameCache[entIndex] then
                            vehicle.PrintName = vehicleNameCache[entIndex]
                        end
                    end
                end
            end
            
            -- Stelle auch cached_vehicle_info wieder her
            if cached_vehicle_info then
                for idx, info in pairs(cached_vehicle_info) do
                    if info and info._originalName then
                        info.name = info._originalName
                        info._originalName = nil
                    end
                end
            end
        end
    end)
end
