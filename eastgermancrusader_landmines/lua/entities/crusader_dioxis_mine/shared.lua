ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Dioxis-Mine"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Instructions = "Vergrabene Dioxis/Giftgas-Mine."
ENT.Purpose = "Explodiert bei Annäherung und setzt Chlorgas frei (gb5_proj_howitzer_shell_cl)."

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsDefusing")
    self:NetworkVar("Int", 0, "TimeRemaining")
end
