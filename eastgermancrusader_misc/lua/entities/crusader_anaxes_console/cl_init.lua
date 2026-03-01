-- eastgermancrusader_misc/lua/entities/crusader_anaxes_console/cl_init.lua

include("shared.lua")

local ANAXES_URL = "https://eastgermancrusader.github.io/Anaxes_Naval_Systems/"
local ConsoleFrame = nil

function ENT:Initialize()
end

function ENT:Draw()
    self:DrawModel()
end

net.Receive("Crusader_AnaxesConsole_Open", function()
    OpenAnaxesConsole()
end)

function OpenAnaxesConsole()
    if IsValid(ConsoleFrame) then
        ConsoleFrame:Remove()
    end

    local w, h = 900, 600
    ConsoleFrame = vgui.Create("DFrame")
    ConsoleFrame:SetSize(w, h)
    ConsoleFrame:Center()
    ConsoleFrame:SetTitle(" Anaxes Naval System – Informationskonsole ")
    ConsoleFrame:SetVisible(true)
    ConsoleFrame:SetDraggable(true)
    ConsoleFrame:ShowCloseButton(true)
    ConsoleFrame:MakePopup()

    -- Dunkles Konsolen-Theme (Anaxes/Star Wars Stil)
    ConsoleFrame.Paint = function(self, fw, fh)
        draw.RoundedBox(8, 0, 0, fw, fh, Color(15, 20, 30, 252))
        surface.SetDrawColor(60, 120, 180, 220)
        surface.DrawOutlinedRect(0, 0, fw, fh)
        draw.RoundedBoxEx(8, 0, 0, fw, 24, Color(30, 50, 80, 255), true, true, false, false)
    end

    -- Untere Leiste mit Schließen-Button (zuerst, damit DHTML den Rest füllt)
    local bottomBar = vgui.Create("DPanel", ConsoleFrame)
    bottomBar:Dock(BOTTOM)
    bottomBar:SetTall(36)
    bottomBar:DockMargin(4, 0, 4, 4)
    bottomBar.Paint = function(_, bw, bh)
        draw.RoundedBox(4, 0, 0, bw, bh, Color(25, 35, 50, 255))
    end

    local closeBtn = vgui.Create("DButton", bottomBar)
    closeBtn:SetText("Schließen")
    closeBtn:SetSize(90, 24)
    closeBtn:Dock(RIGHT)
    closeBtn:DockMargin(0, 6, 8, 6)
    closeBtn:SetTextColor(Color(255, 255, 255))
    closeBtn.Paint = function(self, bw, bh)
        local col = Color(80, 50, 50, 255)
        if self:IsHovered() then col = Color(120, 70, 70, 255) end
        draw.RoundedBox(4, 0, 0, bw, bh, col)
    end
    closeBtn.DoClick = function()
        if IsValid(ConsoleFrame) then
            ConsoleFrame:Remove()
        end
        surface.PlaySound("buttons/button15.wav")
    end

    -- DHTML-Panel (Chromium/CEF) – füllt den Platz über der Leiste
    local html = vgui.Create("DHTML", ConsoleFrame)
    html:Dock(FILL)
    html:DockMargin(4, 28, 4, 4)
    html:OpenURL(ANAXES_URL)

    surface.PlaySound("buttons/button17.wav")
end

-- ESC schließt die Konsole
hook.Add("Think", "Crusader_AnaxesConsole_EscapeCheck", function()
    if IsValid(ConsoleFrame) and input.IsKeyDown(KEY_ESCAPE) then
        ConsoleFrame:Remove()
    end
end)
