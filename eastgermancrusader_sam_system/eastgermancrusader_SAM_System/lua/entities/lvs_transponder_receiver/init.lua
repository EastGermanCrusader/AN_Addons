-- EastGermanCrusader SAM System - Transponder Receiver Server

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
        phys:SetMass(100)
    end
    
    -- Gesundheit
    self:SetMaxHealth(300)
    self:SetHealth(300)
    
    print("[Transponder Receiver] Initialisiert")
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
        
        print("[Transponder Receiver] Zerstört - Fahrzeug-Identifikation nicht mehr verfügbar")
    end
end

function ENT:Think()
    -- Regelmäßige Updates
    self:NextThink(CurTime() + 1)
    return true
end
