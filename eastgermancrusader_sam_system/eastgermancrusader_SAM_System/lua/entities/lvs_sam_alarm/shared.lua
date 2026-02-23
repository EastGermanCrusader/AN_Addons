-- EastGermanCrusader SAM System - Alarm Lampe
-- Leuchtet rot wenn Raketen scharf gemacht werden

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "SAM Alarm Lampe"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Alarm-Lampe für SAM System - Leuchtet rot bei Alarm"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.RenderGroup = RENDERGROUP_OPAQUE

-- Alarm Lampen Modell
ENT.Model = "models/lt_c/sci_fi/alarm.mdl"

-- Reichweite zur Kontrollstation
ENT.LinkRange = 5000

-- Licht-Einstellungen
ENT.LightRadius = 500
ENT.LightBrightness = 4

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "AlarmActive")
    self:NetworkVar("Entity", 0, "LinkedStation")
    
    if SERVER then
        self:SetAlarmActive(false)
    end
end
