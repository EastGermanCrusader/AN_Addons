-- eastgermancrusader_cff/lua/entities/sw_kus_command_center/init.lua
-- KUS Forward Command Center - Server
-- OPTIMIERT für Mehrspieler (20-50 Spieler)
-- BUG-FIX: Kreisende Flak-Schüsse behoben

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- ============================================================================
-- ENTITY VARIABLEN
-- ============================================================================
ENT.Requests = {}
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

-- Performance-Cache
local cachedAV7s_kus = {}
local lastAV7CacheTime_kus = 0

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

local function GetUnmannedAV7s_KUS(forceRefresh)
    local cfg = CFF_CONFIG or {}
    local cacheTime = cfg.AV7CacheTime or 3.0
    
    if not forceRefresh and (CurTime() - lastAV7CacheTime_kus) < cacheTime then
        return cachedAV7s_kus
    end
    
    cachedAV7s_kus = {}
    for _, ent in ipairs(ents.FindByClass("lvs_av7")) do
        if IsValid(ent) and not IsValid(ent:GetDriver()) then
            table.insert(cachedAV7s_kus, ent)
        end
    end
    
    lastAV7CacheTime_kus = CurTime()
    return cachedAV7s_kus
end

local function GetPlayersInRadius_KUS(pos, radius)
    local result = {}
    local radiusSqr = radius * radius
    
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetPos():DistToSqr(pos) < radiusSqr then
            table.insert(result, ply)
        end
    end
    
    return result
end

-- ============================================================================
-- ENTITY FUNKTIONEN
-- ============================================================================

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end
    
    self:SetRequestCount(0)
    self:SetIsActive(true)
    self:SetFlakMode(false)
    self:SetFlakHeight(1)
    self.Requests = {}
    self.LastFlakCheck = 0
    self.LastThinkTime = 0
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    net.Start("cff_kus_open_menu")
    net.WriteEntity(self)
    net.WriteTable(self.Requests)
    net.Send(activator)
end

function ENT:Think()
    local cfg = CFF_CONFIG or {}
    local thinkInterval = cfg.ThinkInterval or 1.0
    
    if CurTime() - self.LastThinkTime < thinkInterval then
        self:NextThink(CurTime() + thinkInterval)
        return true
    end
    self.LastThinkTime = CurTime()
    
    local timeout = cfg.RequestTimeout or 60
    for id, request in pairs(self.Requests) do
        if CurTime() - request.timestamp > timeout then
            self.Requests[id] = nil
        end
    end
    self:SetRequestCount(table.Count(self.Requests))
    
    if self:GetFlakMode() then
        self:UpdateFlakTracking()
    end
    
    self:NextThink(CurTime() + thinkInterval)
    return true
end

-- ============================================================================
-- ARTILLERIE-STRIKE AUSFÜHRUNG
-- ============================================================================

function ENT:ExecuteArtilleryStrike(av7List, targetPos, av7Count, request)
    if not av7List or #av7List == 0 then return end
    
    local cfg = CFF_CONFIG or {}
    local shotsPerAV7 = cfg.ShotsPerAV7 or 3
    local totalShots = av7Count * shotsPerAV7
    local shotDelay = cfg.ShotDelay or 3
    
    local isFlakMode = request and request.isFlakMode or false
    local flakHeight = request and request.flakHeight or 1
    
    local message
    if isFlakMode then
        message = "🎯 KUS Flak-Beschuss! Höhe: Schicht " .. flakHeight .. " | " .. av7Count .. " AV-7(s)"
    else
        message = "🎯 KUS Artillerie-Beschuss! " .. av7Count .. " AV-7(s), " .. totalShots .. " Schüsse"
    end
    
    for _, ply in ipairs(player.GetAll()) do
        ply:ChatPrint(message)
    end
    
    for _, av7 in ipairs(av7List) do
        if IsValid(av7) then
            self:AimAV7AtTarget(av7, targetPos, isFlakMode, flakHeight)
        end
    end
    
    timer.Simple(2, function()
        if not IsValid(self) then return end
        
        local shotIndex = 0
        for av7Index, av7 in ipairs(av7List) do
            if not IsValid(av7) then continue end
            
            for shot = 1, shotsPerAV7 do
                local delay = (av7Index - 1) * shotDelay + (shot - 1) * shotDelay
                
                timer.Simple(delay, function()
                    if not IsValid(self) or not IsValid(av7) then return end
                    
                    self:AimAV7AtTarget(av7, targetPos, isFlakMode, flakHeight)
                    self:FireAV7Weapon(av7, targetPos, isFlakMode, flakHeight)
                    
                    shotIndex = shotIndex + 1
                    if shotIndex >= totalShots then
                        for _, ply in ipairs(player.GetAll()) do
                            ply:ChatPrint("✓ KUS Beschuss abgeschlossen!")
                        end
                    end
                end)
            end
        end
    end)
