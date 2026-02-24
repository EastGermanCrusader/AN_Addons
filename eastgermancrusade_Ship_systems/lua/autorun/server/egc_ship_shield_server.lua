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
    for _, zone in ipairs(zones) do
        net.WriteString(zone.name or "")
        net.WriteString(zone.groupId or "")
        net.WriteFloat(zone.shieldHP or 0)
        net.WriteFloat(zone.hullHP or 0)
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
    zone.shieldHP = math.Clamp(shieldHP, 0, 100000)
    zone.hullHP = math.Clamp(hullHP, 0, 100000)

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
-- GESCHOSS-BLOCKIERUNG
-- ============================================================================

hook.Add("EntityFireBullets", "EGC_Shield_BlockBullets", function(ent, bulletData)
    if not bulletData or not bulletData.Src or not bulletData.Dir then return end
    
    local hit = EGC_SHIP.FindShieldHit(bulletData.Src, bulletData.Dir:GetNormalized(), 50000)
    
    if hit then
        local generator = Entity(hit.entIndex)
        if IsValid(generator) and generator.ApplyShieldDamage then
            local damage = bulletData.Damage or 10
            generator:ApplyShieldDamage(damage, DMG_BULLET)
            
            -- Effekt am Trefferpunkt
            local effectData = EffectData()
            effectData:SetOrigin(hit.hitPos)
            effectData:SetNormal((bulletData.Src - hit.hitPos):GetNormalized())
            effectData:SetScale(0.5)
            util.Effect("AR2Impact", effectData)
        end
        
        return true  -- Geschoss blockieren
    end
end)

-- ============================================================================
-- EXPLOSIONS-SCHADEN
-- ============================================================================

hook.Add("EntityTakeDamage", "EGC_Shield_ExplosionDamage", function(target, dmginfo)
    if not IsValid(target) then return end
    
    local dmgType = dmginfo:GetDamageType()
    if bit.band(dmgType, DMG_BLAST) == 0 then return end  -- Nur Explosionen
    
    local dmgPos = dmginfo:GetDamagePosition()
    if not dmgPos or dmgPos == Vector(0,0,0) then
        dmgPos = target:GetPos()
    end
    
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
