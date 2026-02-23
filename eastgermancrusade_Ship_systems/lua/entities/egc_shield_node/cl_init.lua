--[[
    EGC Shield Node - Client
    Kleine sichtbare Markierung (blaue Kugel/Box) für die Eckpunkte.
]]

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end
