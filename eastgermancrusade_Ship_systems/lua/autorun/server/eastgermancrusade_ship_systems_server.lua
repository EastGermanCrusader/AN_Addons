--[[
    eastgermancrusade_Ship_systems – Server
    Persistenz (JSON), Schadenslogik, Power-Distribution, Breach
]]

if not SERVER then return end

if not EGC_SHIP or not EGC_SHIP.Config then
    return
end

local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end
local CFG = EGC_SHIP.Config
local dataPath = CFG.DataFolder .. "/"
local mapKey = EGC_SHIP.GetMapKey and EGC_SHIP.GetMapKey() or game.GetMap():lower():gsub("[^%w]", "_")

-- ============================================================================
-- PERSISTENZ
-- ============================================================================

function EGC_SHIP.SaveToJSON()
    local data = {
        map = game.GetMap(),
        sectors = {},
        meshes = {},
    }
    for id, sector in pairs(EGC_SHIP.Sectors) do
        data.sectors[id] = {
            id = sector.id,
            name = sector.name,
            sectorType = sector.sectorType,
            shieldPercent = sector.shieldPercent,
            hullPercent = sector.hullPercent,
            powerAllocated = sector.powerAllocated,
            breached = sector.breached,
            hullMeshes = sector.hullMeshes,
            gateMeshes = sector.gateMeshes,
        }
    end
    for meshId, mesh in pairs(EGC_SHIP.Meshes) do
        -- Speichern der Kontrollpunkte (Form); an Map angepasste vertices werden beim Laden neu berechnet
        local cp = mesh.controlPoints or mesh.vertices
        data.meshes[meshId] = {
            type = mesh.type,
            sectorId = mesh.sectorId,
            controlPoints = cp,
            breached = mesh.breached,
        }
    end
    local json = util.TableToJSON(data, true)
    if not file.IsDir(CFG.DataFolder, "DATA") then
        file.CreateDir(CFG.DataFolder, "DATA")
    end
    local fname = dataPath .. mapKey .. "_" .. CFG.MapDataFile
    file.Write(fname, json)
    return true
end

function EGC_SHIP.LoadFromJSON()
    local fname = dataPath .. mapKey .. "_" .. CFG.MapDataFile
    if not file.Exists(fname, "DATA") then return false end
    local raw = file.Read(fname, "DATA")
    if not raw or raw == "" then return false end
    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or not data then return false end
    EGC_SHIP.Sectors = {}
    EGC_SHIP.Meshes = {}
    for id, t in pairs(data.sectors or {}) do
        EGC_SHIP.Sectors[id] = EGC_SHIP.CreateSectorData(t.id, t.name, t.sectorType)
        local s = EGC_SHIP.Sectors[id]
        s.shieldPercent = math.Clamp(tonumber(t.shieldPercent) or 100, 0, 100)
        s.hullPercent = math.Clamp(tonumber(t.hullPercent) or 100, 0, 100)
        s.powerAllocated = tonumber(t.powerAllocated) or 0
        s.breached = t.breached == true
        s.hullMeshes = t.hullMeshes or {}
        s.gateMeshes = t.gateMeshes or {}
    end
    for meshId, t in pairs(data.meshes or {}) do
        local controlPoints = t.controlPoints or t.vertices or {}
        local mesh = {
            type = t.type,
            sectorId = t.sectorId,
            controlPoints = controlPoints,
            vertices = EGC_SHIP.AdaptMeshVerticesToMap(controlPoints),
            breached = t.breached == true,
        }
        EGC_SHIP.Meshes[meshId] = mesh
    end
    return true
end

-- ============================================================================
-- POWER DISTRIBUTION
-- ============================================================================

function EGC_SHIP.GetTotalAllocatedPower()
    local total = 0
    for _, sector in pairs(EGC_SHIP.Sectors) do
        total = total + (sector.powerAllocated or 0)
    end
    return total
end

function EGC_SHIP.SetSectorPower(sectorId, power)
    local sector = EGC_SHIP.Sectors[sectorId]
    if not sector then return false end
    power = math.Clamp(power, 0, CFG.MaxPowerPerSector)
    local currentTotal = EGC_SHIP.GetTotalAllocatedPower()
    local newTotal = currentTotal - (sector.powerAllocated or 0) + power
    if newTotal > CFG.ReactorTotalOutput then
        power = math.max(0, sector.powerAllocated + (CFG.ReactorTotalOutput - currentTotal))
    end
    sector.powerAllocated = power
    sector.overload = (power / CFG.MaxPowerPerSector) > CFG.OverloadThreshold
    EGC_SHIP.BroadcastPowerState()
    return true
end

-- ============================================================================
-- SCHADEN & REGENERATION
-- ============================================================================

