--[[
    EGC Ship Shield System - Client Autorun
    Initialisierung und globale Client-Hooks
]]

if not CLIENT then return end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Generators = EGC_SHIP.Generators or {}
EGC_SHIP.DamageZones = EGC_SHIP.DamageZones or {}
EGC_SHIP._sectorMeshes = EGC_SHIP._sectorMeshes or {}  -- [entIndex] = { {v1,v2,v3}, ... }

net.Receive("EGC_DamageZones_FullSync", function()
    local zones = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        local name = net.ReadString()
        local groupId = net.ReadString()
        local shieldHP = net.ReadFloat()
        local hullHP = net.ReadFloat()
        local numVerts = net.ReadUInt(16)
        local vertices = {}
        for j = 1, numVerts do
            table.insert(vertices, net.ReadVector())
        end
        table.insert(zones, {
            name = name,
            groupId = groupId,
            shieldHP = shieldHP,
            hullHP = hullHP,
            vertices = vertices,
        })
    end
    EGC_SHIP.DamageZones = zones
    -- Zone-Konfig-Panel aktualisieren, falls offen (damit Zonen sichtbar sind)
    if EGC_SHIP.RefreshZoneConfigPanel then
        EGC_SHIP.RefreshZoneConfigPanel()
    end
end)

-- Treffer auf Zone mit Schild-HP → Ring-/Wellen-Effekt
EGC_SHIP._zoneShieldHitEffects = EGC_SHIP._zoneShieldHitEffects or {}
net.Receive("EGC_ZoneShieldHit", function()
    local zoneIndex = net.ReadUInt(16)
    local hitPos = net.ReadVector()
    local hitNormal = net.ReadVector()
    if hitNormal:LengthSqr() < 0.01 then hitNormal = Vector(0, 0, 1) end
    hitNormal = hitNormal:GetNormalized()
    table.insert(EGC_SHIP._zoneShieldHitEffects, {
        pos = hitPos,
        normal = hitNormal,
        zoneIndex = zoneIndex,
        time = CurTime(),
        duration = 0.7,
    })
end)

-- Sofortige HP-Aktualisierung einer Zone (nach Schaden)
net.Receive("EGC_ZoneHPUpdate", function()
    local zoneIndex = net.ReadUInt(16)
    local shieldHP = net.ReadFloat()
    local hullHP = net.ReadFloat()
    EGC_SHIP.DamageZones = EGC_SHIP.DamageZones or {}
    -- Placeholder-Zonen anlegen falls Index größer als aktuelle Liste (z. B. vor FullSync)
    while zoneIndex > #EGC_SHIP.DamageZones do
        table.insert(EGC_SHIP.DamageZones, {
            name = "", groupId = "", shieldHP = 0, hullHP = 0, vertices = {},
        })
    end
    if zoneIndex >= 1 and zoneIndex <= #EGC_SHIP.DamageZones then
        EGC_SHIP.DamageZones[zoneIndex].shieldHP = shieldHP
        EGC_SHIP.DamageZones[zoneIndex].hullHP = hullHP
    end
end)

-- Schild-HP der Zone auf 0 → Zone leuchtet kurz weiß
EGC_SHIP._zoneShieldDepletedEffects = EGC_SHIP._zoneShieldDepletedEffects or {}
net.Receive("EGC_ZoneShieldDepleted", function()
    local zoneIndex = net.ReadUInt(16)
    table.insert(EGC_SHIP._zoneShieldDepletedEffects, {
        zoneIndex = zoneIndex,
        time = CurTime(),
        duration = 0.5,
    })
end)

net.Receive("EGC_Shield_SectorMesh", function()
    local entIndex = net.ReadUInt(16)
    local numTris = net.ReadUInt(16)
    local triangles = {}
    for i = 1, numTris do
        local v1 = net.ReadVector()
        local v2 = net.ReadVector()
        local v3 = net.ReadVector()
        table.insert(triangles, { v1, v2, v3 })
    end
    EGC_SHIP._sectorMeshes[entIndex] = triangles
end)

-- ============================================================================
-- RING-/WELLEN-EFFEKT BEI SCHILD-TREFFER (Zone mit Schild-HP > 0)
-- ============================================================================

local function DrawZoneShieldHitRings()
    local effects = EGC_SHIP._zoneShieldHitEffects
    if not effects or #effects == 0 then return end
    local now = CurTime()
    local zones = EGC_SHIP.DamageZones or {}
    render.SetColorMaterial()
    for i = #effects, 1, -1 do
        local e = effects[i]
        local age = now - e.time
        if age > e.duration then
            table.remove(effects, i)
        else
            local progress = age / e.duration
            local alpha = 1 - progress
            local radius = 40 + progress * 180
            local normal = e.normal
            if not normal or normal:LengthSqr() < 0.01 then
                local zone = zones[e.zoneIndex]
                if zone and zone.vertices and #zone.vertices >= 3 then
                    normal = EGC_SHIP.PolygonNormal(zone.vertices)
                end
            end
            if not normal or normal:LengthSqr() < 0.01 then
                normal = Vector(0, 0, 1)
            end
            normal = normal:GetNormalized()
            local right = normal:Cross(Vector(0, 0, 1))
            if right:LengthSqr() < 0.01 then right = normal:Cross(Vector(0, 1, 0)) end
            right:Normalize()
            local up = right:Cross(normal):GetNormalized()
            local segs = 24
            local col = Color(80, 180, 255, math.Clamp(math.floor(alpha * 220), 0, 255))
            local beamW = 8
            for s = 0, segs - 1 do
                local a1 = (s / segs) * math.pi * 2
                local a2 = ((s + 1) / segs) * math.pi * 2
                local p1 = e.pos + math.cos(a1) * radius * right + math.sin(a1) * radius * up
                local p2 = e.pos + math.cos(a2) * radius * right + math.sin(a2) * radius * up
                render.DrawBeam(p1, p2, beamW, 0, 1, col)
            end
            -- Zweiter Ring etwas verzögert (Wellen-Effekt)
            local radius2 = 20 + progress * 120
            local col2 = Color(120, 200, 255, math.Clamp(math.floor(alpha * 160), 0, 255))
            for s = 0, segs - 1 do
                local a1 = (s / segs) * math.pi * 2
                local a2 = ((s + 1) / segs) * math.pi * 2
                local p1 = e.pos + math.cos(a1) * radius2 * right + math.sin(a1) * radius2 * up
                local p2 = e.pos + math.cos(a2) * radius2 * right + math.sin(a2) * radius2 * up
                render.DrawBeam(p1, p2, beamW * 0.6, 0, 1, col2)
            end
        end
    end
