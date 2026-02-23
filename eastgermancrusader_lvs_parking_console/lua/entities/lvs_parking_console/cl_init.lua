-- eastgermancrusader_base/lua/entities/lvs_parking_console/cl_init.lua

include("shared.lua")

-- ==========================================
-- REPUBLIC DESIGN CONSTANTS
-- ==========================================
local COL_REP_MAIN   = Color(0, 180, 255)
local COL_REP_DIM    = Color(0, 80, 120, 150)
local COL_REP_BG     = Color(5, 15, 25, 230)
local COL_REP_ALERT  = Color(255, 100, 50)
local COL_REP_SUCCESS= Color(0, 255, 150)

-- Hilfsfunktion: Zeichnet einen Tech-Rahmen (Clone Wars Stil)
local function DrawTechBorder(x, y, w, h, col, fillAlpha)
    if fillAlpha then
        surface.SetDrawColor(col.r, col.g, col.b, fillAlpha)
        surface.DrawRect(x, y, w, h)
    end

    surface.SetDrawColor(col)
    surface.DrawOutlinedRect(x, y, w, h, 2)

    -- Ecken-Details
    local len = 10
    surface.DrawRect(x, y, len, 4) -- Oben Links H
    surface.DrawRect(x, y, 4, len) -- Oben Links V

    surface.DrawRect(x + w - len, y + h - 4, len, 4) -- Unten Rechts H
    surface.DrawRect(x + w - 4, y + h - len, 4, len) -- Unten Rechts V
end

-- Hilfsfunktion: Scanline Effekt
local function DrawScanlines(w, h)
    surface.SetDrawColor(0, 180, 255, 5)
    for i = 0, h, 4 do
        surface.DrawRect(0, i, w, 1)
    end
    
    -- Laufender Balken
    local barPos = (CurTime() * 50) % h
    surface.SetDrawColor(0, 180, 255, 15)
    surface.DrawRect(0, barPos, w, 10)
end

function ENT:Initialize()
end

