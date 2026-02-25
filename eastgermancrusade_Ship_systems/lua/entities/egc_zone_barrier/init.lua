--[[
    EGC Zone Barrier - Server
    Physische Barriere für eine Damage-Zone. Wird nur gespawnt, wenn die Zone Schild-HP > 0 hat.
    Schild weg → Barriere wird entfernt, Zone bleibt nur noch als Hitbox für Hüllen-Schaden.
]]

AddCSLuaFile("shared.lua")
include("shared.lua")

local ZONE_BARRIER_THICKNESS = 4  -- Einheiten Dicke der Kollisionsfläche (beidseitig je 2)

function ENT:Initialize()
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:DrawShadow(false)
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetNoDraw(true)
end

-- Vertices = Weltkoordinaten des Zonen-Polygons (mind. 3). Erstellt Kollision als dünnes Prisma.
function ENT:SetZoneVertices(vertices)
    if not vertices or #vertices < 3 then return false end

    local center = Vector(0, 0, 0)
    for _, v in ipairs(vertices) do center = center + v end
    center = center / #vertices
    self:SetPos(center)

    local n = EGC_SHIP and EGC_SHIP.PolygonNormal(vertices) or Vector(0, 0, 1)
    if n:LengthSqr() < 0.01 then n = Vector(0, 0, 1) end
    n = n:GetNormalized()
    local half = ZONE_BARRIER_THICKNESS * 0.5

    -- Dreieck-Fan: (v1, v2, v3), (v1, v3, v4), ... – pro Dreieck ein Prisma (6 Ecken) = 1 Convex, Zone in der Mitte
    local convexes = {}
    for i = 2, #vertices - 1 do
        local a, b, c = vertices[1], vertices[i], vertices[i + 1]
        local v1 = (a - n * half) - center
        local v2 = (b - n * half) - center
        local v3 = (c - n * half) - center
        local v4 = (a + n * half) - center
        local v5 = (b + n * half) - center
        local v6 = (c + n * half) - center
        table.insert(convexes, { v1, v2, v3, v4, v5, v6 })
    end

    if #convexes == 0 then return false end

    self:PhysicsInitMultiConvex(convexes)
    self:EnableCustomCollisions(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    return true
end

function ENT:OnTakeDamage()
    return true
end
