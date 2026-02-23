--[[
    GAR LOGISTICS SYSTEM - SERVER PROTOCOL
    UNIT: SPAWN POINT MARKER
    AUTHORIZATION: COMMAND LEVEL
]]--

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Comm-Link Establishment
util.AddNetworkString("LVS_SpawnPoint_UpdateName")
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

function ENT:Initialize()
    -- Standard Physik-Initialisierung (für Admin-Handling)
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    -- Kollisions-Protokolle: Ghost-Mode (Keine Kollision mit Vehikeln/Spielern)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    
    -- Visuelle Tarnung (Server-seitig)
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:DrawShadow(false)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(true)
        phys:SetMass(100)
    end
end

--[[
    DATA STORAGE PROTOCOL (Duplicator / Save System)
]]--
function ENT:PreEntityCopy()
    local data = {
        SpawnPointName = self:GetSpawnPointName(),
    }
    
    -- Daten in den Entity-Modifikator einspeisen
    duplicator.StoreEntityModifier(self, "LVS_SpawnPoint_Data", data)
end

-- Duplicator Wiederherstellung
duplicator.RegisterEntityModifier("lvs_parking_spawnpoint", "LVS_SpawnPoint_Data", function(ply, ent, data)
    if not IsValid(ent) then return end
    
    if data.SpawnPointName then
        ent:SetSpawnPointName(data.SpawnPointName)
    end
end)

--[[
    DATASTREAM RECEIVER (Network Handling)
]]--
net.Receive("LVS_SpawnPoint_UpdateName", function(len, ply)
    if not _cfgOk() then return end
    if not ply:IsAdmin() then return end
    
    local spawnPoint = net.ReadEntity()
    local newName = net.ReadString()
    
    if not IsValid(spawnPoint) or spawnPoint:GetClass() ~= "lvs_parking_spawnpoint" then return end
    
    -- Neue Designation setzen
    spawnPoint:SetSpawnPointName(newName)
end)