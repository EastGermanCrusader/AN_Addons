--[[
    EGC Shield Sector - Server
    Erstellt aus Punkten eine MultiConvex-Kollision, fängt Projektile ab.
]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:DrawShadow(false)
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetNoDraw(true)
end

-- Poly-Shield: Mesh aus Dreiecken (ein Convex pro Tri, exakte Kanten)
-- triangles = { {v1,v2,v3}, {v4,v5,v6}, ... } in Weltkoordinaten
function ENT:SetMeshTriangles(triangles)
    if not triangles or #triangles == 0 then return false end

    local center = Vector(0, 0, 0)
    local count = 0
    for _, tri in ipairs(triangles) do
        for _, v in ipairs(tri) do
            center = center + v
            count = count + 1
        end
    end
    if count == 0 then return false end
    center = center / count

    self:SetPos(center)

    local convexes = {}
    for _, tri in ipairs(triangles) do
        if #tri >= 3 then
            table.insert(convexes, {
                tri[1] - center,
                tri[2] - center,
                tri[3] - center,
            })
        end
    end
    if #convexes == 0 then return false end

    self:PhysicsInitMultiConvex(convexes)
    self:EnableCustomCollisions(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    self.Triangles = triangles
    self:SendMeshToClients()
    return true
end

function ENT:SendMeshToClients()
    if not self.Triangles or #self.Triangles == 0 then return end
    net.Start("EGC_Shield_SectorMesh")
    net.WriteUInt(self:EntIndex(), 16)
    net.WriteUInt(#self.Triangles, 16)
    for _, tri in ipairs(self.Triangles) do
        if #tri >= 3 then
            net.WriteVector(tri[1])
            net.WriteVector(tri[2])
            net.WriteVector(tri[3])
        end
    end
    net.Broadcast()
end

-- Rückwärtskompatibel: ein Prisma aus Punkten (ein Convex)
function ENT:GenerateFromPoints(points)
    if not points or #points < 4 then
        print("[EGC Shield] Mindestens 4 Punkte nötig für Prisma!")
        return false
    end

    local center = Vector(0, 0, 0)
    for _, p in ipairs(points) do center = center + p end
    center = center / #points
    self:SetPos(center)

    local localPoints = {}
    for _, p in ipairs(points) do table.insert(localPoints, p - center) end

    self:PhysicsInitMultiConvex({ localPoints })
    self:EnableCustomCollisions(true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
    return true
end

-- Verknüpft diesen Sektor mit einem Schildgenerator (für Schaden/Logik)
function ENT:SetGenerator(generator)
    self.Generator = generator
end

function ENT:OnTakeDamage(dmg)
    local hitPos = dmg:GetDamagePosition()
    local hitNormal = dmg:GetDamageNormal()

    -- Visueller Effekt am Einschlagsort
    local effect = EffectData()
    effect:SetOrigin(hitPos)
    effect:SetNormal(hitNormal)
    effect:SetScale(0.5)
    util.Effect("AR2Impact", effect)

    -- Schaden an Generator weiterleiten
    if IsValid(self.Generator) and self.Generator.ApplyShieldDamage then
        self.Generator:ApplyShieldDamage(dmg:GetDamage(), dmg:GetDamageType())
    end

    -- Keinen physischen Schaden am Sektor selbst
    return true
end
