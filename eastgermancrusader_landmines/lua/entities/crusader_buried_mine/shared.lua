ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Vergrabene Landmine"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Instructions = "Unsichtbare Proximity-Landmine."
ENT.Purpose = "Explodiert bei Annäherung (Halbkugel nach oben)."

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsDefusing")
    self:NetworkVar("Int", 0, "TimeRemaining")
end