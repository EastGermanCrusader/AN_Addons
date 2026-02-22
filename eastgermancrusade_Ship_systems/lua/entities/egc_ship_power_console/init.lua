if SERVER and AddCSLuaFile then
    AddCSLuaFile("cl_init.lua")
    AddCSLuaFile("shared.lua")
end
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_lab/monitor01b.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
end
