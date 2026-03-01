-- eastgermancrusader_misc/lua/entities/crusader_anaxes_console/init.lua

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("Crusader_AnaxesConsole_Open")

function ENT:Initialize()
    self:SetModel("models/reizer_props/alysseum_project/console/security_console_01/security_console_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    net.Start("Crusader_AnaxesConsole_Open")
    net.Send(activator)
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
