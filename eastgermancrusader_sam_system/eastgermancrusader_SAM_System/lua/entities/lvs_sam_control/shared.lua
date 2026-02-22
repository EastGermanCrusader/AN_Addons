-- EastGermanCrusader SAM System - Torpedo Kontrollstation
-- Zentrale Steuerung für VLS Abschuss

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Torpedo Kontrollstation"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Steuert VLS-Systeme - Zielerfassung und Abschussfreigabe"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.RenderGroup = RENDERGROUP_OPAQUE

-- Modell
ENT.Model = "models/lt_c/sci_fi/ground_locker_small.mdl"

-- Kontrollstation Konfiguration
ENT.ControlRange = math.huge      -- Unendliche Reichweite zu VLS-Systemen
ENT.RadarRange = 50000            -- Radar-Reichweite für Zielerfassung
ENT.MaxSalvoSize = 8              -- Maximale Raketen pro Salve

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Active")
    self:NetworkVar("Bool", 1, "Scanning")
    self:NetworkVar("Bool", 2, "Armed")           -- NEU: Raketen scharf?
    self:NetworkVar("Bool", 3, "AlarmActive")     -- NEU: Alarm aktiv?
    self:NetworkVar("Entity", 0, "Operator")
    self:NetworkVar("Entity", 1, "SelectedTarget")
    self:NetworkVar("Int", 0, "SalvoSize")        -- DEPRECATED: Wird nicht mehr verwendet
    self:NetworkVar("Int", 1, "TotalMissiles")
    self:NetworkVar("Int", 2, "ConnectedVLS")
    self:NetworkVar("Int", 3, "ActiveMissiles")   -- NEU: Fliegende Raketen
    
    if SERVER then
        self:SetActive(true)
        self:SetScanning(true)
        self:SetSalvoSize(1)
        self:SetArmed(false)
        self:SetAlarmActive(false)
        self:SetActiveMissiles(0)
        -- Liste der ausgewählten VLS-Systeme (Entity-IDs)
        self._selectedVLS = {}
    end
end
