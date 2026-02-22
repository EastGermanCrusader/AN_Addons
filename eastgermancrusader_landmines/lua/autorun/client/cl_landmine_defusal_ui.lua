-- Landmine Defusal Minigame UI (für Crusader-Minen)
if SERVER then return end

local PANEL = {}

function PANEL:Init()
    self:SetSize(ScrW() * 0.7, ScrH() * 0.75)
    self:Center()
    self:SetTitle("⚠️ LANDMINEN-ENTSCHÄRFUNG ⚠️")
    self:SetDraggable(true)
    self:ShowCloseButton(false)
    self:MakePopup()

    self.StartTime = CurTime()
    self.Wires = {}
    self.CutWires = {}
    self.CurrentStep = 1
    self.CaseName = ""
    self.CaseDescription = ""
    self.Sequence = {}

    self.BGPanel = vgui.Create("DPanel", self)
    self.BGPanel:Dock(FILL)
    self.BGPanel:DockMargin(5, 5, 5, 5)
    self.BGPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(15, 15, 20, 250))
        surface.SetDrawColor(80, 80, 100, 200)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    self.TimerLabel = vgui.Create("DLabel", self.BGPanel)
    self.TimerLabel:Dock(TOP)
    self.TimerLabel:DockMargin(10, 10, 10, 5)
    self.TimerLabel:SetFont("DermaLarge")
    self.TimerLabel:SetTextColor(Color(255, 50, 50))
    self.TimerLabel:SetContentAlignment(5)
    self.TimerLabel:SetTall(40)

    -- Kein Anweisungstext (nicht verraten, wie entschärft wird)
    self.CasePanel = vgui.Create("DPanel", self.BGPanel)
    self.CasePanel:Dock(TOP)
    self.CasePanel:DockMargin(10, 5, 10, 5)
    self.CasePanel:SetTall(0)
    self.CasePanel:SetVisible(false)

    self.WirePanel = vgui.Create("DPanel", self.BGPanel)
    self.WirePanel:Dock(FILL)
    self.WirePanel:DockMargin(10, 0, 10, 10)
    self.WirePanel.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 28, 220))
        surface.SetDrawColor(30, 30, 40, 100)
        for i = 0, w, 40 do surface.DrawLine(i, 0, i, h) end
        for i = 0, h, 40 do surface.DrawLine(0, i, w, i) end
    end

    self.CloseButton = vgui.Create("DButton", self.BGPanel)
    self.CloseButton:Dock(BOTTOM)
    self.CloseButton:DockMargin(10, 10, 10, 10)
    self.CloseButton:SetTall(40)
    self.CloseButton:SetText("ABBRECHEN (Mine explodiert!)")
    self.CloseButton:SetTextColor(Color(255, 255, 255))
    self.CloseButton:SetFont("DermaDefaultBold")
    self.CloseButton.Paint = function(s, w, h)
        local col = s:IsHovered() and Color(180, 0, 0, 220) or Color(120, 0, 0, 200)
        draw.RoundedBox(4, 0, 0, w, h, col)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    self.CloseButton.DoClick = function()
        self:Close()
        net.Start("LandmineDefusal_Close")
        net.WriteBool(false)
        net.SendToServer()
    end
end

