-- EastGermanCrusader SAM System - Torpedo Kontrollstation Server
-- Naval VLS Anti-Air System - Realistische Steuerung

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Netzwerk Strings
util.AddNetworkString("EGC_SAM_OpenControlPanel")
util.AddNetworkString("EGC_SAM_UpdateTargets")
util.AddNetworkString("EGC_SAM_SelectTarget")
util.AddNetworkString("EGC_SAM_SetSalvoSize")      -- DEPRECATED: Wird nicht mehr verwendet
util.AddNetworkString("EGC_SAM_FireSalvo")
util.AddNetworkString("EGC_SAM_UpdateVLSStatus")
util.AddNetworkString("EGC_SAM_ArmMissiles")      -- NEU: Raketen scharf machen
util.AddNetworkString("EGC_SAM_DisarmMissiles")   -- NEU: Raketen entsichern
util.AddNetworkString("EGC_SAM_AbortMissiles")    -- NEU: Raketen abbrechen
util.AddNetworkString("EGC_SAM_ToggleVLS")        -- NEU: VLS-System auswählen/abwählen

function ENT:Initialize()
    self:SetModel(self.Model)
    
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(200)
    end
    
    -- Gesundheit
    self:SetMaxHealth(500)
    self:SetHealth(500)
    
    -- Interne Variablen
    self._connectedVLS = {}
    self._radarTargets = {}
    self._lastScan = 0
    self._lastVLSScan = 0
    self._lastAlarmScan = 0  -- NEU: Für Alarm-Scan-Cache
    
    -- NEU: Tracking für fliegende Raketen
    self._activeMissiles = {}
    
    -- NEU: Verbundene Alarm-Geräte
    self._linkedSpeakers = {}
    self._linkedAlarms = {}
    
    -- NEU: Ausgewählte VLS-Systeme (Entity-IDs)
    self._selectedVLS = {}
    
    -- Think-Funktion sofort starten
    self:NextThink(CurTime() + 0.1)
    
    -- Erste Scans sofort ausführen
    timer.Simple(0.2, function()
        if IsValid(self) then
            self:ScanVLS()
            self:SendVLSStatusToNearby()
            self:ScanTargets()
            self:SendTargetsToNearby()
        end
    end)
    
    print("[Torpedo Control] Kontrollstation initialisiert")
end


function ENT:Use(activator, caller)
    -- Use-Funktion deaktiviert - Interaktion erfolgt direkt über das Display
    -- Die Buttons auf dem Display sind interaktiv und funktionieren ohne Panel
end


function ENT:OnTakeDamage(dmginfo)
    local damage = dmginfo:GetDamage()
    self:SetHealth(self:Health() - damage)
    
    if self:Health() <= 0 then
        -- Alarm deaktivieren vor Zerstörung
        self:DeactivateAlarm()
        
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        util.Effect("Explosion", effectdata)
        self:EmitSound("ambient/explosions/explode_4.wav", 100, 100)
        self:Remove()
    end
end

-- ============================================
-- ALARM GERÄTE VERWALTUNG
-- ============================================

function ENT:ScanAlarmDevices()
    self._linkedSpeakers = {}
    self._linkedAlarms = {}
    
    -- Lautsprecher suchen
    for _, ent in pairs(ents.FindByClass("lvs_sam_speaker")) do
        if IsValid(ent) then
            local linkedStation = ent:GetLinkedStation()
            if linkedStation == self then
                table.insert(self._linkedSpeakers, ent)
            end
        end
    end
    
    -- Alarm-Lampen suchen
    for _, ent in pairs(ents.FindByClass("lvs_sam_alarm")) do
        if IsValid(ent) then
            local linkedStation = ent:GetLinkedStation()
            if linkedStation == self then
                table.insert(self._linkedAlarms, ent)
            end
        end
    end
end

function ENT:ActivateAlarm()
    self:SetAlarmActive(true)
    
    -- Alle Lautsprecher aktivieren
    for _, speaker in ipairs(self._linkedSpeakers) do
        if IsValid(speaker) and speaker.StartAlarm then
            speaker:StartAlarm()
        end
    end
    
    -- Alle Alarm-Lampen aktivieren
    for _, alarm in ipairs(self._linkedAlarms) do
        if IsValid(alarm) and alarm.ActivateAlarm then
            alarm:ActivateAlarm()
        end
    end
    
    print("[Torpedo Control] ALARM AKTIVIERT!")
