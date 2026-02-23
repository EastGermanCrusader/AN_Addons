-- crusader_asservatenschrank/lua/entities/crusader_asservatenschrank/shared.lua

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Asservatenschrank"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Instructions = "Drücke E um Waffen abzugeben/abzuholen"
ENT.Purpose = "Sichere Waffenabgabe - behält nur die Hände"

-- Waffen die NICHT entfernt werden sollen
ENT.AllowedWeapons = {
    ["mvp_perfecthands"] = true,
}