function PANEL:SetupWires()
    self.WirePanel:Clear()
    if not self.Wires or #self.Wires == 0 then return end
    -- Größe erst nach Layout verfügbar – feste Werte nutzen, damit Kabel immer sichtbar sind
    local pw = math.max(self.WirePanel:GetWide(), 400)
    local ph = math.max(self.WirePanel:GetTall(), 280)
    local wireHeight = math.min(70, math.floor((ph - 40) / #self.Wires) - 8)
    if wireHeight < 30 then wireHeight = 30 end
    local wireSpacing = 8
    self.WireButtons = {}

    for i, wire in ipairs(self.Wires) do
        local wireContainer = vgui.Create("DPanel", self.WirePanel)
        wireContainer:SetPos(20, 15 + (i-1) * (wireHeight + wireSpacing))
        wireContainer:SetSize(math.max(pw - 40, 360), wireHeight)
        wireContainer.Wire = wire
        wireContainer.IsCut = false
        wireContainer.BlinkAlpha = 0
        wireContainer.Paint = function(s, w, h)
            local shouldHighlight = false
            if self.CurrentStep <= #self.Sequence then
                local expectedName = self.Sequence[self.CurrentStep]
                if wire.name == expectedName and not s.IsCut then
                    shouldHighlight = true
                    s.BlinkAlpha = math.abs(math.sin(CurTime() * 4)) * 120 + 135
                end
            end
            if s.IsCut then
                draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 200))
                local col = Color(wire.color.r * 0.3, wire.color.g * 0.3, wire.color.b * 0.3)
                for j = 0, 6 do
                    surface.SetDrawColor(col.r, col.g, col.b, 180)
                    surface.DrawLine(10, h/2 - 3 + j, w/2 - 15, h/2 - 3 + j)
                    surface.DrawLine(w/2 + 15, h/2 - 3 + j, w - 10, h/2 - 3 + j)
                end
                draw.SimpleText("✗✗✗", "DermaLarge", w/2, h/2, Color(150, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("DURCHGETRENNT", "DermaDefaultBold", w/2, h - 15, Color(100, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                local baseCol = wire.color
                local bgCol = shouldHighlight and Color(baseCol.r * 0.6, baseCol.g * 0.6, baseCol.b * 0.6, s.BlinkAlpha) or Color(baseCol.r * 0.25, baseCol.g * 0.25, baseCol.b * 0.25, 180)
                draw.RoundedBox(4, 0, 0, w, h, bgCol)
                surface.SetDrawColor(baseCol.r, baseCol.g, baseCol.b, shouldHighlight and 255 or 120)
                surface.DrawOutlinedRect(2, 2, w-4, h-4)
                for j = 0, 8 do
                    surface.SetDrawColor(baseCol.r, baseCol.g, baseCol.b, 230)
                    surface.DrawLine(10, h/2 - 4 + j, w - 10, h/2 - 4 + j)
                end
                draw.RoundedBox(0, 5, h/2 - 8, 10, 16, baseCol)
                draw.RoundedBox(0, w - 15, h/2 - 8, 10, 16, baseCol)
                draw.SimpleText(wire.name, "DermaLarge", w/2, h/2 - 20, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("#" .. i, "DermaDefault", 25, h - 12, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        local cutButton = vgui.Create("DButton", wireContainer)
        cutButton:SetSize(180, math.max(wireHeight - 12, 20))
        cutButton:SetPos((math.max(pw - 40, 360)) / 2 - 90, 6)
        cutButton:SetText("")
        cutButton:SetTooltip("Draht durchschneiden")
        cutButton.Paint = function(s, w, h)
            if wireContainer.IsCut then return end
            local col = s:IsHovered() and Color(200, 50, 50, 180) or Color(120, 30, 30, 120)
            draw.RoundedBox(4, 0, 0, w, h, col)
            if s:IsHovered() then surface.DrawOutlinedRect(0, 0, w, h) end
            draw.SimpleText("✂ DURCHSCHNEIDEN", "DermaDefaultBold", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        cutButton.DoClick = function()
            if wireContainer.IsCut then return end
            surface.PlaySound(LandmineDefusal.Sounds.cutWire)
            net.Start("LandmineDefusal_CutWire")
            net.WriteInt(i, 8)
            net.SendToServer()
        end
        table.insert(self.WireButtons, wireContainer)
    end
end

function PANEL:OnWireCut(wirePosition, success, complete)
    if not success then self:ShowFailure() return end
    if self.WireButtons[wirePosition] then self.WireButtons[wirePosition].IsCut = true end
    self.CurrentStep = self.CurrentStep + 1
    if complete then
        timer.Simple(1, function()
            if IsValid(self) then self:ShowSuccess() end
        end)
    end
end

function PANEL:ShowSuccess()
    self:SetTitle("✓ ERFOLG!")
    self.CasePanel:Clear()
    local successMsg = vgui.Create("DLabel", self.CasePanel)
    successMsg:Dock(FILL)
    successMsg:SetFont("DermaLarge")
    successMsg:SetTextColor(Color(0, 255, 0))
    successMsg:SetContentAlignment(5)
    successMsg:SetText("LANDMINE ERFOLGREICH ENTSCHÄRFT!")
    self.WirePanel:Clear()
    local successPanel = vgui.Create("DPanel", self.WirePanel)
    successPanel:Dock(FILL)
    successPanel:DockMargin(20, 20, 20, 20)
    successPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 100, 0, 200))
        surface.DrawOutlinedRect(5, 5, w-10, h-10)
        draw.SimpleText("✓", "DermaLarge", w/2, h/2 - 60, Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("MISSION ERFOLGREICH", "DermaLarge", w/2, h/2, Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(LandmineDefusal.SuccessMessage, "DermaDefault", w/2, h/2 + 40, Color(200, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.CloseButton:SetText("SCHLIEßEN")
    self.CloseButton.Paint = function(s, w, h)
        local col = s:IsHovered() and Color(0, 180, 0) or Color(0, 120, 0)
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    surface.PlaySound(LandmineDefusal.Sounds.success)
    timer.Simple(5, function() if IsValid(self) then self:Close() end end)
end

function PANEL:ShowFailure()
    self:SetTitle("✗ FEHLGESCHLAGEN!")
    self.CasePanel:Clear()
    local failMsg = vgui.Create("DLabel", self.CasePanel)
    failMsg:Dock(FILL)
    failMsg:SetFont("DermaLarge")
    failMsg:SetTextColor(Color(255, 0, 0))
    failMsg:SetContentAlignment(5)
    failMsg:SetText("EXPLOSION!")
    self.WirePanel:Clear()
    local failPanel = vgui.Create("DPanel", self.WirePanel)
    failPanel:Dock(FILL)
    failPanel:DockMargin(20, 20, 20, 20)
    failPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(100, 0, 0, 200))
        surface.DrawOutlinedRect(5, 5, w-10, h-10)
        draw.SimpleText("✗", "DermaLarge", w/2, h/2 - 60, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("MISSION FEHLGESCHLAGEN", "DermaLarge", w/2, h/2, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(LandmineDefusal.FailureMessage, "DermaDefault", w/2, h/2 + 40, Color(255, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.CloseButton:SetText("SCHLIEßEN")
    self.CloseButton.Paint = function(s, w, h)
        local col = s:IsHovered() and Color(100, 100, 100) or Color(70, 70, 70)
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    surface.PlaySound(LandmineDefusal.Sounds.failure)
    timer.Simple(3, function() if IsValid(self) then self:Close() end end)
end

function PANEL:Think()
    if not IsValid(self.Mine) then self:Close() return end
    local timeLeft = self.Mine.GetTimeRemaining and self.Mine:GetTimeRemaining() or 0
    self.TimerLabel:SetText(string.format("⏱ ZEIT: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60))
    if timeLeft <= 10 then self.TimerLabel:SetTextColor(Color(255, 0, 0))
    elseif timeLeft <= 30 then self.TimerLabel:SetTextColor(Color(255, 128, 0))
    else self.TimerLabel:SetTextColor(Color(255, 200, 100)) end
end

vgui.Register("LandmineDefusalUI", PANEL, "DFrame")

net.Receive("LandmineDefusal_OpenUI", function()
    local mine = net.ReadEntity()
    local wires = net.ReadTable()
    local caseName = net.ReadString()
    local caseDesc = net.ReadString()
    local sequence = net.ReadTable()
    local frame = vgui.Create("LandmineDefusalUI")
    frame.Mine = mine
    frame.Wires = wires
    frame.CaseName = caseName
    frame.CaseDescription = caseDesc
    frame.Sequence = sequence
    frame.CurrentStep = 1
    -- Kabel erst nach Layout zeichnen (sonst ist WirePanel-Größe 0)
    timer.Simple(0.05, function()
        if IsValid(frame) and frame.SetupWires then
            frame:SetupWires()
        end
    end)
end)

net.Receive("LandmineDefusal_WireResult", function()
    local wirePos = net.ReadInt(8)
    local success = net.ReadBool()
    local complete = net.ReadBool()
    for _, pnl in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if pnl.ClassName == "LandmineDefusalUI" and IsValid(pnl) then
            pnl:OnWireCut(wirePos, success, complete)
            break
        end
    end
end)

net.Receive("LandmineDefusal_Result", function()
    local success = net.ReadBool()
    for _, pnl in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if pnl.ClassName == "LandmineDefusalUI" and IsValid(pnl) then
            if success then pnl:ShowSuccess() else pnl:ShowFailure() end
            break
        end
    end
end)

local _cacheSchema = 2
timer.Create("CrusaderDefusal_CacheRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC Landmines] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)