end

function ENT:DeactivateAlarm()
    self:SetAlarmActive(false)
    
    -- Alle Lautsprecher deaktivieren
    for _, speaker in ipairs(self._linkedSpeakers) do
        if IsValid(speaker) and speaker.StopAlarm then
            speaker:StopAlarm()
        end
    end
    
    -- Alle Alarm-Lampen deaktivieren
    for _, alarm in ipairs(self._linkedAlarms) do
        if IsValid(alarm) and alarm.DeactivateAlarm then
            alarm:DeactivateAlarm()
        end
    end
    
    print("[Torpedo Control] Alarm deaktiviert")
end

-- ============================================
-- ARM / DISARM SYSTEM
-- ============================================

function ENT:ArmMissiles()
    if self:GetArmed() then return end
    
    local target = self:GetSelectedTarget()
    if not IsValid(target) then
        local operator = self:GetOperator()
        if IsValid(operator) then
            operator:ChatPrint("[Torpedo Control] FEHLER: Kein Ziel ausgewählt!")
        end
        return false
    end
    
    -- Raketen scharf machen
    self:SetArmed(true)
    
    -- Alarm-Geräte scannen und aktivieren
    self:ScanAlarmDevices()
    self:ActivateAlarm()
    
    -- Alle VLS auf "Armed" setzen
    for _, vlsData in ipairs(self._connectedVLS) do
        local vls = vlsData.entity
        if IsValid(vls) then
            vls:SetLocked(true)
            if vls.SetCurrentTarget then
                vls:SetCurrentTarget(target)
            end
        end
    end
    
    local operator = self:GetOperator()
    if IsValid(operator) then
        operator:ChatPrint("[Torpedo Control] ⚠ RAKETEN SCHARF! Bereit zum Abschuss!")
    end
    
    -- Sound an der Station
    self:EmitSound("buttons/button17.wav", 100, 70)
    
    return true
end

function ENT:DisarmMissiles()
    if not self:GetArmed() then return end
    
    -- Raketen entsichern
    self:SetArmed(false)
    
    -- Alarm deaktivieren
    self:DeactivateAlarm()
    
    -- Alle VLS entsichern
    for _, vlsData in ipairs(self._connectedVLS) do
        local vls = vlsData.entity
        if IsValid(vls) then
            vls:SetLocked(false)
        end
    end
    
    local operator = self:GetOperator()
    if IsValid(operator) then
        operator:ChatPrint("[Torpedo Control] Raketen entsichert")
    end
    
    -- Sound
    self:EmitSound("buttons/button19.wav", 100, 100)
end

-- ============================================
-- VLS VERWALTUNG
-- ============================================

