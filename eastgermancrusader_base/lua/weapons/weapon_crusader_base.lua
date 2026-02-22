-- eastgermancrusader_base/lua/weapons/weapon_crusader_base.lua

if SERVER then
	AddCSLuaFile()
end

SWEP.Base = "weapon_base"
SWEP.Category = "EastGermanCrusader" 

-- *** ÄNDERUNG: Auf false setzen! ***
-- Damit ist die Base unsichtbar, liefert aber den Code für das Datapad.
SWEP.Spawnable = false 
SWEP.AdminOnly = false

if CLIENT then
    SWEP.PrintName = "Crusader Base Weapon"
    SWEP.Author = "EastGermanCrusader"
    SWEP.Contact = "N/A"
    SWEP.Purpose = "Basis-Code (Unsichtbar)"
    SWEP.Instructions = "Nicht benutzen."
    
    SWEP.Slot = 1
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

-- Standardwerte
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
	self:SetHoldType( "normal" )
end