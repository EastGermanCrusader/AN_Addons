AddCSLuaFile("shared.lua")
include("shared.lua")

function SWEP:PrimaryAttack()
    if not IsValid(self:GetOwner()) then return end
    self:SetNextPrimaryFire(CurTime() + 0.4)
    net.Start("CrusaderDetectorToggle")
    net.Send(self:GetOwner())
end

function SWEP:SecondaryAttack()
end
