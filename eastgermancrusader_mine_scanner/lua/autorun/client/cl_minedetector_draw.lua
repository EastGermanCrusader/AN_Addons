if SERVER then return end

LordMineDetector = LordMineDetector or {}

-- Colors
LordMineDetector.colors = LordMineDetector.colors or {
    radarBG       = Color(10, 30, 40, 225),
    segment       = Color(0, 200, 255, 45),
    outline       = Color(0, 180, 255, 80),
    outlineMid    = Color(0, 180, 255, 40),
    outlineIn     = Color(0, 180, 255, 20),
    outlineTiny   = Color(0, 180, 255, 35),
    line          = Color(0, 200, 255, 20),
    polyHeader    = Color(0, 200, 255, 25),
    polyBorder    = Color(0, 200, 255, 60),
    polyOutline   = Color(0, 200, 255, 80),
    text          = Color(0, 200, 255, 180),
    mineGlowBase  = Color(0, 255, 255),
    outlineTrans  = Color(10, 30, 40, 180),
    outlinedTextColor = Color(0, 0, 0, 255),
}

function LordMineDetector.DrawHexagon(x, y, size, color)
    surface.SetDrawColor(color)
    local verts = {}
    for i = 0, 5 do
        local angle = math.rad(60 * i - 30)
        local vx = x + size * math.cos(angle)
        local vy = y + size * math.sin(angle)
        table.insert(verts, {x = vx, y = vy})
    end
    surface.DrawPoly(verts)
end

function LordMineDetector.DrawEquipEffect()
    if not LordMineDetector.EquipEffectStart then return end

    local elapsed = CurTime() - LordMineDetector.EquipEffectStart
    if elapsed > LordMineDetector.AnimationDuration then
        LordMineDetector.EquipEffectStart = nil
        LordMineDetector.AnimationCompleted = true
        return
    end

    local progress = elapsed / LordMineDetector.AnimationDuration
    local cx, cy = ScrW() / 2, ScrH() / 2
    local maxDist = math.sqrt(cx * cx + cy * cy)

    local hexHeight = math.sqrt(3) * LordMineDetector.hexSize
    local stepX = LordMineDetector.hexSize * 1.5 + LordMineDetector.hexGap
    local stepY = hexHeight + LordMineDetector.hexGap

    local currentMaxDist = maxDist * (1 - progress)

    for y = -stepY * 5, ScrH() + stepY * 5, stepY do
        for x = -stepX * 5, ScrW() + stepX * 5, stepX do
            local offsetX = (math.floor(y / stepY) % 2) * (stepX / 2)
            local hx = x + offsetX
            local hy = y

            local dist = math.sqrt((hx - cx) ^ 2 + (hy - cy) ^ 2)

            if dist >= currentMaxDist then
                local baseBlue = 200
                local variation = math.random(-20, 20)
                local r = 50 + variation
                local g = 100 + variation
                local b = baseBlue + variation
                local alpha = 80 + math.random(-15, 15)

                LordMineDetector.DrawHexagon(hx, hy, LordMineDetector.hexSize, Color(r, g, b, alpha))
            end
        end
    end
end

function LordMineDetector.DrawSideArcs(cx, cy, radius, thickness, startAngle, endAngle, steps, color)
    local angleStep = (endAngle - startAngle) / steps

    draw.NoTexture()
    surface.SetDrawColor(color)

    for i = 0, steps - 1 do
        local angle1 = math.rad(startAngle + i * angleStep)
        local angle2 = math.rad(startAngle + (i + 1) * angleStep)

        local x1_outer = cx + math.cos(angle1) * radius
        local y1_outer = cy + math.sin(angle1) * radius
        local x2_outer = cx + math.cos(angle2) * radius
        local y2_outer = cy + math.sin(angle2) * radius

        local x1_inner = cx + math.cos(angle1) * (radius - thickness)
        local y1_inner = cy + math.sin(angle1) * (radius - thickness)
        local x2_inner = cx + math.cos(angle2) * (radius - thickness)
        local y2_inner = cy + math.sin(angle2) * (radius - thickness)

        surface.DrawPoly({
            { x = x1_outer, y = y1_outer },
            { x = x2_outer, y = y2_outer },
            { x = x2_inner, y = y2_inner },
            { x = x1_inner, y = y1_inner }
        })
    end
