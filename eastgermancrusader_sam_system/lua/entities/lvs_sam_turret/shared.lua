-- EastGermanCrusader SAM System - Vertical Launch System (VLS)
-- Torpedo Container - Nur manuell über Kontrollstation steuerbar

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "VLS Torpedo Container"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Torpedo Container - Steuerung nur über Kontrollstation"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminSpawnable = false

ENT.RenderGroup = RENDERGROUP_OPAQUE

-- VLS Container Modell (Fass)
ENT.Model = "models/niksacokica/containers/con_toxicwaste_barrel.mdl"

-- VLS Gesundheit
ENT.MaxHealth = 3000

-- VLS System Konfiguration
ENT.SAM_MissileCount = 4          -- Anzahl Torpedos im Container
ENT.SAM_ReloadTime = 5.0          -- Nachladezeit pro Torpedo

-- Torpedo startet von der Oberseite (Deckel) des Containers
ENT.VLS_LaunchOffset = Vector(0, 0, 30) -- Startposition auf der Oberseite

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Locked")
    self:NetworkVar("Entity", 0, "CurrentTarget")
    self:NetworkVar("Float", 0, "LockProgress")
    self:NetworkVar("Int", 0, "MissileCount")
    self:NetworkVar("String", 0, "Nickname")  -- NEU: Nickname für VLS
    
    if SERVER then
        self:SetLocked(false)
        self:SetLockProgress(0)
        self:SetNickname("")  -- Standard: Kein Nickname
    end
end

-- Launchposition für Raketen (Oberseite/Deckel des Modells)
function ENT:GetLaunchPosition()
    return self:GetPos() + self:GetUp() * 30
end

-- Launchrichtung (Immer nach "oben" relativ zum Modell - aus dem Deckel)
function ENT:GetLaunchDirection()
    return self:GetUp()
end

