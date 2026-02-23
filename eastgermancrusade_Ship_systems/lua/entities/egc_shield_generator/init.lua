--[[
    EGC Shield Generator Entity - Server
    Verwaltet Schild-Status, Energie, Schaden
]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local cfg = EGC_SHIP and EGC_SHIP.Config or {}
    local model = cfg.GeneratorModel or "models/props_c17/consolebox01a.mdl"
    
    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
    
    -- Initialisiere Schild-Werte
    self:SetShieldPercent(100)
    self:SetPowerLevel(cfg.MaxPowerOutput or 1000)
    self:SetShieldActive(true)
    self:SetIsRecharging(false)
    self:SetSectorName("Sektor")
    
    -- Health
    self:SetMaxHealth(cfg.GeneratorHealth or 500)
    self:SetHealth(cfg.GeneratorHealth or 500)
    
    -- Registriere im globalen System
    self:RegisterGenerator()
    
    -- Starte Update-Timer
    self.NextRegenTick = CurTime()
    self.NextBroadcast = CurTime()
end

function ENT:RegisterGenerator()
    if not EGC_SHIP then return end
    
    local entIndex = self:EntIndex()
    EGC_SHIP.Generators[entIndex] = EGC_SHIP.CreateGeneratorData(entIndex)
    
    -- Verknüpfe mit Entity
    local genData = EGC_SHIP.Generators[entIndex]
    genData.entity = self
    genData.sectorName = self:GetSectorName()
    
    print("[EGC Shield] Generator registriert: #" .. entIndex)
end

function ENT:UnregisterGenerator()
    if not EGC_SHIP then return end

    self:RemoveShieldSectors()

    local entIndex = self:EntIndex()
    if EGC_SHIP.Generators[entIndex] then
        EGC_SHIP.Generators[entIndex] = nil
        print("[EGC Shield] Generator entfernt: #" .. entIndex)
    end
end

function ENT:OnRemove()
    self:UnregisterGenerator()
end

function ENT:Think()
    local cfg = EGC_SHIP and EGC_SHIP.Config or {}
    local now = CurTime()
    
    -- Regeneration
    if now >= self.NextRegenTick then
        self.NextRegenTick = now + (cfg.RegenTickInterval or 0.5)
        self:DoRegenTick()
    end
    
    -- Broadcast zu Clients
    if now >= self.NextBroadcast then
        self.NextBroadcast = now + (cfg.BroadcastInterval or 0.25)
        self:BroadcastState()
    end
    
    self:NextThink(now + 0.1)
    return true
end

function ENT:DoRegenTick()
    local cfg = EGC_SHIP and EGC_SHIP.Config or {}
    local tickInterval = cfg.RegenTickInterval or 0.5
    
    -- Recharge-Modus prüfen
    if self:GetIsRecharging() then
        local genData = self:GetGeneratorData()
        if genData and genData.rechargeTime and CurTime() >= genData.rechargeTime then
            self:SetIsRecharging(false)
            self:SetShieldPercent(10)  -- Startet mit 10%
        end
        return
    end
    
    -- Schild-Regeneration
    if self:GetShieldActive() and self:GetShieldPercent() < 100 then
        local powerMult = self:GetPowerLevel() / (cfg.MaxPowerOutput or 1000)
        local regenAmount = (cfg.ShieldRegenRate or 2) * tickInterval * powerMult * (cfg.ShieldRegenPowerMult or 0.5)
        
        local newShield = math.min(100, self:GetShieldPercent() + regenAmount)
        self:SetShieldPercent(newShield)
        
        -- Generator-Daten aktualisieren
        local genData = self:GetGeneratorData()
        if genData then
            genData.shieldPercent = newShield
        end
    end
    
    -- Energie-Regeneration
    local maxPower = cfg.MaxPowerOutput or 1000
    if self:GetPowerLevel() < maxPower then
        local regenAmount = (cfg.PowerRegenRate or 10) * tickInterval
        self:SetPowerLevel(math.min(maxPower, self:GetPowerLevel() + regenAmount))
        
        local genData = self:GetGeneratorData()
        if genData then
            genData.powerLevel = self:GetPowerLevel()
        end
    end
end

function ENT:BroadcastState()
    -- Nur wenn sich etwas geändert hat
    local genData = self:GetGeneratorData()
    if not genData then return end
    
    -- State für schnelle Updates (kein volles Sync nötig)
    net.Start("EGC_Shield_Update")
    net.WriteUInt(self:EntIndex(), 16)
    net.WriteFloat(self:GetShieldPercent())
    net.WriteFloat(self:GetPowerLevel())
    net.WriteBool(self:GetShieldActive())
    net.WriteBool(self:GetIsRecharging())
    net.Broadcast()
end

function ENT:GetGeneratorData()
    if not EGC_SHIP then return nil end
    return EGC_SHIP.Generators[self:EntIndex()]
end

-- Schaden am Schild
function ENT:ApplyShieldDamage(amount, damageType)
    if not self:GetShieldActive() or self:GetIsRecharging() then return end
    
    local cfg = EGC_SHIP and EGC_SHIP.Config or {}
    
    -- Multiplikator je nach Schadenstyp
    local mult = cfg.BulletDamageToShield or 0.5
    if damageType and bit.band(damageType, DMG_BLAST) > 0 then
        mult = cfg.ExplosionDamageToShield or 2.0
    end
    
    local shieldDamage = amount * mult
    local newShield = self:GetShieldPercent() - shieldDamage
    
    -- Energie verbrauchen
    local powerDrain = cfg.PowerDrainPerHit or 5
    self:SetPowerLevel(math.max(0, self:GetPowerLevel() - powerDrain))
    
    if newShield <= 0 then
        -- Schild kollabiert
        self:SetShieldPercent(0)
        self:SetShieldActive(false)
        self:SetIsRecharging(true)
        
        local genData = self:GetGeneratorData()
        if genData then
            genData.shieldPercent = 0
            genData.active = false
            genData.recharging = true
            genData.rechargeTime = CurTime() + (cfg.ShieldDownDuration or 10)
        end
        
        -- Effekt
        local effectData = EffectData()
        effectData:SetOrigin(self:GetPos())
        effectData:SetScale(2)
        util.Effect("cball_explode", effectData)
        
        self:EmitSound("ambient/energy/zap" .. math.random(1,9) .. ".wav", 75, 100)
        
        print("[EGC Shield] Schild kollabiert!")
    else
        self:SetShieldPercent(newShield)
        
        local genData = self:GetGeneratorData()
        if genData then
            genData.shieldPercent = newShield
        end
    end
    
    -- Hit-Effekt an Clients senden
    net.Start("EGC_Shield_Hit")
    net.WriteUInt(self:EntIndex(), 16)
    net.WriteFloat(shieldDamage)
    net.Broadcast()
end

-- Interaktion
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    -- Öffne Konfiguration (später implementieren)
    activator:ChatPrint("[Schildgenerator] Schild: " .. math.Round(self:GetShieldPercent()) .. "% | Energie: " .. math.Round(self:GetPowerLevel()))
end

-- Physischer Schaden am Generator selbst
function ENT:OnTakeDamage(dmginfo)
    -- Wenn Schild aktiv, Schaden dorthin leiten
    if self:GetShieldActive() and self:GetShieldPercent() > 0 then
        self:ApplyShieldDamage(dmginfo:GetDamage(), dmginfo:GetDamageType())
        return
    end
    
    -- Sonst normaler Schaden am Generator
    self:SetHealth(self:Health() - dmginfo:GetDamage())
    
    if self:Health() <= 0 then
        local effectData = EffectData()
        effectData:SetOrigin(self:GetPos())
        effectData:SetScale(3)
        util.Effect("Explosion", effectData)
        
        self:Remove()
    end
end

-- Poly-Shield: Erstellt Sektor aus Vertices + Dreiecks-Indizes (exakte Kanten)
function ENT:CreatePolyShieldFromTriangles(vertices, faces)
    local genData = self:GetGeneratorData()
    if not genData or not vertices or #vertices < 3 or not faces or #faces == 0 then return nil end

    local triangles = {}
    for _, f in ipairs(faces) do
        if #f >= 3 and f[1] >= 1 and f[1] <= #vertices and f[2] >= 1 and f[2] <= #vertices and f[3] >= 1 and f[3] <= #vertices then
            table.insert(triangles, {
                vertices[f[1]],
                vertices[f[2]],
                vertices[f[3]],
            })
        end
    end
    if #triangles == 0 then return nil end

    local sector = ents.Create("egc_shield_sector")
    if not IsValid(sector) then return nil end
    sector:SetPos(vertices[1])
    sector:Spawn()
    sector:SetMeshTriangles(triangles)
    sector:SetGenerator(self)

    self:RemoveShieldSectors()
    genData.sectors = { sector }
    genData.sectorPoints = nil
    genData.polyVertices = vertices
    genData.polyFaces = faces

    -- Bounds für Ray-Check (optional)
    genData.hullCenter, genData.hullRadius = EGC_SHIP.CalculateBounds(vertices)
    genData.hullMesh = vertices

    print("[EGC Shield] Poly-Shield erstellt: " .. #triangles .. " Dreiecke, " .. #vertices .. " Vertices")
    return sector
end

-- Hull-Wrapping: Erstellt ein physisches Sektor-Entity aus Punkten (Prisma)
function ENT:CreateShieldSectorFromPoints(points)
    local genData = self:GetGeneratorData()
    if not genData or not points or #points < 4 then return nil end

    local sector = ents.Create("egc_shield_sector")
    if not IsValid(sector) then return nil end

    sector:SetPos(points[1]) -- wird in GenerateFromPoints auf Zentrum gesetzt
    sector:Spawn()
    sector:GenerateFromPoints(points)
    sector:SetGenerator(self)

    genData.sectors = genData.sectors or {}
    table.insert(genData.sectors, sector)
    genData.sectorPoints = points

    print("[EGC Shield] Sektor aus " .. #points .. " Punkten erstellt (Hull-Wrapping)")
    return sector
end

-- Alte Sektor-Entities entfernen
function ENT:RemoveShieldSectors()
    local genData = self:GetGeneratorData()
    if not genData or not genData.sectors then return end
    for _, sector in ipairs(genData.sectors) do
        if IsValid(sector) then sector:Remove() end
    end
    genData.sectors = {}
end

-- Hull/Gate-Daten setzen (vom Tool). skipSectorCreation = true beim Laden aus Save.
function ENT:SetHullData(hullPoints, hullMesh, skipSectorCreation)
    local genData = self:GetGeneratorData()
    if not genData then return end

    genData.hullPoints = hullPoints or {}
    genData.hullMesh = hullMesh or {}

    -- Bounds berechnen
    if #genData.hullMesh > 0 then
        genData.hullCenter, genData.hullRadius = EGC_SHIP.CalculateBounds(genData.hullMesh)
    end

    -- Hull-Wrapping: Physischen Sektor aus Orientierungspunkten erstellen (Prisma)
    if not skipSectorCreation then
        self:RemoveShieldSectors()
        if #(hullPoints or {}) >= 4 then
            self:CreateShieldSectorFromPoints(hullPoints)
        end
    end

    print("[EGC Shield] Hull-Daten gesetzt: " .. #genData.hullMesh .. " Mesh-Punkte")
end

function ENT:AddGate(gatePoints, gateMesh)
    local genData = self:GetGeneratorData()
    if not genData then return end
    
    local cfg = EGC_SHIP and EGC_SHIP.Config or {}
    if #genData.gates >= (cfg.MaxGatesPerGenerator or 8) then
        print("[EGC Shield] Max. Gates erreicht!")
        return false
    end
    
    local gate = EGC_SHIP.CreateGateData()
    gate.points = gatePoints or {}
    gate.mesh = gateMesh or {}
    
    if #gate.mesh > 0 then
        gate.center = EGC_SHIP.CalculateBounds(gate.mesh)
        gate.normal = EGC_SHIP.PolygonNormal(gate.mesh)
    end
    
    table.insert(genData.gates, gate)
    
    print("[EGC Shield] Gate hinzugefügt: " .. #gate.mesh .. " Punkte, Total: " .. #genData.gates)
    return true
end

function ENT:ClearGates()
    local genData = self:GetGeneratorData()
    if genData then
        genData.gates = {}
        print("[EGC Shield] Alle Gates gelöscht")
    end
end
