if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("CrusaderMineTypeUpdate")
end

SWEP.Base = "weapon_crusader_base"
SWEP.Category = "EastGermanCrusader"

SWEP.Spawnable = true
SWEP.AdminOnly = false

if CLIENT then
    SWEP.PrintName = "Minenleger"
    SWEP.Author = "EastGermanCrusader"
    SWEP.Contact = "N/A"
    SWEP.Purpose = "Platziert vergrabene Proximity-Landminen"
    SWEP.Instructions = "Linksklick: Mine platzieren | Rechtsklick: Alle eigenen Minen entfernen | R: Minenart wechseln (Landmine / Spring / Dioxis)"
    
    SWEP.Slot = 4
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
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
    self:SetHoldType("slam")
    
    -- Minenarten: 1 = Normale Mine, 2 = Spring-Splittermine, 3 = Dioxis-Mine
    if not self.MineType then
        self.MineType = 1
    end
end