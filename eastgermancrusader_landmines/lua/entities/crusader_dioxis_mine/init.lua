AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Waffe zum Entschärfen: defuser_bomb. Mit STRG langsam zur Mine, dann LMB.
local DEFUSER_WEAPONS = {
    ["defuser_bomb"] = true,
}
local DEFUSAL_TIMER_NAME = "CrusaderDefusal_"
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

function ENT:GenerateWireConfiguration()
    if not LandmineDefusal or not LandmineDefusal.WireTypes then return end
    local wireCount = math.random(5, 7)
    self.Wires = {}
    for i = 1, wireCount do
        local wireType = table.Random(LandmineDefusal.WireTypes)
        table.insert(self.Wires, { id = i, name = wireType.name, color = wireType.color, position = i, isCut = false })
    end
    self:DetermineCase()
    if not self.ActiveCase then self:GenerateWireConfiguration() else self.CurrentStep = 1 self.CutWires = {} end
end
function ENT:DetermineCase()
    if not LandmineDefusal or not LandmineDefusal.Cases then return end
    for _, case in ipairs(LandmineDefusal.Cases) do if case.check(self.Wires) then self.ActiveCase = case return end end
    self.ActiveCase = nil
end
function ENT:StartDefusalMinigame(ply)
    if CLIENT then return end
    if not self.Armed or not IsValid(ply) or not ply:IsPlayer() then return end
    if self:GetIsDefusing() then return end
    if not LandmineDefusal or not LandmineDefusal.Cases then self:Defuse(ply) return end
    self:SetIsDefusing(true)
    self:GenerateWireConfiguration()
    if not self.ActiveCase then self:SetIsDefusing(false) self:Defuse(ply) return end
    self:SetTimeRemaining(LandmineDefusal.DefusalTime or 90)
    net.Start("LandmineDefusal_OpenUI") net.WriteEntity(self) net.WriteTable(self.Wires) net.WriteString(self.ActiveCase.name) net.WriteString(self.ActiveCase.description) net.WriteTable(self.ActiveCase.sequence) net.Send(ply)
    local tid = DEFUSAL_TIMER_NAME .. self:EntIndex()
    timer.Create(tid, 1, 0, function()
        if not IsValid(self) then timer.Remove(tid) return end
        if not self:GetIsDefusing() then timer.Remove(tid) return end
        local r = self:GetTimeRemaining() - 1
        self:SetTimeRemaining(r)
        if r <= 0 then timer.Remove(tid) self:Explode() end
    end)
end
function ENT:CheckWireCut(wirePosition, ply)
    if not self.ActiveCase or not self.ActiveCase.sequence then self:Explode() return false end
    local wire = self.Wires[wirePosition]
    if not wire or wire.isCut then self:Explode() return false end
    local expectedWireName = self.ActiveCase.sequence[self.CurrentStep]
    if wire.name == expectedWireName then
        wire.isCut = true
        self.CutWires[wirePosition] = true
        self.CurrentStep = self.CurrentStep + 1
        if self.CurrentStep > #self.ActiveCase.sequence then
            timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
            self:SetIsDefusing(false)
            self:Defuse(ply)
            return true, true
        end
        return true, false
    else
        self:Explode()
        return false, false
    end
end

local SLOW_WALK_SPEED = 100

local VALID_CLASSES = {
    ["prop_physics"] = true,
    ["prop_physics_multiplayer"] = true
}

local function IsValidTarget(ent, pos, self)
    if ent == self then return false end
    if not IsValid(ent) then return false end
    if self:IsBlacklisted(ent) then return false end

    if ent:IsPlayer() then
        if ent:KeyDown(IN_DUCK) or ent:KeyDown(IN_WALK) then return false end
        local velocity = ent:GetVelocity():Length2D()
        if velocity < SLOW_WALK_SPEED and velocity > 0 then return false end
        local weapon = ent:GetActiveWeapon()
        if IsValid(weapon) and DEFUSER_WEAPONS[weapon:GetClass()] then return false end
        return true
    end
    if ent:IsNPC() or ent:IsVehicle() then return true end
    local class = ent:GetClass()
    if class:find("lvs_", 1, true) or class:find("starwars", 1, true) then return true end
    if VALID_CLASSES[class] then
        local phys = ent:GetPhysicsObject()
        return IsValid(phys) and phys:GetMass() > 50
    end
    return false
end

function ENT:UpdateCheckInterval(playerCount)
    self._nearbyPlayersCount = playerCount
    local newInterval = (playerCount == 0) and 0.5 or ((playerCount == 1) and 0.15 or 0.1)
    if newInterval ~= self._proximityCheckInterval then
        self._proximityCheckInterval = newInterval
        local timerName = "CrusaderDioxisMine_" .. self:EntIndex()
        timer.Remove(timerName)
        timer.Create(timerName, newInterval, 0, function()
            if IsValid(self) then self:AdaptiveProximityCheck() end
        end)
    end
end

function ENT:AdaptiveProximityCheck()
    if not self.Armed then return end
    local pos = self:GetPos()
    local entsInRadius = ents.FindInSphere(pos, self.ProximityRadius)
    if #entsInRadius == 0 then
        self:UpdateCheckInterval(0)
        return
    end
    local playerCount = 0
    for i = 1, #entsInRadius do
        local ent = entsInRadius[i]
        if ent:IsPlayer() and IsValid(ent) then
            playerCount = playerCount + 1
            local currentVel = ent:GetVelocity():Length2D()
            local isMoving = currentVel > SLOW_WALK_SPEED
            local isStandingStill = currentVel < 10
            if isMoving and not isStandingStill and not ent:KeyDown(IN_WALK) and not ent:KeyDown(IN_DUCK) then
                local weapon = ent:GetActiveWeapon()
                if not IsValid(weapon) or not DEFUSER_WEAPONS[weapon:GetClass()] then
                    self:Explode()
                    return
                end
            end
        elseif IsValidTarget(ent, pos, self) then
            self:Explode()
            return
        end
    end
    self:UpdateCheckInterval(playerCount)
