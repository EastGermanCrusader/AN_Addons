-- EastGermanCrusader SAM System - Radar
-- Erfasst Fahrzeuge im Bereich

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Radar"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Erfasst Fahrzeuge im Bereich"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.RenderGroup = RENDERGROUP_OPAQUE

-- Modell
ENT.Model = "models/props_rooftop/roof_dish001.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Active")
    self:NetworkVar("Bool", 1, "Destroyed")
    
    if SERVER then
        self:SetActive(true)
        self:SetDestroyed(false)
    end
end
