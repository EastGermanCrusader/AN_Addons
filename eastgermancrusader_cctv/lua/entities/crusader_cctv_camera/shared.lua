-- eastgermancrusader_cctv/lua/entities/crusader_cctv_camera/shared.lua

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "CCTV Kamera"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Purpose = "Überwachungskamera für das CCTV-System"
ENT.Instructions = "Platzieren und mit E benennen. Kann beschädigt werden. Reparatur mit LVS Repair Tool."

-- Netzwerk-Variablen
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "CameraName")
    self:NetworkVar("Bool", 0, "IsActive")
    self:NetworkVar("Bool", 1, "VideoActive")
    self:NetworkVar("Bool", 2, "AudioActive")
    self:NetworkVar("Int", 0, "CameraHealth")
end

-- Kamera-Blickwinkel
function ENT:GetViewPosition()
    local pos = self:GetPos() + self:GetForward() * 20 + self:GetUp() * 8
    local ang = self:GetAngles()
    return pos, ang
end