function ENT:ScanVLS()
    self._connectedVLS = {}
    local totalMissiles = 0
    
    local allVLS = ents.FindByClass("lvs_sam_turret")
    
    for _, ent in pairs(allVLS) do
        if not IsValid(ent) then continue end
        
        local dist = self:GetPos():Distance(ent:GetPos())
        if dist > self.ControlRange then continue end
        
        local missiles = 0
        if ent.GetMissileCount then
            missiles = ent:GetMissileCount()
        else
            -- Fallback: Verwende SAM_MissileCount
            missiles = ent.SAM_MissileCount or 0
        end
        
        table.insert(self._connectedVLS, {
            entity = ent,
            distance = dist,
            missiles = missiles,
            locked = ent.GetLocked and ent:GetLocked() or false,
        })
        
        totalMissiles = totalMissiles + missiles
    end
    
    -- Debug: Zeige gefundene VLS
    if #self._connectedVLS > 0 then
        if not self._lastVLSDebug or CurTime() - self._lastVLSDebug > 5 then
            self._lastVLSDebug = CurTime()
            print("[Torpedo Control] ScanVLS: " .. #self._connectedVLS .. " VLS gefunden, " .. totalMissiles .. " Torpedos")
        end
    end
    
    self:SetConnectedVLS(#self._connectedVLS)
    self:SetTotalMissiles(totalMissiles)
    
    -- Bereinige ausgewählte VLS-Liste (entferne ungültige IDs)
    if self._selectedVLS then
        local validSelectedVLS = {}
        for _, selectedID in ipairs(self._selectedVLS) do
            local found = false
            for _, vlsData in ipairs(self._connectedVLS) do
                if IsValid(vlsData.entity) and vlsData.entity:EntIndex() == selectedID then
                    found = true
                    break
                end
            end
            if found then
                table.insert(validSelectedVLS, selectedID)
            end
        end
        self._selectedVLS = validSelectedVLS
    end
    
    -- Status an Operator senden
    local operator = self:GetOperator()
    if IsValid(operator) then
        self:SendVLSStatus(operator)
    end
end

function ENT:SendVLSStatus(ply)
    if not IsValid(ply) then return end
    
    net.Start("EGC_SAM_UpdateVLSStatus")
    net.WriteEntity(self)
    net.WriteInt(#self._connectedVLS, 8)
    
    for _, vls in ipairs(self._connectedVLS) do
        net.WriteEntity(vls.entity)
        net.WriteInt(vls.missiles, 8)
        net.WriteBool(vls.locked)
        net.WriteFloat(vls.distance)
    end
    
    -- Sende auch ausgewählte VLS-IDs
    net.WriteInt(#(self._selectedVLS or {}), 8)
    for _, vlsID in ipairs(self._selectedVLS or {}) do
        net.WriteInt(vlsID, 32)
    end
    
    net.Send(ply)
end

-- Sendet VLS-Status an alle Clients in der Nähe (für Display)
function ENT:SendVLSStatusToNearby()
    local myPos = self:GetPos()
    local nearbyPlayers = {}
    
    -- Erhöhte Reichweite für Display-Updates (2000 Einheiten = Sichtweite + Puffer)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetPos():Distance(myPos) < 2000 then
            table.insert(nearbyPlayers, ply)
        end
    end
    
    if #nearbyPlayers == 0 then return end
    
    local vlsCount = #self._connectedVLS
    
    net.Start("EGC_SAM_UpdateVLSStatus")
    net.WriteEntity(self)
    net.WriteInt(vlsCount, 8)
    
    for _, vls in ipairs(self._connectedVLS) do
        if IsValid(vls.entity) then
            net.WriteEntity(vls.entity)
            net.WriteInt(vls.missiles or 0, 8)
            net.WriteBool(vls.locked or false)
            net.WriteFloat(vls.distance or 0)
        else
            -- Ungültige Entity - sende leere Daten
            net.WriteEntity(NULL)
            net.WriteInt(0, 8)
            net.WriteBool(false)
            net.WriteFloat(0)
        end
    end
    
    -- Sende auch ausgewählte VLS-IDs
    net.WriteInt(#(self._selectedVLS or {}), 8)
    for _, vlsID in ipairs(self._selectedVLS or {}) do
        net.WriteInt(vlsID, 32)
    end
    
    net.Send(nearbyPlayers)
    
    -- Debug (nur wenn sich etwas geändert hat)
    if vlsCount > 0 and (#nearbyPlayers > 0) then
        -- Reduziere Debug-Ausgaben
        if not self._lastVLSDebug or CurTime() - self._lastVLSDebug > 5 then
            self._lastVLSDebug = CurTime()
            print("[Torpedo Control] VLS-Status gesendet: " .. vlsCount .. " VLS an " .. #nearbyPlayers .. " Spieler")
        end
    end
end

-- ============================================
-- ZIELERFASSUNG
-- ============================================

function ENT:ScanTargets()
    if not LVS then 
        self._radarTargets = {}
        return 
    end
    
    -- Prüfe ob Radar verfügbar ist
    local hasRadar = false
    if EGC_SAM_HasRadar then
        hasRadar = EGC_SAM_HasRadar()
    else
        -- Fallback: Prüfe direkt
        local radars = ents.FindByClass("lvs_radar")
        if #radars > 0 then
            for _, ent in pairs(radars) do
                if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                    hasRadar = true
                    break
                end
            end
        end
        -- Wenn keine Radars vorhanden, hasRadar bleibt false (wie zerstört)
    end
    
    -- Wenn kein Radar vorhanden, keine Ziele erfassen
    if not hasRadar then
        self._radarTargets = {}
        -- Leere Liste an Clients senden
        self:SendTargetsToNearby()
        return
    end
    
    -- Prüfe ob Transponder verfügbar ist
    local hasTransponder = false
    if EGC_SAM_HasTransponderReceiver then
        hasTransponder = EGC_SAM_HasTransponderReceiver()
    else
        -- Fallback: Prüfe direkt
        local receivers = ents.FindByClass("lvs_transponder_receiver")
        if #receivers > 0 then
            for _, ent in pairs(receivers) do
                if IsValid(ent) and ent:GetActive() and not ent:GetDestroyed() then
                    hasTransponder = true
                    break
                end
            end
        end
        -- Wenn keine Receivers vorhanden, hasTransponder bleibt false (wie zerstört)
    end
    
    self._radarTargets = {}
    local myPos = self:GetPos()
    
    local allVehicles = LVS:GetVehicles()
    local vehicleCount = 0
    if allVehicles then
        if type(allVehicles) == "table" then
            vehicleCount = table.Count(allVehicles)
        end
    end
    
    
    for _, ent in pairs(allVehicles or {}) do
        if not IsValid(ent) then continue end
        
        local targetPos = ent:GetPos()
        local distance = myPos:Distance(targetPos)
        
        if distance > self.RadarRange then continue end
        
        -- Sichtbarkeit prüfen
        local tr = util.TraceLine({
            start = myPos + Vector(0, 0, 50),
            endpos = targetPos,
            filter = {self},
        })
        
        local visible = not tr.Hit or tr.Entity == ent
        
        -- Hitzesignatur
        local heatSignature = 10
        if ent.GetHeatSignature then
            heatSignature = ent:GetHeatSignature()
        elseif ent.GetEngineActive and ent:GetEngineActive() then
            heatSignature = 50
            if ent.GetThrottle then
                heatSignature = heatSignature + (ent:GetThrottle() * 50)
            end
        end
        
        -- Fahrzeug-Info - Name nur wenn Transponder verfügbar
        local name = "UNBEKANNTES FAHRZEUG"
        if hasTransponder then
            name = ent.PrintName or ent:GetClass()
        end
        local velocity = ent:GetVelocity():Length()
        
        table.insert(self._radarTargets, {
            entity = ent,
            name = name,
            distance = distance,
            altitude = targetPos.z - myPos.z,
            velocity = velocity,
            heatSignature = heatSignature,
            visible = visible,
            position = targetPos,
            identified = hasTransponder,  -- NEU: Flag ob identifiziert
        })
    end
    
    -- Nach Distanz sortieren
    table.sort(self._radarTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    
    -- An Operator senden
    local operator = self:GetOperator()
    if IsValid(operator) then
        self:SendTargets(operator)
    end
    
    -- Immer an alle Clients in der Nähe senden (für Display)
    self:SendTargetsToNearby()
end

function ENT:SendTargets(ply)
    if not IsValid(ply) then return end
    
    net.Start("EGC_SAM_UpdateTargets")
    net.WriteEntity(self)
    net.WriteInt(#self._radarTargets, 16)
    
    for _, target in ipairs(self._radarTargets) do
        net.WriteEntity(target.entity)
        net.WriteString(target.name)
        net.WriteFloat(target.distance)
        net.WriteFloat(target.altitude)
        net.WriteFloat(target.velocity)
        net.WriteFloat(target.heatSignature)
        net.WriteBool(target.visible)
        net.WriteBool(target.identified or false)  -- NEU: Identifizierungs-Flag
    end
    
    net.Send(ply)
end

-- Sendet Ziele an alle Clients in der Nähe (für Display)
function ENT:SendTargetsToNearby()
    local myPos = self:GetPos()
    local nearbyPlayers = {}
    
    -- Erhöhte Reichweite für Display-Updates (2000 Einheiten = Sichtweite + Puffer)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetPos():Distance(myPos) < 2000 then
            table.insert(nearbyPlayers, ply)
        end
    end
    
    if #nearbyPlayers == 0 then return end
    
    local targetCount = #self._radarTargets
    
    net.Start("EGC_SAM_UpdateTargets")
    net.WriteEntity(self)
    net.WriteInt(targetCount, 16)
    
    for _, target in ipairs(self._radarTargets) do
        if IsValid(target.entity) then
            net.WriteEntity(target.entity)
            net.WriteString(target.name or "Unknown")
            net.WriteFloat(target.distance or 0)
            net.WriteFloat(target.altitude or 0)
            net.WriteFloat(target.velocity or 0)
            net.WriteFloat(target.heatSignature or 0)
            net.WriteBool(target.visible or false)
            net.WriteBool(target.identified or false)
        else
            -- Ungültige Entity - sende leere Daten
            net.WriteEntity(NULL)
            net.WriteString("Invalid")
            net.WriteFloat(0)
            net.WriteFloat(0)
            net.WriteFloat(0)
            net.WriteFloat(0)
            net.WriteBool(false)
            net.WriteBool(false)
        end
    end
    
    net.Send(nearbyPlayers)
    
    -- Debug
    if targetCount > 0 then
        print("[Torpedo Control] Ziele gesendet: " .. targetCount .. " Ziele an " .. #nearbyPlayers .. " Spieler")
    end
end

-- ============================================
-- ABSCHUSS STEUERUNG
-- ============================================

function ENT:FireSalvo(target, salvoSize)
    if not IsValid(target) then return 0 end
    
    -- Prüfen ob Armed
    if not self:GetArmed() then
        local operator = self:GetOperator()
        if IsValid(operator) then
            operator:ChatPrint("[Torpedo Control] FEHLER: Raketen nicht scharf! Erst ARM drücken!")
        end
        return 0
    end
    
    local fired = 0
    
    -- Prüfe ob VLS ausgewählt wurden
    if not self._selectedVLS or #self._selectedVLS == 0 then
        local operator = self:GetOperator()
        if IsValid(operator) then
            operator:ChatPrint("[Torpedo Control] FEHLER: Keine VLS-Systeme ausgewählt!")
        end
        return 0
    end
    
    -- Feuere nur ausgewählte VLS-Systeme
    for _, vlsData in ipairs(self._connectedVLS) do
        local vls = vlsData.entity
        if not IsValid(vls) then continue end
        
        -- Prüfe ob dieses VLS ausgewählt ist
        local isSelected = false
        for _, selectedID in ipairs(self._selectedVLS) do
            if vls:EntIndex() == selectedID then
                isSelected = true
                break
            end
        end
        
        if not isSelected then continue end
        
        local missiles = vls.GetMissileCount and vls:GetMissileCount() or 0
        if missiles <= 0 then continue end
        
        -- Rakete von diesem VLS abfeuern
        if vls.LaunchMissile then
            local missile = vls:LaunchMissile(target)
            if missile then
                fired = fired + 1
                vlsData.missiles = vlsData.missiles - 1
                
                -- Rakete tracken für Abort
                if IsValid(missile) then
                    table.insert(self._activeMissiles, {
                        entity = missile,
                        launchTime = CurTime(),
                        target = target,
                    })
                end
            end
        end
    end
    
    -- Update active missiles count
    self:SetActiveMissiles(#self._activeMissiles)
    
    -- VLS Status aktualisieren
    self:ScanVLS()
    -- Sofort aktualisierte Daten senden
    self:SendVLSStatusToNearby()
    
    local operator = self:GetOperator()
    if IsValid(operator) then
        if fired > 0 then
            operator:ChatPrint(string.format("[Torpedo Control] %d Torpedos abgefeuert!", fired))
        else
            operator:ChatPrint("[Torpedo Control] Abschuss fehlgeschlagen - Keine Munition!")
        end
    end
    
    return fired
end

-- ============================================
-- ABORT FUNKTION
-- ============================================

function ENT:AbortAllMissiles()
    local aborted = 0
    
    for _, missileData in ipairs(self._activeMissiles) do
        local missile = missileData.entity
        if IsValid(missile) and missile.Abort then
            missile:Abort()
            aborted = aborted + 1
        end
    end
    
    -- Liste leeren
    self._activeMissiles = {}
    self:SetActiveMissiles(0)
    
    -- Alarm deaktivieren
    self:DisarmMissiles()
    
    local operator = self:GetOperator()
    if IsValid(operator) then
        if aborted > 0 then
            operator:ChatPrint(string.format("[Torpedo Control] ABORT! %d Raketen zerstört!", aborted))
        else
            operator:ChatPrint("[Torpedo Control] Keine aktiven Raketen zum Abbrechen")
        end
    end
    
    -- Abort Sound
    self:EmitSound("buttons/button10.wav", 100, 60)
    
    return aborted
end

-- ============================================
-- NETZWERK EMPFANG
-- ============================================

net.Receive("EGC_SAM_SelectTarget", function(len, ply)
    local station = net.ReadEntity()
    local target = net.ReadEntity()
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    -- Prüfe ob Ziel in der Ziel-Liste ist
    local isInTargetList = false
    for _, targetData in ipairs(station._radarTargets or {}) do
        if IsValid(targetData.entity) and targetData.entity == target then
            isInTargetList = true
            break
        end
    end
    
    if not isInTargetList then
        ply:ChatPrint("[Torpedo Control] Ziel nicht in der Radar-Liste!")
        return
    end
    
    station:SetSelectedTarget(target)
    
    -- Alle VLS auf dieses Ziel setzen
    for _, vlsData in ipairs(station._connectedVLS) do
        local vls = vlsData.entity
        if IsValid(vls) and vls.SetCurrentTarget then
            vls:SetCurrentTarget(target)
        end
    end
    
    ply:ChatPrint("[Torpedo Control] Ziel erfasst: " .. (IsValid(target) and (target.PrintName or target:GetClass()) or "Keins"))
end)

net.Receive("EGC_SAM_SetSalvoSize", function(len, ply)
    -- DEPRECATED: Wird nicht mehr verwendet, aber für Kompatibilität behalten
    local station = net.ReadEntity()
    local size = net.ReadInt(8)
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    size = math.Clamp(size, 1, station.MaxSalvoSize)
    station:SetSalvoSize(size)
    
    ply:ChatPrint("[Torpedo Control] Salvengröße: " .. size .. " Torpedos (DEPRECATED - Verwende VLS-Auswahl)")
end)

-- NEU: VLS-System auswählen/abwählen
net.Receive("EGC_SAM_ToggleVLS", function(len, ply)
    local station = net.ReadEntity()
    local vlsEntity = net.ReadEntity()
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsValid(vlsEntity) then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    -- Prüfe ob VLS verbunden ist
    local isConnected = false
    for _, vlsData in ipairs(station._connectedVLS or {}) do
        if IsValid(vlsData.entity) and vlsData.entity == vlsEntity then
            isConnected = true
            break
        end
    end
    
    if not isConnected then
        ply:ChatPrint("[Torpedo Control] VLS-System nicht verbunden!")
        return
    end
    
    -- Toggle VLS-Auswahl
    local vlsID = vlsEntity:EntIndex()
    local isSelected = false
    local newSelection = {}
    
    for _, selectedID in ipairs(station._selectedVLS or {}) do
        if selectedID == vlsID then
            isSelected = true
        else
            table.insert(newSelection, selectedID)
        end
    end
    
    if not isSelected then
        -- VLS auswählen
        table.insert(newSelection, vlsID)
        ply:ChatPrint("[Torpedo Control] VLS #" .. vlsID .. " ausgewählt")
    else
        -- VLS abwählen
        ply:ChatPrint("[Torpedo Control] VLS #" .. vlsID .. " abgewählt")
    end
    
    station._selectedVLS = newSelection
    
    -- Sofort aktualisierte Daten senden
    station:SendVLSStatusToNearby()
end)

net.Receive("EGC_SAM_FireSalvo", function(len, ply)
    local station = net.ReadEntity()
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    local target = station:GetSelectedTarget()
    
    if not IsValid(target) then
        ply:ChatPrint("[Torpedo Control] FEHLER: Kein Ziel ausgewählt!")
        return
    end
    
    -- FEUER! (salvoSize wird nicht mehr verwendet)
    station:EmitSound("buttons/button9.wav", 100, 80)
    station:FireSalvo(target, 0)
end)

-- NEU: Arm Missiles
net.Receive("EGC_SAM_ArmMissiles", function(len, ply)
    local station = net.ReadEntity()
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    station:ArmMissiles()
end)

-- NEU: Disarm Missiles
net.Receive("EGC_SAM_DisarmMissiles", function(len, ply)
    local station = net.ReadEntity()
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    station:DisarmMissiles()
end)

-- NEU: Abort Missiles
net.Receive("EGC_SAM_AbortMissiles", function(len, ply)
    local station = net.ReadEntity()
    
    if not IsValid(station) or station:GetClass() ~= "lvs_sam_control" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (1000 Einheiten)
    if ply:GetPos():Distance(station:GetPos()) > 1000 then return end
    
    station:AbortAllMissiles()
end)

-- ============================================
-- THINK LOOP
-- ============================================


-- ============================================
-- THINK LOOP - OPTIMIERT
-- ============================================

function ENT:Think()
    local T = CurTime()
    
    -- Beim ersten Durchlauf sofort scannen und senden
    if not self._initializedThink then
        self._initializedThink = true
        self._lastVLSScan = 0
        self._lastScan = 0
        -- Sofort erste Scans ausführen
        self:ScanVLS()
        self:SendVLSStatusToNearby()
        self:ScanTargets()
        self:SendTargetsToNearby()
    end
    
    -- OPTIMIERT: VLS alle 2 Sekunden scannen (häufiger für bessere Updates)
    if T - (self._lastVLSScan or 0) > 2 then
        self._lastVLSScan = T
        self:ScanVLS()
        -- Daten an alle Clients in der Nähe senden (für Display)
        self:SendVLSStatusToNearby()
    end
    
    -- OPTIMIERT: Alarm-Geräte alle 10 Sekunden scannen (statt bei jedem VLS-Scan)
    if T - (self._lastAlarmScan or 0) > 10 then
        self._lastAlarmScan = T
        self:ScanAlarmDevices()
    end
    
    -- Ziele alle 0.5 Sekunden scannen (häufiger für bessere Updates)
    if T - (self._lastScan or 0) > 0.5 then
        self._lastScan = T
        self:ScanTargets()
        -- Daten an alle Clients in der Nähe senden (für Display)
        self:SendTargetsToNearby()
    end
    
    -- Aktive Raketen bereinigen - nur wenn Raketen aktiv sind
    if #self._activeMissiles > 0 then
        local validMissiles = {}
        for _, missileData in ipairs(self._activeMissiles) do
            if IsValid(missileData.entity) then
                table.insert(validMissiles, missileData)
            end
        end
        self._activeMissiles = validMissiles
        self:SetActiveMissiles(#self._activeMissiles)
    end
    
    -- Think immer aktiv halten - jeden Frame für sofortige Updates
    self:NextThink(T + 0.01)  -- Fast jeden Frame (100 FPS)
    return true
end

-- Hook: Sende Daten sofort wenn Spieler spawnt
hook.Add("PlayerInitialSpawn", "EGC_SAM_SendDataOnSpawn", function(ply)
    timer.Simple(1, function()  -- Kurze Verzögerung für Initialisierung
        if not IsValid(ply) then return end
        
        for _, station in pairs(ents.FindByClass("lvs_sam_control")) do
            if IsValid(station) and station:GetActive() then
                local dist = ply:GetPos():Distance(station:GetPos())
                if dist < 2000 then
                    -- Sende VLS-Status
                    if station.SendVLSStatus then
                        station:SendVLSStatus(ply)
                    end
                    -- Sende Ziele
                    if station.SendTargets then
                        station:SendTargets(ply)
                    end
                end
            end
        end
    end)
end)

function ENT:OnOperatorLeave()
    print("[Torpedo Control] Operator hat Station verlassen - Scans deaktiviert")
    self._lastScan = 0
    self._lastVLSScan = 0
    self._lastAlarmScan = 0
end

function ENT:OnRemove()
    self:DeactivateAlarm()
end

-- ============================================
-- OPTIMIERT: Operator-Disconnect Handling
-- ============================================
hook.Add("PlayerDisconnected", "SAM_OperatorDisconnect", function(ply)
    for _, station in pairs(ents.FindByClass("lvs_sam_control")) do
        if IsValid(station) and station:GetOperator() == ply then
            station:SetOperator(NULL)
            if station.OnOperatorLeave then
                station:OnOperatorLeave()
            end
        end
    end
end)

print("[EastGermanCrusader SAM System] Control Station geladen - OPTIMIERT!")
