--[[
    EGC Ship Shield System - Server
    Hull-Scan, Gate-System, Schild-Kollision, Persistenz
]]

if not SERVER then return end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Generators = EGC_SHIP.Generators or {}
EGC_SHIP.DamageZones = EGC_SHIP.DamageZones or {}

local CFG = EGC_SHIP.Config or {}
local MIN_ZONE_VERTICES = EGC_SHIP.MinZoneVertices or 3

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

-- Vereinfacht Punktwolke: behält Punkte, die die Form gut beschreiben (nicht nur jedes N-te)
local function SimplifyPointCloud(points, maxPoints)
    if #points <= maxPoints then return points end
    
    local step = math.ceil(#points / maxPoints)
    local simplified = {}
    
    for i = 1, #points, step do
        table.insert(simplified, points[i])
    end
    
    return simplified
end

-- Entfernt Punkte, die zu nah am vorherigen liegen (reduziert Rauschen, erhält Umriss)
local function MergeNearbyPoints(points, minDist)
    minDist = minDist or 25
    if #points < 3 then return points end
    
    local out = { points[1] }
    for i = 2, #points do
        local prev = out[#out]
        local cur = points[i]
        if prev:Distance(cur) >= minDist then
            table.insert(out, cur)
        end
    end
    
    if #out >= 3 and out[#out]:Distance(out[1]) < minDist then
        table.remove(out)  -- Letzten entfernen wenn er zu nah am ersten
    end
    
    return #out >= 3 and out or points
end

-- ============================================================================
-- AUTO-HULL-DETECTION
-- Die Orientierungspunkte definieren die Form; das Mesh legt sich von außen
-- auf die Map und die Punkte (Oberfläche wird per Trace abgetastet).
-- ============================================================================

-- Projiziert einen Punkt von außen auf die nächste feste Oberfläche (Map/Prop)
local function ProjectPointOntoSurface(point, outwardDir, mask)
    local start = point + outwardDir * 120   -- von außen starten
    local endPos = point - outwardDir * 4000 -- nach innen durch Schiff/Map
    local tr = util.TraceLine({
        start = start,
        endpos = endPos,
        mask = mask,
    })
    if tr.Hit then
        return tr.HitPos
    end
    return point
end

local function ScanHullFromPoints(orientationPoints, resolution)
    if #orientationPoints < 3 then return {} end
    
    resolution = math.Clamp(resolution or 50, 10, 500)
    local mask = MASK_SOLID
    
    -- Zentrum der vom Spieler vorgegebenen Form
    local center = Vector(0, 0, 0)
    for _, p in ipairs(orientationPoints) do center = center + p end
    center = center / #orientationPoints
    
    -- 1. Jeden Orientierungspunkt von außen auf die Oberfläche legen
    --    → Das Mesh folgt der Form und liegt auf Map/Schiff
    local hullPoints = {}
    for _, p in ipairs(orientationPoints) do
        local outDir = (p - center):GetNormalized()
        local onSurface = ProjectPointOntoSurface(p, outDir, mask)
        table.insert(hullPoints, onSurface)
    end
    
    -- 2. Optional: Kontur verdichten (Zwischenpunkte ebenfalls auf Oberfläche projizieren)
    local segs = math.Clamp(math.floor(resolution / 25), 0, 8)  -- 0–8 Zwischenpunkte pro Kante
    if segs > 0 then
        local dense = {}
        for i = 1, #hullPoints do
            local a = hullPoints[i]
            local b = hullPoints[(i % #hullPoints) + 1]
            table.insert(dense, a)
            for k = 1, segs do
                local t = k / (segs + 1)
                local mid = Vector(
                    Lerp(t, a.x, b.x),
                    Lerp(t, a.y, b.y),
                    Lerp(t, a.z, b.z)
                )
                local outDir = (mid - center):GetNormalized()
                table.insert(dense, ProjectPointOntoSurface(mid, outDir, mask))
            end
        end
        hullPoints = dense
    end
    
    if #hullPoints < 3 then return {} end
    
    -- 3. Doppelte/zu nahe Punkte zusammenfassen, Reihenfolge bleibt (Form bleibt erkennbar)
    hullPoints = MergeNearbyPoints(hullPoints, 15)
    
    local maxPts = CFG.MaxHullPoints or 256
    if #hullPoints > maxPts then
        hullPoints = SimplifyPointCloud(hullPoints, maxPts)
    end
    
    print(string.format("[EGC Shield] Hull-Mesh: %d Punkte (Form von außen auf Map gelegt)", #hullPoints))
    return hullPoints
end

-- ============================================================================
-- SYNC-ANFRAGE
-- ============================================================================

-- Sync-Anfrage
net.Receive("EGC_Shield_RequestSync", function(len, ply)
    if not IsValid(ply) then return end
    
    -- Alle Generatoren synchronisieren
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        local ent = Entity(entIndex)
        if IsValid(ent) then
            SendGeneratorSync(ent, ply)
        end
    end
    -- Damage-Zonen mitsenden
    SendDamageZonesSync(ply)
end)

EGC_SHIP.DamageZones = EGC_SHIP.DamageZones or {}
EGC_SHIP.ZoneGroupHP = EGC_SHIP.ZoneGroupHP or {}  -- [groupKey] = { shieldHP, hullHP } – gemeinsamer HP-Pool pro Zonengruppe

-- Gruppen-Key: gleiche groupId = gleicher Pool; leere groupId = Zone hat eigenen Pool (z1, z2, …)
local function GetGroupKey(zone, zoneIndex)
    local g = zone and zone.groupId
    if g and g ~= "" then return g end
    return "z" .. tostring(zoneIndex)
end

-- Gibt den HP-Pool für die Gruppe dieser Zone zurück (erstellt ihn aus Zone, falls nötig).
function EGC_SHIP.GetZoneGroupPool(zone, zoneIndex)
    local zones = EGC_SHIP.DamageZones or {}
    if not zone or zoneIndex < 1 or zoneIndex > #zones then return nil end
    local key = GetGroupKey(zone, zoneIndex)
    if not EGC_SHIP.ZoneGroupHP[key] then
        EGC_SHIP.ZoneGroupHP[key] = {
            shieldHP = math.max(0, tonumber(zone.shieldHP) or 0),
            hullHP = math.max(0, tonumber(zone.hullHP) or 0),
        }
    end
    return EGC_SHIP.ZoneGroupHP[key]
end

-- Alle Zonen-Indizes, die dieselbe Gruppe wie zoneIndex haben (gleicher HP-Pool).
function EGC_SHIP.GetZoneIndicesInGroup(zoneIndex)
    local zones = EGC_SHIP.DamageZones or {}
    if zoneIndex < 1 or zoneIndex > #zones then return {} end
    local key = GetGroupKey(zones[zoneIndex], zoneIndex)
    local out = {}
    for i, z in ipairs(zones) do
        if GetGroupKey(z, i) == key then table.insert(out, i) end
    end
    return out
end

-- ============================================================================
-- DAMAGE-ZONEN (Flächen)
-- ============================================================================

net.Receive("EGC_DamageZone_Finish", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local numVerts = net.ReadUInt(16)
    if numVerts < MIN_ZONE_VERTICES then return end

    local vertices = {}
    for i = 1, numVerts do
        local p = net.ReadVector()
        if EGC_SHIP.ValidateVector(p) then
            table.insert(vertices, p)
        end
    end

    if #vertices < MIN_ZONE_VERTICES then return end

    local zone = EGC_SHIP.CreateDamageZoneData(vertices)
    zone.name = "Zone " .. (#EGC_SHIP.DamageZones + 1)
    table.insert(EGC_SHIP.DamageZones, zone)

    BroadcastDamageZonesSync()
end)

function SendDamageZonesSync(target)
    net.Start("EGC_DamageZones_FullSync")
    local zones = EGC_SHIP.DamageZones or {}
    net.WriteUInt(#zones, 16)
    for i, zone in ipairs(zones) do
        net.WriteString(zone.name or "")
        net.WriteString(zone.groupId or "")
        local pool = EGC_SHIP.GetZoneGroupPool(zone, i)
        net.WriteFloat(pool and pool.shieldHP or 0)
        net.WriteFloat(pool and pool.hullHP or 0)
        local verts = zone.vertices or {}
        net.WriteUInt(#verts, 16)
        for _, p in ipairs(verts) do
            net.WriteVector(p)
        end
    end
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

function BroadcastDamageZonesSync()
    SendDamageZonesSync(nil)
    -- Barrieren-Update verzögern: nicht in Physik-/Schadens-Callback (Cannot destroy physics in a physics callback)
    timer.Simple(0, function() EGC_SHIP.UpdateZoneBarriers() end)
end

-- Physische Barrieren: Nur Zonen mit Schild-HP der Gruppe > 0 haben Kollision.
function EGC_SHIP.UpdateZoneBarriers()
    EGC_SHIP._zoneBarriers = EGC_SHIP._zoneBarriers or {}
    local zones = EGC_SHIP.DamageZones or {}
    local barriers = EGC_SHIP._zoneBarriers

    for i = 1, #zones do
        local zone = zones[i]
        local verts = zone.vertices
        local pool = EGC_SHIP.GetZoneGroupPool(zone, i)
        local shieldHP = pool and math.max(0, pool.shieldHP) or 0

        if shieldHP > 0 and verts and #verts >= 3 then
            if barriers[i] and IsValid(barriers[i]) then
                barriers[i]:SetZoneVertices(verts)
            else
                local ent = ents.Create("egc_zone_barrier")
                if IsValid(ent) then
                    ent:Spawn()
                    ent:SetZoneVertices(verts)
                    barriers[i] = ent
                end
            end
        else
            if barriers[i] and IsValid(barriers[i]) then
                barriers[i]:Remove()
                barriers[i] = nil
            end
        end
    end

    for i = #zones + 1, 256 do
        if barriers[i] and IsValid(barriers[i]) then
            barriers[i]:Remove()
            barriers[i] = nil
        end
    end
end

net.Receive("EGC_DamageZones_RequestSync", function(len, ply)
    if not IsValid(ply) then return end
    SendDamageZonesSync(ply)
end)

-- Zone-Konfig: Name, Gruppe, Schild-HP, Hüllen-HP (Index 1-based)
net.Receive("EGC_ZoneConfig_Update", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local zoneIndex = net.ReadUInt(16)
    local name = net.ReadString()
    local groupId = net.ReadString()
    local shieldHP = net.ReadFloat()
    local hullHP = net.ReadFloat()

    local zones = EGC_SHIP.DamageZones or {}
    if zoneIndex < 1 or zoneIndex > #zones then return end

    local zone = zones[zoneIndex]
    zone.name = name or ""
    zone.groupId = groupId or ""
    -- Gruppen-Pool setzen (HP gilt für die gesamte Zonengruppe)
    local key = (groupId and groupId ~= "") and groupId or ("z" .. tostring(zoneIndex))
    EGC_SHIP.ZoneGroupHP = EGC_SHIP.ZoneGroupHP or {}
    EGC_SHIP.ZoneGroupHP[key] = {
        shieldHP = math.Clamp(shieldHP, 0, 100000),
        hullHP = math.Clamp(hullHP, 0, 100000),
    }

    BroadcastDamageZonesSync()
end)

-- ============================================================================
-- NETZWERK-SYNC
-- ============================================================================

function SendGeneratorSync(generator, target)
    if not IsValid(generator) then return end
    
    local genData = generator:GetGeneratorData()
    if not genData then return end
    
    net.Start("EGC_Shield_FullSync")
    net.WriteUInt(generator:EntIndex(), 16)
    
    -- Hull-Mesh
    local hullMesh = genData.hullMesh or {}
    net.WriteUInt(#hullMesh, 16)
    for _, p in ipairs(hullMesh) do
        net.WriteVector(p)
    end
    
    -- Gates
    local gates = genData.gates or {}
    net.WriteUInt(#gates, 8)
    for _, gate in ipairs(gates) do
        local mesh = gate.mesh or {}
        net.WriteUInt(#mesh, 8)
        for _, p in ipairs(mesh) do
            net.WriteVector(p)
        end
    end
    
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

function BroadcastGeneratorSync(generator)
    SendGeneratorSync(generator, nil)
end

-- ============================================================================
-- DAMAGE-ZONEN: Treffer ermitteln (Ray gegen Polygon)
-- ============================================================================

-- Findet die nächste getroffene Damage-Zone entlang des Strahls
function EGC_SHIP.FindZoneHit(origin, dir, maxDist)
    maxDist = maxDist or 50000
    local zones = EGC_SHIP.DamageZones or {}
    local bestT, bestIdx, bestPos = nil, nil, nil
    for i, zone in ipairs(zones) do
        local verts = zone.vertices
        if verts and #verts >= 3 then
            local t = EGC_SHIP.RayPolygonIntersect(origin, dir, verts)
            if t and t > 0.05 and t <= maxDist and (not bestT or t < bestT) then
                bestT = t
                bestIdx = i
                bestPos = origin + dir * t
            end
        end
    end
    if bestIdx then
        return { zoneIndex = bestIdx, hitPos = bestPos, distance = bestT }
    end
    return nil
end

-- Wendet Schaden auf die Gruppe der Zone an (gemeinsamer HP-Pool). Gibt true zurück, wenn Schild getroffen wurde.
function EGC_SHIP.ApplyZoneDamage(zoneIndex, damage)
    local zones = EGC_SHIP.DamageZones or {}
    if zoneIndex < 1 or zoneIndex > #zones then return false end
    local zone = zones[zoneIndex]
    local pool = EGC_SHIP.GetZoneGroupPool(zone, zoneIndex)
    if not pool then return false end
    local shieldHP = math.max(0, pool.shieldHP)
    local hullHP = math.max(0, pool.hullHP)
    local hadShield = shieldHP > 0
    local takeFromShield = math.min(shieldHP, damage)
    pool.shieldHP = math.max(0, shieldHP - takeFromShield)
    local remainder = damage - takeFromShield
    pool.hullHP = math.max(0, hullHP - remainder)
    -- HP-Update für alle Zonen dieser Gruppe an Clients senden
    for _, idx in ipairs(EGC_SHIP.GetZoneIndicesInGroup(zoneIndex)) do
        net.Start("EGC_ZoneHPUpdate")
        net.WriteUInt(idx, 16)
        net.WriteFloat(pool.shieldHP)
        net.WriteFloat(pool.hullHP)
        net.Broadcast()
    end
    return hadShield
end

-- Gibt Zonen-Indizes zurück, deren Mittelpunkt oder ein Vertex im Radius um pos liegt (für Explosionen/Raketen)
function EGC_SHIP.FindZonesInRadius(pos, radius)
    local zones = EGC_SHIP.DamageZones or {}
    local out = {}
    local r2 = radius * radius
    for i, zone in ipairs(zones) do
        local verts = zone.vertices
        if not verts or #verts < 3 then continue end
        local center = Vector(0, 0, 0)
        for _, v in ipairs(verts) do center = center + v end
        center = center / #verts
        if center:DistToSqr(pos) <= r2 then
            table.insert(out, i)
        else
            for _, v in ipairs(verts) do
                if v:DistToSqr(pos) <= r2 then
                    table.insert(out, i)
                    break
                end
            end
        end
    end
    return out
end

-- ============================================================================
-- PROJEKTIL-ENTITIES ABFANGEN (Raketen, Pfeile, Combine-Bälle etc.)
-- ============================================================================

EGC_SHIP._projLastPos = EGC_SHIP._projLastPos or {}
local projCheckInterval = (EGC_SHIP.Config and EGC_SHIP.Config.ProjectileCheckInterval) or 0.04

timer.Create("EGC_Zone_ProjectileCheck", projCheckInterval, 0, function()
    local projClasses = (EGC_SHIP.Config and EGC_SHIP.Config.ProjectileClasses) or {}
    local zones = EGC_SHIP.DamageZones or {}
    if #zones == 0 then return end
    local lastPos = EGC_SHIP._projLastPos

    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        local class = ent:GetClass()
        local dmg = projClasses[class]
        if not dmg or dmg <= 0 then continue end

        local pos = ent:GetPos()
        local idx = ent:EntIndex()
        local prev = lastPos[idx]
        local zoneHit = nil

        if prev and prev:Distance(pos) > 2 then
            local dir = (pos - prev):GetNormalized()
            local maxDist = pos:Distance(prev)
            for i, zone in ipairs(zones) do
                local verts = zone.vertices
                if verts and #verts >= 3 then
                    local t = EGC_SHIP.RayPolygonIntersect(prev, dir, verts)
                    if t and t > 0.02 and t < maxDist then
                        if not zoneHit or t < zoneHit.t then
                            zoneHit = { zoneIndex = i, hitPos = prev + dir * t, t = t }
                        end
                    end
                end
            end
        else
            for i, zone in ipairs(zones) do
                local verts = zone.vertices
                if verts and #verts >= 3 and EGC_SHIP.PointInPolygon3D(verts, pos) then
                    zoneHit = { zoneIndex = i, hitPos = pos }
                    break
                end
            end
        end

        lastPos[idx] = pos

        if zoneHit then
            local hadShield = EGC_SHIP.ApplyZoneDamage(zoneHit.zoneIndex, dmg)
            local zone = EGC_SHIP.DamageZones[zoneHit.zoneIndex]
            if hadShield then
                local hitNormal = (zone and zone.vertices and #zone.vertices >= 3) and EGC_SHIP.PolygonNormal(zone.vertices) or Vector(0, 0, 1)
                if hitNormal:LengthSqr() < 0.01 then hitNormal = Vector(0, 0, 1) end
                hitNormal = hitNormal:GetNormalized()
                net.Start("EGC_ZoneShieldHit")
                net.WriteUInt(zoneHit.zoneIndex, 16)
                net.WriteVector(zoneHit.hitPos)
                net.WriteVector(hitNormal)
                net.Broadcast()
            end
            local pool = zone and EGC_SHIP.GetZoneGroupPool(zone, zoneHit.zoneIndex)
            if pool and pool.shieldHP <= 0 and hadShield then
                for _, idx in ipairs(EGC_SHIP.GetZoneIndicesInGroup(zoneHit.zoneIndex)) do
                    net.Start("EGC_ZoneShieldDepleted")
                    net.WriteUInt(idx, 16)
                    net.Broadcast()
                end
            end
            BroadcastDamageZonesSync()
            ent:Remove()
            lastPos[idx] = nil
            local ed = EffectData()
            ed:SetOrigin(zoneHit.hitPos)
            ed:SetScale(1)
            util.Effect("Explosion", ed)
        end
    end

    for idx, _ in pairs(lastPos) do
        if not IsValid(Entity(idx)) then lastPos[idx] = nil end
    end
end)

-- ============================================================================
-- GESCHOSS-BLOCKIERUNG (Schild-Generator + Damage-Zonen)
-- ============================================================================

hook.Add("EntityFireBullets", "EGC_Shield_BlockBullets", function(ent, bulletData)
    if not bulletData or not bulletData.Src or not bulletData.Dir then return end

    local dir = bulletData.Dir:GetNormalized()
    local zoneHit = EGC_SHIP.FindZoneHit(bulletData.Src, dir, 50000)
    local shieldHit = EGC_SHIP.FindShieldHit(bulletData.Src, dir, 50000)

    -- Nächsten Treffer verwenden: zuerst Zone, dann globaler Schild
    if zoneHit and (not shieldHit or zoneHit.distance < shieldHit.distance) then
        local cfg = EGC_SHIP.Config or {}
        local rawDmg = bulletData.Damage or 0
        local damage = math.max(rawDmg, cfg.ZoneBulletDamageMin or 10) * (cfg.ZoneBulletDamageMultiplier or 1)
        local hadShield = EGC_SHIP.ApplyZoneDamage(zoneHit.zoneIndex, damage)
        if hadShield then
            local zone = EGC_SHIP.DamageZones[zoneHit.zoneIndex]
            local hitNormal = (zone and zone.vertices and #zone.vertices >= 3) and EGC_SHIP.PolygonNormal(zone.vertices) or Vector(0, 0, 1)
            if hitNormal:LengthSqr() < 0.01 then hitNormal = Vector(0, 0, 1) end
            hitNormal = hitNormal:GetNormalized()
            net.Start("EGC_ZoneShieldHit")
            net.WriteUInt(zoneHit.zoneIndex, 16)
            net.WriteVector(zoneHit.hitPos)
            net.WriteVector(hitNormal)
            net.Broadcast()
        end
        local zone = EGC_SHIP.DamageZones[zoneHit.zoneIndex]
        if zone and hadShield then
            local pool = EGC_SHIP.GetZoneGroupPool(zone, zoneHit.zoneIndex)
            if pool and pool.shieldHP <= 0 then
                for _, idx in ipairs(EGC_SHIP.GetZoneIndicesInGroup(zoneHit.zoneIndex)) do
                    net.Start("EGC_ZoneShieldDepleted")
                    net.WriteUInt(idx, 16)
                    net.Broadcast()
                end
            end
        end
        BroadcastDamageZonesSync()
        local effectData = EffectData()
        effectData:SetOrigin(zoneHit.hitPos)
        effectData:SetNormal((bulletData.Src - zoneHit.hitPos):GetNormalized())
        effectData:SetScale(0.4)
        util.Effect("AR2Impact", effectData)
        return true
    end

    if shieldHit then
        local generator = Entity(shieldHit.entIndex)
        if IsValid(generator) and generator.ApplyShieldDamage then
            local cfg = EGC_SHIP.Config or {}
            local rawDmg = bulletData.Damage or 0
            local damage = math.max(rawDmg, cfg.ZoneBulletDamageMin or 10) * (cfg.ZoneBulletDamageMultiplier or 1)
            generator:ApplyShieldDamage(damage, DMG_BULLET)
            local effectData = EffectData()
            effectData:SetOrigin(shieldHit.hitPos)
            effectData:SetNormal((bulletData.Src - shieldHit.hitPos):GetNormalized())
            effectData:SetScale(0.5)
            util.Effect("AR2Impact", effectData)
        end
        return true
    end
end)

-- ============================================================================
-- ZONEN-SCHADEN: Alle Schadenstypen inkl. LVS, ArcCW, Gbomb, Hbomb, HL2-Bullets
-- (DMG_GENERIC, BULLET, SLASH, SHOCK, BURN, BLAST, RADIATION, FALL, CLUB, CRUSH, Area)
-- ============================================================================

hook.Add("EntityTakeDamage", "EGC_Shield_ExplosionDamage", function(target, dmginfo)
    if not IsValid(target) then return end
    
    local dmgType = dmginfo:GetDamageType()
    local dmgPos = dmginfo:GetDamagePosition()
    if not dmgPos or dmgPos == Vector(0,0,0) then
        dmgPos = target:GetPos()
    end

    -- Zonen ermitteln, die getroffen werden (kein Filter nach Schadenstyp – alle Typen wirken):
    -- 1) Trefferpunkt liegt im Polygon
    -- 2) Toleranzradius für alle Typen (Area/Nahbereich)
    -- 3) Explosionsradius zusätzlich bei DMG_BLAST
    local zonesToDamage = {}
    local zones = EGC_SHIP.DamageZones or {}
    for i, zone in ipairs(zones) do
        local verts = zone.vertices
        if verts and #verts >= 3 and EGC_SHIP.PointInPolygon3D(verts, dmgPos) then
            zonesToDamage[i] = true
        end
    end
    local toleranceRadius = (EGC_SHIP.Config and EGC_SHIP.Config.ZoneDamageToleranceRadius) or 80
    for _, idx in ipairs(EGC_SHIP.FindZonesInRadius(dmgPos, toleranceRadius)) do
        zonesToDamage[idx] = true
    end
    local explosionRadius = (EGC_SHIP.Config and EGC_SHIP.Config.ZoneExplosionRadius) or 450
    if bit.band(dmgType, DMG_BLAST) ~= 0 then
        for _, idx in ipairs(EGC_SHIP.FindZonesInRadius(dmgPos, explosionRadius)) do
            zonesToDamage[idx] = true
        end
    end

    local damage = dmginfo:GetDamage()
    if not damage or damage <= 0 then damage = 0 end
    local cfg = EGC_SHIP.Config or {}
    -- Realistisch skalieren: Kugeln/Schüsse wenig, Explosionen je nach Stärke mehr (RPG < Nuke)
    if bit.band(dmgType, DMG_BULLET) ~= 0 then
        damage = math.max(damage, cfg.ZoneBulletDamageMin or 2) * (cfg.ZoneBulletDamageMultiplier or 0.08)
    elseif bit.band(dmgType, DMG_BLAST) ~= 0 then
        damage = math.max(damage, cfg.ZoneExplosionDamageMin or 5)
        if cfg.ZoneExplosionScaleByAmount then
            local ref = math.max(1, cfg.ZoneExplosionScaleRef or 300)
            local scale = 0.4 + math.min(damage / ref, 2.6)  -- 0.4 bei wenig, bis ~3 bei großer Explosion
            damage = damage * (cfg.ZoneExplosionDamageMultiplier or 1) * scale
        else
            damage = damage * (cfg.ZoneExplosionDamageMultiplier or 1)
        end
    end
    -- Schaden nur einmal pro Zonengruppe anwenden (gemeinsamer HP-Pool)
    local groupsHit = {}
    for zoneIndex, _ in pairs(zonesToDamage) do
        local z = zones[zoneIndex]
        if z then
            local key = GetGroupKey(z, zoneIndex)
            if not groupsHit[key] then groupsHit[key] = zoneIndex end
        end
    end
    for _, zoneIndex in pairs(groupsHit) do
        if damage > 0 then
            local hadShield = EGC_SHIP.ApplyZoneDamage(zoneIndex, damage)
            local z = EGC_SHIP.DamageZones[zoneIndex]
            if hadShield then
                local zone = EGC_SHIP.DamageZones[zoneIndex]
                local hitNormal = (zone and zone.vertices and #zone.vertices >= 3) and EGC_SHIP.PolygonNormal(zone.vertices) or Vector(0, 0, 1)
                if hitNormal:LengthSqr() < 0.01 then hitNormal = Vector(0, 0, 1) end
                hitNormal = hitNormal:GetNormalized()
                net.Start("EGC_ZoneShieldHit")
                net.WriteUInt(zoneIndex, 16)
                net.WriteVector(dmgPos)
                net.WriteVector(hitNormal)
                net.Broadcast()
            end
            local pool = z and EGC_SHIP.GetZoneGroupPool(z, zoneIndex)
            if pool and pool.shieldHP <= 0 and hadShield then
                for _, idx in ipairs(EGC_SHIP.GetZoneIndicesInGroup(zoneIndex)) do
                    net.Start("EGC_ZoneShieldDepleted")
                    net.WriteUInt(idx, 16)
                    net.Broadcast()
                end
            end
        end
    end
    if next(zonesToDamage) then
        BroadcastDamageZonesSync()
        -- Schaden am eigentlichen Ziel blockieren, da die Zone ihn übernommen hat
        return true
    end

    -- Ab hier nur noch Explosionen für globalen Schild-Generator
    if bit.band(dmgType, DMG_BLAST) == 0 then return end
    
    -- Prüfe ob Explosion durch Schild blockiert wird
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        if not genData.active or genData.shieldPercent <= 0 then continue end
        
        local generator = Entity(entIndex)
        if not IsValid(generator) then continue end
        
        -- Vereinfachte Prüfung: ist Ziel innerhalb des Schilds?
        if genData.hullCenter then
            local distToCenter = dmgPos:Distance(genData.hullCenter)
            local targetDist = target:GetPos():Distance(genData.hullCenter)
            
            -- Explosion außerhalb, Ziel innerhalb = blockieren
            if distToCenter > (genData.hullRadius or 5000) and targetDist < (genData.hullRadius or 5000) then
                generator:ApplyShieldDamage(dmginfo:GetDamage(), dmgType)
                return true  -- Schaden blockieren
            end
        end
    end
end)

-- ============================================================================
-- PROP-KOLLISION MIT GATES
-- ============================================================================

local propCheckInterval = CFG.CollisionCheckInterval or 0.1
local lastPropCheck = 0

timer.Create("EGC_Shield_PropCollision", propCheckInterval, 0, function()
    if CurTime() - lastPropCheck < propCheckInterval then return end
    lastPropCheck = CurTime()
    
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        if not genData.active or genData.shieldPercent <= 0 then continue end
        if not genData.hullCenter then continue end
        
        local generator = Entity(entIndex)
        if not IsValid(generator) then continue end
        
        -- Finde Props in der Nähe des Schilds
        local radius = (genData.hullRadius or 5000) + 500
        local nearbyEnts = ents.FindInSphere(genData.hullCenter, radius)
        
        for _, ent in ipairs(nearbyEnts) do
            if not IsValid(ent) then continue end
            if ent:IsPlayer() or ent:IsNPC() then continue end
            
            local class = ent:GetClass()
            if class ~= "prop_physics" and class ~= "prop_physics_multiplayer" then continue end
            
            local pos = ent:GetPos()
            local vel = ent:GetVelocity()
            
            -- Nur bewegte Props
            if vel:LengthSqr() < 100 then continue end
            
            -- Prüfe ob durch Gate
            if EGC_SHIP.IsPointInAnyGate(pos, genData) then
                continue  -- Durch Gate, nicht blockieren
            end
            
            -- Prüfe ob Prop von außen kommt
            local distToCenter = pos:Distance(genData.hullCenter)
            local velToCenter = vel:Dot((genData.hullCenter - pos):GetNormalized())
            
            -- Prop bewegt sich nach innen und ist nahe am Schild-Rand
            if velToCenter > 0 and math.abs(distToCenter - (genData.hullRadius or 5000)) < 200 then
                -- Prop abprallen lassen
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    local normal = (pos - genData.hullCenter):GetNormalized()
                    local bounceVel = vel - 2 * vel:Dot(normal) * normal
                    phys:SetVelocity(bounceVel * 0.5)
                    
                    -- Kleiner Schaden am Schild
                    local mass = phys:GetMass()
                    local impact = vel:Length() * mass * 0.0001
                    generator:ApplyShieldDamage(impact, DMG_CRUSH)
                end
            end
        end
    end
end)

-- ============================================================================
-- PERSISTENZ
-- ============================================================================

local function GetSaveFilename()
    return (CFG.DataFolder or "egc_ship_shields") .. "/" .. EGC_SHIP.GetMapKey() .. "_shields.json"
end

function EGC_SHIP.SaveAllGenerators()
    local data = {
        map = game.GetMap(),
        generators = {},
    }
    
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        local ent = Entity(entIndex)
        if not IsValid(ent) then continue end
        
        table.insert(data.generators, {
            pos = ent:GetPos(),
            ang = ent:GetAngles(),
            sectorName = ent:GetSectorName(),
            hullPoints = genData.hullPoints,
            hullMesh = genData.hullMesh,
            sectorPoints = genData.sectorPoints,
            polyVertices = genData.polyVertices,
            polyFaces = genData.polyFaces,
            gates = genData.gates,
        })
    end
    
    local json = util.TableToJSON(data, true)
    local folder = CFG.DataFolder or "egc_ship_shields"
    
    if not file.IsDir(folder, "DATA") then
        file.CreateDir(folder)
    end
    
    file.Write(GetSaveFilename(), json)
    print("[EGC Shield] " .. #data.generators .. " Generatoren gespeichert")
end

function EGC_SHIP.LoadAllGenerators()
    local filename = GetSaveFilename()
    if not file.Exists(filename, "DATA") then return end
    
    local json = file.Read(filename, "DATA")
    if not json then return end
    
    local ok, data = pcall(util.JSONToTable, json)
    if not ok or not data then return end
    
    print("[EGC Shield] Lade " .. #(data.generators or {}) .. " Generatoren...")
    
    for _, genSave in ipairs(data.generators or {}) do
        local ent = ents.Create("egc_shield_generator")
        if IsValid(ent) then
            ent:SetPos(genSave.pos)
            ent:SetAngles(genSave.ang)
            ent:Spawn()
            ent:SetSectorName(genSave.sectorName or "Sektor")
            
            -- Daten wiederherstellen (Hull-Wrapping: Sektor aus gespeicherten Punkten)
            timer.Simple(0.1, function()
                if IsValid(ent) then
                    ent:SetHullData(genSave.hullPoints, genSave.hullMesh, true)
                    if genSave.polyVertices and genSave.polyFaces and #genSave.polyVertices >= 3 and #genSave.polyFaces > 0 then
                        ent:CreatePolyShieldFromTriangles(genSave.polyVertices, genSave.polyFaces)
                    else
                        local sectorPoints = genSave.sectorPoints or genSave.hullPoints
                        if sectorPoints and #sectorPoints >= 4 then
                            ent:CreateShieldSectorFromPoints(sectorPoints)
                        end
                    end

                    for _, gate in ipairs(genSave.gates or {}) do
                        ent:AddGate(gate.points, gate.mesh)
                    end

                    BroadcastGeneratorSync(ent)
                end
            end)
        end
    end
end

-- Auto-Load beim Map-Start
hook.Add("InitPostEntity", "EGC_Shield_LoadData", function()
    timer.Simple(2, function()
        EGC_SHIP.LoadAllGenerators()
    end)
end)

-- Auto-Save beim Shutdown
hook.Add("ShutDown", "EGC_Shield_SaveData", function()
    EGC_SHIP.SaveAllGenerators()
end)

-- Periodisches Auto-Save
if CFG.AutoSave then
    timer.Create("EGC_Shield_AutoSave", CFG.AutoSaveInterval or 300, 0, function()
        EGC_SHIP.SaveAllGenerators()
    end)
end

-- ============================================================================
-- CONSOLE COMMANDS
-- ============================================================================

concommand.Add("egc_shield_save", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    EGC_SHIP.SaveAllGenerators()
    if IsValid(ply) then
        ply:ChatPrint("[EGC Shield] Generatoren gespeichert!")
    end
end)

concommand.Add("egc_shield_load", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    EGC_SHIP.LoadAllGenerators()
    if IsValid(ply) then
        ply:ChatPrint("[EGC Shield] Generatoren geladen!")
    end
end)

concommand.Add("egc_shield_debug", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    
    print("========== EGC Shield Debug ==========")
    print("Aktive Generatoren: " .. table.Count(EGC_SHIP.Generators))
    
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        local ent = Entity(entIndex)
        print(string.format("  [#%d] Valid=%s, Hull=%d, Gates=%d, Shield=%.1f%%",
            entIndex,
            tostring(IsValid(ent)),
            #(genData.hullMesh or {}),
            #(genData.gates or {}),
            genData.shieldPercent or 0
        ))
    end
    print("=======================================")
end)

print("[EGC Ship Shield System] Server geladen")