end

function LordMineDetector.DrawBlueFilter(timeLeft)
    local baseAlpha = 40
    surface.SetDrawColor(0, 100, 255, baseAlpha * timeLeft)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end

function LordMineDetector.DrawSideArcsWithClip(isHolstered, timeLeft)
    local ply = LocalPlayer()
    local speed = ply:GetVelocity():Length()
    local alphaMax, alphaMin = 150, 30
    local speedClamp = math.Clamp(speed, 0, LordMineDetector.SpeedMax)
    local alpha = Lerp(speedClamp / LordMineDetector.SpeedMax, alphaMax, alphaMin)
    local color = Color(0, 200, 255, alpha)

    if isHolstered then
        local clipHeight = ScrH() * timeLeft
        local clipStartY = ScrH() - clipHeight
        render.SetScissorRect(0, clipStartY, ScrW(), ScrH(), true)
        LordMineDetector.DrawSideArcs(ScrW() / 1.5, ScrH() / 2, 450, 30, -35, 35, 25, color)
        LordMineDetector.DrawSideArcs(ScrW() / 3, ScrH() / 2, 450, 30, 145, 215, 25, color)
        render.SetScissorRect(0, 0, 0, 0, false)
    else
        LordMineDetector.DrawSideArcs(ScrW() / 1.5, ScrH() / 2, 450, 30, -35, 35, 25, color)
        LordMineDetector.DrawSideArcs(ScrW() / 3, ScrH() / 2, 450, 30, 145, 215, 25, color)
    end
end

function LordMineDetector.DrawFilledCircle(x, y, radius, segments, color)
    surface.SetDrawColor(color)
    draw.NoTexture()
    local circle = {{x = x, y = y}}
    for i = 0, segments do
        local ang = math.rad((i / segments) * 360)
        table.insert(circle, {
            x = x + math.cos(ang) * radius,
            y = y + math.sin(ang) * radius
        })
    end
    surface.DrawPoly(circle)
end

function LordMineDetector.DrawCircleOutline(x, y, radius, segments, color)
    surface.SetDrawColor(color)
    local points = {}
    for i = 0, segments do
        local angle = math.rad((i / segments) * 360)
        table.insert(points, {
            x = x + math.cos(angle) * radius,
            y = y + math.sin(angle) * radius
        })
    end
    for i = 1, #points - 1 do
        surface.DrawLine(points[i].x, points[i].y, points[i+1].x, points[i+1].y)
    end
end

function LordMineDetector.DrawOutlinedText(text, x, y, color)
    surface.SetFont("LordAurebeshFont")
    local w, h = surface.GetTextSize(text)
    local xPos = x - w / 2
    surface.SetTextColor(LordMineDetector.colors.outlinedTextColor)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                surface.SetTextPos(xPos + dx, y + dy)
                surface.DrawText(text)
            end
        end
    end
    surface.SetTextColor(color.r, color.g, color.b, color.a)
    surface.SetTextPos(xPos, y)
    surface.DrawText(text)
end

function LordMineDetector.DrawRadarLines(cx, cy, radius)
    surface.SetDrawColor(LordMineDetector.colors.line)
    for i = 0, 2 do
        local a1 = math.rad(i * 60)
        local a2 = math.rad((i + 3) * 60)
        local x1 = cx + math.cos(a1) * radius
        local y1 = cy + math.sin(a1) * radius
        local x2 = cx + math.cos(a2) * radius
        local y2 = cy + math.sin(a2) * radius
        surface.DrawLine(x1, y1, x2, y2)
    end
end
