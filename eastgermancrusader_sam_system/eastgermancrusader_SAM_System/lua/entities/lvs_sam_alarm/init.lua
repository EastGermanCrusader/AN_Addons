-- EastGermanCrusader SAM System - Alarm Lampe Server

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.Model)
    
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(30)
    end
    
    -- Gesundheit
    self:SetMaxHealth(150)
    self:SetHealth(150)
    
    print("[SAM Alarm] Alarm-Lampe initialisiert")
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local station = self:GetLinkedStation()
    if IsValid(station) then
        activator:ChatPrint("[SAM Alarm] Verbunden mit Kontrollstation")
    else
        activator:ChatPrint("[SAM Alarm] Keine Kontrollstation in Reichweite")
    end
    
    local alarmActive = self:GetAlarmActive()
    activator:ChatPrint("[SAM Alarm] Status: " .. (alarmActive and "ALARM AKTIV" or "Standby"))
end

function ENT:OnTakeDamage(dmginfo)
    local damage = dmginfo:GetDamage()
    self:SetHealth(self:Health() - damage)
    
    if self:Health() <= 0 then
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        util.Effect("Explosion", effectdata)
        self:Remove()
    end
end

-- ============================================
-- ALARM FUNKTIONEN
-- ============================================

function ENT:ActivateAlarm()
    self:SetAlarmActive(true)
end

function ENT:DeactivateAlarm()
    self:SetAlarmActive(false)
end

-- ============================================
-- THINK - Suche nach Kontrollstationen
-- ============================================

function ENT:Think()
    local T = CurTime()
    
    -- Alle 2 Sekunden nach Kontrollstation suchen
    if not self._lastSearch or T - self._lastSearch > 2 then
        self._lastSearch = T
        
        local nearestStation = nil
        local nearestDist = self.LinkRange
        
        for _, ent in pairs(ents.FindByClass("lvs_sam_control")) do
            if IsValid(ent) then
                local dist = self:GetPos():Distance(ent:GetPos())
                if dist < nearestDist then
                    nearestDist = dist
                    nearestStation = ent
                end
            end
        end
        
        self:SetLinkedStation(nearestStation or NULL)
    end
    
    self:NextThink(T + 0.5)
    return true
end
