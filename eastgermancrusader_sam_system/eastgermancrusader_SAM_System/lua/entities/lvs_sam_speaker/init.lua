-- EastGermanCrusader SAM System - Alarm Lautsprecher Server

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
        phys:SetMass(50)
    end
    
    -- Gesundheit
    self:SetMaxHealth(200)
    self:SetHealth(200)
    
    -- Sound Objekt
    self._alarmSound = nil
    self._isPlaying = false
    
    print("[SAM Speaker] Lautsprecher initialisiert")
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local station = self:GetLinkedStation()
    if IsValid(station) then
        activator:ChatPrint("[SAM Speaker] Verbunden mit Kontrollstation")
    else
        activator:ChatPrint("[SAM Speaker] Keine Kontrollstation in Reichweite")
    end
    
    local alarmActive = self:GetAlarmActive()
    activator:ChatPrint("[SAM Speaker] Alarm: " .. (alarmActive and "AKTIV" or "Inaktiv"))
end

function ENT:OnTakeDamage(dmginfo)
    local damage = dmginfo:GetDamage()
    self:SetHealth(self:Health() - damage)
    
    if self:Health() <= 0 then
        self:StopAlarm()
        
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        util.Effect("Explosion", effectdata)
        self:Remove()
    end
end

-- ============================================
-- ALARM FUNKTIONEN
-- ============================================

function ENT:StartAlarm()
    if self._isPlaying then return end
    
    self:SetAlarmActive(true)
    self._isPlaying = true
    self._lastSoundPlay = 0  -- Sofort starten
    
    print("[SAM Speaker] Alarm gestartet!")
end

function ENT:StopAlarm()
    if not self._isPlaying then return end
    
    self:SetAlarmActive(false)
    self._isPlaying = false
    
    -- Sound stoppen
    if self._alarmSound then
        self._alarmSound:Stop()
        self._alarmSound = nil
    end
    
    print("[SAM Speaker] Alarm gestoppt!")
end

-- Sound abspielen (wird regelmäßig aufgerufen für Loop)
function ENT:PlayAlarmSound()
    -- EmitSound für den Loop - spielt den Sound ab
    -- Sound Level 120 (20% lauter als Standard 100)
    self:EmitSound(self.AlarmSound, 120, 100, 1, CHAN_STATIC)
end

-- ============================================
-- THINK - Suche nach Kontrollstationen & Sound Loop
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
    
    -- Sound Loop: Sound regelmäßig neu abspielen (für Dauerschleife)
    -- Intervall in shared.lua konfigurierbar (ENT.SoundLoopInterval)
    if self._isPlaying then
        if not self._lastSoundPlay or T - self._lastSoundPlay >= self.SoundLoopInterval then
            self._lastSoundPlay = T
            self:PlayAlarmSound()
        end
    end
    
    self:NextThink(T + 0.1)  -- Schnelleres Think für präzisen Sound-Loop
    return true
end

function ENT:OnRemove()
    self:StopAlarm()
end
