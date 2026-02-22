-- EastGermanCrusader SAM System - Transponder Receiver
-- Empfängt Transponder-Signale von Fahrzeugen für Identifikation

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Transponder Receiver"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Empfängt Transponder-Signale zur Fahrzeug-Identifikation"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.RenderGroup = RENDERGROUP_OPAQUE

-- Modell
ENT.Model = "models/reizer_props/alysseum_project/antennas/antenna_01/antenna_01.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Active")
    self:NetworkVar("Bool", 1, "Destroyed")
    
    if SERVER then
        self:SetActive(true)
        self:SetDestroyed(false)
    end
end
