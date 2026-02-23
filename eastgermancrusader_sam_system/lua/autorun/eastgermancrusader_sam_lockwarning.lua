-- EastGermanCrusader SAM System - Missile Lock Warning System
-- Warnt Piloten wenn sie von SAM-Systemen erfasst werden

if not LVS then return end
if SERVER and not _LVS_NodeOK then return end

print("[EGC SAM System] Lade Missile Lock Warning System...")

-- ============================================
-- SERVER-SEITE
-- ============================================

if SERVER then
    -- Netzwerk-Strings registrieren
    util.AddNetworkString("EGC_SAM_LockWarning")
    util.AddNetworkString("EGC_SAM_MissileIncoming")
    
    -- Lock Warning an Fahrzeug senden
    function EGC_SAM_SendLockWarning(vehicle, isLocked, lockingEntity)
        if not IsValid(vehicle) then return end
        
        -- Finde alle Spieler im Fahrzeug
        local players = {}
        
        -- Fahrer
        if vehicle.GetDriver and IsValid(vehicle:GetDriver()) then
            table.insert(players, vehicle:GetDriver())
        end
        
        -- Passagiere
        if vehicle.pPASSENGER then
            for _, seat in pairs(vehicle.pPASSENGER) do
                if IsValid(seat) and IsValid(seat:GetDriver()) then
                    table.insert(players, seat:GetDriver())
                end
            end
        end
        
        -- Nachricht senden
        for _, ply in pairs(players) do
            net.Start("EGC_SAM_LockWarning")
            net.WriteBool(isLocked)
            net.WriteEntity(lockingEntity or NULL)
            net.Send(ply)
        end
    end
    
    -- Missile Incoming Warning
    function EGC_SAM_SendMissileWarning(vehicle, missile)
        if not IsValid(vehicle) then return end
        
        local players = {}
        
        if vehicle.GetDriver and IsValid(vehicle:GetDriver()) then
            table.insert(players, vehicle:GetDriver())
        end
        
        if vehicle.pPASSENGER then
            for _, seat in pairs(vehicle.pPASSENGER) do
                if IsValid(seat) and IsValid(seat:GetDriver()) then
                    table.insert(players, seat:GetDriver())
                end
            end
        end
        
        for _, ply in pairs(players) do
            net.Start("EGC_SAM_MissileIncoming")
            net.WriteEntity(missile or NULL)
            net.Send(ply)
        end
    end
    
    -- Hook um Raketen zu tracken die auf Spieler zielen
    hook.Add("Think", "EGC_SAM_MissileTracking", function()
        local T = CurTime()
        if (EGC_SAM_LastMissileCheck or 0) + 0.25 > T then return end
        EGC_SAM_LastMissileCheck = T
        
        -- Finde alle SAM-Torpedos (Klasse: lvs_sam_torpedo – kompatibel mit RWS)
        for _, ent in pairs(ents.FindByClass("lvs_sam_torpedo")) do
            if not IsValid(ent) then continue end
            
            local target = ent:GetTarget()
            if not IsValid(target) then continue end
            
            -- Sende Warnung an Ziel
            if not ent._warningSent then
                ent._warningSent = true
                EGC_SAM_SendMissileWarning(target, ent)
            end
        end
    end)
end

-- ============================================
-- CLIENT-SEITE
-- ============================================

if CLIENT then
    local lockWarningActive = false
    local lockingEntity = NULL
    local missileIncoming = false
    local incomingMissile = NULL
    local lastWarningSound = 0
    
    -- Lock Warning empfangen
    net.Receive("EGC_SAM_LockWarning", function()
        lockWarningActive = net.ReadBool()
        lockingEntity = net.ReadEntity()
        
        if lockWarningActive then
            surface.PlaySound("buttons/button17.wav")
        end
    end)
    
    -- Missile Incoming empfangen
    net.Receive("EGC_SAM_MissileIncoming", function()
        missileIncoming = true
        incomingMissile = net.ReadEntity()
        
        surface.PlaySound("ambient/alarms/alarm1.wav")
        
        -- Nach 5 Sekunden zurücksetzen
        timer.Create("EGC_SAM_MissileWarningReset", 5, 1, function()
            missileIncoming = false
            incomingMissile = NULL
        end)
    end)
    
    -- HUD zeichnen
    hook.Add("HUDPaint", "EGC_SAM_LockWarningHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local vehicle = ply:GetVehicle()
        if not IsValid(vehicle) then return end
        
        -- Prüfe ob in LVS Fahrzeug
        local baseEnt = vehicle.LVSBaseEnt
        if not IsValid(baseEnt) or not baseEnt.LVS then return end
        
        local scrW, scrH = ScrW(), ScrH()
        
        -- Lock Warning anzeigen
        if lockWarningActive then
            local pulse = math.abs(math.sin(CurTime() * 5))
            local alpha = 150 + pulse * 105
            
            draw.RoundedBox(4, scrW / 2 - 100, 50, 200, 40, Color(255, 0, 0, alpha * 0.5))
            draw.SimpleText("!! LOCK WARNING !!", "DermaLarge", scrW / 2, 70, Color(255, 255, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Wiederholender Warnton
            if CurTime() - lastWarningSound > 0.5 then
                surface.PlaySound("buttons/button17.wav")
                lastWarningSound = CurTime()
            end
        end
        
        -- Missile Incoming Warning
        if missileIncoming then
            local pulse = math.abs(math.sin(CurTime() * 8))
            local alpha = 200 + pulse * 55
            
            draw.RoundedBox(4, scrW / 2 - 120, 100, 240, 50, Color(255, 0, 0, alpha * 0.7))
            draw.SimpleText("!!! MISSILE INCOMING !!!", "DermaLarge", scrW / 2, 125, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Richtung zur Rakete anzeigen
            if IsValid(incomingMissile) then
                local missilePos = incomingMissile:GetPos()
                local screenPos = missilePos:ToScreen()
                
                if screenPos.visible then
                    -- Pfeil zur Rakete
                    surface.SetDrawColor(255, 0, 0, alpha)
                    
                    local dirX = screenPos.x - scrW / 2
                    local dirY = screenPos.y - scrH / 2
                    local dist = math.sqrt(dirX * dirX + dirY * dirY)
                    
                    if dist > 100 then
                        dirX = dirX / dist * 100
                        dirY = dirY / dist * 100
                    end
                    
                    surface.DrawLine(scrW / 2, scrH / 2, scrW / 2 + dirX, scrH / 2 + dirY)
                end
            end
        end
    end)
    
    -- Reset wenn Fahrzeug verlassen wird
    hook.Add("PlayerLeaveVehicle", "EGC_SAM_ResetWarnings", function(ply, vehicle)
        if ply == LocalPlayer() then
            lockWarningActive = false
            missileIncoming = false
        end
    end)
end

print("[EGC SAM System] Missile Lock Warning System geladen!")
