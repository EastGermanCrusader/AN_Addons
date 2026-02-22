-- EastGermanCrusader LVS Overhaul - Erweiterte AI Waffen-Logik
-- Ermöglicht AI-gesteuerten Fahrzeugen (besonders Vulture Droids) alle Waffen zu nutzen
-- Inklusive Schnellfeuerwaffen, Raketen und sekundäre Waffensysteme

if not LVS then return end
if CLIENT then return end -- Nur Server-seitig

print("[EastGermanCrusader LVS Overhaul] Lade erweiterte AI Waffen-Logik...")

-- Konfiguration
local AI_WEAPON_CONFIG = {
    -- Raketen-Einstellungen
    MissileMinDistance = 800,       -- Minimale Distanz für Raketenangriff
    MissileMaxDistance = 5000,      -- Maximale Distanz für Raketenangriff
    MissileTargetAngle = 45,        -- Maximaler Winkel zum Ziel für Raketenabschuss
    MissileCooldown = 4.0,          -- Cooldown zwischen Raketenangriffen
    MissileChance = 0.6,            -- Wahrscheinlichkeit (0-1) dass AI Rakete abfeuert wenn möglich
    MissileLoadTime = 1.2,          -- Zeit zum Laden/Locken einer Rakete bevor Abschuss
    MissileMaxLoadTime = 3.0,       -- Maximale Ladezeit bevor Abschuss erzwungen wird
    
    -- Waffen-Wechsel Einstellungen
    WeaponSwitchCooldown = 1.5,     -- Schnellerer Waffenwechsel für AI
    HeatThresholdHigh = 0.85,       -- Bei diesem Hitze-Level Waffe wechseln
    HeatThresholdLow = 0.3,         -- Unter diesem Level zurück zur Hauptwaffe
    
    -- Distanz-basierte Waffenwahl
    CloseRangeDistance = 500,       -- Nahkampf-Distanz
    MediumRangeDistance = 2000,     -- Mittlere Distanz
    
    -- Debug-Modus
    Debug = false,
}

-- Speicher für AI-Zustände
local AIWeaponStates = {}

-- Hilfsfunktion zum Abrufen des AI-Zustands
local function GetAIState(ent)
    local idx = ent:EntIndex()
    if not AIWeaponStates[idx] then
        AIWeaponStates[idx] = {
            lastMissileTime = 0,
            lastWeaponSwitch = 0,
            currentPhase = "attack",  -- attack, missile, cooldown
            missileTarget = NULL,
            pendingMissile = nil,
        }
    end
    return AIWeaponStates[idx]
end

-- Aufräumen wenn Entity entfernt wird
hook.Add("EntityRemoved", "EastGermanCrusader_AIWeapon_Cleanup", function(ent)
    if ent and ent:EntIndex() then
        AIWeaponStates[ent:EntIndex()] = nil
    end
end)

-- Prüft ob eine Waffe Raketen/Missiles ist
local function IsWeaponMissile(weapon)
    if not weapon then return false end
    
    -- Prüfe Icon-Material
    local icon = weapon.Icon
    if icon then
        local iconName = tostring(icon)
        if string.find(iconName, "missile") or 
           string.find(iconName, "torpedo") or
           string.find(iconName, "rocket") then
            return true
        end
    end
    
    -- Prüfe auf FinishAttack (typisch für Raketen)
    if weapon.FinishAttack then
        return true
    end
    
    -- Prüfe auf niedrige Munition (typisch für Raketen)
    if weapon.Ammo and weapon.Ammo > 0 and weapon.Ammo <= 8 then
        return true
    end
    
    return false
end

-- Prüft ob eine Waffe eine Schnellfeuerwaffe ist
local function IsWeaponRapidFire(weapon)
    if not weapon then return false end
    
    -- Schnellfeuerwaffen haben kurze Delay
    if weapon.Delay and weapon.Delay <= 0.15 and weapon.Delay > 0 then
        return true
    end
    
    -- Hohe Munition deutet auf Schnellfeuerwaffe hin
    if weapon.Ammo and weapon.Ammo >= 500 then
        return true
    end
    
    return false
end

-- Erweiterte AI Waffen-Auswahl Funktion
local function EnhancedAISelectWeapon(ent, ID, force)
    if not IsValid(ent) then return end
    if not ent.SelectWeapon then return end
    
    if ID == ent:GetSelectedWeapon() and not force then return end
    
    local T = CurTime()
    local state = GetAIState(ent)
    
    -- Cooldown prüfen (außer bei force)
    if not force and (state.lastWeaponSwitch + AI_WEAPON_CONFIG.WeaponSwitchCooldown) > T then 
        return 
    end
    
    state.lastWeaponSwitch = T
    ent:SelectWeapon(ID)
    
    if AI_WEAPON_CONFIG.Debug then
        print("[AI Weapons] " .. tostring(ent) .. " wechselt zu Waffe " .. ID)
    end
end

