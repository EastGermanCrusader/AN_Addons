-- EastGermanCrusader SAM System - Alarm Lautsprecher
-- Spielt Alarm-Sound ab wenn Raketen scharf gemacht werden

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "SAM Alarm Lautsprecher"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Lautsprecher für SAM Alarm - Verbindet sich automatisch mit Kontrollstationen"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.RenderGroup = RENDERGROUP_OPAQUE

-- Lautsprecher Modell
ENT.Model = "models/dav0r/thruster.mdl"

-- Alarm Sound
ENT.AlarmSound = "Radar_locket.wav"

-- Sound Loop Intervall (Sekunden) - Passe an die Länge des Sounds an
ENT.SoundLoopInterval = 1.2  -- Verkürzt für häufigere Alarm-Töne

-- Reichweite zur Kontrollstation
ENT.LinkRange = 5000

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "AlarmActive")
    self:NetworkVar("Entity", 0, "LinkedStation")
    
    if SERVER then
        self:SetAlarmActive(false)
    end
end
