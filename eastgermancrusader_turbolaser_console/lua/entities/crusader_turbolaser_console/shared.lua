-- eastgermancrusader_base/lua/entities/crusader_turbolaser_console/shared.lua

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Turbolaser Konsole"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Instructions = "Benutzen (E) um verfügbare Turbolaser anzuzeigen und zu steuern."
ENT.Purpose = "Ermöglicht die Fernsteuerung von Turbolasern auf der Karte."

-- Netzwerk-Strings für die Kommunikation
function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "InUse")
    self:NetworkVar("Entity", 0, "CurrentUser")
end