end

function ENT:StartTouch(entity)
    if not IsValid(entity) or not self.Armed then return end
    local pos = self:GetPos()
    if entity:IsPlayer() then
        local currentVel = entity:GetVelocity():Length2D()
        if currentVel > SLOW_WALK_SPEED and currentVel > 10 and not entity:KeyDown(IN_WALK) and not entity:KeyDown(IN_DUCK) then
            local weapon = entity:GetActiveWeapon()
            if not IsValid(weapon) or not DEFUSER_WEAPONS[weapon:GetClass()] then
                self:Explode()
            end
        end
    elseif IsValidTarget(entity, pos, self) then
        self:Explode()
    end
end

function ENT:IsBlacklisted(ent)
    if not self.VehicleBlacklist or type(self.VehicleBlacklist) ~= "table" then
        self.VehicleBlacklist = {}
        return false
    end
    local class, model = ent:GetClass(), ent:GetModel()
    for i = 1, #self.VehicleBlacklist do
        if class == self.VehicleBlacklist[i] or model == self.VehicleBlacklist[i] then return true end
    end
    return false
end

-- Dioxis: Auslösen = gb5_proj_howitzer_shell_cl spawnen und sofort zur Explosion bringen (Chlorgas)
function ENT:Explode()
    if SERVER and not _cfgOk() then return end
    if not self.Armed then return end
    local wasDefusing = self.GetIsDefusing and self:GetIsDefusing()
    self.Armed = false
    if self.SetIsDefusing then self:SetIsDefusing(false) end
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
    if wasDefusing and SERVER then
        net.Start("LandmineDefusal_Result") net.WriteBool(false) net.Broadcast()
    end

    local timerName = "CrusaderDioxisMine_" .. self:EntIndex()
    if timer.Exists(timerName) then timer.Remove(timerName) end

    local pos = self:GetPos()
    local owner = self:GetOwner()

    local shell = ents.Create("gb5_proj_howitzer_shell_cl")
    if IsValid(shell) then
        shell:SetPos(pos)
        shell:SetAngles(Angle(0, 0, 0))
        shell:Spawn()
        shell:Activate()
        if IsValid(owner) then
            shell:SetOwner(owner)
            shell:SetVar("GBOWNER", owner)
        end
        shell:Arm()
        timer.Simple(0.15, function()
            if IsValid(shell) then
                shell.Exploded = true
                shell:Explode()
            end
        end)
    end

    SafeRemoveEntityDelayed(self, 0.1)
end

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end

    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetRenderMode(RENDERMODE_NONE)
    self:SetHealth(1)
    self:SetUseType(SIMPLE_USE)

    self.Armed = true
    self.ProximityRadius = self.ProximityRadius or 200
    self.VehicleBlacklist = self.VehicleBlacklist or {}
    self._proximityCheckInterval = 0.5
    self._nearbyPlayersCount = 0

    local timerName = "CrusaderDioxisMine_" .. self:EntIndex()
    timer.Create(timerName, self._proximityCheckInterval, 0, function()
        if IsValid(self) then self:AdaptiveProximityCheck() end
    end)
end

function ENT:OnTakeDamage(dmg)
    if dmg:GetDamage() > 0 and self.Armed then self:Explode() end
end

function ENT:OnRemove()
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
    local timerName = "CrusaderDioxisMine_" .. self:EntIndex()
    if timer.Exists(timerName) then timer.Remove(timerName) end
end

-- Entschärfen mit Rechtsklick, Linksklick oder E (mit defuser_bomb + STRG/langsam)
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() or not self.Armed then return end
    local weapon = activator:GetActiveWeapon()
    if not IsValid(weapon) or not DEFUSER_WEAPONS[weapon:GetClass()] then return end
    if activator:KeyDown(IN_DUCK) or activator:KeyDown(IN_WALK) then
        self:StartDefusalMinigame(activator)
    else
        activator:ChatPrint("[Mine] STRG gedrückt halten und langsam bewegen, dann Rechtsklick/Linksklick oder E.")
    end
end

function ENT:Defuse(defuser)
    if not self.Armed then return end
    self.Armed = false
    if self.SetIsDefusing then self:SetIsDefusing(false) end
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())

    local timerName = "CrusaderDioxisMine_" .. self:EntIndex()
    if timer.Exists(timerName) then timer.Remove(timerName) end

    local pos = self:GetPos()
    self:EmitSound("buttons/button9.wav", 75, 100)
    self:EmitSound("ambient/steam/steam_short" .. math.random(1, 2) .. ".wav", 75, 100)

    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetNormal(Vector(0, 0, 1))
    effectdata:SetMagnitude(1)
    effectdata:SetScale(1)
    util.Effect("ElectricSpark", effectdata)

    local steamEffect = EffectData()
    steamEffect:SetOrigin(pos)
    steamEffect:SetNormal(Vector(0, 0, 1))
    steamEffect:SetMagnitude(2)
    steamEffect:SetScale(1.5)
    util.Effect("SteamJet", steamEffect)

    if IsValid(defuser) and defuser:IsPlayer() then
        defuser:ChatPrint("[Mine] Dioxis-Mine erfolgreich entschärft!")
    end

    timer.Simple(0.5, function()
        if IsValid(self) then self:Remove() end
    end)
end

function ENT:SetupDataTables()
end

function ENT:Think()
    self:NextThink(CurTime() + 1)
    return true
end
