--[[
    EGC Shield Node - Shared
    Kleines Hilfs-Entity für Hull-Wrapping: Eckpunkt eines Schild-Segments.
    Das Tool setzt diese an die Hülle; der Mesh-Generator liest die Positionen
    und erstellt daraus ein egc_shield_sector (PhysicsInitMultiConvex).
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Schild-Node (Eckpunkt)"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Purpose = "Eckpunkt für Schild-Sektor (Hull-Wrapping)"
ENT.Instructions = "Mit Schild-Tool an der Hülle platzieren, dann Sektor generieren"

ENT.Spawnable = false
ENT.AdminOnly = true

ENT.RenderGroup = RENDERGROUP_BOTH