end

hook.Add("PostDrawTranslucentRenderables", "EGC_ZoneShieldHitRings", DrawZoneShieldHitRings)

-- ============================================================================
-- ZONE LEUCHTET WEISS WENN SCHILD-HP WEG
-- ============================================================================

local function DrawZoneShieldDepletedFlash()
    local effects = EGC_SHIP._zoneShieldDepletedEffects
    if not effects or #effects == 0 then return end
    local now = CurTime()
    local zones = EGC_SHIP.DamageZones or {}
    render.SetColorMaterial()
    for i = #effects, 1, -1 do
        local e = effects[i]
        local age = now - e.time
        if age > e.duration then
            table.remove(effects, i)
        else
            local alpha = 1 - (age / e.duration)
            local zone = zones[e.zoneIndex]
            if not zone or not zone.vertices or #zone.vertices < 3 then continue end
            local verts = zone.vertices
            local col = Color(255, 255, 255, math.Clamp(math.floor(alpha * 200), 0, 255))
            local beamW = 12
            for j = 1, #verts do
                local a, b = verts[j], verts[(j % #verts) + 1]
                render.DrawBeam(a, b, beamW, 0, 1, col)
            end
        end
    end
end

hook.Add("PostDrawTranslucentRenderables", "EGC_ZoneShieldDepletedFlash", DrawZoneShieldDepletedFlash)

-- ============================================================================
-- DEBUG-ANZEIGE: Verbleibende Schadenspunkte (Schild / Hülle) pro Zone
-- ============================================================================

CreateClientConVar("egc_zone_debug", "0", true, false)

hook.Add("HUDPaint", "EGC_ZoneDebugHP", function()
    if GetConVar("egc_zone_debug"):GetInt() ~= 1 then return end
    local zones = EGC_SHIP.DamageZones or {}
    if #zones == 0 then return end

    local padding = 12
    local lineH = 18
    local headerH = 24
    local w = 280
    local h = headerH + #zones * lineH + padding * 2
    local x, y = ScrW() - w - 20, 80

    draw.RoundedBox(6, x, y, w, h, Color(0, 0, 0, 200))
    draw.RoundedBox(6, x, y, w, headerH, Color(40, 80, 120, 220))
    draw.SimpleText("Zonen HP (Debug)", "DermaDefaultBold", x + w * 0.5, y + headerH * 0.5 - 1, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    for i, zone in ipairs(zones) do
        local name = (zone.name and zone.name ~= "") and zone.name or ("Zone " .. i)
        local shieldHP = math.floor(tonumber(zone.shieldHP) or 0)
        local hullHP = math.floor(tonumber(zone.hullHP) or 0)
        local ly = y + headerH + padding + (i - 1) * lineH
        draw.SimpleText(name .. ":", "DermaDefault", x + padding, ly, Color(200, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Schild: " .. shieldHP, "DermaDefault", x + padding + 120, ly, shieldHP > 0 and Color(100, 200, 255) or Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Hülle: " .. hullHP, "DermaDefault", x + padding + 200, ly, hullHP > 0 and Color(255, 200, 100) or Color(120, 120, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end)

-- ============================================================================
-- INITIALISIERUNG
-- ============================================================================

hook.Add("InitPostEntity", "EGC_Shield_ClientInit", function()
    print("[EGC Ship Shield System] Client initialisiert")
    
    -- Sync anfordern (Generatoren + Damage-Zonen)
    timer.Simple(1, function()
        net.Start("EGC_Shield_RequestSync")
        net.SendToServer()
        net.Start("EGC_DamageZones_RequestSync")
        net.SendToServer()
    end)
end)

-- ============================================================================
-- CLEANUP WENN GENERATOR ENTFERNT
-- ============================================================================

hook.Add("EntityRemoved", "EGC_Shield_CleanupGenerator", function(ent)
    if not IsValid(ent) then return end

    local entIndex = ent:EntIndex()
    if EGC_SHIP.Generators[entIndex] then
        EGC_SHIP.Generators[entIndex] = nil
    end
    if EGC_SHIP._sectorMeshes and EGC_SHIP._sectorMeshes[entIndex] then
        EGC_SHIP._sectorMeshes[entIndex] = nil
    end
end)

print("[EGC Ship Shield System] Client Autorun geladen")
