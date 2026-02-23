-- eastgermancrusader_cff/lua/entities/sw_kus_command_center/shared.lua
-- KUS Forward Command Center
-- OPTIMIERT für Mehrspieler

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "KUS Forward Command Center"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"
ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Model = "models/props_combine/combine_interface001.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "RequestCount")
    self:NetworkVar("Bool", 0, "IsActive")
    self:NetworkVar("Bool", 1, "FlakMode")
    self:NetworkVar("Int", 1, "FlakHeight")
end
