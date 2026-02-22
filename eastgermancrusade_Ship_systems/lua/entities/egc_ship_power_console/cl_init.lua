include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_lab/monitor01b.mdl")
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if EGC_SHIP and EGC_SHIP.OpenPowerTerminal then
        EGC_SHIP.OpenPowerTerminal()
    end
end

function ENT:Draw()
    self:DrawModel()
end