end

-- ============================================================================
-- AV-7 AUSRICHTUNG
-- ============================================================================

function ENT:AimAV7AtTarget(av7, targetPos, isFlakMode, flakHeight)
    if not IsValid(av7) then return end
    
    local muzzleID = av7:LookupAttachment("muzzle")
    if not muzzleID then return end
    
    local muzzle = av7:GetAttachment(muzzleID)
    if not muzzle then return end
    
    local muzzlePos = muzzle.Pos
    local toTarget = targetPos - muzzlePos
    local distance = toTarget:Length()
    
    local yaw = math.deg(math.atan2(toTarget.y, toTarget.x))
    local currentAngles = av7:GetAngles()
    av7:SetAngles(Angle(currentAngles.p, yaw, currentAngles.r))
    
    local pitch = -45
    
    if isFlakMode then
        local toTargetDir = toTarget:GetNormalized()
        pitch = math.deg(math.asin(-toTargetDir.z))
    else
        local projectileSpeed = 3000
        local gravity = math.abs(physenv.GetGravity().z)
        if gravity == 0 then gravity = 600 end
        
        local gd = gravity * distance
        local v2 = projectileSpeed * projectileSpeed
        
        if gd <= v2 then
            local sinAngle = gd / v2
            if sinAngle <= 1 and sinAngle >= 0 then
                pitch = -math.deg(math.asin(sinAngle)) / 2
            end
        end
    end
    
    pitch = math.Clamp(pitch, -50, 20)
    
    local gunBone = av7:LookupBone("gun")
    if gunBone then
        av7:ManipulateBoneAngles(gunBone, Angle(0, 0, pitch))
    end
end

-- ============================================================================
-- AV-7 WAFFE ABFEUERN (MIT FLAK BUG-FIX)
-- ============================================================================

function ENT:FireAV7Weapon(av7, targetPos, isFlakMode, flakHeight)
    if not IsValid(av7) then return end
    if av7:GetBodygroup(1) == 1 then return end
    if av7:GetAmmo() <= 0 then
        av7:SetHeat(1)
        return
    end
    
    local muzzleID = av7:LookupAttachment("muzzle")
    if not muzzleID then return end
    
    local muzzle = av7:GetAttachment(muzzleID)
    if not muzzle then return end
    
    local muzzlePos = muzzle.Pos
    local muzzleAng = muzzle.Ang
    
    timer.Simple(0.2, function()
        if not IsValid(av7) then return end
        if av7:GetAmmo() <= 0 then 
            av7:SetHeat(1)
            return 
        end
        
        av7:TakeAmmo()
        
        local cfg = CFF_CONFIG or {}
        
        if isFlakMode then
            -- FLAK-MODUS: GERADE SCHUSSBAHN (BUG-FIX!)
            local projectile = ents.Create("lvs_protontorpedo")
            if not IsValid(projectile) then return end
            
            local toTarget = (targetPos - muzzlePos)
            local dir = toTarget:GetNormalized()
            local speed = cfg.FlakProjectileSpeed or 4000
            
            projectile:SetPos(muzzlePos)
            projectile:SetAngles(dir:Angle())
            projectile:Spawn()
            projectile:SetDamage(cfg.FlakDamage or 550)
            projectile:SetRadius(cfg.FlakRadius or 350)
            projectile:Activate()
            
            -- BUG-FIX: Keine Zielverfolgung!
            projectile.GetTarget = function(missile)
                return nil
            end
            
            local fixedTarget = targetPos
            projectile.GetTargetPos = function(missile)
                return fixedTarget
            end
            
            projectile:SetAttacker(av7)
            if av7.GetCrosshairFilterEnts then
                projectile:SetEntityFilter(av7:GetCrosshairFilterEnts())
            end
            projectile:Enable()
            
            -- Gerade Flugbahn durch Physics
            local phys = projectile:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableGravity(false)
                phys:SetVelocity(dir * speed)
            else
                projectile:SetVelocity(dir * speed)
            end
            
            local flightTime = toTarget:Length() / speed
            timer.Simple(flightTime + 2, function()
                if IsValid(projectile) then
                    projectile:Remove()
                end
            end)
            
            projectile:EmitSound("vehicle/starwars/av7/av7fire.wav")
        else
            -- ARTILLERIE-MODUS
            local projectile = ents.Create("lvs_fall_missel")
            if not IsValid(projectile) then return end
            
            local dir = muzzleAng:Up()
            
            projectile:SetPos(muzzlePos)
            projectile:SetAngles(dir:Angle())
            projectile:Spawn()
            projectile:Activate()
            
            local fixedTarget = targetPos
            projectile.GetTarget = function(missile)
                return missile
            end
            projectile.GetTargetPos = function(missile)
                return fixedTarget + VectorRand() * math.random(-10, 10)
            end
            
            projectile:SetAttacker(av7)
            if av7.GetCrosshairFilterEnts then
                projectile:SetEntityFilter(av7:GetCrosshairFilterEnts())
            end
            projectile:Enable()
            projectile:EmitSound("vehicle/starwars/av7/av7fire.wav")
        end
        
        -- Effekte
        util.ScreenShake(av7:GetPos(), 100, 40, 1, 2000, true)
        local effectdata = EffectData()
        effectdata:SetOrigin(av7:GetPos())
        effectdata:SetRadius(250000)
        effectdata:SetScale(480)
        util.Effect("ThumperDust", effectdata, true, true)
        
        -- Rückstoß
        av7:SetPos(av7:GetPos() - av7:GetForward() * 1.5)
        timer.Simple(1.5, function()
            if IsValid(av7) then
                av7:SetPos(av7:GetPos() + av7:GetForward() * 1.5)
            end
        end)
    end)
