--[[
    EGC Zone Barrier - Shared
    Unsichtbare physische Barriere für eine Damage-Zone (Polygon).
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Zonen-Barriere"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Purpose = "Physische Barriere für Damage-Zone (Projektile/Props prallen ab)"
ENT.Instructions = "Nur aktiv wenn Zone Schild-HP > 0 hat; bei 0 Schild wird Barriere entfernt (nur Hülle als Hitbox)"

ENT.Spawnable = false
ENT.AdminOnly = true

ENT.RenderGroup = RENDERGROUP_OTHER
