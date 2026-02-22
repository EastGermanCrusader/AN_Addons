-- EastGermanCrusader SAM System - Torpedo Kontrollstation Client
-- Naval VLS Anti-Air System - Realistisches GUI

include("shared.lua")

-- Farben
local COLORS = {
    bg_dark = Color(15, 25, 15, 250),
    bg_panel = Color(20, 35, 20, 240),
    bg_button = Color(30, 50, 30, 255),
    bg_button_hover = Color(50, 80, 50, 255),
    bg_button_active = Color(80, 120, 80, 255),
    border = Color(0, 100, 0, 255),
    text = Color(0, 255, 0, 255),
    text_dim = Color(0, 150, 0, 255),
    text_warning = Color(255, 200, 0, 255),
    text_danger = Color(255, 50, 50, 255),
    target_hostile = Color(255, 50, 50, 255),
    target_selected = Color(255, 255, 0, 255),
    vls_online = Color(0, 255, 100, 255),
    vls_empty = Color(255, 100, 100, 255),
    scanline = Color(0, 255, 0, 30),
    armed = Color(255, 50, 50, 255),
    disarmed = Color(100, 100, 100, 255),
}

-- Schriftarten
surface.CreateFont("TorpedoControl_Title", {
    font = "Roboto Mono",
    size = 28,
    weight = 700,
})

surface.CreateFont("TorpedoControl_Large", {
    font = "Roboto Mono",
    size = 20,
    weight = 600,
})

surface.CreateFont("TorpedoControl_Medium", {
    font = "Roboto Mono",
    size = 16,
    weight = 500,
})

surface.CreateFont("TorpedoControl_Small", {
    font = "Roboto Mono",
    size = 13,
    weight = 400,
})

-- Lokale Variablen
local controlStation = nil
local vlsList = {}
local targetList = {}
local selectedTarget = nil
local salvoSize = 1
local panelOpen = false

-- ============================================
-- NETZWERK EMPFANG
-- ============================================

-- Panel-Empfänger deaktiviert - Interaktion erfolgt direkt über das Display
-- net.Receive("EGC_SAM_OpenControlPanel", function()
--     controlStation = net.ReadEntity()
--     
--     if IsValid(controlStation) then
--         OpenControlPanel()
--     end
-- end)

net.Receive("EGC_SAM_UpdateVLSStatus", function()
    local station = net.ReadEntity()
    if station ~= controlStation then return end
    
    vlsList = {}
    local count = net.ReadInt(8)
    
    for i = 1, count do
        table.insert(vlsList, {
            entity = net.ReadEntity(),
            missiles = net.ReadInt(8),
            locked = net.ReadBool(),
            distance = net.ReadFloat(),
        })
    end
end)

net.Receive("EGC_SAM_UpdateTargets", function()
    local station = net.ReadEntity()
    if station ~= controlStation then return end
    
    targetList = {}
    local count = net.ReadInt(16)
    
    for i = 1, count do
        table.insert(targetList, {
            entity = net.ReadEntity(),
            name = net.ReadString(),
            distance = net.ReadFloat(),
            altitude = net.ReadFloat(),
            velocity = net.ReadFloat(),
            heatSignature = net.ReadFloat(),
            visible = net.ReadBool(),
        })
    end
end)

-- ============================================
-- CONTROL PANEL GUI
-- ============================================

