-- eastgermancrusader_cctv/lua/entities/crusader_cctv_camera_v2/shared.lua

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "CCTV Kamera (Typ 2)"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Purpose = "Alternative Überwachungskamera für das CCTV-System"
ENT.Instructions = "Platzieren und mit E benennen. Kann beschädigt werden. Reparatur mit LVS Repair Tool."

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "CameraName")
    self:NetworkVar("Bool", 0, "IsActive")
    self:NetworkVar("Bool", 1, "VideoActive")
    self:NetworkVar("Bool", 2, "AudioActive")
    self:NetworkVar("Int", 0, "CameraHealth")
end

-- 30 Grad nach unten geneigt
function ENT:GetViewPosition()
    local pos = self:GetPos() + self:GetForward() * 25 + self:GetUp() * 10
    local ang = self:GetAngles()
    ang.p = ang.p + 30
    return pos, ang
end
