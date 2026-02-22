AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

-- Precache Models
util.PrecacheModel("models/weapons/v_rpg.mdl")
util.PrecacheModel("models/weapons/w_rocket_launcher.mdl")
util.PrecacheModel("models/weapons/w_missile_launch.mdl")

-- Precache Sounds
util.PrecacheSound("weapons/rpg/rocketfire1.wav")
util.PrecacheSound("weapons/rpg/rocket1.wav")
util.PrecacheSound("buttons/blip2.wav")
util.PrecacheSound("buttons/button10.wav")
util.PrecacheSound("ambient/energy/force_field_loop1.wav")