function ENT:Draw()
    self:DrawModel()
    
    -- 3D2D Text über der Konsole (Holo-Projektor Stil)
    local pos = self:GetPos() + self:GetUp() * 90
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    
    -- Pulsierender Effekt
    local pulse = math.abs(math.sin(CurTime() * 2))
    local floatY = math.sin(CurTime()) * 2
    
    -- Berechtigung prüfen für visuelles Feedback
    local hasAccess = self:HasClearance(LocalPlayer())
    
    cam.Start3D2D(pos + Vector(0, 0, floatY), ang, 0.1)
        -- Holo-Basisring
        surface.SetDrawColor(0, 180, 255, 50)
        draw.NoTexture()
        local size = 350
        
        -- Farbe basierend auf Zugriff ändern
        local mainColor = hasAccess and COL_REP_MAIN or COL_REP_ALERT
        
        DrawTechBorder(-size/2, -60, size, 120, mainColor, 20)
        
        -- Text
        draw.SimpleText("LOGISTICS TERMINAL", "DermaLarge", 0, -20, mainColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("[" .. self:GetConsoleName():upper() .. "]", "DermaDefaultBold", 0, 10, Color(0, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- "Press E" oder "Restricted"
        local alpha = 100 + (pulse * 155)
        
        if hasAccess then
            draw.SimpleText("ACCESS: [ E ]", "DermaDefault", 0, 40, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("RESTRICTED", "DermaDefaultBold", 0, 40, Color(255, 50, 50, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

-- =====================
-- C-MENÜ (Context Menu)
-- =====================
properties.Add("lvs_parking_config", {
    MenuLabel = "LVS Parking Einstellungen",
    Order = 1000,
    MenuIcon = "icon16/cog.png",
    
    Filter = function(self, ent, ply)
        if not IsValid(ent) then return false end
        if ent:GetClass() ~= "lvs_parking_console" then return false end
        if not ply:IsAdmin() then return false end
        return true
    end,
    
    Action = function(self, ent)
        net.Start("LVS_Parking_RequestConfig")
            net.WriteEntity(ent)
        net.SendToServer()
    end
})

net.Receive("LVS_Parking_SendConfig", function()
    local console = net.ReadEntity()
    local vehicles = net.ReadTable()
    local limits = net.ReadTable()
    
    if not IsValid(console) then return end
    
    LVS_Parking_OpenConfigMenu(console, vehicles, limits)
end)

-- Admin Config Menü (Datapad Stil)
function LVS_Parking_OpenConfigMenu(console, vehicles, limits)
    if not IsValid(console) then return end
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(550, 650)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false) -- Custom Close Button
    
    frame.Paint = function(self, w, h)
        surface.SetDrawColor(COL_REP_BG)
        surface.DrawRect(0, 0, w, h)
        DrawTechBorder(0, 0, w, h, COL_REP_MAIN)
        draw.SimpleText("SYSTEM CONFIGURATION // ADMIN", "DermaDefaultBold", 15, 10, COL_REP_MAIN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(510, 5)
    closeBtn:SetSize(35, 20)
    closeBtn:SetText("X")
    closeBtn:SetTextColor(COL_REP_ALERT)
    closeBtn.Paint = function() end
    closeBtn.DoClick = function() frame:Close() end
    
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(15, 35, 15, 15)
    
    -- Helper für Labels
    local function AddHeader(text, parent)
        local l = vgui.Create("DLabel", parent)
        l:Dock(TOP)
        l:SetText(text)
        l:SetTextColor(COL_REP_MAIN)
        l:SetFont("DermaDefaultBold")
        l:DockMargin(0, 15, 0, 5)
        return l
    end
    
    AddHeader("TERMINAL DESIGNATION", scroll)
    
    local nameEntry = vgui.Create("DTextEntry", scroll)
    nameEntry:Dock(TOP)
    nameEntry:SetValue(console:GetConsoleName())
    nameEntry:SetTall(30)
    nameEntry.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(COL_REP_DIM)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(Color(255,255,255), COL_REP_MAIN, Color(255,255,255))
    end
    nameEntry.OnEnter = function(self)
        net.Start("LVS_Parking_UpdateConfig")
            net.WriteEntity(console)
            net.WriteString("name")
            net.WriteString(self:GetValue())
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end
    
    AddHeader("HANGAR LIMIT (SIMULTANEOUS)", scroll)
    
    local maxSlider = vgui.Create("DNumSlider", scroll)
    maxSlider:Dock(TOP)
    maxSlider:SetText("")
    maxSlider:SetMin(1)
    maxSlider:SetMax(50)
    maxSlider:SetDecimals(0)
    maxSlider:SetValue(console:GetMaxSpawned())
    maxSlider:SetDark(false) -- Wichtig für Textfarbe
    maxSlider.Label:SetTextColor(Color(255,255,255))
    
    maxSlider.OnValueChanged = function(self, value)
        net.Start("LVS_Parking_UpdateConfig")
            net.WriteEntity(console)
            net.WriteString("maxspawned")
            net.WriteUInt(math.Round(value), 8)
        net.SendToServer()
    end
    
    AddHeader("VEHICLE REQUISITION LIMITS", scroll)
    
    -- Kategorien
    local categories = {}
    for class, data in pairs(vehicles) do
        local cat = data.category or "Unclassified"
        categories[cat] = categories[cat] or {}
        table.insert(categories[cat], {class = class, name = data.name})
    end
    
    for catName, catVehicles in SortedPairs(categories) do
        local catLabel = vgui.Create("DLabel", scroll)
        catLabel:Dock(TOP)
        catLabel:SetText("> SECTOR: " .. catName:upper())
        catLabel:SetTextColor(Color(0, 150, 200))
        catLabel:DockMargin(0, 10, 0, 2)
        
        for _, veh in SortedPairsByMemberValue(catVehicles, "name") do
            local panel = vgui.Create("DPanel", scroll)
            panel:Dock(TOP)
            panel:SetTall(30)
            panel:DockMargin(0, 2, 0, 0)
            panel.Paint = function(self, w, h)
                surface.SetDrawColor(10, 30, 50, 200)
                surface.DrawRect(0, 0, w, h)
            end
            
            local label = vgui.Create("DLabel", panel)
            label:Dock(LEFT)
            label:SetWide(300)
            label:SetText(veh.name)
            label:SetTextColor(Color(200, 220, 255))
            label:DockMargin(10, 0, 0, 0)
            
            local numWang = vgui.Create("DNumberWang", panel)
            numWang:Dock(RIGHT)
            numWang:SetWide(60)
            numWang:SetMin(0)
            numWang:SetMax(50)
            numWang:SetValue(limits[veh.class] or 2)
            numWang:DockMargin(0, 5, 5, 5)
            
            numWang.OnValueChanged = function(self, value)
                net.Start("LVS_Parking_UpdateConfig")
                    net.WriteEntity(console)
                    net.WriteString("vehiclelimit")
                    net.WriteString(veh.class)
                    net.WriteUInt(math.Round(value), 8)
                net.SendToServer()
            end
        end
    end
end

-- =====================
-- FAHRZEUG AUSWAHL MENÜ
-- =====================
net.Receive("LVS_Parking_OpenMenu", function()
    local console = net.ReadEntity()
    local consoleName = net.ReadString()
    local vehicles = net.ReadTable()
    local limits = net.ReadTable()
    local counts = net.ReadTable()
    local maxSpawned = net.ReadUInt(8)
    local totalSpawned = net.ReadUInt(8)
    local spawnPoints = net.ReadTable()
    
    -- Hauptfenster (Holo Interface)
    local frame = vgui.Create("DFrame")
    frame:SetSize(800, 600)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    
    frame.Paint = function(self, w, h)
        -- Transparenter Hintergrund
        surface.SetDrawColor(COL_REP_BG)
        surface.DrawRect(0, 0, w, h)
        
        -- Tech Border
        DrawTechBorder(0, 0, w, h, COL_REP_MAIN)
        
        -- Scanlines
        DrawScanlines(w, h)
        
        -- Header
        surface.SetDrawColor(COL_REP_DIM)
        surface.DrawRect(5, 5, w-10, 30)
        draw.SimpleText("REPUBLIC LOGISTICS // " .. consoleName:upper(), "DermaDefaultBold", 15, 20, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(760, 5)
    closeBtn:SetSize(35, 30)
    closeBtn:SetText("X")
    closeBtn:SetFont("DermaLarge")
    closeBtn:SetTextColor(COL_REP_ALERT)
    closeBtn.Paint = function() end
    closeBtn.DoClick = function() 
        surface.PlaySound("buttons/combine_button2.wav")
        frame:Close() 
    end
    
    -- Status Anzeige (Oben)
    local statusPanel = vgui.Create("DPanel", frame)
    statusPanel:Dock(TOP)
    statusPanel:SetTall(40)
    statusPanel:DockMargin(10, 40, 10, 10)
    statusPanel.Paint = function(self, w, h)
        surface.SetDrawColor(0, 20, 40, 200)
        surface.DrawRect(0, 0, w, h)
        
        -- Fortschrittsbalken
        local pct = math.Clamp(totalSpawned / maxSpawned, 0, 1)
        local barCol = pct >= 1 and COL_REP_ALERT or COL_REP_SUCCESS
        
        surface.SetDrawColor(barCol.r, barCol.g, barCol.b, 50)
        surface.DrawRect(2, 2, (w-4) * pct, h-4)
        
        surface.SetDrawColor(COL_REP_MAIN)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        draw.SimpleText("HANGAR CAPACITY: " .. totalSpawned .. " / " .. maxSpawned, "DermaDefaultBold", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    local mainPanel = vgui.Create("DPanel", frame)
    mainPanel:Dock(FILL)
    mainPanel:DockMargin(10, 0, 10, 10)
    mainPanel.Paint = nil
    
    -- ===== LINKE SEITE: SPAWN PUNKTE (ZIELERFASSUNG) =====
    local leftPanel = vgui.Create("DPanel", mainPanel)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(220)
    leftPanel:DockMargin(0, 0, 10, 0)
    leftPanel.Paint = function(self, w, h)
        DrawTechBorder(0, 0, w, h, COL_REP_DIM, 50)
    end
    
    local spLabel = vgui.Create("DLabel", leftPanel)
    spLabel:Dock(TOP)
    spLabel:SetTall(30)
    spLabel:SetText("  TARGET LZ:")
    spLabel:SetTextColor(COL_REP_MAIN)
    spLabel:SetFont("DermaDefaultBold")
    spLabel.Paint = function(self, w, h) 
        surface.SetDrawColor(0, 0, 0, 100)
        surface.DrawRect(0,0,w,h)
    end
    
    local spScroll = vgui.Create("DScrollPanel", leftPanel)
    spScroll:Dock(FILL)
    spScroll:DockMargin(5, 5, 5, 5)
    
    local selectedSpawnPoint = nil
    local spawnPointButtons = {}
    
    if #spawnPoints == 0 then
        local noSpLabel = vgui.Create("DLabel", spScroll)
        noSpLabel:Dock(TOP)
        noSpLabel:SetTall(50)
        noSpLabel:SetText("NO UPLINK DETECTED")
        noSpLabel:SetTextColor(COL_REP_ALERT)
        noSpLabel:SetContentAlignment(5)
    else
        for i, sp in ipairs(spawnPoints) do
            local btn = vgui.Create("DButton", spScroll)
            btn:Dock(TOP)
            btn:SetTall(40)
            btn:SetText(sp.name)
            btn:SetFont("DermaDefault")
            btn:SetTextColor(Color(200,200,200))
            btn:DockMargin(0, 2, 0, 2)
            btn.spData = sp
            btn.selected = false
            
            btn.Paint = function(self, w, h)
                local col = self.selected and COL_REP_SUCCESS or COL_REP_DIM
                if self:IsHovered() and not self.selected then col = COL_REP_MAIN end
                
                -- Button Rahmen
                surface.SetDrawColor(col)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                
                -- Füllung bei Auswahl
                if self.selected then
                    surface.SetDrawColor(col.r, col.g, col.b, 50)
                    surface.DrawRect(0, 0, w, h)
                    -- Kleiner Pfeil
                    draw.SimpleText(">", "DermaDefault", 10, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
            
            btn.DoClick = function(self)
                surface.PlaySound("buttons/button15.wav")
                for _, b in ipairs(spawnPointButtons) do b.selected = false end
                self.selected = true
                selectedSpawnPoint = self.spData
            end
            
            table.insert(spawnPointButtons, btn)
            if i == 1 then btn.selected = true; selectedSpawnPoint = sp end
        end
    end
    
    -- ===== RECHTE SEITE: FAHRZEUGE (MANIFEST) =====
    local rightPanel = vgui.Create("DPanel", mainPanel)
    rightPanel:Dock(FILL)
    rightPanel.Paint = function(self, w, h)
        DrawTechBorder(0, 0, w, h, COL_REP_DIM, 50)
    end
    
    local vehLabel = vgui.Create("DLabel", rightPanel)
    vehLabel:Dock(TOP)
    vehLabel:SetTall(30)
    vehLabel:SetText("  AVAILABLE ASSETS: " .. table.Count(vehicles))
    vehLabel:SetTextColor(COL_REP_MAIN)
    vehLabel:SetFont("DermaDefaultBold")
    vehLabel.Paint = function(self, w, h) 
        surface.SetDrawColor(0, 0, 0, 100)
        surface.DrawRect(0,0,w,h)
    end
    
    local vehScroll = vgui.Create("DScrollPanel", rightPanel)
    vehScroll:Dock(FILL)
    vehScroll:DockMargin(5, 5, 5, 5)
    
    local categories = {}
    for class, data in pairs(vehicles) do
        local cat = data.category or "Other"
        categories[cat] = categories[cat] or {}
        table.insert(categories[cat], {class = class, name = data.name})
    end
    
    for catName, catVehicles in SortedPairs(categories) do
        local catHeader = vgui.Create("DLabel", vehScroll)
        catHeader:Dock(TOP)
        catHeader:SetText("// " .. catName:upper())
        catHeader:SetTextColor(Color(0, 150, 200))
        catHeader:DockMargin(5, 10, 0, 5)
        
        for _, veh in SortedPairsByMemberValue(catVehicles, "name") do
            local limit = limits[veh.class] or 0
            local count = counts[veh.class] or 0
            
            if limit > 0 then
                local btn = vgui.Create("DButton", vehScroll)
                btn:Dock(TOP)
                btn:SetTall(35)
                btn:SetText("")
                btn:DockMargin(0, 2, 0, 2)
                
                local available = count < limit and totalSpawned < maxSpawned
                
                btn.Paint = function(self, w, h)
                    local baseCol = available and COL_REP_DIM or Color(80, 20, 20, 100)
                    local txtCol = available and Color(255,255,255) or Color(100,100,100)
                    
                    if self:IsHovered() and available then
                        baseCol = COL_REP_MAIN
                    end
                    
                    surface.SetDrawColor(baseCol)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    
                    -- Hintergrund leicht füllen
                    surface.SetDrawColor(baseCol.r, baseCol.g, baseCol.b, 20)
                    surface.DrawRect(0, 0, w, h)
                    
                    -- Fahrzeug Name
                    draw.SimpleText(veh.name:upper(), "DermaDefault", 15, h/2, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    
                    -- Limit Anzeige
                    local countCol = available and COL_REP_SUCCESS or COL_REP_ALERT
                    draw.SimpleText(count .. " / " .. limit, "DermaDefault", w - 15, h/2, countCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                
                btn.DoClick = function()
                    if not available then
                        surface.PlaySound("buttons/button10.wav")
                        return
                    end
                    
                    if not selectedSpawnPoint then
                        surface.PlaySound("buttons/button10.wav")
                        LocalPlayer():ChatPrint("[LOGISTICS] ERROR: NO LZ SELECTED")
                        return
                    end
                    
                    surface.PlaySound("buttons/button14.wav")
                    
                    net.Start("LVS_Parking_SpawnVehicle")
                        net.WriteEntity(console)
                        net.WriteString(veh.class)
                        net.WriteUInt(selectedSpawnPoint.entIndex, 16)
                    net.SendToServer()
                    
                    frame:Close()
                end
            end
        end
    end
    
    local infoLabel = vgui.Create("DLabel", frame)
    infoLabel:Dock(BOTTOM)
    infoLabel:SetTall(25)
    infoLabel:SetText("PRESS [E] TO RETURN VEHICLE")
    infoLabel:SetTextColor(Color(100, 200, 255, 100))
    infoLabel:SetContentAlignment(5)
end)

local _cacheSchema = 2
timer.Create("LVS_Parking_ConfigRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC LVS Parking] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)