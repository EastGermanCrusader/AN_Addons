-- eastgermancrusader_cctv/lua/entities/crusader_cctv_console/init.lua
-- ============================================
-- OPTIMIERTE SERVER-SEITIGE KONSOLEN LOGIK
-- ============================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Lokale Referenzen
local IsValid = IsValid
local ipairs = ipairs
local net_Start = net.Start
local net_WriteEntity = net.WriteEntity
local net_WriteString = net.WriteString
local net_WriteVector = net.WriteVector
local net_WriteBool = net.WriteBool
local net_WriteUInt = net.WriteUInt
local net_Send = net.Send

function ENT:Initialize()
    self:SetModel("models/kingpommes/starwars/misc/bridge_console1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    -- OPTIMIERT: Nutze gecachte Kamera-Suche
    local cameras = CRUSADER_GetAllCCTVCameras(true)
    
    net_Start("crusader_cctv_console_open")
        net_WriteEntity(self)
        net_WriteUInt(#cameras, 8)
        
        for _, ent in ipairs(cameras) do
            net_WriteEntity(ent)
            net_WriteString(ent:GetCameraName())
            net_WriteVector(ent:GetPos())
            net_WriteBool(ent:GetIsActive())
            net_WriteBool(ent:GetVideoActive())
            net_WriteBool(ent:GetAudioActive())
            net_WriteUInt(ent:GetCameraHealth(), 8)
        end
    net_Send(activator)
end