function EGC_SHIP.ApplyShieldDamage(sectorId, amount)
    local sector = EGC_SHIP.Sectors[sectorId]
    if not sector then return end
    sector.shieldPercent = math.Clamp((sector.shieldPercent or 100) - amount, 0, 100)
    if sector.shieldPercent <= CFG.GateBreachThreshold then
        for _, meshId in ipairs(sector.gateMeshes or {}) do
            local mesh = EGC_SHIP.Meshes[meshId]
            if mesh then mesh.breached = true end
        end
        sector.breached = true
        EGC_SHIP.BroadcastBreachState()
    end
    EGC_SHIP.BroadcastSectorDamage()
end

function EGC_SHIP.ApplyHullDamage(sectorId, amount)
    local sector = EGC_SHIP.Sectors[sectorId]
    if not sector then return end
    sector.hullPercent = math.Clamp((sector.hullPercent or 100) - amount, 0, 100)
    EGC_SHIP.BroadcastSectorDamage()
end

-- Wenn Schild > 0: Schaden geht an Schild. Wenn Schild = 0: Schaden an Hülle.
function EGC_SHIP.ApplyDamageToSector(sectorId, amount)
    local sector = EGC_SHIP.Sectors[sectorId]
    if not sector then return end
    if (sector.shieldPercent or 0) > 0 then
        EGC_SHIP.ApplyShieldDamage(sectorId, amount)
    else
        EGC_SHIP.ApplyHullDamage(sectorId, amount)
    end
end

-- Tick: Regeneration + Überlast-Schaden an Emittern
local nextTick = 0
hook.Add("Think", "EGC_Ship_ServerThink", function()
    if not _cfgOk() then return end
    if CurTime() < nextTick then return end
    nextTick = CurTime() + 0.5
    for id, sector in pairs(EGC_SHIP.Sectors) do
        local pwr = sector.powerAllocated or 0
        local regen = CFG.BaseRegenPerUnit * (pwr / CFG.MaxPowerPerSector) * 0.5
        sector.shieldPercent = math.Clamp((sector.shieldPercent or 0) + regen, 0, 100)
        if sector.overload and IsValid(sector.emitterEntity) then
            local dmg = DamageInfo()
            dmg:SetDamage(CFG.OverloadDamageRate * 0.5)
            dmg:SetAttacker(Entity(0))
            dmg:SetInflictor(Entity(0))
            sector.emitterEntity:TakeDamageInfo(dmg)
        end
    end
    EGC_SHIP.BroadcastSectorDamage()
end)

-- ============================================================================
-- BREACH REPARATUR
-- ============================================================================

function EGC_SHIP.RepairSectorBreach(sectorId, ply)
    local sector = EGC_SHIP.Sectors[sectorId]
    if not sector or not sector.breached then return false end
    sector.breached = false
    for _, meshId in ipairs(sector.gateMeshes or {}) do
        local mesh = EGC_SHIP.Meshes[meshId]
        if mesh then mesh.breached = false end
    end
    sector.shieldPercent = math.min(sector.shieldPercent + 10, 100)
    EGC_SHIP.BroadcastBreachState()
    EGC_SHIP.BroadcastSectorDamage()
    EGC_SHIP.SaveToJSON()
    return true
end

-- ============================================================================
-- TOOL: VERTEX / MESH HINZUFÜGEN (Sicherheit: eastgermancrusader_base)
-- ============================================================================

net.Receive("EGC_Ship_ToolVertex", function(len, ply)
    if not _cfgOk() then return end
    if not EGC_SHIP.CanUseAdminTool(ply) then return end
    local pos = net.ReadVector()
    local meshType = net.ReadString()
    local sectorId = net.ReadString()
    local meshId = net.ReadString()
    if meshId == "" then meshId = nil end
    if #(meshId or "") > (CFG.MaxMeshIdLen or 128) then return end
    if not EGC_SHIP.ValidateVertexPos(pos) then return end
    if meshType ~= "hull" and meshType ~= "gate" then return end
    if not EGC_SHIP.ValidateSectorId(sectorId) then return end
    EGC_SHIP.ToolAddVertex(ply, pos, meshType, sectorId, meshId)
end)

