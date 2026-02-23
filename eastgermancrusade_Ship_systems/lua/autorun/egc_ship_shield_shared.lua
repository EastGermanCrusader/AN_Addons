--[[
    EGC Ship Shield System - Shared
    Datenstrukturen, Hilfsfunktionen, Geometrie-Checks
]]

if SERVER then
    AddCSLuaFile()
end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Generators = EGC_SHIP.Generators or {}  -- Alle aktiven Generatoren

-- ============================================================================
-- DATENSTRUKTUREN
-- ============================================================================

-- Erstellt Generator-Daten
function EGC_SHIP.CreateGeneratorData(entIndex)
    return {
        entIndex = entIndex,
        shieldPercent = 100,
        powerLevel = EGC_SHIP.Config.MaxPowerOutput,
        active = true,
        recharging = false,
        rechargeTime = 0,
        
        -- Hull-Daten (Außenhülle)
        hullPoints = {},           -- Orientierungspunkte vom Spieler
        hullMesh = {},             -- Generiertes Mesh nach Scan
        hullCenter = Vector(0,0,0),
        hullRadius = 0,
        
        -- Gate-Daten (Durchlass-Zonen)
        gates = {},                -- Liste von Gates: { points = {}, mesh = {}, center = Vector }
        
        -- Sektor-Info
        sectorName = "default",
        sectorType = "custom",
    }
end

-- Erstellt Gate-Daten
function EGC_SHIP.CreateGateData()
    return {
        points = {},               -- 4 Eckpunkte des Gates
        mesh = {},                 -- Generiertes Mesh
        center = Vector(0,0,0),
        normal = Vector(0,0,1),
        active = true,
    }
end

-- ============================================================================
-- GEOMETRIE-HILFSFUNKTIONEN
-- ============================================================================

-- Berechnet Zentrum und Radius einer Punktwolke
function EGC_SHIP.CalculateBounds(points)
    if #points == 0 then return Vector(0,0,0), 0 end
    
    local center = Vector(0,0,0)
    for _, p in ipairs(points) do
        center = center + p
    end
    center = center / #points
    
    local maxDist = 0
    for _, p in ipairs(points) do
        local dist = center:Distance(p)
        if dist > maxDist then maxDist = dist end
    end
    
    return center, maxDist
end

-- Berechnet Bounding-Box
function EGC_SHIP.CalculateBoundingBox(points)
    if #points == 0 then 
        return Vector(0,0,0), Vector(0,0,0) 
    end
    
    local mins = Vector(math.huge, math.huge, math.huge)
    local maxs = Vector(-math.huge, -math.huge, -math.huge)
    
    for _, p in ipairs(points) do
        mins.x = math.min(mins.x, p.x)
        mins.y = math.min(mins.y, p.y)
        mins.z = math.min(mins.z, p.z)
        maxs.x = math.max(maxs.x, p.x)
        maxs.y = math.max(maxs.y, p.y)
        maxs.z = math.max(maxs.z, p.z)
    end
    
    return mins, maxs
end

-- Polygon-Normale berechnen
function EGC_SHIP.PolygonNormal(vertices)
    if #vertices < 3 then return Vector(0, 0, 1) end
    local v1, v2, v3 = vertices[1], vertices[2], vertices[3]
    local e1 = v2 - v1
    local e2 = v3 - v1
    return e1:Cross(e2):GetNormalized()
end

-- Punkt in 2D-Polygon (Ray-Casting)
function EGC_SHIP.PointInPolygon2D(verts2d, px, py)
    local n = #verts2d
    if n < 3 then return false end
    
    local inside = false
    local j = n
    
    for i = 1, n do
        local xi, yi = verts2d[i][1], verts2d[i][2]
        local xj, yj = verts2d[j][1], verts2d[j][2]
        
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

-- Punkt in 3D-Polygon (projiziert auf Ebene)
function EGC_SHIP.PointInPolygon3D(vertices, point)
    if #vertices < 3 then return false end
    
    local n = EGC_SHIP.PolygonNormal(vertices)
    local center = Vector(0, 0, 0)
    for _, v in ipairs(vertices) do center = center + v end
    center = center / #vertices
    
    -- Koordinatensystem auf Polygon-Ebene
    local right = n:Cross(Vector(0, 0, 1))
    if right:LengthSqr() < 0.01 then right = n:Cross(Vector(0, 1, 0)) end
    right:Normalize()
    local up = right:Cross(n):GetNormalized()
    
    -- Vertices zu 2D projizieren
    local verts2d = {}
    for _, v in ipairs(vertices) do
        local d = v - center
        table.insert(verts2d, { d:Dot(right), d:Dot(up) })
    end
    
    -- Punkt projizieren
    local pd = point - center
    local px, py = pd:Dot(right), pd:Dot(up)
    
    return EGC_SHIP.PointInPolygon2D(verts2d, px, py)
end

-- Ray-Triangle Intersection (Möller-Trumbore)
function EGC_SHIP.RayTriangleIntersect(origin, dir, v0, v1, v2)
    local e1 = v1 - v0
    local e2 = v2 - v0
    local h = dir:Cross(e2)
    local a = e1:Dot(h)
    
    if math.abs(a) < 1e-6 then return nil end
    
    local f = 1 / a
    local s = origin - v0
    local u = f * s:Dot(h)
    
    if u < 0 or u > 1 then return nil end
    
    local q = s:Cross(e1)
    local v = f * dir:Dot(q)
    
    if v < 0 or u + v > 1 then return nil end
    
    local t = f * e2:Dot(q)
    if t > 1e-6 then return t end
    
    return nil
