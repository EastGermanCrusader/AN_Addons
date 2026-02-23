-- eastgermancrusader_cctv/lua/entities/crusader_cctv_camera/init.lua
-- ============================================
-- OPTIMIERTE SERVER-SEITIGE KAMERA LOGIK
-- Nutzt gemeinsame Funktionen aus sh_config
-- Think-Intervall auf 1 Sekunde erhöht
-- ============================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Lokale Referenzen für Performance
local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
local math_max = math.max
local math_min = math.min

function ENT:Initialize()
    self:SetModel("models/reizer_props/alysseum_project/misc_stuff/cctv_01/cctv_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
    
    -- Standard-Werte
    self:SetCameraName("Kamera")
    self:SetCameraHealth(CCTV_HEALTH_MAX)
    self:SetIsActive(true)
    self:SetVideoActive(true)
    self:SetAudioActive(true)
    
    -- OPTIMIERT: Initialer Think-Zeitpunkt randomisiert (verteilt Last)
    self.NextThinkTime = CurTime() + math_random() * 2
end

-- Use-Taste schaltet Kamera ein/aus
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local wasActive = self:GetIsActive()
    local name = self:GetCameraName()
    
    if wasActive then
        self:SetIsActive(false)
        self:SetVideoActive(false)
        self:SetAudioActive(false)
        self:EmitSound("buttons/combine_button3.wav", 70, 100)
        activator:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera " .. name .. " DEAKTIVIERT")
    else
        self:SetIsActive(true)
        self:EmitSound("buttons/combine_button2.wav", 70, 100)
        
        timer.Simple(0.5, function()
            if IsValid(self) then
                self:UpdateDamageState()
                self:EmitSound("buttons/combine_button7.wav", 60, 120)
            end
        end)
        
        activator:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera " .. name .. " AKTIVIERT")
    end
end

function ENT:CanProperty(ply, property)
    return true
end

-- ============================================
-- SCHADENS-SYSTEM (Nutzt gemeinsame Funktion)
-- ============================================
function ENT:OnTakeDamage(dmginfo)
    CRUSADER_CCTV_SHARED.OnTakeDamage(self, dmginfo)
    
    -- Think reaktivieren wenn Kamera jetzt beschädigt ist
    local health = self:GetCameraHealth()
    if health > 0 and health <= CCTV_HEALTH_AUDIO_THRESHOLD then
        self:NextThink(CurTime() + 0.5)
    end
end

function ENT:UpdateDamageState()
    CRUSADER_CCTV_SHARED.UpdateDamageState(self)
end

-- ============================================
-- REPARATUR-SYSTEM (Nutzt gemeinsame Funktion)
-- ============================================
function ENT:LVSRepair(ply, amount)
    return CRUSADER_CCTV_SHARED.RepairCamera(self, amount or 10, ply)
end

function ENT:Repair(amount, ply)
    return CRUSADER_CCTV_SHARED.RepairCamera(self, amount or 10, ply)
end

function ENT:RepairCamera(amount, ply)
    return CRUSADER_CCTV_SHARED.RepairCamera(self, amount, ply)
end

-- ============================================
-- STARK OPTIMIERT: Think NUR bei beschädigten Kameras
-- Bei 20-50 Spielern aber nur 2-3 CCTV-Nutzern spart das enorm CPU
-- ============================================
function ENT:Think()
    local health = self:GetCameraHealth()
    
    -- KRITISCH: Gesunde Kameras brauchen KEIN Think!
    -- Think nur bei kritischem Schaden für zufällige Statusänderungen
    if health > CCTV_HEALTH_AUDIO_THRESHOLD or health <= 0 then
        -- Kamera ist entweder gesund oder zerstört - kein Think nötig
        -- NextThink wird NICHT aufgerufen = Think deaktiviert
        return false
    end
    
    -- Nur beschädigte Kameras (0 < health <= 40) brauchen Think
    if math_random() < 0.15 then
        self:UpdateDamageState()
    end
    
    -- Langsames Intervall für beschädigte Kameras
    self:NextThink(CurTime() + 2)
    return true
end

-- Think reaktivieren wenn Kamera beschädigt wird
function ENT:OnHealthChanged()
    local health = self:GetCameraHealth()
    if health > 0 and health <= CCTV_HEALTH_AUDIO_THRESHOLD then
        -- Think wieder aktivieren
        self:NextThink(CurTime() + 0.1)
    end
end
