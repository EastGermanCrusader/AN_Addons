if SERVER then return end

LordMineDetector = LordMineDetector or {}

-- Detector detection script
function LordMineDetector.DetectEntities(owner, detectRange)
    local ct = CurTime()
    if ct < LordMineDetector.m_fNextSweep then return end
    if not IsValid(owner) then return end

    local ep = owner:EyePos()
    local tbl = {}

    local speed = owner:GetVelocity():Length()
    local t = math.Clamp(speed / LordMineDetector.SpeedMax, 0, 1)
    local speedFactor = 1.0 - (1.0 - LordMineDetector.SpeedMinRangeFactor) * (t ^ 2)

    local dynamicRange = (detectRange or LordMineDetector.maxDistance) * speedFactor

    local entitiesToDetect = MineDetector_GlobalEntities or {}

    for _, v in ipairs(ents.GetAll()) do
        if entitiesToDetect[v:GetClass()] then
            local pos = v:LocalToWorld(v:OBBCenter())
            if pos:Distance(ep) <= dynamicRange then
                table.insert(tbl, v)
            end
        end
    end

    LordMineDetector.m_DetectedEntities = tbl
    LordMineDetector.m_fNextSweep = ct + LordMineDetector.RefreshRate
end

-- Draws the detected things of detector
function LordMineDetector.DrawDetectedEntities(ply, range, curTime)
    local ep = ply:EyePos()
    local closest

    for _, ent in ipairs(LordMineDetector.m_DetectedEntities) do
        if not IsValid(ent) then continue end

        local pos = ent:LocalToWorld(ent:OBBCenter())
        local dist = ep:Distance(pos)
        if dist > range then continue end

        local ts = pos:ToScreen()
        local x, y = ts.x, ts.y

        local waveDuration = 0.5
        local waveProgress = (curTime % waveDuration) / waveDuration

        local radius = 32 + waveProgress * 48
        local alpha = (1 - waveProgress) * 200

        surface.SetDrawColor(255, 255, 255, alpha)
        surface.DrawCircle(x, y, radius)

        local mdist = math.Round(dist / 64)
        draw.SimpleTextOutlined(mdist .. " M", "LordAurebeshFont", x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(75, 75, 75))

        if not closest or dist < closest then
            closest = dist
        end
    end

    return closest
end

-- Everything around the beep down here
LordMineDetector.BeepSoundInfo = {
    snd = "beep.wav",
    volume = 1,
    pitch = 100,
}

-- detector beep
function LordMineDetector.HandleDetectorBeep(closest, wep, range)
    if closest and not LordMineDetector.radarActive then
        local ct = CurTime()
        if not wep.m_fNextBeep or ct >= wep.m_fNextBeep then
            local time = math.max(0.2, 2 * (closest / range))
            LocalPlayer():EmitSound(LordMineDetector.BeepSoundInfo.snd, 75, LordMineDetector.BeepSoundInfo.pitch, LordMineDetector.BeepSoundInfo.volume)
            wep.m_fNextBeep = ct + time
        end
    end
end

-- radar beep
function LordMineDetector.UpdateRadarBeep(curTime, closestDist, hasTarget, pos)
    if hasTarget then
        local minDelay, maxDelay = 0.1, 1.5
        local delay = math.Clamp((closestDist / LordMineDetector.maxDistance) * maxDelay, minDelay, maxDelay)
        if curTime >= LordMineDetector.nextPingTime then
            sound.Play("beep.wav", pos, 75, 100, LordMineDetector.cvars.pingVolume:GetFloat())
            LordMineDetector.nextPingTime = curTime + delay
        end
    else
        LordMineDetector.nextPingTime = 0
    end
end