end

-- Ray-Polygon Intersection (Triangle-Fan)
function EGC_SHIP.RayPolygonIntersect(origin, dir, vertices)
    if #vertices < 3 then return nil end
    
    local bestT = nil
    for i = 2, #vertices - 1 do
        local t = EGC_SHIP.RayTriangleIntersect(origin, dir, vertices[1], vertices[i], vertices[i + 1])
        if t and (not bestT or t < bestT) then 
            bestT = t 
        end
    end
    
    return bestT
end

-- ============================================================================
-- GATE-CHECKS
-- ============================================================================

-- Prüft ob ein Punkt innerhalb eines Gates liegt
function EGC_SHIP.IsPointInGate(point, gate)
    if not gate or not gate.mesh or #gate.mesh < 3 then return false end
    
    -- Schnelle Distanz-Prüfung zuerst
    if gate.center and point:Distance(gate.center) > 1000 then
        return false
    end
    
    return EGC_SHIP.PointInPolygon3D(gate.mesh, point)
end

-- Prüft ob ein Punkt in irgendeinem Gate eines Generators liegt
function EGC_SHIP.IsPointInAnyGate(point, generatorData)
    if not generatorData or not generatorData.gates then return false end
    
    for _, gate in ipairs(generatorData.gates) do
        if gate.active and EGC_SHIP.IsPointInGate(point, gate) then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- SCHILD-CHECKS
-- ============================================================================

-- Prüft ob ein Ray das Schild trifft (aber nicht durch ein Gate geht)
function EGC_SHIP.RayHitsShield(origin, dir, generatorData, maxDist)
    if not generatorData or not generatorData.hullMesh or #generatorData.hullMesh < 3 then
        return nil
    end
    
    if not generatorData.active or generatorData.shieldPercent <= 0 then
        return nil
    end
    
    maxDist = maxDist or 50000
    
    -- Schnelle Bounding-Check
    if generatorData.hullCenter then
        local toCenter = generatorData.hullCenter - origin
        local distToCenter = toCenter:Length()
        if distToCenter > (generatorData.hullRadius or 5000) + maxDist then
            return nil
        end
    end
    
    -- Ray gegen Hull-Mesh testen
    local t = EGC_SHIP.RayPolygonIntersect(origin, dir, generatorData.hullMesh)
    
    if t and t <= maxDist then
        local hitPoint = origin + dir * t
        
        -- Prüfe ob Treffer durch ein Gate geht
        if EGC_SHIP.IsPointInAnyGate(hitPoint, generatorData) then
            return nil  -- Durch Gate, kein Schild-Treffer
        end
        
        return {
            distance = t,
            hitPos = hitPoint,
            generatorData = generatorData,
        }
    end
    
    return nil
end

-- Findet den nächsten Schild-Treffer über alle Generatoren
function EGC_SHIP.FindShieldHit(origin, dir, maxDist)
    maxDist = maxDist or 50000
    local bestHit = nil
    
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        local hit = EGC_SHIP.RayHitsShield(origin, dir, genData, maxDist)
        if hit then
            if not bestHit or hit.distance < bestHit.distance then
                bestHit = hit
                bestHit.entIndex = entIndex
            end
        end
    end
    
    return bestHit
end

-- ============================================================================
-- ENTITY-KOLLISION
-- ============================================================================

-- Prüft ob eine Entity durch das Schild blockiert wird
function EGC_SHIP.ShouldBlockEntity(ent, generatorData)
    if not IsValid(ent) then return false end
    if not generatorData or not generatorData.active then return false end
    if generatorData.shieldPercent <= 0 then return false end
    
    local pos = ent:GetPos()
    local cfg = EGC_SHIP.Config
    
    -- Spieler durch Gates lassen
    if ent:IsPlayer() and cfg.GateAllowPlayers then
        if EGC_SHIP.IsPointInAnyGate(pos, generatorData) then
            return false
        end
    end
    
    -- Fahrzeuge durch Gates lassen
    if ent:IsVehicle() and cfg.GateAllowVehicles then
        if EGC_SHIP.IsPointInAnyGate(pos, generatorData) then
            return false
        end
    end
    
    -- Props durch Gates lassen
    if cfg.GateAllowProps then
        local class = ent:GetClass()
        if class == "prop_physics" or class == "prop_physics_multiplayer" then
            if EGC_SHIP.IsPointInAnyGate(pos, generatorData) then
                return false
            end
        end
    end
    
    -- Ansonsten prüfen ob Entity im Schild-Bereich
    -- (vereinfachte Prüfung: ist Entity innerhalb des Hull-Radius?)
    if generatorData.hullCenter then
        local dist = pos:Distance(generatorData.hullCenter)
        if dist < (generatorData.hullRadius or 5000) then
            -- Entity ist innerhalb, nicht blockieren
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- VALIDIERUNG
-- ============================================================================

function EGC_SHIP.ValidateVector(v)
    if not isvector(v) then return false end
    if v.x ~= v.x or v.y ~= v.y or v.z ~= v.z then return false end  -- NaN check
    if v:Length() > 50000 then return false end
    return true
end

-- ============================================================================
-- MAP-KEY FÜR PERSISTENZ
-- ============================================================================

function EGC_SHIP.GetMapKey()
    return game.GetMap():lower():gsub("[^%w]", "_")
end