function EGC_SHIP.ToolAddVertex(ply, pos, meshType, sectorId, meshId)
    local sector = EGC_SHIP.Sectors[sectorId]
    if not sector then
        sector = EGC_SHIP.CreateSectorData(sectorId, "Sektor " .. sectorId, sectorId)
        EGC_SHIP.Sectors[sectorId] = sector
    end
    local list = (meshType == "gate") and sector.gateMeshes or sector.hullMeshes
    if not list then
        sector.hullMeshes = sector.hullMeshes or {}
        sector.gateMeshes = sector.gateMeshes or {}
        list = (meshType == "gate") and sector.gateMeshes or sector.hullMeshes
    end
    local mesh = meshId and EGC_SHIP.Meshes[meshId] or nil
    if not mesh then
        if #list >= (CFG.MaxMeshesPerSector or 8) then return end
        meshId = "mesh_" .. meshType .. "_" .. sectorId .. "_" .. (#list + 1) .. "_" .. os.time()
        mesh = EGC_SHIP.CreateMeshData(meshType, sectorId, { pos })
        EGC_SHIP.Meshes[meshId] = mesh
        table.insert(list, meshId)
        mesh.vertices = EGC_SHIP.AdaptMeshVerticesToMap(mesh.controlPoints)
    else
        if not mesh.controlPoints then mesh.controlPoints = mesh.vertices or {} end
        if #mesh.controlPoints >= (CFG.MaxVerticesPerMesh or 64) then return end
        table.insert(mesh.controlPoints, pos)
        mesh.vertices = EGC_SHIP.AdaptMeshVerticesToMap(mesh.controlPoints)
    end
    EGC_SHIP.SaveToJSON()
    EGC_SHIP.BroadcastShieldData()
end

net.Receive("EGC_Ship_ToolFinishMesh", function(len, ply)
    if not _cfgOk() then return end
    if not EGC_SHIP.CanUseAdminTool(ply) then return end
    local meshId = net.ReadString()
    if #(meshId or "") > (CFG.MaxMeshIdLen or 128) then return end
    EGC_SHIP.BroadcastShieldData()
end)

-- ============================================================================
-- POWER SLIDER (Brücken-Crew)
-- ============================================================================

net.Receive("EGC_Ship_PowerSlider", function(len, ply)
    if not _cfgOk() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sectorId = net.ReadString()
    local power = net.ReadFloat()
    if not EGC_SHIP.ValidateSectorId(sectorId) then return end
    if type(power) ~= "number" or power ~= power then return end -- NaN-Check
    power = math.Clamp(power, 0, (CFG.MaxPowerPerSector or 150) * 1.5)
    EGC_SHIP.SetSectorPower(sectorId, power)
end)

-- ============================================================================
-- REPARATUR (Techniker) – Berechtigung via Base: EGC_Base.CanRepairSector(ply)
-- ============================================================================

net.Receive("EGC_Ship_RepairSector", function(len, ply)
    if not _cfgOk() then return end
    if not EGC_SHIP.CanRepairSector(ply) then return end
    local sectorId = net.ReadString()
    if not EGC_SHIP.ValidateSectorId(sectorId) then return end
    EGC_SHIP.RepairSectorBreach(sectorId, ply)
end)

-- ============================================================================
-- BROADCAST AN CLIENTEN
-- ============================================================================

function EGC_SHIP.BroadcastShieldData()
    local data = {
        sectors = EGC_SHIP.Sectors,
        meshes = EGC_SHIP.Meshes,
    }
    local json = util.TableToJSON(data)
    local compressed = util.Compress(json)
    net.Start("EGC_Ship_ShieldData")
    net.WriteUInt(#compressed, 16)
    net.WriteData(compressed, #compressed)
    net.Broadcast()
end

function EGC_Ship_BroadcastPowerState()
    local t = {}
    for id, s in pairs(EGC_SHIP.Sectors or {}) do
        t[id] = { powerAllocated = s.powerAllocated, overload = s.overload }
    end
    net.Start("EGC_Ship_PowerState")
    net.WriteTable(t)
    net.Broadcast()
end
EGC_SHIP.BroadcastPowerState = EGC_Ship_BroadcastPowerState

function EGC_SHIP.BroadcastSectorDamage()
    local t = {}
    for id, s in pairs(EGC_SHIP.Sectors or {}) do
        t[id] = { shieldPercent = s.shieldPercent, hullPercent = s.hullPercent }
    end
    net.Start("EGC_Ship_SectorDamage")
    net.WriteTable(t)
    net.Broadcast()
end

function EGC_SHIP.BroadcastBreachState()
    local t = {}
    for id, s in pairs(EGC_SHIP.Sectors or {}) do
        t[id] = s.breached
    end
    net.Start("EGC_Ship_BreachState")
    net.WriteTable(t)
    net.Broadcast()
end

-- ============================================================================
-- PHYSISCHE KOLLISION: Ray vs. Polygon, Geschosse blockieren, Gate-Props
-- ============================================================================

-- Liefert alle Meshes, die aktuell Kollision haben (Schild aktiv; Gate nicht gebrochen)
function EGC_SHIP.GetActiveCollisionMeshes()
    local out = {}
    for meshId, mesh in pairs(EGC_SHIP.Meshes or {}) do
        local sector = EGC_SHIP.Sectors and EGC_SHIP.Sectors[mesh.sectorId]
        if not sector then else
            local shieldOk = (sector.shieldPercent or 0) > 0
            if mesh.type == "hull" then
                if shieldOk then
                    out[meshId] = { mesh = mesh, sectorId = mesh.sectorId }
                end
            elseif mesh.type == "gate" then
                if shieldOk and not mesh.breached and not sector.breached then
                    out[meshId] = { mesh = mesh, sectorId = mesh.sectorId }
                end
            end
        end
    end
    return out
end

-- Nächster Ray-Treffer auf aktiven Schilden: Rückgabe { sectorId, distance } oder nil
function EGC_SHIP.RayShieldHit(origin, dir, maxDist)
    maxDist = maxDist or (CFG.ShieldMaxTraceDist or 50000)
    local active = EGC_SHIP.GetActiveCollisionMeshes()
    local bestT = maxDist + 1
    local bestSectorId = nil
    for _, data in pairs(active) do
        local verts = EGC_SHIP.MeshVerticesAsVectors(data.mesh)
        if #verts >= 3 then
            local t = EGC_SHIP.RayPolygonIntersect(origin, dir, verts)
            if t and t > 0 and t < bestT then
                bestT = t
                bestSectorId = data.sectorId
            end
        end
    end
    if bestSectorId and bestT <= maxDist then
        return { sectorId = bestSectorId, distance = bestT }
    end
    return nil
end

-- Geschosse: an erstem Schild-Treffer blockieren und Sektor-Schaden anwenden
hook.Add("EntityFireBullets", "EGC_Ship_BlockBullets", function(ent, bullet)
    if not CFG.ShieldBlockBullets or not bullet or not bullet.Src or not bullet.Dir then return end
    local hit = EGC_SHIP.RayShieldHit(bullet.Src, bullet.Dir:GetNormalized(), CFG.ShieldMaxTraceDist)
    if not hit then return end
    local rawDmg = (bullet.Damage or 0) * (CFG.ShieldBulletDamageScale or 1)
    if rawDmg <= 0 then return end
    local sectorDmg = rawDmg * (CFG.ShieldSectorDamagePerPoint or 0.15)
    EGC_SHIP.ApplyDamageToSector(hit.sectorId, sectorDmg)
    return true -- Bullet unterdrücken
end)

-- Gate-Props: bei nicht gebrochenem Gate Entities aus dem Polygon rausdrücken
local gatePropNextThink = 0
hook.Add("Think", "EGC_Ship_GatePropPush", function()
    if not _cfgOk() then return end
    if not CFG.GateBlockProps or CurTime() < gatePropNextThink then return end
    gatePropNextThink = CurTime() + (CFG.GatePropThinkInterval or 0.15)
    local active = EGC_SHIP.GetActiveCollisionMeshes()
    for meshId, data in pairs(active) do
        if data.mesh.type ~= "gate" then else
            local verts = EGC_SHIP.MeshVerticesAsVectors(data.mesh)
            if #verts >= 3 then
                local n = EGC_SHIP.PolygonNormal(verts)
                local center = Vector(0, 0, 0)
                for _, v in ipairs(verts) do center = center + v end
                center = center / #verts
                local r = CFG.GatePropCheckRadius or 200
                local boxMin = center - Vector(r, r, r)
                local boxMax = center + Vector(r, r, r)
                for _, e in ipairs(ents.FindInBox(boxMin, boxMax)) do
                    if IsValid(e) and not e:IsPlayer() and e:IsSolid() then
                        local pos = e:GetPos()
                        if EGC_SHIP.PointInPolygon3D(verts, pos) then
                            local toPlane = (pos - center):Dot(n) * n
                            local outDir = -toPlane
                            if outDir:LengthSqr() < 1 then outDir = n end
                            outDir = outDir:GetNormalized()
                            local phys = e:GetPhysicsObject()
                            if IsValid(phys) then
                                phys:ApplyForceCenter(outDir * (CFG.GatePropPushForce or 800))
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- INIT & MAP LOAD
-- ============================================================================

hook.Add("Initialize", "EGC_Ship_LoadData", function()
    timer.Simple(1, function()
        if not _cfgOk() then return end
        EGC_SHIP.LoadFromJSON()
        EGC_SHIP.BroadcastShieldData()
        EGC_SHIP.BroadcastPowerState()
        EGC_SHIP.BroadcastSectorDamage()
        EGC_SHIP.BroadcastBreachState()
    end)
end)

hook.Add("ShutDown", "EGC_Ship_SaveData", function()
    if not _cfgOk() then return end
    EGC_SHIP.SaveToJSON()
end)

net.Receive("EGC_Ship_RequestFullState", function(len, ply)
    if not _cfgOk() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    EGC_SHIP.BroadcastShieldData()
    EGC_SHIP.BroadcastPowerState()
    EGC_SHIP.BroadcastSectorDamage()
    EGC_SHIP.BroadcastBreachState()
end)
