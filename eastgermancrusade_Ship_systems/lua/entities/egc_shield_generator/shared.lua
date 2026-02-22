--[[
    EGC Shield Generator Entity - Shared
    Die physische Quelle des Schilds
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Schildgenerator"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Purpose = "Generiert ein Schutzschild um das Schiff"
ENT.Instructions = "Platzieren und mit Tool konfigurieren"

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.RenderGroup = RENDERGROUP_BOTH

-- Netzwerk-Variablen
function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "ShieldPercent")
    self:NetworkVar("Float", 1, "PowerLevel")
    self:NetworkVar("Bool", 0, "ShieldActive")
    self:NetworkVar("Bool", 1, "IsRecharging")
    self:NetworkVar("String", 0, "SectorName")
end
