if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("CrusaderDetectorToggle")
end

SWEP.Base = "weapon_base"
SWEP.Category = "EastGermanCrusader"

SWEP.Spawnable = true
SWEP.AdminOnly = false

if CLIENT then
    SWEP.PrintName = "Minen-Detektor (SH)"
    SWEP.Author = "EastGermanCrusader"
    SWEP.Contact = "N/A"
    SWEP.Purpose = "Markiert explosionsfähige Objekte im Sichtbereich."
    SWEP.Instructions = "Linksklick: Scanner ein/aus – Explosives im 45°-Fächer (100 Units) wird blau markiert."

    SWEP.Slot = 4
    SWEP.SlotPos = 3
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

SWEP.HoldType = "pistol"

SWEP.ViewModel = "models/lt_c/sci_fi/detector.mdl"
SWEP.WorldModel = "models/lt_c/sci_fi/detector.mdl"
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType("pistol")
end
