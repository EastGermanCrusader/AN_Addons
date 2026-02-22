--[[
    eastgermancrusade_Ship_systems – Shared
    Polygon-Mesh-Datenmodell, Sektor-Definitionen, Hilfsfunktionen
]]

if SERVER then
    AddCSLuaFile()
end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Sectors = EGC_SHIP.Sectors or {}
EGC_SHIP.Meshes = EGC_SHIP.Meshes or {}

-- Mesh-Typ: "hull" = Hüllenschutz, "gate" = Hangar-Barriere (kollabierbar)
-- controlPoints = vom User gesetzte Punkte (Form); vertices = an Map angepasst (wird serverseitig berechnet)
function EGC_SHIP.CreateMeshData(meshType, sectorId, controlPoints)
    controlPoints = controlPoints or {}
    return {
        type = meshType,
        sectorId = sectorId,
        controlPoints = controlPoints,
        vertices = {},  -- wird serverseitig aus controlPoints via AdaptMeshVerticesToMap gefüllt
        breached = false,
    }
end

-- ============================================================================
-- NAVMESH-ÄHNLICH: Kontrollpunkte → Kanten entlang der Map
-- Nur auf Server aufrufen (util.TraceLine gegen Welt). Liefert angepasste Vertex-Liste.
-- ============================================================================
function EGC_SHIP.AdaptMeshVerticesToMap(controlPoints)
    local cfg = EGC_SHIP.Config
    local stepSize = (cfg and cfg.MeshAdaptStepSize) or 40
    local traceDist = (cfg and cfg.MeshAdaptTraceDist) or 500
    local verts = EGC_SHIP.MeshVerticesAsVectors({ vertices = controlPoints })
    if #verts < 3 then return verts end

    local up = Vector(0, 0, 1)
    local result = {}
    local mask = MASK_SOLID

    for i = 1, #verts do
        local a = verts[i]
        local b = verts[(i % #verts) + 1]
        local len = a:Distance(b)
        local nSteps = math.max(1, math.floor(len / stepSize))
        for k = 0, nSteps - 1 do
            local t = k / nSteps
            local p = a + (b - a) * t
            local tr = util.TraceLine({
                start = p + up * traceDist,
                endpos = p - up * traceDist,
                mask = mask,
            })
            if tr and tr.Hit then
                table.insert(result, tr.HitPos)
            else
                table.insert(result, p)
            end
        end
    end
    return result
end

-- Sektor: logische Gruppe (Bug, Heck, Hangar …)
function EGC_SHIP.CreateSectorData(id, name, sectorType)
    return {
        id = id,
        name = name or ("Sektor " .. id),
        sectorType = sectorType or "custom",
        shieldPercent = 100,
        hullPercent = 100,
        powerAllocated = 0,      -- zugewiesene Energie (0 .. Config.MaxPowerPerSector)
        overload = false,
        breached = false,        -- Gate gebrochen
        hullMeshes = {},
        gateMeshes = {},
        emitterEntity = nil,     -- Server: Entity-Referenz für Emitter-Schaden
    }
end

-- Prüft ob ein Punkt in einem konvexen Polygon (2D-Projektion auf Ebene) liegt
function EGC_SHIP.PointInConvexPolygon(vertices, point, normal)
    if #vertices < 3 then return false end
    normal = normal or EGC_SHIP.PolygonNormal(vertices)
    for i = 1, #vertices do
        local a = vertices[i]
        local b = vertices[(i % #vertices) + 1]
        if type(a) == "table" and a.x then a = Vector(a.x, a.y, a.z) end
        if type(b) == "table" and b.x then b = Vector(b.x, b.y, b.z) end
        local edge = b - a
        local toPoint = point - a
        if edge:Cross(toPoint):Dot(normal) < -1e-6 then
            return false
        end
    end
    return true
end

-- Grobe Flächennormale aus ersten drei Vertices
function EGC_SHIP.PolygonNormal(vertices)
    if #vertices < 3 then return Vector(0, 0, 1) end
    local v1, v2, v3 = vertices[1], vertices[2], vertices[3]
    if type(v1) == "table" and v1.x then v1 = Vector(v1.x, v1.y, v1.z) end
    if type(v2) == "table" and v2.x then v2 = Vector(v2.x, v2.y, v2.z) end
    if type(v3) == "table" and v3.x then v3 = Vector(v3.x, v3.y, v3.z) end
    local e1 = v2 - v1
    local e2 = v3 - v1
    return e1:Cross(e2):GetNormalized()
end

-- Vertex-Liste zu Vector-Liste (für aus JSON geladene Meshes)
function EGC_SHIP.MeshVerticesAsVectors(mesh)
    if not mesh or not mesh.vertices then return {} end
    local out = {}
    for _, v in ipairs(mesh.vertices) do
        if type(v) == "Vector" then
            table.insert(out, v)
        elseif type(v) == "table" and v.x ~= nil then
            table.insert(out, Vector(tonumber(v.x) or 0, tonumber(v.y) or 0, tonumber(v.z) or 0))
        end
    end
    return out
end

-- ============================================================================
-- RAY–TRIANGEL (für angepasste/nicht-ebene Polygone)
-- ============================================================================
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

-- ============================================================================
-- RAY–POLYGON für Schild-Treffererkennung (unterstützt angepasste/nicht-ebene Meshes)
-- Ray: origin + t*dir. Liefert t (Distanz) oder nil.
-- ============================================================================
function EGC_SHIP.RayPolygonIntersect(rayOrigin, rayDir, vertices)
    local verts = type(vertices[1]) == "Vector" and vertices or EGC_SHIP.MeshVerticesAsVectors({ vertices = vertices })
    if #verts < 3 then return nil end
    -- Dreiecks-Fan von v1 aus; funktioniert für eben und angepasst
    local bestT = nil
    for i = 2, #verts - 1 do
        local t = EGC_SHIP.RayTriangleIntersect(rayOrigin, rayDir, verts[1], verts[i], verts[i + 1])
        if t and (not bestT or t < bestT) then bestT = t end
    end
    return bestT
end

-- 2D-Punkt-in-Polygon (Ray-Cast, beliebige Polygone)
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

-- Punkt in 3D-Polygon (projiziert auf Best-Fit-Ebene; für angepasste Meshes)
function EGC_SHIP.PointInPolygon3D(vertices, point)
    local verts = type(vertices[1]) == "Vector" and vertices or EGC_SHIP.MeshVerticesAsVectors({ vertices = vertices })
    if #verts < 3 then return false end
    local n = EGC_SHIP.PolygonNormal(verts)
    local center = Vector(0, 0, 0)
    for _, v in ipairs(verts) do center = center + v end
    center = center / #verts
    local right = n:Cross(Vector(0, 0, 1))
    if right:LengthSqr() < 0.01 then right = n:Cross(Vector(0, 1, 0)) end
    right:Normalize()
    local up = right:Cross(n):GetNormalized()
    local verts2d = {}
    for _, v in ipairs(verts) do
        local d = v - center
        table.insert(verts2d, { d:Dot(right), d:Dot(up) })
    end
    local pd = point - center
    local px, py = pd:Dot(right), pd:Dot(up)
    return EGC_SHIP.PointInPolygon2D(verts2d, px, py)
end

-- Eindeutige Sektor-IDs pro Map (für Persistenz)
function EGC_SHIP.GetMapKey()
    return game.GetMap():lower():gsub("[^%w]", "_")
end

-- ============================================================================
-- SICHERHEIT – Anbindung eastgermancrusader_base
-- Nutzt EGC_Base.CanUseAdminTool(ply) / EGC_Base.CanRepairSector(ply) falls
-- die Base diese API bereitstellt; sonst Fallback (IsAdmin / immer erlauben).
-- ============================================================================

function EGC_SHIP.CanUseAdminTool(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if EGC_Base and type(EGC_Base.CanUseAdminTool) == "function" then
        return EGC_Base.CanUseAdminTool(ply) == true
    end
    return ply:IsAdmin()
end

function EGC_SHIP.CanRepairSector(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if EGC_Base and type(EGC_Base.CanRepairSector) == "function" then
        return EGC_Base.CanRepairSector(ply) == true
    end
    return ply:IsAdmin()
end

function EGC_SHIP.ValidateSectorId(sectorId)
    local cfg = EGC_SHIP.Config
    if type(sectorId) ~= "string" or #sectorId == 0 or #sectorId > (cfg.MaxSectorIdLen or 32) then
        return false
    end
    return (cfg.AllowedSectorIds and cfg.AllowedSectorIds[sectorId]) == true
end

function EGC_SHIP.ValidateVertexPos(pos)
    if not isvector(pos) then return false end
    local maxD = (EGC_SHIP.Config and EGC_SHIP.Config.MaxVertexDistance) or 50000
    return pos:Length() <= maxD and pos.x == pos.x and pos.y == pos.y and pos.z == pos.z
end
