LordMineDetector = LordMineDetector or {}

if SERVER then
	AddCSLuaFile()
end

SWEP.Base = "weapon_crusader_base"
SWEP.Category = "EastGermanCrusader"
SWEP.Spawnable = true
SWEP.UseHands = true
local swepHoldType = "slam"
SWEP.HoldType = swepHoldType
SWEP.Slot = 5

SWEP.ViewModel = ""
SWEP.WorldModel = ""

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false


/** GENERAL OPTIONS **/

-- Entities that the detector can detect

if CLIENT then
    MineDetector_GlobalEntities = MineDetector_GlobalEntities or {}

    net.Receive("MineDetector_UpdateEntities", function()
        local count = net.ReadUInt(8)
        MineDetector_GlobalEntities = {}

        for i = 1, count do
            local class = net.ReadString()
            MineDetector_GlobalEntities[class] = true
        end
    end)
end

-- Play sound when deploying/holstering detector
SWEP.PlaySounds = true

/** CLIENTSIDE OPTIONS **/

-- Draw pulsing circle on detected entities?
SWEP.DrawPulseCircle = true

-- Draw distance to detected entities?
SWEP.DrawDistance = true

-- Play (clientside) beeping sound when detecting an entity?
-- The closer the player is to a detected entity, the faster the beeping.
SWEP.PlayBeepSound = true

-- Beep sound file, volume and pitch. Only applicable if "PlayBeepSound" is true
SWEP.BeepSoundInfo = {
	snd = Sound("beep.wav"),
	pitch = 100, -- 0 to 255, 100 is normal
	volume = 0.5
}

function SWEP:Initialize()
	self:SetDeploySpeed(1)
	self:SetHoldType(swepHoldType)
		
	if CLIENT then
		self.EntitiesToDetect = MineDetector_GlobalEntities or {}
        LordMineDetector.ToggleRadar(true)
	end
end

-- Empty methods to prevent silly clics when using the swep
function SWEP:PrimaryAttack()
    if SERVER then return end
    LordMineDetector.IsActivated = true
end

function SWEP:SecondaryAttack()
    if SERVER then return end
    LordMineDetector.IsActivated = false
    LordMineDetector.Reset()
end
