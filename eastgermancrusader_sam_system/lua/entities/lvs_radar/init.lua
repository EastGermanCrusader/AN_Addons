-- EastGermanCrusader SAM System - Radar Server

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.Model)
    
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(150)
    end
    
    -- Gesundheit
    self:SetMaxHealth(400)
    self:SetHealth(400)
    
    print("[Radar] Initialisiert")
end

function ENT:OnTakeDamage(dmginfo)
    local damage = dmginfo:GetDamage()
    self:SetHealth(self:Health() - damage)
    
    if self:Health() <= 0 and not self:GetDestroyed() then
        self:SetDestroyed(true)
        self:SetActive(false)
        
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        util.Effect("Explosion", effectdata)
        self:EmitSound("ambient/explosions/explode_4.wav", 100, 100)
        
        print("[Radar] Zerstört - Fahrzeug-Erfassung nicht mehr verfügbar")
    end
end

function ENT:Think()
    -- Rotiere die Radar-Schüssel langsam
    if not self:GetDestroyed() then
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 10 * FrameTime())
        self:SetAngles(ang)
    end
    
    self:NextThink(CurTime() + 0.1)
    return true
end
