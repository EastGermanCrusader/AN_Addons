if SERVER then return end

LordMineDetector = LordMineDetector or {}

-- Client convars
LordMineDetector.cvars = {
    radarPosX = CreateClientConVar("mine_detector_pos_x", "125", true, false),
    radarPosY = CreateClientConVar("mine_detector_pos_y", "430", true, false),
    radarSize = CreateClientConVar("mine_detector_size", "100", true, false),
    pingVolume = CreateClientConVar("mine_detector_ping_volume", "0.5", true, false)
}

-- Internal states
LordMineDetector.mines = LordMineDetector.mines or {}
LordMineDetector.radarActive = LordMineDetector.radarActive or false
LordMineDetector.maxDistance = LordMineDetector.maxDistance or 1024
LordMineDetector.nextPingTime = LordMineDetector.nextPingTime or 0
LordMineDetector.lastDrawTime = LordMineDetector.lastDrawTime or 0
LordMineDetector.drawInterval = 1 / 1000
LordMineDetector.RefreshRate = 0.5

-- Server requests
timer.Create("MineDetector_RequestLoop", LordMineDetector.RefreshRate, 0, function()
    if LordMineDetector.radarActive then
        net.Start("MineDetector_Request")
        net.WriteUInt(LordMineDetector.maxDistance, 11)
        net.SendToServer()
    end
end)

net.Receive("MineDetector_Update", function()
    LordMineDetector.mines = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        table.insert(LordMineDetector.mines, net.ReadVector())
    end
end)

-- Toggle radar function
function LordMineDetector.ToggleRadar(state)
    if LordMineDetector.PlayerHasMineDetectorSWEP() and LordMineDetector.IsActivated then
        LordMineDetector.radarActive = state
    end
end

-- Function that checks if player has the swep
function LordMineDetector.PlayerHasMineDetectorSWEP()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetClass() == "weapon_sh_detector" then
            return true
        end
    end
    return false
end


-- Paint HUD function
hook.Add("HUDPaint", "MineDetector_Draw", function()
    local self = LordMineDetector
    local curTime = CurTime()
    if curTime - self.lastDrawTime < self.drawInterval then return end
    self.lastDrawTime = curTime

    if not self.radarActive or LordMineDetector.AnimatedHUDActive then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local cx, cy = self.cvars.radarPosX:GetInt(), self.cvars.radarPosY:GetInt()
    local radius = self.cvars.radarSize:GetInt()
    local scale = radius / self.maxDistance

    -- Radar wave
    self.MineDetectorWave = self.MineDetectorWave or {startTime = CurTime()}
    local elapsed = (curTime - self.MineDetectorWave.startTime) % 2
    local pulse = (elapsed / 2) * radius
    local alpha = 100 * (1 - (elapsed / 2))
    self.DrawCircleOutline(cx, cy, pulse, 64, Color(0, 255, 255, alpha))

    -- Background
    self.DrawFilledCircle(cx, cy, radius, 64, self.colors.radarBG)

    -- Decorations
    self.DrawCircleOutline(cx, cy, radius, 64, self.colors.outline)
    self.DrawCircleOutline(cx, cy, radius * 0.66, 64, self.colors.outlineMid)
    self.DrawCircleOutline(cx, cy, radius * 0.33, 64, self.colors.outlineIn)
    self.DrawCircleOutline(cx, cy, radius * 0.1, 32, self.colors.outlineTiny)
    self.DrawRadarLines(cx, cy, radius)

    -- Mines
    local closestDist = self.maxDistance + 1
    local found = false

    for _, pos in ipairs(self.mines) do
        local dir = pos - ply:GetPos()
        local dist = dir:Length()
        if dist <= self.maxDistance then
            dir:Normalize()
            local yaw = math.rad(ply:EyeAngles().yaw)
            local angle = -(math.atan2(dir.y, dir.x) - yaw + math.pi / 2)
            local r = dist * scale
            local x = cx + math.cos(angle) * r
            local y = cy + math.sin(angle) * r

            for glowRadius = 8, 14, 2 do
                local glowAlpha = 150 * (1 - (glowRadius - 8) / 6) * 0.4
                local glowColor = Color(self.colors.mineGlowBase.r, self.colors.mineGlowBase.g, self.colors.mineGlowBase.b, glowAlpha)
                self.DrawFilledCircle(x, y, glowRadius, 24, glowColor)
            end
            self.DrawFilledCircle(x, y, 5, 24, Color(self.colors.mineGlowBase.r, self.colors.mineGlowBase.g, self.colors.mineGlowBase.b, 255))
            self.DrawOutlinedText(math.floor(dist / 64) .. "m", x, y + 10, self.colors.text)

            if dist < closestDist then
                closestDist = dist
            end
            found = true
        end
    end

    self.UpdateRadarBeep(curTime, closestDist, found, ply:GetPos())
end)

local _cacheSchema = 2
timer.Create("MineDetector_RadarRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC Mine Scanner] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)