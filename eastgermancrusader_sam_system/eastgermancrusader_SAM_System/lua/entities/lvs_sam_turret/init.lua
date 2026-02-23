-- EastGermanCrusader SAM System - VLS Server-seitiger Code
-- Nur manuell steuerbar über Torpedo Kontrollstation

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Netzwerk für Nickname
util.AddNetworkString("EGC_SAM_SetVLSNickname")
util.AddNetworkString("EGC_SAM_OpenVLSNicknameMenu")

function ENT:Initialize()
    self:SetModel(self.Model)
    
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(500)
    end
    
    -- Gesundheit
    self:SetMaxHealth(self.MaxHealth)
    self:SetHealth(self.MaxHealth)
    
    -- Initialisiere Munition
    self:SetMissileCount(self.SAM_MissileCount)
    
    -- Initialisiere Nickname
    self:SetNickname("")
    
    -- Interne Variablen
    self._lastFireTime = 0
    self._reloadStartTime = nil
    
    print("[VLS] System initialisiert - " .. self.SAM_MissileCount .. " Torpedos geladen")
    print("[VLS] Steuerung nur über Torpedo Kontrollstation möglich")
end

-- Kontextmenü (C + Rechtsklick) - Server-seitig
function ENT:OnContextMenu(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe Entfernung
    if ply:GetPos():Distance(self:GetPos()) > 500 then return end
    
    -- Sende Netzwerk-Nachricht an Client, um Menü zu öffnen
    net.Start("EGC_SAM_OpenVLSNicknameMenu")
    net.WriteEntity(self)
    net.Send(ply)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    -- Info-Nachricht
    local ammo = self:GetMissileCount()
    local maxAmmo = self.SAM_MissileCount
    local nickname = self:GetNickname()
    
    activator:ChatPrint("[VLS] Status: " .. ammo .. "/" .. maxAmmo .. " Torpedos")
    if nickname and nickname ~= "" then
        activator:ChatPrint("[VLS] Nickname: " .. nickname)
    end
    activator:ChatPrint("[VLS] Steuerung nur über Torpedo Kontrollstation möglich!")
    activator:ChatPrint("[VLS] Drücke C für Kontextmenü (Nickname setzen)")
end


function ENT:OnTakeDamage(dmginfo)
    local damage = dmginfo:GetDamage()
    self:SetHealth(self:Health() - damage)
    
    if self:Health() <= 0 then
        self:Explode()
    end
end

function ENT:Explode()
    local pos = self:GetPos()
    
    -- Explosion
    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetScale(3)
    util.Effect("Explosion", effectdata)
    
    -- Schaden
    util.BlastDamage(self, self, pos, 300, 200)
    
    -- Sound
    self:EmitSound("ambient/explosions/explode_4.wav", 120, 100)
    
    self:Remove()
end

-- ============================================
-- RAKETEN ABFEUERN (wird von Kontrollstation aufgerufen)
-- ============================================

function ENT:LaunchMissile(target)
    if not IsValid(target) then return nil end
    
    local curAmmo = self:GetMissileCount()
    if curAmmo <= 0 then return nil end
    
    -- Cooldown zwischen Schüssen
    if CurTime() - (self._lastFireTime or 0) < 2.5 then return nil end
    
    local Pos = self:GetLaunchPosition()
    local Dir = self:GetLaunchDirection()
    
    -- SAM Torpedo spawnen (Ballistische Kurve)
    local torpedo = ents.Create("lvs_sam_torpedo")
    if not IsValid(torpedo) then return nil end
    
    torpedo:SetPos(Pos)
    torpedo:SetAngles(Dir:Angle())
    torpedo:SetOwner(self)
    torpedo:Spawn()
    torpedo:Activate()
    
    -- LVS Missile Einstellungen
    torpedo:SetAttacker(self)
    torpedo:SetTarget(target)
    torpedo:SetDamage(600)
    torpedo:SetRadius(400)
    torpedo:SetEntityFilter({self})
    
    -- Launch-Richtung setzen (basierend auf Modell-Rotation)
    torpedo:SetLaunchDirection(Dir)
    
    -- Aktivieren (startet Boost-Phase)
    torpedo:Enable()
    
    -- Startgeschwindigkeit in Abschussrichtung
    local phys = torpedo:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(Dir * 1000) -- Schneller Start in Schussrichtung
    end
    
    -- Munition reduzieren
    self:SetMissileCount(curAmmo - 1)
    self._lastFireTime = CurTime()
    
    -- Launch Sound
    self:EmitSound("weapons/rpg/rocketfire1.wav", 100, 110)
    self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav", 90, 90)
    
    -- Rauch-Effekt beim Start
    local smokeEffect = EffectData()
    smokeEffect:SetOrigin(Pos)
    smokeEffect:SetNormal(Dir)
    smokeEffect:SetScale(3)
    util.Effect("WheelDust", smokeEffect)
    
    -- Muzzle Flash Effekt
    local muzzle = EffectData()
    muzzle:SetOrigin(Pos)
    muzzle:SetNormal(Dir)
    muzzle:SetScale(1)
    util.Effect("MuzzleEffect", muzzle)
    
    -- Ziel-Warnung
    if EGC_SAM_SendMissileWarning then
        EGC_SAM_SendMissileWarning(target, torpedo)
    end
    
    print("[VLS] Torpedo abgefeuert! Verbleibend: " .. (curAmmo - 1))
    
    -- Rakete zurückgeben für Tracking
    return torpedo
end

-- ============================================
-- NACHLADEN
-- ============================================

function ENT:ReloadMissile()
    local currentCount = self:GetMissileCount()
    
    if currentCount >= self.SAM_MissileCount then return end
    
    if not self._reloadStartTime then
        self._reloadStartTime = CurTime()
    end
    
    local reloadTime = CurTime() - self._reloadStartTime
    
    if reloadTime >= self.SAM_ReloadTime then
        self:SetMissileCount(currentCount + 1)
        self._reloadStartTime = nil
        self:EmitSound("weapons/357/357_reload4.wav", 70, 80)
    end
end

-- ============================================
-- THINK LOOP (nur Nachladen)
-- ============================================

function ENT:Think()
    local T = CurTime()
    
    -- Nachladen
    self:ReloadMissile()
    
    self:NextThink(T + 0.5)
    return true
end

-- ============================================
-- NETZWERK EMPFANG
-- ============================================

net.Receive("EGC_SAM_SetVLSNickname", function(len, ply)
    local vls = net.ReadEntity()
    local nickname = net.ReadString()
    
    if not IsValid(vls) or vls:GetClass() ~= "lvs_sam_turret" then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Prüfe ob Spieler in der Nähe ist (500 Einheiten)
    if ply:GetPos():Distance(vls:GetPos()) > 500 then return end
    
    -- Setze Nickname (maximal 30 Zeichen)
    nickname = string.sub(nickname, 1, 30)
    vls:SetNickname(nickname)
    
    if nickname == "" then
        ply:ChatPrint("[VLS] Nickname entfernt")
    else
        ply:ChatPrint("[VLS] Nickname gesetzt: " .. nickname)
    end
end)
