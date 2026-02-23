-- eastgermancrusader_base/lua/entities/crusader_turbolaser_console/cl_init.lua

include("shared.lua")

-- Lokale Variablen für das UI
local ConsolePanel = nil

function ENT:Initialize()
    -- Nichts Spezielles clientseitig
end

function ENT:Draw()
    self:DrawModel()
end

-- Empfange die Turbolaser-Liste vom Server und öffne das UI
net.Receive("Crusader_TurbolaserConsole_Open", function()
    local console = net.ReadEntity()
    local count = net.ReadUInt(8)
    
    local turbolasers = {}
    for i = 1, count do
        table.insert(turbolasers, {
            entity = net.ReadEntity(),
            name = net.ReadString(),
            pos = net.ReadVector(),
            occupied = net.ReadBool(),
            health = net.ReadFloat(),
            maxhealth = net.ReadFloat()
        })
    end
    
    OpenTurbolaserConsoleUI(console, turbolasers)
end)

function OpenTurbolaserConsoleUI(console, turbolasers)
    -- Schließe existierendes Panel
    if IsValid(ConsolePanel) then
        ConsolePanel:Remove()
    end
    
    -- Hauptframe erstellen
    ConsolePanel = vgui.Create("DFrame")
    ConsolePanel:SetSize(500, 400)
    ConsolePanel:Center()
    ConsolePanel:SetTitle("⚡ TURBOLASER KONTROLLKONSOLE ⚡")
    ConsolePanel:SetVisible(true)
    ConsolePanel:SetDraggable(true)
    ConsolePanel:ShowCloseButton(true)
    ConsolePanel:MakePopup()
    
    -- Dunkles Star Wars Theme
    ConsolePanel.Paint = function(self, w, h)
        -- Hintergrund
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 25, 35, 250))
        -- Rahmen
        surface.SetDrawColor(80, 150, 255, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        -- Titel-Leiste
        draw.RoundedBoxEx(8, 0, 0, w, 25, Color(40, 60, 100, 255), true, true, false, false)
    end
    
    -- Info-Label
    local infoLabel = vgui.Create("DLabel", ConsolePanel)
    infoLabel:SetPos(10, 30)
    infoLabel:SetSize(480, 20)
    infoLabel:SetText("Verfügbare Turbolaser: " .. #turbolasers)
    infoLabel:SetTextColor(Color(100, 200, 255))
    infoLabel:SetFont("DermaDefaultBold")
    
    -- Scroll Panel für die Turbolaser-Liste
    local scrollPanel = vgui.Create("DScrollPanel", ConsolePanel)
    scrollPanel:SetPos(10, 55)
    scrollPanel:SetSize(480, 300)
    
    -- Scrollbar stylen
    local sbar = scrollPanel:GetVBar()
    sbar:SetHideButtons(true)
    sbar.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 40, 60, 200))
    end
    sbar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(80, 150, 255, 200))
    end
    
    if #turbolasers == 0 then
        -- Keine Turbolaser gefunden
        local noTurboLabel = vgui.Create("DLabel", scrollPanel)
        noTurboLabel:SetPos(10, 50)
        noTurboLabel:SetSize(460, 40)
        noTurboLabel:SetText("Keine Turbolaser auf der Karte gefunden!\n\nSpawne einen 'lvs_turbo_laser' um ihn hier zu sehen.")
        noTurboLabel:SetTextColor(Color(255, 100, 100))
        noTurboLabel:SetWrap(true)
        noTurboLabel:SetFont("DermaDefault")
    else
        -- Liste der Turbolaser erstellen
        for i, turbo in ipairs(turbolasers) do
            local turboPanel = vgui.Create("DPanel", scrollPanel)
            turboPanel:SetSize(460, 70)
            turboPanel:Dock(TOP)
            turboPanel:DockMargin(0, 5, 0, 0)
            
            local isOccupied = turbo.occupied
            local healthPercent = (turbo.maxhealth > 0) and (turbo.health / turbo.maxhealth) or 1
            
            turboPanel.Paint = function(self, w, h)
                -- Hintergrund basierend auf Status
                local bgColor = Color(40, 50, 70, 200)
                if isOccupied then
                    bgColor = Color(70, 50, 40, 200)
                end
                draw.RoundedBox(6, 0, 0, w, h, bgColor)
                
                -- Rahmen
                local borderColor = Color(60, 120, 200, 150)
                if isOccupied then
                    borderColor = Color(200, 100, 60, 150)
                end
                surface.SetDrawColor(borderColor)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                
                -- Gesundheitsbalken
                local healthBarWidth = w - 20
                local healthBarHeight = 8
                local healthBarY = h - 15
                
                -- Hintergrund des Balkens
                draw.RoundedBox(2, 10, healthBarY, healthBarWidth, healthBarHeight, Color(30, 30, 30, 200))
                
                -- Gesundheit
                local healthColor = Color(100, 255, 100)
                if healthPercent < 0.5 then
                    healthColor = Color(255, 200, 50)
                end
                if healthPercent < 0.25 then
                    healthColor = Color(255, 80, 80)
                end
                draw.RoundedBox(2, 10, healthBarY, healthBarWidth * healthPercent, healthBarHeight, healthColor)
            end
            
            -- Name des Turbolasers
            local nameLabel = vgui.Create("DLabel", turboPanel)
            nameLabel:SetPos(10, 5)
            nameLabel:SetSize(300, 20)
            nameLabel:SetText(turbo.name)
            nameLabel:SetTextColor(Color(200, 220, 255))
            nameLabel:SetFont("DermaDefaultBold")
            
            -- Position
            local posLabel = vgui.Create("DLabel", turboPanel)
            posLabel:SetPos(10, 25)
            posLabel:SetSize(300, 15)
            local posText = string.format("Position: X: %.0f | Y: %.0f | Z: %.0f", turbo.pos.x, turbo.pos.y, turbo.pos.z)
            posLabel:SetText(posText)
            posLabel:SetTextColor(Color(150, 170, 200))
            posLabel:SetFont("DermaDefault")
            
            -- Status
            local statusLabel = vgui.Create("DLabel", turboPanel)
            statusLabel:SetPos(10, 40)
            statusLabel:SetSize(200, 15)
            if isOccupied then
                statusLabel:SetText("⚠ BESETZT")
                statusLabel:SetTextColor(Color(255, 150, 100))
            else
                statusLabel:SetText("✓ VERFÜGBAR")
                statusLabel:SetTextColor(Color(100, 255, 150))
            end
            statusLabel:SetFont("DermaDefault")
            
            -- Verbinden-Button
            local connectBtn = vgui.Create("DButton", turboPanel)
            connectBtn:SetPos(350, 15)
            connectBtn:SetSize(100, 35)
            connectBtn:SetText("VERBINDEN")
            connectBtn:SetTextColor(Color(255, 255, 255))
            
            if isOccupied then
                connectBtn:SetEnabled(false)
                connectBtn:SetText("BESETZT")
                connectBtn.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(80, 60, 60, 200))
                end
            else
                connectBtn.Paint = function(self, w, h)
                    local btnColor = Color(60, 120, 200, 255)
                    if self:IsHovered() then
                        btnColor = Color(80, 150, 255, 255)
                    end
                    if self:IsDown() then
                        btnColor = Color(40, 100, 180, 255)
                    end
                    draw.RoundedBox(4, 0, 0, w, h, btnColor)
                end
                
                connectBtn.DoClick = function()
                    if IsValid(turbo.entity) and IsValid(console) then
                        net.Start("Crusader_TurbolaserConsole_Select")
                            net.WriteEntity(console)
                            net.WriteEntity(turbo.entity)
                        net.SendToServer()
                        
                        ConsolePanel:Remove()
                        
                        -- Hinweis anzeigen
                        notification.AddLegacy("Verbinde mit " .. turbo.name .. "...", NOTIFY_HINT, 3)
                        surface.PlaySound("buttons/button14.wav")
                    end
                end
            end
        end
    end
    
    -- Aktualisieren-Button
    local refreshBtn = vgui.Create("DButton", ConsolePanel)
    refreshBtn:SetPos(10, 365)
    refreshBtn:SetSize(150, 25)
    refreshBtn:SetText("🔄 AKTUALISIEREN")
    refreshBtn:SetTextColor(Color(255, 255, 255))
    refreshBtn.Paint = function(self, w, h)
        local btnColor = Color(50, 100, 80, 255)
        if self:IsHovered() then
            btnColor = Color(70, 130, 100, 255)
        end
        draw.RoundedBox(4, 0, 0, w, h, btnColor)
    end
    refreshBtn.DoClick = function()
        ConsolePanel:Remove()
        -- Simuliere erneute Verwendung der Konsole
        if IsValid(console) then
            net.Start("Crusader_TurbolaserConsole_Select")
                net.WriteEntity(console)
                net.WriteEntity(Entity(0)) -- Ungültige Entity als Refresh-Signal
            net.SendToServer()
            
            -- Manuell Use aufrufen geht nicht, also simulieren wir es
            RunConsoleCommand("gm_use", console:EntIndex())
        end
        surface.PlaySound("buttons/button15.wav")
    end
    
    -- Schließen-Button
    local closeBtn = vgui.Create("DButton", ConsolePanel)
    closeBtn:SetPos(340, 365)
    closeBtn:SetSize(150, 25)
    closeBtn:SetText("✖ SCHLIESSEN")
    closeBtn:SetTextColor(Color(255, 255, 255))
    closeBtn.Paint = function(self, w, h)
        local btnColor = Color(120, 50, 50, 255)
        if self:IsHovered() then
            btnColor = Color(150, 70, 70, 255)
        end
        draw.RoundedBox(4, 0, 0, w, h, btnColor)
    end
    closeBtn.DoClick = function()
        ConsolePanel:Remove()
        surface.PlaySound("buttons/combine_button1.wav")
    end
    
    -- Sound beim Öffnen
    surface.PlaySound("buttons/button17.wav")
end

-- Schließe das Panel wenn ESC gedrückt wird
hook.Add("Think", "Crusader_TurboConsole_EscapeCheck", function()
    if IsValid(ConsolePanel) and input.IsKeyDown(KEY_ESCAPE) then
        ConsolePanel:Remove()
    end
end)

local _cacheSchema = 2
timer.Create("CrusaderTurbolaser_ConfigRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC Turbolaser] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)
