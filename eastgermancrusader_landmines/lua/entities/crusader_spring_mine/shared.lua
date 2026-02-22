ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Spring-Splittermine"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Instructions = "Vergrabene Spring-Splittermine."
ENT.Purpose = "Springt hoch und schießt Pistolenkugeln in alle Richtungen."

-- Netzwerk-Variablen für Client-Synchronisation
function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsVisible")
    self:NetworkVar("Bool", 1, "IsDefusing")
    self:NetworkVar("Int", 0, "TimeRemaining")
end
