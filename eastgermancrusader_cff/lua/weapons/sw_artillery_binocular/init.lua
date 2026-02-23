-- eastgermancrusader_cff/lua/weapons/sw_artillery_binocular/init.lua
-- Artillerie Binocular - Server
-- OPTIMIERT für Mehrspieler

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

DEFINE_BASECLASS("weapon_base")

if SERVER then
    function SWEP:Initialize()
        if BaseClass and BaseClass.Initialize then
            BaseClass.Initialize(self)
        end
        if self.SetIronSights then
            self:SetIronSights(false)
        end
    end
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    
    if self.SetIronSights and self.GetIronSights then
        self:SetIronSights(not self:GetIronSights())
    else
        self:SetNWBool("IronSights", not self:GetNWBool("IronSights", false))
    end
    
    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:Think()
    if BaseClass and BaseClass.Think then
        BaseClass.Think(self)
    end
    self:NextThink(CurTime())
    return true
end
