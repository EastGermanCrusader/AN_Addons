--[[
    EGC Ship Shield System - Server
    Hull-Scan, Gate-System, Schild-Kollision, Persistenz
]]

if not SERVER then return end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Generators = EGC_SHIP.Generators or {}

local CFG = EGC_SHIP.Config or {}

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

-- Vereinfacht Punktwolke
local function SimplifyPointCloud(points, maxPoints)
    if #points <= maxPoints then return points end
    
    local step = math.ceil(#points / maxPoints)
    local simplified = {}
    
    for i = 1, #points, step do
        table.insert(simplified, points[i])
    end
    
    return simplified
end

-- ============================================================================
-- AUTO-HULL-DETECTION
-- Scannt die Map-Geometrie basierend auf Orientierungspunkten
-- ============================================================================

local function ScanHullFromPoints(orientationPoints, resolution)
    if #orientationPoints < 3 then return {} end
    
    resolution = math.Clamp(resolution or 50, 20, 500)
    
    -- Bounding-Box berechnen
    local mins, maxs = EGC_SHIP.CalculateBoundingBox(orientationPoints)
    local center = (mins + maxs) / 2
    
    -- Scan-Bereich erweitern
    local scanHeight = CFG.ScanHeight or 500
    mins.z = mins.z - scanHeight
    maxs.z = maxs.z + scanHeight
    
    local hullPoints = {}
    local scanned = {}  -- Duplikate vermeiden
    local mask = MASK_SOLID_BRUSHONLY
    
    -- Von allen 6 Seiten scannen
    local directions = {
        { axis = "x", dir = Vector(1, 0, 0),  start = mins.x - 100 },
        { axis = "x", dir = Vector(-1, 0, 0), start = maxs.x + 100 },
        { axis = "y", dir = Vector(0, 1, 0),  start = mins.y - 100 },
        { axis = "y", dir = Vector(0, -1, 0), start = maxs.y + 100 },
        { axis = "z", dir = Vector(0, 0, 1),  start = mins.z - 100 },
        { axis = "z", dir = Vector(0, 0, -1), start = maxs.z + 100 },
    }
    
    for _, scan in ipairs(directions) do
        local ranges = {}
        
        if scan.axis == "x" then
            ranges = {
                { from = mins.y, to = maxs.y, var = "y" },
                { from = mins.z, to = maxs.z, var = "z" },
            }
        elseif scan.axis == "y" then
            ranges = {
                { from = mins.x, to = maxs.x, var = "x" },
                { from = mins.z, to = maxs.z, var = "z" },
            }
        else
            ranges = {
                { from = mins.x, to = maxs.x, var = "x" },
                { from = mins.y, to = maxs.y, var = "y" },
            }
        end
        
        -- Grid durchgehen
        for v1 = ranges[1].from, ranges[1].to, resolution do
            for v2 = ranges[2].from, ranges[2].to, resolution do
                local startPos = Vector(0, 0, 0)
                
                if scan.axis == "x" then
                    startPos = Vector(scan.start, v1, v2)
                elseif scan.axis == "y" then
                    startPos = Vector(v1, scan.start, v2)
                else
                    startPos = Vector(v1, v2, scan.start)
                end
                
                local endPos = startPos + scan.dir * 10000
                
                local tr = util.TraceLine({
                    start = startPos,
                    endpos = endPos,
                    mask = mask,
                })
                
                if tr.Hit then
                    -- Jede Geometrie zählt (nicht nur HitWorld – funktioniert auch auf Displacements/Props)
                    -- Duplikat-Check (runde auf 10er)
                    local key = string.format("%.0f_%.0f_%.0f",
                        math.Round(tr.HitPos.x / 10) * 10,
                        math.Round(tr.HitPos.y / 10) * 10,
                        math.Round(tr.HitPos.z / 10) * 10)
                    
                    if not scanned[key] then
                        scanned[key] = true
                        table.insert(hullPoints, tr.HitPos)
                    end
                end
            end
        end
    end
    
    -- Zu Convex Hull vereinfachen
    if #hullPoints > (CFG.MaxHullPoints or 128) then
        hullPoints = SimplifyPointCloud(hullPoints, CFG.MaxHullPoints or 128)
    end
    
    print(string.format("[EGC Shield] Hull-Scan: %d Punkte gefunden", #hullPoints))
    return hullPoints
end

-- ============================================================================
-- TOOL NETZWERK-EMPFANG
-- ============================================================================

-- Einzelner Punkt (wird nur für Vorschau genutzt)
net.Receive("EGC_Shield_ToolPoint", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    -- Punkte werden client-seitig verwaltet
end)

-- Punkte löschen
net.Receive("EGC_Shield_ToolClear", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    -- Client-seitig
end)

-- Finish: Hull-Scan oder Gate erstellen
net.Receive("EGC_Shield_ToolFinish", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then
        net.Start("EGC_Shield_ScanResult")
        net.WriteBool(false)
        net.WriteUInt(0, 16)
        net.Send(ply)
        return
    end

    local entIndex = net.ReadUInt(16)
    local mode = net.ReadString()  -- "hull" oder "gate"
    local resolution = net.ReadUInt(16)
    local numPoints = net.ReadUInt(16)
    
    -- Generator finden
    local generator = Entity(entIndex)
    if not IsValid(generator) or generator:GetClass() ~= "egc_shield_generator" then
        net.Start("EGC_Shield_ScanResult")
        net.WriteBool(false)
        net.WriteUInt(0, 16)
        net.Send(ply)
        return
    end
    
    -- Punkte lesen
    local points = {}
    for i = 1, numPoints do
        local p = net.ReadVector()
        if EGC_SHIP.ValidateVector(p) then
            table.insert(points, p)
        end
    end
    
    if #points < 3 then
        net.Start("EGC_Shield_ScanResult")
        net.WriteBool(false)
        net.WriteUInt(0, 16)
        net.Send(ply)
        return
    end
    
    if mode == "hull" then
        -- Hull-Scan durchführen
        print("[EGC Shield] Starte Hull-Scan...")
        local hullMesh = ScanHullFromPoints(points, resolution)
        
        -- Fallback: Wenn Scan zu wenig Punkte liefert (z. B. flache Map), Polygon aus gesetzten Punkten nutzen
        if #hullMesh < 3 then
            hullMesh = table.Copy(points)
            print("[EGC Shield] Scan lieferte " .. #hullMesh .. " Punkte – nutze Orientierungspunkte als Hull.")
        end
        
        if #hullMesh < 3 then
            net.Start("EGC_Shield_ScanResult")
            net.WriteBool(false)
            net.WriteUInt(0, 16)
            net.Send(ply)
            return
        end
        
        -- Am Generator speichern
        generator:SetHullData(points, hullMesh)
        
        -- Erfolg an Client
        net.Start("EGC_Shield_ScanResult")
        net.WriteBool(true)
        net.WriteUInt(#hullMesh, 16)
        net.Send(ply)
        
        -- Full Sync an alle
        BroadcastGeneratorSync(generator)
        
    elseif mode == "gate" then
        -- Gate erstellen (Punkte direkt als Mesh)
        local success = generator:AddGate(points, points)
        
        net.Start("EGC_Shield_ScanResult")
        net.WriteBool(success)
        net.WriteUInt(#points, 16)
        net.Send(ply)
        
        if success then
            BroadcastGeneratorSync(generator)
        end
    end
end)

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
            gates = genData.gates,
        })
    end
    
    local json = util.TableToJSON(data, true)
    local folder = CFG.DataFolder or "egc_ship_shields"
    
    if not file.IsDir(folder, "DATA") then
        file.CreateDir(folder, "DATA")
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
            
            -- Daten wiederherstellen
            timer.Simple(0.1, function()
                if IsValid(ent) then
                    ent:SetHullData(genSave.hullPoints, genSave.hullMesh)
                    
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
