include("shared.lua")
include("base_code.lua")
if SERVER then return end

LordMineDetector = LordMineDetector or {}

SWEP.PrintName = "Mine detector"
SWEP.Purpose = "Detects various elements"
SWEP.Instructions = "Activate to detect objects on screen."
SWEP.DrawCrosshair = false
SWEP.BobScale = 0.5
SWEP.SwayScale = 0.5

LordMineDetector.IsActivated = LordMineDetector.IsActivated or false
LordMineDetector.HUDVisibleUntil = LordMineDetector.HUDVisibleUntil or 0
LordMineDetector.maxDistance = LordMineDetector.maxDistance or 1024
LordMineDetector.RefreshRate = LordMineDetector.RefreshRate or 0.5
LordMineDetector.radarActive = LordMineDetector.radarActive or false
LordMineDetector.AnimatedHUDActive = LordMineDetector.AnimatedHUDActive or false
LordMineDetector.m_DetectedEntities = LordMineDetector.m_DetectedEntities or {}
LordMineDetector.m_fNextSweep = LordMineDetector.m_fNextSweep or 0
LordMineDetector.hexSize = LordMineDetector.hexSize or 40
LordMineDetector.hexGap = LordMineDetector.hexGap or 10
LordMineDetector.AnimationDuration = LordMineDetector.AnimationDuration or 0.5
LordMineDetector.EquipEffectStart = LordMineDetector.EquipEffectStart or nil
LordMineDetector.AnimationPlayed = LordMineDetector.AnimationPlayed or false
LordMineDetector.AnimationCompleted = LordMineDetector.AnimationCompleted or false
LordMineDetector.WaitingForReset = LordMineDetector.WaitingForReset or false

LordMineDetector.DeploySoundInfo = LordMineDetector.DeploySoundInfo or {
    snd = "warden_deploy.wav",
    volume = 1,
    pitch = 100,
}

LordMineDetector.SpeedMax = 400
LordMineDetector.SpeedMinRangeFactor = 0.5

function LordMineDetector.Reset()
    LordMineDetector.AnimationPlayed = false
    LordMineDetector.AnimationCompleted = false
    LordMineDetector.EquipEffectStart = nil
    LordMineDetector.HUDVisibleUntil = 0
    LordMineDetector.m_DetectedEntities = {}
    LordMineDetector.m_fNextSweep = 0
	LordMineDetector.WaitingForReset = false
    LordMineDetector.AnimatedHUDActive = false
    LordMineDetector.ToggleRadar(LordMineDetector.PlayerHasMineDetectorSWEP())
end

function LordMineDetector.OnWeaponEquipped()
    if not LordMineDetector.IsActivated or LordMineDetector.AnimationPlayed then return end
    LordMineDetector.AnimationPlayed = true
    LordMineDetector.AnimationCompleted = false
    LordMineDetector.ToggleRadar(false)

    local ply = LocalPlayer()
    ply:EmitSound(LordMineDetector.DeploySoundInfo.snd, 75, LordMineDetector.DeploySoundInfo.pitch, LordMineDetector.DeploySoundInfo.volume)

    timer.Simple(0.9, function()
        LordMineDetector.EquipEffectStart = CurTime()
    end)
end

function SWEP:Think()
    if not LordMineDetector.AnimationCompleted then return end
    LordMineDetector.DetectEntities(self.Owner, self.DetectRange)
end

function SWEP:Holster()
    if not LordMineDetector.IsActivated then return end
    LordMineDetector.HUDVisibleUntil = CurTime() + 10
	LordMineDetector.WaitingForReset = true
    return true
end

function SWEP:Deploy()
    LordMineDetector.OnWeaponEquipped()
end

local function CalculateTimeLeft(curTime, hudVisibleUntil)
    local totalDuration = 10
    local fadeDuration = 5
    local delayBeforeFade = totalDuration - fadeDuration
    local fadeStartOffset = 0.5

    local animationStart = hudVisibleUntil - totalDuration
    local timeSinceStart = curTime - animationStart

    if timeSinceStart < delayBeforeFade + fadeStartOffset then
        return 1
    elseif timeSinceStart <= totalDuration + fadeStartOffset then
        return 1 - ((timeSinceStart - (delayBeforeFade + fadeStartOffset)) / fadeDuration)
    else
        return 0
    end
end

local function CheckReset(isEquiped)
    if LordMineDetector.WaitingForReset and CurTime() >= LordMineDetector.HUDVisibleUntil - 0.1 and not isEquiped then
        LordMineDetector.Reset()
        LordMineDetector.WaitingForReset = false
    end
end

hook.Add("HUDPaint", "MineDetectorOverlay", function()
    local ply = LocalPlayer()
    local wep = ply:GetActiveWeapon()

    local isEquipped = IsValid(wep) and wep:GetClass() == "weapon_sh_detector"
    local hudActive = isEquipped or (LordMineDetector.HUDVisibleUntil and CurTime() < LordMineDetector.HUDVisibleUntil)
    if not hudActive then return end

    LordMineDetector.AnimatedHUDActive = true

    if isEquipped and not LordMineDetector.AnimationPlayed then
        LordMineDetector.OnWeaponEquipped()
    end

    LordMineDetector.DrawEquipEffect()

    local curTime = CurTime()
    local isHolstered = not isEquipped and LordMineDetector.HUDVisibleUntil and curTime < LordMineDetector.HUDVisibleUntil

    local timeLeft = 1
    if isHolstered then
        timeLeft = CalculateTimeLeft(curTime, LordMineDetector.HUDVisibleUntil)
    end

    if LordMineDetector.AnimationCompleted then
        LordMineDetector.DrawBlueFilter(timeLeft)
    end

    if LordMineDetector.AnimationCompleted or isHolstered then
        LordMineDetector.DrawSideArcsWithClip(isHolstered, timeLeft)
    end

    local range = (isEquipped and wep.DetectRange) or LordMineDetector.maxDistance
    local closest = LordMineDetector.DrawDetectedEntities(ply, range, curTime)

    LordMineDetector.HandleDetectorBeep(closest, wep, range)
    CheckReset(isEquipped)
end)

hook.Add("Think", "MineDetector_DetectWhileHolstered", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if LordMineDetector.HUDVisibleUntil and CurTime() < LordMineDetector.HUDVisibleUntil then
        LordMineDetector.DetectEntities(ply, LordMineDetector.maxDistance)
    end
end)