--[[
    EGC Shield Node - Server
    Nur Position speichern; keine Physik.
]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:DrawShadow(false)
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetColor(Color(60, 200, 255))
end

-- Optional: Zuordnung zu einem Generator (für "Sektor aus Nodes" pro Generator)
function ENT:SetGenerator(generator)
    self.Generator = generator
end

function ENT:GetPosition()
    return self:GetPos()
end