-- Initialisiere beim Spawn neuer Fahrzeuge
hook.Add("OnEntityCreated", "EastGermanCrusader_AIWeapon_EntityCreated", function(ent)
    if not IsValid(ent) then return end
    
    timer.Simple(0.5, function()
        if not IsValid(ent) then return end
        if not ent.LVS then return end
        
        -- Markiere alle Waffen als AI-nutzbar (falls nicht explizit deaktiviert)
        if ent.WEAPONS and ent.WEAPONS[1] then
            for weaponID, weapon in ipairs(ent.WEAPONS[1]) do
                if weapon.UseableByAI == nil then
                    weapon.UseableByAI = true
                end
            end
        end
    end)
end)

-- Spezieller Handler für Vulture Droids und andere Starfighter
-- Überschreibt deren AI-Waffenlogik für intelligentere Waffennutzung
hook.Add("Think", "EastGermanCrusader_VultureDroid_WeaponHandler", function()
    local T = CurTime()
    
    -- Nur alle 0.1 Sekunden für bessere Reaktion
    if (EastGermanCrusader_LastVultureThink or 0) + 0.1 > T then return end
    EastGermanCrusader_LastVultureThink = T
    
    -- Finde alle Starfighter (Vulture Droids und andere)
    for _, ent in pairs(LVS:GetVehicles()) do
        if not IsValid(ent) then continue end
        if not ent:GetAI() then continue end
        if not ent.WEAPONS or not ent.WEAPONS[1] then continue end
        
        -- Prüfe ob es ein Starfighter ist (hat RunAI Funktion)
        if not ent.RunAI then continue end
        
        -- Prüfe ob Fahrzeug mindestens 2 Waffen hat
        local weaponCount = #ent.WEAPONS[1]
        if weaponCount < 2 then continue end
        
        local state = GetAIState(ent)
        local target = ent._LastAITarget
        
        -- Berechne Distanz und Winkel zum Ziel
        local distance = nil
        local angleToTarget = 180
        
        if IsValid(target) then
            local targetPos = target:GetPos()
            local myPos = ent:GetPos()
            distance = myPos:Distance(targetPos)
            
            local dirToTarget = (targetPos - myPos):GetNormalized()
            local myForward = ent:GetForward()
            angleToTarget = math.deg(math.acos(math.Clamp(myForward:Dot(dirToTarget), -1, 1)))
        end
        
        local selectedWeapon = ent:GetSelectedWeapon() or 1
        local isFiring = ent._AIFireInput or false
        local currentWeaponData = ent.WEAPONS[1][selectedWeapon]
        local currentHeat = ent:GetNWHeat() or 0
        
        -- ===== RAKETEN-ABSCHUSS-LOGIK =====
        -- Das LVS Waffensystem ruft FinishAttack nur auf wenn _AIFireInput von true auf false wechselt
        -- Wir müssen also _AIFireInput kurz auf false setzen um die Rakete abzufeuern
        
        if state.missileLoadStartTime and selectedWeapon == state.missileWeaponID then
            local loadTime = T - state.missileLoadStartTime
            local missile = ent._ProtonTorpedo or ent._LoadedMissile
            
            -- Prüfe ob Rakete bereit zum Abschuss ist
            local hasLock = false
            if IsValid(missile) and missile.GetNWTarget then
                local missileTarget = missile:GetNWTarget()
                hasLock = IsValid(missileTarget)
            end
            
            -- Abschuss-Bedingungen:
            -- 1. Hat Lock auf Ziel UND mindestens MissileLoadTime geladen
            -- 2. ODER maximale Ladezeit erreicht
            local shouldFire = (hasLock and loadTime >= AI_WEAPON_CONFIG.MissileLoadTime) or 
                               (loadTime >= AI_WEAPON_CONFIG.MissileMaxLoadTime)
            
            if shouldFire then
                -- KRITISCH: Setze _AIFireInput auf false um FinishAttack auszulösen
                ent._AIFireInput = false
                
                -- Markiere dass wir gerade abgefeuert haben
                state.lastMissileTime = T
                state.missileLoadStartTime = nil
                state.missileWeaponID = nil
                
                if AI_WEAPON_CONFIG.Debug then
                    print("[AI Weapons] " .. tostring(ent) .. " feuert Rakete ab! (Lock: " .. tostring(hasLock) .. ", LoadTime: " .. string.format("%.1f", loadTime) .. "s)")
                end
                
                -- Nach kurzer Verzögerung zurück zur Hauptwaffe wechseln
                timer.Simple(0.3, function()
                    if IsValid(ent) and ent:GetAI() then
                        local heat = ent:GetNWHeat() or 0
                        -- Wähle beste Laserwaffe basierend auf Hitze
                        if heat > 0.5 and ent:AIHasWeapon(3) then
                            EnhancedAISelectWeapon(ent, 3, true)
                        else
                            EnhancedAISelectWeapon(ent, 1, true)
                        end
                    end
                end)
                
                continue -- Nächstes Fahrzeug, dieses Frame überspringen
            end
        end
        
        -- ===== NORMALE KAMPF-LOGIK =====
        if isFiring and IsValid(target) then
            -- Prüfe ob wir im Raketen-Lade-Modus sind
            if state.missileLoadStartTime then
                -- Weiter laden, nichts ändern
                continue
            end
            
            -- Finde Raketen-Waffe
            local missileWeaponID = nil
            local missileAmmo = 0
            for wID, weapon in ipairs(ent.WEAPONS[1]) do
                if IsWeaponMissile(weapon) then
                    missileWeaponID = wID
                    missileAmmo = weapon._CurAmmo or weapon.Ammo or 0
                    break
                end
            end
            
            -- Prüfe ob wir Raketen abfeuern sollten
            local shouldUseMissile = false
            
            if missileWeaponID and missileAmmo > 0 and distance then
                -- Gute Distanz für Rakete?
                if distance >= AI_WEAPON_CONFIG.MissileMinDistance and 
                   distance <= AI_WEAPON_CONFIG.MissileMaxDistance then
                    -- Ziel in gutem Winkel?
                    if angleToTarget <= AI_WEAPON_CONFIG.MissileTargetAngle then
                        -- Cooldown geprüft?
                        if (state.lastMissileTime + AI_WEAPON_CONFIG.MissileCooldown) <= T then
                            -- Zufällige Chance
                            if math.random() <= AI_WEAPON_CONFIG.MissileChance then
                                shouldUseMissile = true
                            end
                        end
                    end
                end
            end
            
            if shouldUseMissile and missileWeaponID then
                -- Wechsel zu Raketen und starte Ladevorgang
                EnhancedAISelectWeapon(ent, missileWeaponID, true)
                state.missileLoadStartTime = T
                state.missileWeaponID = missileWeaponID
                
                if AI_WEAPON_CONFIG.Debug then
                    print("[AI Weapons] " .. tostring(ent) .. " lädt Rakete (Waffe " .. missileWeaponID .. ")...")
                end
            else
                -- Normaler Waffenwechsel zwischen verfügbaren Laserwaffen
                -- Finde alle Nicht-Raketen-Waffen
                local laserWeapons = {}
                for wID, weapon in ipairs(ent.WEAPONS[1]) do
                    if not IsWeaponMissile(weapon) and weapon.UseableByAI ~= false then
                        local ammo = weapon._CurAmmo or weapon.Ammo or -1
                        if ammo ~= 0 then
                            table.insert(laserWeapons, wID)
                        end
                    end
                end
                
                if #laserWeapons > 1 then
                    -- Mehrere Laserwaffen verfügbar - intelligent wechseln
                    if currentHeat > AI_WEAPON_CONFIG.HeatThresholdHigh then
                        -- Überhitzt - wechsel zur nächsten Laserwaffe
                        local currentIndex = 1
                        for i, wID in ipairs(laserWeapons) do
                            if wID == selectedWeapon then
                                currentIndex = i
                                break
                            end
                        end
                        local nextIndex = (currentIndex % #laserWeapons) + 1
                        EnhancedAISelectWeapon(ent, laserWeapons[nextIndex])
                    elseif currentHeat < AI_WEAPON_CONFIG.HeatThresholdLow then
                        -- Abgekühlt - wähle basierend auf Distanz
                        if distance then
                            if distance < AI_WEAPON_CONFIG.CloseRangeDistance then
                                -- Nahkampf - bevorzuge Schnellfeuer (meist Waffe 1)
                                for _, wID in ipairs(laserWeapons) do
                                    local weapon = ent.WEAPONS[1][wID]
                                    if IsWeaponRapidFire(weapon) then
                                        EnhancedAISelectWeapon(ent, wID)
                                        break
                                    end
                                end
                            elseif distance > AI_WEAPON_CONFIG.MediumRangeDistance then
                                -- Längere Distanz - bevorzuge schwere Waffen
                                for _, wID in ipairs(laserWeapons) do
                                    local weapon = ent.WEAPONS[1][wID]
                                    if not IsWeaponRapidFire(weapon) then
                                        EnhancedAISelectWeapon(ent, wID)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            -- Nicht im Kampf
            -- Wenn Rakete noch lädt aber kein Ziel mehr, abbrechen
            if state.missileLoadStartTime then
                local loadTime = T - state.missileLoadStartTime
                if loadTime > 5 then
                    -- Zu lange ohne Ziel, abbrechen
                    state.missileLoadStartTime = nil
                    state.missileWeaponID = nil
                    EnhancedAISelectWeapon(ent, 1, true)
                end
            end
        end
    end
end)

-- ConVar für Debug-Modus
local function ToggleAIWeaponDebug(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    AI_WEAPON_CONFIG.Debug = not AI_WEAPON_CONFIG.Debug
    print("[AI Weapons] Debug-Modus: " .. (AI_WEAPON_CONFIG.Debug and "AN" or "AUS"))
end
concommand.Add("lvs_ai_weapon_debug", ToggleAIWeaponDebug)

print("[EastGermanCrusader LVS Overhaul] Erweiterte AI Waffen-Logik geladen!")
print("[AI Weapons] Starfighter nutzen jetzt alle Waffen: Schnellfeuer-Laser, Raketen und Schwere Laser")
print("[AI Weapons] Debug: 'lvs_ai_weapon_debug' in Konsole eingeben")
