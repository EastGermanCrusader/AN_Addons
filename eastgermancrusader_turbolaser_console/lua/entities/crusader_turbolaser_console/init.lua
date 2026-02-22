-- eastgermancrusader_base/lua/entities/crusader_turbolaser_console/init.lua

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Netzwerk-Strings registrieren
util.AddNetworkString("Crusader_TurbolaserConsole_Open")
util.AddNetworkString("Crusader_TurbolaserConsole_Select")
util.AddNetworkString("Crusader_TurbolaserConsole_Update")

-- Tabelle um Spieler-Ursprungspositionen zu speichern
ENT.PlayerOrigins = ENT.PlayerOrigins or {}
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

function ENT:Initialize()
    self:SetModel("models/kingpommes/starwars/misc/bridge_console4.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
    
    self:SetInUse(false)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    -- Alle Turbolaser auf der Karte finden
    local turbolasers = self:FindAllTurbolasers()
    
    -- Sende die Liste an den Client
    net.Start("Crusader_TurbolaserConsole_Open")
        net.WriteEntity(self)
        net.WriteUInt(#turbolasers, 8)
        for _, turbo in ipairs(turbolasers) do
            net.WriteEntity(turbo.entity)
            net.WriteString(turbo.name)
            net.WriteVector(turbo.pos)
            net.WriteBool(turbo.occupied)
            net.WriteFloat(turbo.health)
            net.WriteFloat(turbo.maxhealth)
        end
    net.Send(activator)
end

function ENT:FindAllTurbolasers()
    local turbolasers = {}
    
    -- Suche nach allen lvs_turbo_laser Entities
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and string.find(ent:GetClass(), "lvs_turbo") then
            local name = ent:GetClass()
            
            -- Versuche einen besseren Namen zu bekommen
            if ent.PrintName and ent.PrintName ~= "" then
                name = ent.PrintName
            elseif ent:GetNWString("Name", "") ~= "" then
                name = ent:GetNWString("Name")
            end
            
            -- Prüfe ob besetzt
            local occupied = false
            if ent.GetDriver and IsValid(ent:GetDriver()) then
                occupied = true
            elseif ent.GetPassenger then
                for i = 0, 10 do
                    if IsValid(ent:GetPassenger(i)) then
                        occupied = true
                        break
                    end
                end
            end
            
            -- Hole Gesundheit
            local health = ent:Health() or 100
            local maxhealth = ent:GetMaxHealth() or 100
            if maxhealth == 0 then maxhealth = 100 end
            
            table.insert(turbolasers, {
                entity = ent,
                name = name .. " #" .. ent:EntIndex(),
                pos = ent:GetPos(),
                occupied = occupied,
                health = health,
                maxhealth = maxhealth
            })
        end
    end
    
    return turbolasers
end

-- Empfange Auswahl vom Client
net.Receive("Crusader_TurbolaserConsole_Select", function(len, ply)
    if not _cfgOk() then return end
    local console = net.ReadEntity()
    local turbolaser = net.ReadEntity()
    
    if not IsValid(console) or not IsValid(turbolaser) or not IsValid(ply) then return end
    if console:GetClass() ~= "crusader_turbolaser_console" then return end
    
    -- Speichere die Ursprungsposition des Spielers
    console.PlayerOrigins = console.PlayerOrigins or {}
    console.PlayerOrigins[ply:SteamID()] = {
        pos = ply:GetPos(),
        ang = ply:EyeAngles(),
        console = console
    }
    
    -- Versuche den Spieler ins Fahrzeug zu setzen
    timer.Simple(0.1, function()
        if not IsValid(ply) or not IsValid(turbolaser) then return end
        
        local entered = false
        
        -- Methode 1: LVS GetDriverSeat
        if not entered and turbolaser.GetDriverSeat then
            local seat = turbolaser:GetDriverSeat()
            if IsValid(seat) and seat:IsVehicle() then
                ply:EnterVehicle(seat)
                entered = true
            end
        end
        
        -- Methode 2: LVS GetPassengerSeats
        if not entered and turbolaser.GetPassengerSeats then
            local seats = turbolaser:GetPassengerSeats()
            if seats and #seats > 0 then
                for _, seat in ipairs(seats) do
                    if IsValid(seat) and seat:IsVehicle() then
                        local driver = seat:GetDriver()
                        if not IsValid(driver) then
                            ply:EnterVehicle(seat)
                            entered = true
                            break
                        end
                    end
                end
            end
        end
        
        -- Methode 3: Suche nach pPod (LVS spezifisch)
        if not entered and turbolaser.pPod and IsValid(turbolaser.pPod) then
            ply:EnterVehicle(turbolaser.pPod)
            entered = true
        end
        
        -- Methode 4: Suche nach allen Vehicle-Children
        if not entered then
            for _, child in ipairs(turbolaser:GetChildren()) do
                if IsValid(child) and child:IsVehicle() then
                    local driver = child:GetDriver()
                    if not IsValid(driver) then
                        ply:EnterVehicle(child)
                        entered = true
                        break
                    end
                end
            end
        end
        
        -- Methode 5: Direkt als Vehicle
        if not entered and turbolaser:IsVehicle() then
            ply:EnterVehicle(turbolaser)
            entered = true
        end
        
        -- Methode 6: Simulated Use - Teleportiere und rufe Use auf
        if not entered then
            local oldPos = ply:GetPos()
            local oldAng = ply:EyeAngles()
            
            -- Teleportiere nah an den Turbolaser
            local usePos = turbolaser:GetPos() + turbolaser:GetForward() * 50 + Vector(0, 0, 20)
            ply:SetPos(usePos)
            ply:SetEyeAngles((turbolaser:GetPos() - usePos):Angle())
            
            -- Rufe Use auf
            timer.Simple(0.05, function()
                if IsValid(ply) and IsValid(turbolaser) then
                    turbolaser:Use(ply, ply, USE_ON, 1)
                    
                    -- Prüfe ob Spieler jetzt in einem Fahrzeug ist
                    timer.Simple(0.1, function()
                        if IsValid(ply) then
                            if not IsValid(ply:GetVehicle()) then
                                -- Use hat nicht funktioniert, setze zurück
                                ply:SetPos(oldPos)
                                ply:SetEyeAngles(oldAng)
                                ply:ChatPrint("[Konsole] Konnte nicht mit dem Turbolaser verbinden!")
                                
                                -- Lösche Origin da wir nicht eingestiegen sind
                                if console.PlayerOrigins then
                                    console.PlayerOrigins[ply:SteamID()] = nil
                                end
                                return
                            end
                        end
                    end)
                end
            end)
            
            entered = true -- Wir haben es versucht
        end
        
        -- Starte Überwachung für diesen Spieler
        console:StartPlayerMonitoring(ply, turbolaser)
    end)
end)

function ENT:StartPlayerMonitoring(ply, turbolaser)
    local steamid = ply:SteamID()
    local origin = self.PlayerOrigins[steamid]
    
    if not origin then return end
    
    local timerName = "Crusader_TurboMonitor_" .. steamid .. "_" .. self:EntIndex()
    local hasEnteredVehicle = false
    local checkCount = 0
    
 
        if not IsValid(ply) then return end
        
        timer.Create(timerName, 0.1, 0, function()
            -- Prüfe ob Spieler noch gültig ist
            if not IsValid(ply) then
                timer.Remove(timerName)
                return
            end
            
            checkCount = checkCount + 1
            
            -- Prüfe ob Turbolaser zerstört wurde
            local turboDestroyed = not IsValid(turbolaser)
            
            -- Prüfe ob Spieler in einem Fahrzeug ist
            local currentVehicle = ply:GetVehicle()
            local isInVehicle = IsValid(currentVehicle)
            
            print(isInVehicle, ply, currentVehicle)
            local isInTurbolaser = false
            if isInVehicle and not turboDestroyed then
                -- Direkt der Turbolaser
                if currentVehicle == turbolaser then
                    isInTurbolaser = true
                -- Parent ist der Turbolaser
                elseif IsValid(currentVehicle:GetParent()) and currentVehicle:GetParent() == turbolaser then
                    isInTurbolaser = true
                -- Prüfe alle Children des Turbolasers
                else
                    for _, child in ipairs(turbolaser:GetChildren()) do
                        if child == currentVehicle then
                            isInTurbolaser = true
                            break
                        end
                    end
                end
            end
            
            -- Merke wenn Spieler erfolgreich eingestiegen ist
            if isInTurbolaser then
                hasEnteredVehicle = true
            end
            
            -- Spieler ist ausgestiegen wenn:
            -- 1. Er vorher im Fahrzeug war UND jetzt nicht mehr drin ist
            -- 2. ODER er ist in einem anderen Fahrzeug
            local playerExited = false
            if hasEnteredVehicle and not isInTurbolaser then
                playerExited = true
            end
            
            -- Wenn ausgestiegen oder zerstört, teleportiere zurück
            if turboDestroyed or playerExited then
                timer.Remove(timerName)
                
                if IsValid(ply) and origin then
                    -- Kurze Verzögerung für sauberes Exit
                    timer.Simple(0.1, function()
                        if IsValid(ply) then
                            -- Verlasse Fahrzeug falls noch drin
                            if IsValid(ply:GetVehicle()) then
                                ply:ExitVehicle()
                            end
                            
                            -- Teleportiere zurück
                            ply:SetPos(origin.pos)
                            ply:SetEyeAngles(origin.ang)
                            
                            -- Benachrichtige den Spieler
                            if turboDestroyed then
                                ply:ChatPrint("[Konsole] Turbolaser wurde zerstört! Du wurdest zurück teleportiert.")
                            else
                                ply:ChatPrint("[Konsole] Verbindung getrennt. Du wurdest zurück zur Konsole teleportiert.")
                            end
                        end
                    end)
                end
                
                -- Lösche den Eintrag
                if self.PlayerOrigins then
                    self.PlayerOrigins[steamid] = nil
                end
            end
        end)
 
end

function ENT:OnRemove()
    -- Räume alle Timer auf
    for steamid, data in pairs(self.PlayerOrigins or {}) do
        local timerName = "Crusader_TurboMonitor_" .. steamid .. "_" .. self:EntIndex()
        timer.Remove(timerName)
    end
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end
    
    local pos = tr.HitPos + tr.HitNormal * 10
    local ent = ents.Create(ClassName)
    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    ent:Spawn()
    ent:Activate()
    
    return ent
end