end

-- ============================================================================
-- FLAK-TRACKING SYSTEM
-- ============================================================================

function ENT:UpdateFlakTracking()
    local cfg = CFF_CONFIG or {}
    local checkInterval = cfg.FlakCheckInterval or 2.0
    
    if CurTime() - self.LastFlakCheck < checkInterval then return end
    self.LastFlakCheck = CurTime()
    
    local aircraftTypes = {
        ["fighterplane"] = true,
        ["helicopter"] = true,
        ["starfighter"] = true
    }
    
    local enemyAircraft = {}
    local allVehicles = {}
    
    if LVS and LVS.GetVehicles then
        allVehicles = LVS:GetVehicles()
    else
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent.LVS and ent.GetVehicleType then
                table.insert(allVehicles, ent)
            end
        end
    end
    
    for _, vehicle in ipairs(allVehicles) do
        if not IsValid(vehicle) then continue end
        
        local vehicleType = vehicle:GetVehicleType and vehicle:GetVehicleType()
        if vehicleType and aircraftTypes[vehicleType] then
            local driver = vehicle:GetDriver()
            if IsValid(driver) and driver:IsPlayer() then
                table.insert(enemyAircraft, vehicle)
            end
        end
    end
    
    if #enemyAircraft > 0 then
        local target = enemyAircraft[math.random(1, #enemyAircraft)]
        if IsValid(target) then
            self:ExecuteFlakAttack(target)
        end
    end
end

function ENT:ExecuteFlakAttack(aircraft)
    if not IsValid(aircraft) then return end
    
    local unmannedAV7s = GetUnmannedAV7s_KUS(true)
    if #unmannedAV7s == 0 then return end
    
    local cfg = CFF_CONFIG or {}
    local aircraftPos = aircraft:GetPos()
    local flakHeight = self:GetFlakHeight()
    local heightOffset = flakHeight * (cfg.FlakHeightMultiplier or 500)
    local targetPos = aircraftPos + Vector(0, 0, heightOffset)
    
    local request = {
        isFlakMode = true,
        flakHeight = flakHeight
    }
    
    self:ExecuteArtilleryStrike(unmannedAV7s, targetPos, #unmannedAV7s, request)
end

function ENT:OnRemove() end

-- ============================================================================
-- NETZWERK-HANDLER (KUS-spezifisch)
-- ============================================================================

if SERVER then
    -- Network Strings für KUS
    util.AddNetworkString("cff_kus_request")
    util.AddNetworkString("cff_kus_open_menu")
    util.AddNetworkString("cff_kus_close_menu")
    util.AddNetworkString("cff_kus_respond_request")
    util.AddNetworkString("cff_kus_request_response")
    util.AddNetworkString("cff_kus_toggle_flak")
    util.AddNetworkString("cff_kus_set_flak_height")
    
    if not cff_kus_request_registered then
        cff_kus_request_registered = true
        
        net.Receive("cff_kus_request", function(len, ply)
            if not _cfgOk() then return end
            local commandCenter = net.ReadEntity()
            if not IsValid(commandCenter) then return end
            if commandCenter:GetClass() ~= "sw_kus_command_center" then return end
            
            local requestId = net.ReadString()
            local requester = net.ReadEntity()
            local targetPos = net.ReadVector()
            local requestType = net.ReadString()
            local isFlakMode = net.ReadBool() or false
            local flakHeight = net.ReadInt(8) or 1
            
            if not IsValid(requester) or requester ~= ply then return end
            
            local request = {
                id = requestId,
                requester = requester,
                targetPos = targetPos,
                type = requestType,
                isFlakMode = isFlakMode,
                flakHeight = flakHeight,
                timestamp = CurTime(),
                status = "pending"
            }
            
            commandCenter.Requests = commandCenter.Requests or {}
            commandCenter.Requests[requestId] = request
            commandCenter:SetRequestCount(table.Count(commandCenter.Requests))
            
            local cfg = CFF_CONFIG or {}
            local nearbyPlayers = GetPlayersInRadius_KUS(commandCenter:GetPos(), cfg.NotifyRadius or 200)
            
            for _, v in ipairs(nearbyPlayers) do
                net.Start("cff_kus_open_menu")
                net.WriteEntity(commandCenter)
                net.WriteTable(commandCenter.Requests)
                net.Send(v)
            end
        end)
    end
    
    if not cff_kus_respond_registered then
        cff_kus_respond_registered = true
        
        net.Receive("cff_kus_respond_request", function(len, ply)
            if not _cfgOk() then return end
            local commandCenter = net.ReadEntity()
            if not IsValid(commandCenter) then return end
            if commandCenter:GetClass() ~= "sw_kus_command_center" then return end
            
            local requestId = net.ReadString()
            local response = net.ReadBool()
            
            commandCenter.Requests = commandCenter.Requests or {}
            if not commandCenter.Requests[requestId] then return end
            
            local request = commandCenter.Requests[requestId]
            
            if response then
                local unmannedAV7s = GetUnmannedAV7s_KUS(true)
                
                if #unmannedAV7s == 0 then
                    ply:ChatPrint("❌ Keine unbemannte AV-7 verfügbar!")
                    request.status = "denied"
                    
                    if IsValid(request.requester) then
                        net.Start("cff_kus_request_response")
                        net.WriteString(requestId)
                        net.WriteBool(false)
                        net.WriteVector(request.targetPos)
                        net.Send(request.requester)
                    end
                    return
                end
                
                request.status = "accepted"
                commandCenter:ExecuteArtilleryStrike(unmannedAV7s, request.targetPos, #unmannedAV7s, request)
            else
                request.status = "denied"
            end
            
            local cfg = CFF_CONFIG or {}
            local nearbyPlayers = GetPlayersInRadius_KUS(commandCenter:GetPos(), cfg.NotifyRadius or 200)
            
            for _, v in ipairs(nearbyPlayers) do
                net.Start("cff_kus_open_menu")
                net.WriteEntity(commandCenter)
                net.WriteTable(commandCenter.Requests)
                net.Send(v)
            end
            
            if IsValid(request.requester) then
                net.Start("cff_kus_request_response")
                net.WriteString(requestId)
                net.WriteBool(response)
                net.WriteVector(request.targetPos)
                net.Send(request.requester)
            end
            
            timer.Simple(5, function()
                if IsValid(commandCenter) and commandCenter.Requests then
                    commandCenter.Requests[requestId] = nil
                    commandCenter:SetRequestCount(table.Count(commandCenter.Requests))
                end
            end)
        end)
    end
    
    if not cff_kus_toggle_flak_registered then
        cff_kus_toggle_flak_registered = true
        
        net.Receive("cff_kus_toggle_flak", function(len, ply)
            if not _cfgOk() then return end
            local commandCenter = net.ReadEntity()
            if not IsValid(commandCenter) then return end
            if commandCenter:GetClass() ~= "sw_kus_command_center" then return end
            
            commandCenter:SetFlakMode(not commandCenter:GetFlakMode())
            ply:ChatPrint("KUS Flak-Modus: " .. (commandCenter:GetFlakMode() and "AKTIVIERT" or "DEAKTIVIERT"))
        end)
        
        net.Receive("cff_kus_set_flak_height", function(len, ply)
            if not _cfgOk() then return end
            local commandCenter = net.ReadEntity()
            if not IsValid(commandCenter) then return end
            if commandCenter:GetClass() ~= "sw_kus_command_center" then return end
            
            local height = math.Clamp(net.ReadInt(8), 1, 4)
            commandCenter:SetFlakHeight(height)
            ply:ChatPrint("KUS Flak-Höhe: Schicht " .. height)
        end)
    end
end
