-- eastgermancrusader_cff/lua/weapons/sw_kus_binocular/shared.lua
-- KUS Artillerie Binocular

AddCSLuaFile()

SWEP.Base = "weapon_base"
SWEP.Category = "EastGermanCrusader"
SWEP.Author = "EastGermanCrusader"
SWEP.PrintName = "KUS Artillerie Binocular"
SWEP.Type = "Artillerie Zielgerät"

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.DrawCrosshair = false
SWEP.DrawCrosshairIS = false
SWEP.DrawAmmo = false

SWEP.Secondary = {}
SWEP.Secondary.IronFOV = 75

SWEP.Primary.ClipSize = 0
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false

SWEP.FireModes = { "none" }

SWEP.ViewModel = "models/nate159/swbf2015/pewpew/electrobinocular.mdl"
SWEP.WorldModel = "models/nate159/swbf2015/pewpew/electrobinocular.mdl"
SWEP.ViewModelFOV = 75
SWEP.ViewModelFlip = false
SWEP.UseHands = false
SWEP.HoldType = "slam"

SWEP.ShowWorldModel = true
SWEP.IronSightTime = 0.5
SWEP.MoveSpeed = 1
SWEP.IronSightsMoveSpeed = 0.5

SWEP.IronSightsPos = Vector(-2, -2, 0)
SWEP.IronSightsAng = Vector(0, 0, 0)
SWEP.VMPos = Vector(0, 0, 0)
SWEP.VMAng = Vector(0, 0, 0)

if SERVER then
    function SWEP:SetupDataTables()
        self:NetworkVar("Bool", 0, "IronSights")
    end
end