function OpenControlPanel()
    if panelOpen then return end
    panelOpen = true
    
    local scrW, scrH = ScrW(), ScrH()
    local panelW, panelH = 1000, 700
    
    -- Hauptframe
    local frame = vgui.Create("DFrame")
    frame:SetSize(panelW, panelH)
    frame:SetPos((scrW - panelW) / 2, (scrH - panelH) / 2)
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    
    frame.Paint = function(self, w, h)
        -- Hintergrund
        draw.RoundedBox(8, 0, 0, w, h, COLORS.bg_dark)
        draw.RoundedBox(6, 2, 2, w - 4, h - 4, COLORS.bg_panel)
        
        -- Rahmen
        surface.SetDrawColor(COLORS.border)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        
        -- Scanlines Effekt
        for i = 0, h, 4 do
            surface.SetDrawColor(COLORS.scanline)
            surface.DrawRect(0, i, w, 1)
        end
        
        -- Titel
        draw.SimpleText("▓▓ NAVAL VLS KONTROLLSTATION ▓▓", "TorpedoControl_Title", w / 2, 25, COLORS.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Armed Status im Titel
        if IsValid(controlStation) and controlStation:GetArmed() then
            local blink = math.sin(CurTime() * 6) > 0
            local armCol = blink and Color(255, 50, 50) or Color(200, 0, 0)
            draw.SimpleText("⚠ WAFFEN SCHARF ⚠", "TorpedoControl_Large", w / 2, 48, armCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        -- Trennlinie
        surface.SetDrawColor(COLORS.border)
        surface.DrawRect(10, 65, w - 20, 2)
    end
    
    frame.OnClose = function()
        panelOpen = false
        controlStation = nil
    end
    
    -- Close Button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(panelW - 40, 10)
    closeBtn:SetSize(30, 30)
    closeBtn:SetText("X")
    closeBtn:SetFont("TorpedoControl_Large")
    closeBtn:SetTextColor(COLORS.text_danger)
    closeBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and COLORS.bg_button_hover or COLORS.bg_button
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    closeBtn.DoClick = function()
        frame:Close()
    end
    
    -- ============================================
    -- LINKE SEITE: VLS STATUS
    -- ============================================
    
    local vlsPanel = vgui.Create("DPanel", frame)
    vlsPanel:SetPos(15, 75)
    vlsPanel:SetSize(280, 250)
    vlsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 20, 10, 200))
        surface.SetDrawColor(COLORS.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        draw.SimpleText("═══ VLS SYSTEME ═══", "TorpedoControl_Medium", w / 2, 15, COLORS.text, TEXT_ALIGN_CENTER)
    end
    
    local vlsScroll = vgui.Create("DScrollPanel", vlsPanel)
    vlsScroll:SetPos(5, 35)
    vlsScroll:SetSize(270, 210)
    
    -- VLS Liste aktualisieren
    local function UpdateVLSList()
        vlsScroll:Clear()
        
        for i, vls in ipairs(vlsList) do
            local vlsEntry = vgui.Create("DPanel", vlsScroll)
            vlsEntry:SetSize(260, 45)
            vlsEntry:Dock(TOP)
            vlsEntry:DockMargin(0, 2, 0, 2)
            
            vlsEntry.Paint = function(self, w, h)
                local col = vls.missiles > 0 and Color(20, 40, 20, 200) or Color(40, 20, 20, 200)
                draw.RoundedBox(4, 0, 0, w, h, col)
                
                draw.SimpleText("VLS #" .. i, "TorpedoControl_Medium", 10, 6, COLORS.text)
                draw.SimpleText(string.format("%.0fm", vls.distance), "TorpedoControl_Small", w - 10, 6, COLORS.text_dim, TEXT_ALIGN_RIGHT)
                
                local ammoCol = vls.missiles > 0 and COLORS.vls_online or COLORS.vls_empty
                draw.SimpleText(string.format("Torpedos: %d", vls.missiles), "TorpedoControl_Medium", 10, 25, ammoCol)
                
                local status = vls.locked and "ARMED" or "STANDBY"
                local statCol = vls.locked and COLORS.armed or COLORS.text_dim
                draw.SimpleText(status, "TorpedoControl_Small", w - 10, 25, statCol, TEXT_ALIGN_RIGHT)
            end
        end
        
        if #vlsList == 0 then
            local noVLS = vgui.Create("DLabel", vlsScroll)
            noVLS:SetText("Keine VLS in Reichweite")
            noVLS:SetFont("TorpedoControl_Medium")
            noVLS:SetTextColor(COLORS.text_warning)
            noVLS:Dock(TOP)
            noVLS:DockMargin(10, 20, 10, 0)
        end
    end
    
    -- ============================================
    -- MITTE: ZIELE
    -- ============================================
    
    local targetPanel = vgui.Create("DPanel", frame)
    targetPanel:SetPos(305, 75)
    targetPanel:SetSize(400, 350)
    targetPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 20, 10, 200))
        surface.SetDrawColor(COLORS.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        draw.SimpleText("═══ RADAR - ZIELERFASSUNG ═══", "TorpedoControl_Medium", w / 2, 15, COLORS.text, TEXT_ALIGN_CENTER)
    end
    
    local targetScroll = vgui.Create("DScrollPanel", targetPanel)
    targetScroll:SetPos(5, 35)
    targetScroll:SetSize(390, 310)
    
    -- Ziel Liste aktualisieren
    local function UpdateTargetList()
        targetScroll:Clear()
        
        for i, target in ipairs(targetList) do
            local targetEntry = vgui.Create("DButton", targetScroll)
            targetEntry:SetSize(380, 65)
            targetEntry:Dock(TOP)
            targetEntry:DockMargin(0, 2, 0, 2)
            targetEntry:SetText("")
            
            local isSelected = selectedTarget == target.entity
            
            targetEntry.Paint = function(self, w, h)
                local bgCol = Color(25, 35, 25, 200)
                if isSelected then
                    bgCol = Color(60, 60, 20, 230)
                elseif self:IsHovered() then
                    bgCol = Color(35, 50, 35, 220)
                end
                draw.RoundedBox(4, 0, 0, w, h, bgCol)
                
                if isSelected then
                    surface.SetDrawColor(COLORS.target_selected)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                    draw.SimpleText("►", "TorpedoControl_Large", 8, h / 2, COLORS.target_selected, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                
                local nameCol = target.visible and COLORS.target_hostile or COLORS.text_dim
                draw.SimpleText(target.name, "TorpedoControl_Medium", 25, 8, nameCol)
                
                draw.SimpleText(string.format("Dist: %.0fm", target.distance), "TorpedoControl_Small", 25, 28, COLORS.text)
                
                local altText = target.altitude >= 0 and string.format("+%.0fm", target.altitude) or string.format("%.0fm", target.altitude)
                draw.SimpleText("Alt: " .. altText, "TorpedoControl_Small", 130, 28, COLORS.text)
                
                draw.SimpleText(string.format("%.0f km/h", target.velocity * 0.06858), "TorpedoControl_Small", 25, 46, COLORS.text_dim)
                
                local heatCol = target.heatSignature > 50 and COLORS.text_warning or COLORS.text_dim
                draw.SimpleText(string.format("IR: %.0f", target.heatSignature), "TorpedoControl_Small", 130, 46, heatCol)
                
                local visText = target.visible and "SICHTBAR" or "VERDECKT"
                local visCol = target.visible and COLORS.vls_online or COLORS.text_dim
                draw.SimpleText(visText, "TorpedoControl_Small", w - 10, 8, visCol, TEXT_ALIGN_RIGHT)
            end
            
            targetEntry.DoClick = function()
                selectedTarget = target.entity
                
                net.Start("EGC_SAM_SelectTarget")
                net.WriteEntity(controlStation)
                net.WriteEntity(target.entity)
                net.SendToServer()
                
                surface.PlaySound("buttons/button14.wav")
                UpdateTargetList()
            end
        end
        
        if #targetList == 0 then
            local noTargets = vgui.Create("DLabel", targetScroll)
            noTargets:SetText("Keine Ziele erfasst")
            noTargets:SetFont("TorpedoControl_Medium")
            noTargets:SetTextColor(COLORS.text_dim)
            noTargets:Dock(TOP)
            noTargets:DockMargin(10, 50, 10, 0)
        end
    end
    
    -- ============================================
    -- RECHTE SEITE: STEUERUNG
    -- ============================================
    
    local controlPanel = vgui.Create("DPanel", frame)
    controlPanel:SetPos(715, 75)
    controlPanel:SetSize(270, 550)
    controlPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 20, 10, 200))
        surface.SetDrawColor(COLORS.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        draw.SimpleText("═══ WAFFENKONTROLLE ═══", "TorpedoControl_Medium", w / 2, 15, COLORS.text, TEXT_ALIGN_CENTER)
    end
    
    -- Ausgewähltes Ziel Anzeige
    local targetDisplay = vgui.Create("DPanel", controlPanel)
    targetDisplay:SetPos(10, 40)
    targetDisplay:SetSize(250, 55)
    targetDisplay.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(5, 15, 5, 255))
        
        draw.SimpleText("ZIEL:", "TorpedoControl_Small", 8, 5, COLORS.text_dim)
        
        if IsValid(selectedTarget) then
            local name = selectedTarget.PrintName or selectedTarget:GetClass()
            draw.SimpleText(string.sub(name, 1, 25), "TorpedoControl_Medium", w / 2, 25, COLORS.target_selected, TEXT_ALIGN_CENTER)
            draw.SimpleText("ERFASST", "TorpedoControl_Small", w / 2, 42, COLORS.vls_online, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("KEIN ZIEL AUSGEWÄHLT", "TorpedoControl_Medium", w / 2, 30, COLORS.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    
    -- Trennlinie
    local sep0 = vgui.Create("DPanel", controlPanel)
    sep0:SetPos(10, 100)
    sep0:SetSize(250, 2)
    sep0.Paint = function(self, w, h)
        surface.SetDrawColor(COLORS.border)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- ============================================
    -- ARM / DISARM BUTTONS
    -- ============================================
    
    local armLabel = vgui.Create("DLabel", controlPanel)
    armLabel:SetPos(10, 110)
    armLabel:SetSize(250, 20)
    armLabel:SetText("SCHRITT 1: RAKETEN AKTIVIEREN")
    armLabel:SetFont("TorpedoControl_Small")
    armLabel:SetTextColor(COLORS.text)
    
    -- ARM Button
    local armBtn = vgui.Create("DButton", controlPanel)
    armBtn:SetPos(10, 135)
    armBtn:SetSize(120, 50)
    armBtn:SetText("")
    armBtn.Paint = function(self, w, h)
        local isArmed = IsValid(controlStation) and controlStation:GetArmed()
        local col = Color(60, 30, 30, 255)
        
        if isArmed then
            col = Color(100, 50, 50, 255)
        elseif self:IsHovered() then
            col = Color(100, 40, 40, 255)
        end
        
        draw.RoundedBox(6, 0, 0, w, h, col)
        
        if isArmed then
            surface.SetDrawColor(Color(255, 100, 100, 150))
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
        
        local textCol = isArmed and Color(255, 100, 100) or Color(255, 200, 200)
        draw.SimpleText("ARM", "TorpedoControl_Large", w / 2, h / 2 - 8, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Scharf", "TorpedoControl_Small", w / 2, h / 2 + 12, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    armBtn.DoClick = function()
        if not IsValid(controlStation) then return end
        
        net.Start("EGC_SAM_ArmMissiles")
        net.WriteEntity(controlStation)
        net.SendToServer()
        
        surface.PlaySound("buttons/button17.wav")
    end
    
    -- DISARM Button
    local disarmBtn = vgui.Create("DButton", controlPanel)
    disarmBtn:SetPos(140, 135)
    disarmBtn:SetSize(120, 50)
    disarmBtn:SetText("")
    disarmBtn.Paint = function(self, w, h)
        local isArmed = IsValid(controlStation) and controlStation:GetArmed()
        local col = Color(30, 50, 30, 255)
        
        if not isArmed then
            col = Color(40, 60, 40, 255)
        elseif self:IsHovered() then
            col = Color(50, 80, 50, 255)
        end
        
        draw.RoundedBox(6, 0, 0, w, h, col)
        
        local textCol = not isArmed and Color(100, 150, 100) or Color(200, 255, 200)
        draw.SimpleText("SAFE", "TorpedoControl_Large", w / 2, h / 2 - 8, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Sichern", "TorpedoControl_Small", w / 2, h / 2 + 12, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    disarmBtn.DoClick = function()
        if not IsValid(controlStation) then return end
        
        net.Start("EGC_SAM_DisarmMissiles")
        net.WriteEntity(controlStation)
        net.SendToServer()
        
        surface.PlaySound("buttons/button19.wav")
    end
    
    -- Trennlinie
    local sep1 = vgui.Create("DPanel", controlPanel)
    sep1:SetPos(10, 195)
    sep1:SetSize(250, 2)
    sep1.Paint = function(self, w, h)
        surface.SetDrawColor(COLORS.border)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- ============================================
    -- SALVENGRÖSSE
    -- ============================================
    
    local salvoLabel = vgui.Create("DLabel", controlPanel)
    salvoLabel:SetPos(10, 205)
    salvoLabel:SetSize(250, 20)
    salvoLabel:SetText("SCHRITT 2: SALVENGRÖSSE")
    salvoLabel:SetFont("TorpedoControl_Small")
    salvoLabel:SetTextColor(COLORS.text)
    
    local salvoDisplay = vgui.Create("DPanel", controlPanel)
    salvoDisplay:SetPos(10, 230)
    salvoDisplay:SetSize(250, 45)
    salvoDisplay.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(5, 15, 5, 255))
        draw.SimpleText(tostring(salvoSize) .. " TORPEDOS", "TorpedoControl_Large", w / 2, h / 2, COLORS.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    local minusBtn = vgui.Create("DButton", controlPanel)
    minusBtn:SetPos(10, 280)
    minusBtn:SetSize(120, 35)
    minusBtn:SetText("-")
    minusBtn:SetFont("TorpedoControl_Title")
    minusBtn:SetTextColor(COLORS.text)
    minusBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and COLORS.bg_button_hover or COLORS.bg_button
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    minusBtn.DoClick = function()
        salvoSize = math.max(1, salvoSize - 1)
        net.Start("EGC_SAM_SetSalvoSize")
        net.WriteEntity(controlStation)
        net.WriteInt(salvoSize, 8)
        net.SendToServer()
        surface.PlaySound("buttons/button15.wav")
    end
    
    local plusBtn = vgui.Create("DButton", controlPanel)
    plusBtn:SetPos(140, 280)
    plusBtn:SetSize(120, 35)
    plusBtn:SetText("+")
    plusBtn:SetFont("TorpedoControl_Title")
    plusBtn:SetTextColor(COLORS.text)
    plusBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and COLORS.bg_button_hover or COLORS.bg_button
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    plusBtn.DoClick = function()
        salvoSize = math.min(8, salvoSize + 1)
        net.Start("EGC_SAM_SetSalvoSize")
        net.WriteEntity(controlStation)
        net.WriteInt(salvoSize, 8)
        net.SendToServer()
        surface.PlaySound("buttons/button15.wav")
    end
    
    -- Trennlinie
    local sep2 = vgui.Create("DPanel", controlPanel)
    sep2:SetPos(10, 325)
    sep2:SetSize(250, 2)
    sep2.Paint = function(self, w, h)
        surface.SetDrawColor(COLORS.border)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- ============================================
    -- FEUER BUTTON
    -- ============================================
    
    local fireLabel = vgui.Create("DLabel", controlPanel)
    fireLabel:SetPos(10, 335)
    fireLabel:SetSize(250, 20)
    fireLabel:SetText("SCHRITT 3: ABSCHUSS")
    fireLabel:SetFont("TorpedoControl_Small")
    fireLabel:SetTextColor(COLORS.text)
    
    local fireBtn = vgui.Create("DButton", controlPanel)
    fireBtn:SetPos(10, 360)
    fireBtn:SetSize(250, 70)
    fireBtn:SetText("")
    fireBtn.Paint = function(self, w, h)
        local isArmed = IsValid(controlStation) and controlStation:GetArmed()
        local hasTarget = IsValid(selectedTarget)
        local canFire = isArmed and hasTarget
        
        local col = Color(50, 20, 20, 255)
        if canFire then
            col = Color(120, 30, 30, 255)
            if self:IsHovered() then
                col = Color(150, 40, 40, 255)
            end
            if self:IsDown() then
                col = Color(200, 60, 60, 255)
            end
        end
        
        draw.RoundedBox(6, 0, 0, w, h, col)
        
        if canFire then
            surface.SetDrawColor(Color(255, 50, 50, 150))
            surface.DrawOutlinedRect(0, 0, w, h, 3)
        end
        
        local textCol = canFire and Color(255, 255, 255) or Color(150, 100, 100)
        draw.SimpleText("▼ FEUER ▼", "TorpedoControl_Title", w / 2, h / 2 - 10, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if not isArmed then
            draw.SimpleText("Erst ARM drücken!", "TorpedoControl_Small", w / 2, h / 2 + 15, COLORS.text_warning, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif not hasTarget then
            draw.SimpleText("Kein Ziel!", "TorpedoControl_Small", w / 2, h / 2 + 15, COLORS.text_warning, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("ABSCHUSS FREIGEBEN", "TorpedoControl_Small", w / 2, h / 2 + 15, Color(255, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    fireBtn.DoClick = function()
        if not IsValid(controlStation) then return end
        if not controlStation:GetArmed() then
            surface.PlaySound("buttons/button10.wav")
            return
        end
        if not IsValid(selectedTarget) then
            surface.PlaySound("buttons/button10.wav")
            return
        end
        
        net.Start("EGC_SAM_FireSalvo")
        net.WriteEntity(controlStation)
        net.SendToServer()
        
        surface.PlaySound("buttons/button9.wav")
    end
    
    -- Trennlinie
    local sep3 = vgui.Create("DPanel", controlPanel)
    sep3:SetPos(10, 440)
    sep3:SetSize(250, 2)
    sep3.Paint = function(self, w, h)
        surface.SetDrawColor(COLORS.border)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- ============================================
    -- ABORT BUTTON
    -- ============================================
    
    local abortLabel = vgui.Create("DLabel", controlPanel)
    abortLabel:SetPos(10, 450)
    abortLabel:SetSize(250, 20)
    abortLabel:SetText("NOTFALL: RAKETEN ABBRECHEN")
    abortLabel:SetFont("TorpedoControl_Small")
    abortLabel:SetTextColor(COLORS.text_danger)
    
    local abortBtn = vgui.Create("DButton", controlPanel)
    abortBtn:SetPos(10, 475)
    abortBtn:SetSize(250, 60)
    abortBtn:SetText("")
    abortBtn.Paint = function(self, w, h)
        local activeMissiles = IsValid(controlStation) and controlStation:GetActiveMissiles() or 0
        local hasActive = activeMissiles > 0
        
        local col = Color(80, 60, 20, 255)
        if hasActive then
            local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7
            col = Color(150 * pulse, 100 * pulse, 20, 255)
            if self:IsHovered() then
                col = Color(180, 120, 30, 255)
            end
        end
        
        draw.RoundedBox(6, 0, 0, w, h, col)
        
        if hasActive then
            surface.SetDrawColor(Color(255, 200, 0, 150))
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
        
        local textCol = hasActive and Color(255, 255, 200) or Color(150, 130, 80)
        draw.SimpleText("ABORT", "TorpedoControl_Title", w / 2, h / 2 - 8, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Aktive Raketen: " .. activeMissiles, "TorpedoControl_Small", w / 2, h / 2 + 15, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    abortBtn.DoClick = function()
        if not IsValid(controlStation) then return end
        
        net.Start("EGC_SAM_AbortMissiles")
        net.WriteEntity(controlStation)
        net.SendToServer()
        
        surface.PlaySound("buttons/button10.wav")
    end
    
    -- ============================================
    -- UNTERER BEREICH: STATUS
    -- ============================================
    
    local statusPanel = vgui.Create("DPanel", frame)
    statusPanel:SetPos(15, 435)
    statusPanel:SetSize(690, 90)
    statusPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 20, 10, 200))
        surface.SetDrawColor(COLORS.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        local totalMissiles = 0
        for _, vls in ipairs(vlsList) do
            totalMissiles = totalMissiles + vls.missiles
        end
        
        local isArmed = IsValid(controlStation) and controlStation:GetArmed()
        local activeMissiles = IsValid(controlStation) and controlStation:GetActiveMissiles() or 0
        
        draw.SimpleText("SYSTEM STATUS", "TorpedoControl_Medium", 15, 10, COLORS.text)
        
        -- Status-Werte
        draw.SimpleText(string.format("VLS Online: %d", #vlsList), "TorpedoControl_Medium", 15, 35, #vlsList > 0 and COLORS.vls_online or COLORS.vls_empty)
        draw.SimpleText(string.format("Torpedos: %d", totalMissiles), "TorpedoControl_Medium", 150, 35, totalMissiles > 0 and COLORS.text or COLORS.vls_empty)
        draw.SimpleText(string.format("Ziele: %d", #targetList), "TorpedoControl_Medium", 280, 35, #targetList > 0 and COLORS.text_warning or COLORS.text_dim)
        
        -- Armed Status
        local armText = isArmed and "SCHARF" or "GESICHERT"
        local armCol = isArmed and COLORS.armed or COLORS.disarmed
        draw.SimpleText("Status: " .. armText, "TorpedoControl_Medium", 15, 60, armCol)
        
        -- Aktive Raketen
        local activeCol = activeMissiles > 0 and COLORS.text_warning or COLORS.text_dim
        draw.SimpleText(string.format("Fliegende Raketen: %d", activeMissiles), "TorpedoControl_Medium", 200, 60, activeCol)
        
        -- Zeit
        draw.SimpleText(os.date("%H:%M:%S"), "TorpedoControl_Large", w - 15, 35, COLORS.text_dim, TEXT_ALIGN_RIGHT)
        
        -- Alarm-Status
        local alarmActive = IsValid(controlStation) and controlStation:GetAlarmActive()
        if alarmActive then
            local blink = math.sin(CurTime() * 8) > 0
            local alarmCol = blink and Color(255, 50, 50) or Color(200, 0, 0)
            draw.SimpleText("⚠ ALARM AKTIV ⚠", "TorpedoControl_Medium", w - 15, 60, alarmCol, TEXT_ALIGN_RIGHT)
        end
        
        -- Scanline Animation
        local scanY = (CurTime() * 50) % h
        surface.SetDrawColor(0, 255, 0, 50)
        surface.DrawRect(0, scanY, w, 2)
    end
    
    -- ============================================
    -- LINKE SEITE UNTEN: ALARM GERÄTE
    -- ============================================
    
    local alarmPanel = vgui.Create("DPanel", frame)
    alarmPanel:SetPos(15, 335)
    alarmPanel:SetSize(280, 90)
    alarmPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 20, 10, 200))
        surface.SetDrawColor(COLORS.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        draw.SimpleText("═══ ALARM SYSTEM ═══", "TorpedoControl_Medium", w / 2, 12, COLORS.text, TEXT_ALIGN_CENTER)
        
        local alarmActive = IsValid(controlStation) and controlStation:GetAlarmActive()
        local statusText = alarmActive and "ALARM AKTIV" or "Standby"
        local statusCol = alarmActive and COLORS.armed or COLORS.text_dim
        
        draw.SimpleText("Status: " .. statusText, "TorpedoControl_Medium", 15, 40, statusCol)
        draw.SimpleText("Platziere Lautsprecher & Lampen", "TorpedoControl_Small", 15, 65, COLORS.text_dim)
    end
    
    -- ============================================
    -- HINWEISE
    -- ============================================
    
    local hintsPanel = vgui.Create("DPanel", frame)
    hintsPanel:SetPos(15, 535)
    hintsPanel:SetSize(690, 35)
    hintsPanel.Paint = function(self, w, h)
        draw.SimpleText("1. Ziel auswählen │ 2. ARM drücken (Alarm startet) │ 3. FEUER │ ABORT stoppt fliegende Raketen", 
            "TorpedoControl_Small", w / 2, h / 2, COLORS.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    -- Schritt-für-Schritt Anleitung
    local stepsPanel = vgui.Create("DPanel", frame)
    stepsPanel:SetPos(15, 580)
    stepsPanel:SetSize(970, 50)
    stepsPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(5, 15, 5, 200))
        
        local hasTarget = IsValid(selectedTarget)
        local isArmed = IsValid(controlStation) and controlStation:GetArmed()
        
        -- Schritt 1
        local step1Col = hasTarget and COLORS.vls_online or COLORS.text_dim
        draw.SimpleText("1. ZIEL", "TorpedoControl_Medium", 80, 15, step1Col, TEXT_ALIGN_CENTER)
        draw.SimpleText(hasTarget and "✓ Erfasst" or "○ Auswählen", "TorpedoControl_Small", 80, 32, step1Col, TEXT_ALIGN_CENTER)
        
        -- Pfeil
        draw.SimpleText("→", "TorpedoControl_Large", 180, 22, COLORS.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Schritt 2
        local step2Col = isArmed and COLORS.vls_online or (hasTarget and COLORS.text_warning or COLORS.text_dim)
        draw.SimpleText("2. ARM", "TorpedoControl_Medium", 280, 15, step2Col, TEXT_ALIGN_CENTER)
        draw.SimpleText(isArmed and "✓ Scharf" or "○ Aktivieren", "TorpedoControl_Small", 280, 32, step2Col, TEXT_ALIGN_CENTER)
        
        -- Pfeil
        draw.SimpleText("→", "TorpedoControl_Large", 380, 22, COLORS.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Schritt 3
        local step3Col = (hasTarget and isArmed) and COLORS.armed or COLORS.text_dim
        draw.SimpleText("3. FEUER", "TorpedoControl_Medium", 480, 15, step3Col, TEXT_ALIGN_CENTER)
        draw.SimpleText((hasTarget and isArmed) and "● BEREIT" or "○ Warten", "TorpedoControl_Small", 480, 32, step3Col, TEXT_ALIGN_CENTER)
        
        -- Abort Info
        local activeMissiles = IsValid(controlStation) and controlStation:GetActiveMissiles() or 0
        if activeMissiles > 0 then
            local blink = math.sin(CurTime() * 5) > 0
            local abortCol = blink and Color(255, 200, 0) or Color(200, 150, 0)
            draw.SimpleText("│  ABORT verfügbar: " .. activeMissiles .. " Raketen aktiv", "TorpedoControl_Medium", 600, 22, abortCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    
    -- ============================================
    -- UPDATE TIMER
    -- ============================================
    
    timer.Create("TorpedoControl_Update", 0.5, 0, function()
        if not IsValid(frame) then
            timer.Remove("TorpedoControl_Update")
            return
        end
        
        UpdateVLSList()
        UpdateTargetList()
    end)
    
    -- Initial Update
    UpdateVLSList()
    UpdateTargetList()
end

-- ============================================
-- 3D RENDERING
-- ============================================

function ENT:Draw()
    self:DrawModel()
    
    local isArmed = self:GetArmed()
    local pos = self:GetPos() + self:GetUp() * 50
    
    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        dlight.pos = pos
        
        if isArmed then
            -- Rot pulsierend wenn armed
            local pulse = math.sin(CurTime() * 6) * 0.5 + 0.5
            dlight.r = 255
            dlight.g = 50 * pulse
            dlight.b = 50 * pulse
            dlight.brightness = 2 + pulse
        else
            -- Grün wenn nicht armed
            dlight.r = 0
            dlight.g = 200
            dlight.b = 0
            dlight.brightness = 1
        end
        
        dlight.decay = 1000
        dlight.size = 100
        dlight.dietime = CurTime() + 0.1
    end
end

function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    
    if dist > 500 then return end
    
    local pos = self:GetPos() + Vector(0, 0, 70)
    local ang = (ply:EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    
    local isArmed = self:GetArmed()
    
    cam.Start3D2D(pos, ang, 0.15)
        local bgCol = isArmed and Color(60, 0, 0, 220) or Color(0, 0, 0, 200)
        draw.RoundedBox(4, -110, -30, 220, 60, bgCol)
        
        if isArmed then
            local blink = math.sin(CurTime() * 6) > 0
            local textCol = blink and Color(255, 255, 255) or Color(255, 100, 100)
            draw.SimpleText("⚠ WAFFEN SCHARF ⚠", "TorpedoControl_Medium", 0, -12, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("TORPEDO CONTROL", "TorpedoControl_Medium", 0, -12, COLORS.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        draw.SimpleText("Display interaktiv", "TorpedoControl_Small", 0, 10, COLORS.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
