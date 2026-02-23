--[[
    EGC Shield Generator Entity - Client
    Schild-Visualisierung, Hit-Effekte
]]

include("shared.lua")

-- Lokale Caches
local lastHitTime = {}
local hitIntensity = {}

function ENT:Initialize()
    self.ShieldAlpha = 0
    self.TargetAlpha = 80
    self.LastShieldPercent = 100
end

function ENT:Draw()
    self:DrawModel()
    
    -- Status-Anzeige über Generator
    if LocalPlayer():GetPos():Distance(self:GetPos()) < 500 then
        self:DrawStatusOverlay()
    end
end

function ENT:DrawStatusOverlay()
    local pos = self:GetPos() + Vector(0, 0, 50)
    local ang = (LocalPlayer():EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)
    
    cam.Start3D2D(pos, ang, 0.15)
        -- Hintergrund
        draw.RoundedBox(8, -100, -40, 200, 80, Color(0, 0, 0, 180))
        
        -- Titel
        draw.SimpleText("SCHILDGENERATOR", "DermaDefaultBold", 0, -30, Color(60, 200, 255), TEXT_ALIGN_CENTER)
        
        -- Schild-Balken
        local shieldPercent = self:GetShieldPercent()
        local shieldColor = Color(60, 200, 255)
        if shieldPercent < 25 then
            shieldColor = Color(255, 80, 80)
        elseif shieldPercent < 50 then
            shieldColor = Color(255, 200, 50)
        end
        
        draw.RoundedBox(4, -90, -10, 180, 20, Color(40, 40, 40))
        draw.RoundedBox(4, -90, -10, 180 * (shieldPercent / 100), 20, shieldColor)
        draw.SimpleText(math.Round(shieldPercent) .. "%", "DermaDefault", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Status
        local statusText = "AKTIV"
        local statusColor = Color(100, 255, 100)
        if self:GetIsRecharging() then
            statusText = "LÄDT..."
            statusColor = Color(255, 200, 50)
        elseif not self:GetShieldActive() then
            statusText = "OFFLINE"
            statusColor = Color(255, 80, 80)
        end
        
        draw.SimpleText(statusText, "DermaDefault", 0, 25, statusColor, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

function ENT:Think()
    -- Smooth Alpha-Übergang
    local targetAlpha = 80
    if not self:GetShieldActive() or self:GetShieldPercent() <= 0 then
        targetAlpha = 0
    elseif self:GetShieldPercent() < 25 then
        -- Flackern bei niedrigem Schild
        targetAlpha = 40 + math.sin(CurTime() * 10) * 30
    end
    
    self.ShieldAlpha = Lerp(FrameTime() * 5, self.ShieldAlpha or 0, targetAlpha)
    self.LastShieldPercent = self:GetShieldPercent()
end

-- ============================================================================
-- SCHILD-MESH ZEICHNEN (Global Hook)
-- ============================================================================

local function DrawShieldMeshes()
    if not EGC_SHIP or not EGC_SHIP.Generators then return end
    
    local cfg = EGC_SHIP.Config or {}
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local eyePos = ply:EyePos()
    
    render.SetColorMaterial()
    
    for entIndex, genData in pairs(EGC_SHIP.Generators) do
        local ent = Entity(entIndex)
        if not IsValid(ent) then continue end
        
        -- Distanz-Check für Performance
        if genData.hullCenter and eyePos:Distance(genData.hullCenter) > 15000 then
            continue
        end
        
        -- Schild-Status
        local shieldPercent = ent:GetShieldPercent()
        local shieldActive = ent:GetShieldActive() and shieldPercent > 0
        
        if not shieldActive then continue end
        
        -- Schild-Farbe basierend auf Status
        local baseColor = cfg.ShieldColor or Color(60, 150, 255, 80)
        local alpha = baseColor.a
        
        -- Hit-Effekt
        local hitTime = lastHitTime[entIndex] or 0
        local hitAge = CurTime() - hitTime
        if hitAge < 0.5 then
            local hitAlpha = (1 - hitAge / 0.5) * (hitIntensity[entIndex] or 50)
            alpha = alpha + hitAlpha
            baseColor = Color(
                Lerp(hitAge / 0.5, 255, baseColor.r),
                Lerp(hitAge / 0.5, 100, baseColor.g),
                Lerp(hitAge / 0.5, 100, baseColor.b),
                alpha
            )
        end
        
        -- Niedriger Schild = andere Farbe + Flackern
        if shieldPercent < 25 then
            local flicker = math.sin(CurTime() * 15) * 0.3 + 0.7
            baseColor = Color(255, 200, 50, alpha * flicker)
        elseif shieldPercent < 50 then
            baseColor = Color(
                Lerp(shieldPercent / 50, 255, baseColor.r),
                Lerp(shieldPercent / 50, 200, baseColor.g),
                baseColor.b,
                alpha
            )
        end
        
        -- Hull-Mesh zeichnen
        local hullMesh = genData.hullMesh
        if hullMesh and #hullMesh >= 3 then
            -- Kanten zeichnen
            for i = 1, #hullMesh do
                local a = hullMesh[i]
                local b = hullMesh[(i % #hullMesh) + 1]
                render.DrawBeam(a, b, 5, 0, 1, baseColor)
            end
            
            -- Fläche füllen (vereinfacht als Triangle-Fan)
            local center = genData.hullCenter or hullMesh[1]
            local fillColor = Color(baseColor.r, baseColor.g, baseColor.b, baseColor.a * 0.3)
            
            for i = 1, #hullMesh do
                local a = hullMesh[i]
                local b = hullMesh[(i % #hullMesh) + 1]
                
                render.DrawQuad(
                    center, a, b, center,
                    fillColor
                )
            end
        end
        
        -- Gates zeichnen
        local gateColor = cfg.GateColor or Color(100, 255, 100, 60)
        for _, gate in ipairs(genData.gates or {}) do
            if gate.active and gate.mesh and #gate.mesh >= 3 then
                -- Gate-Kanten
                for i = 1, #gate.mesh do
                    local a = gate.mesh[i]
                    local b = gate.mesh[(i % #gate.mesh) + 1]
                    render.DrawBeam(a, b, 8, 0, 1, gateColor)
                end
            end
        end
    end
end

hook.Add("PostDrawTranslucentRenderables", "EGC_Shield_DrawMeshes", DrawShieldMeshes)

-- ============================================================================
-- NETZWERK-EMPFANG
-- ============================================================================

-- Vollständige Synchronisation
net.Receive("EGC_Shield_FullSync", function()
    local entIndex = net.ReadUInt(16)
    local numHullPoints = net.ReadUInt(16)
    
    if not EGC_SHIP then EGC_SHIP = {} end
    if not EGC_SHIP.Generators then EGC_SHIP.Generators = {} end
    
    EGC_SHIP.Generators[entIndex] = EGC_SHIP.Generators[entIndex] or EGC_SHIP.CreateGeneratorData(entIndex)
    local genData = EGC_SHIP.Generators[entIndex]
    
    -- Hull-Mesh lesen
    genData.hullMesh = {}
    for i = 1, numHullPoints do
        table.insert(genData.hullMesh, net.ReadVector())
    end
    
    -- Bounds berechnen
    if #genData.hullMesh > 0 then
        genData.hullCenter, genData.hullRadius = EGC_SHIP.CalculateBounds(genData.hullMesh)
    end
    
    -- Gates lesen
    local numGates = net.ReadUInt(8)
    genData.gates = {}
    
    for g = 1, numGates do
        local gate = EGC_SHIP.CreateGateData()
        local numGatePoints = net.ReadUInt(8)
        
        gate.mesh = {}
        for i = 1, numGatePoints do
            table.insert(gate.mesh, net.ReadVector())
        end
        
        if #gate.mesh > 0 then
            gate.center = EGC_SHIP.CalculateBounds(gate.mesh)
        end
        gate.active = true
        
        table.insert(genData.gates, gate)
    end
    
    print("[EGC Shield] Sync empfangen: Hull=" .. #genData.hullMesh .. ", Gates=" .. #genData.gates)
end)

-- Status-Update
net.Receive("EGC_Shield_Update", function()
    local entIndex = net.ReadUInt(16)
    local shieldPercent = net.ReadFloat()
    local powerLevel = net.ReadFloat()
    local active = net.ReadBool()
    local recharging = net.ReadBool()
    
    if EGC_SHIP and EGC_SHIP.Generators and EGC_SHIP.Generators[entIndex] then
        local genData = EGC_SHIP.Generators[entIndex]
        genData.shieldPercent = shieldPercent
        genData.powerLevel = powerLevel
        genData.active = active
        genData.recharging = recharging
    end
end)

-- Hit-Effekt
net.Receive("EGC_Shield_Hit", function()
    local entIndex = net.ReadUInt(16)
    local damage = net.ReadFloat()
    
    lastHitTime[entIndex] = CurTime()
    hitIntensity[entIndex] = math.Clamp(damage * 2, 20, 100)
    
    -- Sound
    local ent = Entity(entIndex)
    if IsValid(ent) then
        ent:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 60, math.random(90, 110))
    end
end)

-- Scan-Ergebnis
net.Receive("EGC_Shield_ScanResult", function()
    local success = net.ReadBool()
    local numPoints = net.ReadUInt(16)
    
    if success then
        notification.AddLegacy("Hull gescannt: " .. numPoints .. " Punkte!", NOTIFY_GENERIC, 4)
        surface.PlaySound("buttons/button14.wav")
    else
        notification.AddLegacy("Scan fehlgeschlagen!", NOTIFY_ERROR, 3)
        surface.PlaySound("buttons/button10.wav")
    end
end)

-- Anfrage bei Spawn
hook.Add("InitPostEntity", "EGC_Shield_RequestSync", function()
    timer.Simple(1, function()
        net.Start("EGC_Shield_RequestSync")
        net.SendToServer()
    end)
end)
