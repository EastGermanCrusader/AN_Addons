AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    -- Verwende ein Standard-Modell für Bolzen
    -- Versuche verschiedene Modell-Pfade
    local modelPaths = {
        "models/weapons/w_models/w_arrow.mdl",
        "models/weapons/w_models/w_bolt.mdl",
        "models/hunter/misc/sphere025x025.mdl" -- Fallback
    }
    
    local modelSet = false
    for _, path in ipairs(modelPaths) do
        if util.IsValidModel(path) then
            self:SetModel(path)
            modelSet = true
            break
        end
    end
    
    if not modelSet then
        -- Letzter Fallback
        self:SetModel("models/hunter/misc/sphere025x025.mdl")
    end
    
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
    
    -- Sichtbar machen
    self:SetNoDraw(false)
    self:DrawShadow(true)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(0.1)
        phys:EnableGravity(true)
        phys:SetMaterial("metal")
    end
    
    -- Bolzen-Eigenschaften
    self.Damage = 20 -- Schaden (nur verletzen, nicht töten)
    self.Speed = 2000 -- Geschwindigkeit
    self.Lifetime = 5 -- Lebensdauer in Sekunden
    
    -- Entferne nach Lebensdauer
    timer.Simple(self.Lifetime, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
end

function ENT:PhysicsCollide(data, phys)
    if not IsValid(self) then return end
    
    local hitEnt = data.HitEntity
    
    -- Wenn wir etwas getroffen haben
    if IsValid(hitEnt) then
        -- Schaden nur an Spielern und NPCs (nur verletzen, nicht töten)
        if hitEnt:IsPlayer() or hitEnt:IsNPC() then
            local owner = self:GetOwner()
            local dmg = DamageInfo()
            dmg:SetDamage(self.Damage)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamageForce(data.OurOldVelocity:GetNormalized() * 100)
            dmg:SetDamagePosition(data.HitPos)
            
            -- Stelle sicher, dass der Spieler nicht stirbt (maximal auf 1 HP reduzieren)
            local currentHealth = hitEnt:Health()
            if currentHealth > 1 then
                hitEnt:TakeDamageInfo(dmg)
                
                -- Falls der Schaden den Spieler töten würde, setze HP auf 1
                if hitEnt:Health() <= 0 then
                    hitEnt:SetHealth(1)
                end
            end
        end
        
        -- Sound-Effekt
        self:EmitSound("weapons/crossbow/hitbod" .. math.random(1, 2) .. ".wav", 75, 100)
        
        -- Impact-Effekt
        local effectdata = EffectData()
        effectdata:SetOrigin(data.HitPos)
        effectdata:SetNormal(data.HitNormal)
        util.Effect("BloodImpact", effectdata)
    else
        -- Wand-Treffer
        self:EmitSound("weapons/crossbow/hit" .. math.random(1, 2) .. ".wav", 75, 100)
        
        local effectdata = EffectData()
        effectdata:SetOrigin(data.HitPos)
        effectdata:SetNormal(data.HitNormal)
        util.Effect("Impact", effectdata)
    end
    
    -- Bolzen stecken lassen (Physik einfrieren)
    phys:EnableMotion(false)
    self:SetMoveType(MOVETYPE_NONE)
    
    -- Entferne nach kurzer Zeit
    timer.Simple(2, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
end

function ENT:SetVelocity(vel)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(vel)
    end
end
