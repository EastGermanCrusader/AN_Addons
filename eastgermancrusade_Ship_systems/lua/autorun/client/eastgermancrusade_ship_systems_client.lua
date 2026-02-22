--[[
    eastgermancrusade_Ship_systems – Client
    Empfang von Schild-/Sektor-Daten, Power-State, Breach.
    Grundlage für Terminal-UI, Diagnose-Tool und visuelles Feedback.
]]

if not CLIENT then return end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.ClientSectors = EGC_SHIP.ClientSectors or {}
EGC_SHIP.ClientMeshes = EGC_SHIP.ClientMeshes or {}
EGC_SHIP.ClientPower = EGC_SHIP.ClientPower or {}
EGC_SHIP.ClientBreach = EGC_SHIP.ClientBreach or {}

local function vecFromTable(t)
    if not t then return Vector(0,0,0) end
    if type(t) == "Vector" then return t end
    if t.x and t.y and t.z then return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0) end
    return Vector(0,0,0)
end

local function normalizeMeshVertices(vertices)
    if not vertices then return {} end
    local out = {}
    for _, v in ipairs(vertices) do
        table.insert(out, vecFromTable(v))
    end
    return out
end

net.Receive("EGC_Ship_ShieldData", function()
    local n = net.ReadUInt(16)
    if n == 0 then return end
    local comp = net.ReadData(n)
    if not comp or #comp == 0 then return end
    local json = util.Decompress(comp)
    if not json then return end
    local ok, data = pcall(util.JSONToTable, json)
    if not ok or not data then return end
    EGC_SHIP.ClientSectors = {}
    EGC_SHIP.ClientMeshes = {}
    for id, s in pairs(data.sectors or {}) do
        EGC_SHIP.ClientSectors[id] = {
            id = s.id,
            name = s.name or ("Sektor " .. id),
            sectorType = s.sectorType or "custom",
            shieldPercent = tonumber(s.shieldPercent) or 100,
            hullPercent = tonumber(s.hullPercent) or 100,
            breached = s.breached == true,
            hullMeshes = s.hullMeshes or {},
            gateMeshes = s.gateMeshes or {},
        }
    end
    for meshId, m in pairs(data.meshes or {}) do
        EGC_SHIP.ClientMeshes[meshId] = {
            type = m.type,
            sectorId = m.sectorId,
            vertices = normalizeMeshVertices(m.vertices),
            breached = m.breached == true,
        }
    end
end)

net.Receive("EGC_Ship_PowerState", function()
    local t = net.ReadTable()
    EGC_SHIP.ClientPower = t or {}
end)

net.Receive("EGC_Ship_SectorDamage", function()
    local t = net.ReadTable()
    if not t then return end
    for id, p in pairs(t) do
        if EGC_SHIP.ClientSectors[id] then
            EGC_SHIP.ClientSectors[id].shieldPercent = p.shieldPercent
            EGC_SHIP.ClientSectors[id].hullPercent = p.hullPercent
        end
    end
end)

net.Receive("EGC_Ship_BreachState", function()
    EGC_SHIP.ClientBreach = net.ReadTable() or {}
    for id, breached in pairs(EGC_SHIP.ClientBreach) do
        if EGC_SHIP.ClientSectors[id] then
            EGC_SHIP.ClientSectors[id].breached = breached
        end
    end
    for _, mesh in pairs(EGC_SHIP.ClientMeshes or {}) do
        local sid = mesh.sectorId
        if EGC_SHIP.ClientBreach[sid] then
            mesh.breached = true
        end
    end
end)

-- Beim Spawn/Start: vollständigen State anfordern
hook.Add("InitPostEntity", "EGC_Ship_RequestState", function()
    timer.Simple(0.5, function()
        net.Start("EGC_Ship_RequestFullState")
        net.SendToServer()
    end)
end)

-- Power-Terminal öffnen (Brücke)
include("vgui/egc_ship_power_terminal.lua")
concommand.Add("egc_ship_power_terminal", function()
    EGC_SHIP.OpenPowerTerminal()
end)

local _cacheSchema = 2
timer.Create("EGC_Ship_ConfigRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC Ship Systems] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)
