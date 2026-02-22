-- eastgermancrusader_cff/lua/entities/sw_rep_command_center/cl_init.lua
-- Republic Forward Command Center - Client
-- OPTIMIERT für Mehrspieler

include("shared.lua")

-- ============================================================================
-- LOKALE VARIABLEN
-- ============================================================================
local menuOpen = false
local commandCenter = nil
local requests = {}
local menuFrame = nil

-- Performance-Cache für AV-7 Zählung
local cachedAV7Count = 0
local lastAV7CountTime = 0
local AV7_CACHE_TIME = 2.0 -- Sekunden

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

-- Gecachte AV-7 Zählung (nicht jeden Frame!)
local function GetCachedUnmannedAV7Count()
    if (CurTime() - lastAV7CountTime) < AV7_CACHE_TIME then
        return cachedAV7Count
    end
    
    cachedAV7Count = 0
    for _, ent in ipairs(ents.FindByClass("lvs_av7")) do
        if IsValid(ent) and not IsValid(ent:GetDriver()) then
            cachedAV7Count = cachedAV7Count + 1
        end
    end
    
    lastAV7CountTime = CurTime()
    return cachedAV7Count
end

-- ============================================================================
-- NETZWERK-EMPFÄNGER
-- ============================================================================

net.Receive("cff_artillery_open_menu", function()
    commandCenter = net.ReadEntity()
    requests = net.ReadTable() or {}
    
    if IsValid(commandCenter) then
        if IsValid(menuFrame) then
            menuFrame:Close()
        end
        menuOpen = true
        CreateCommandCenterMenu()
    end
end)

net.Receive("cff_artillery_close_menu", function()
    menuOpen = false
    commandCenter = nil
    requests = {}
end)

-- ============================================================================
-- MENÜ-ERSTELLUNG
-- ============================================================================

function CreateCommandCenterMenu()
    if not menuOpen or not IsValid(commandCenter) then return end
    if IsValid(menuFrame) then return end
    
    local frame = vgui.Create("DFrame")
    menuFrame = frame
    frame:SetTitle("Republic Forward Command Center")
    frame:SetSize(600, 520)
    frame:Center()
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    frame.OnClose = function()
        menuOpen = false
        menuFrame = nil
        timer.Remove("cff_menu_update")
        net.Start("cff_artillery_close_menu")
        net.SendToServer()
    end
    
    -- AV-7 Status
    local av7Status = vgui.Create("DLabel", frame)
    av7Status:SetPos(10, 30)
    av7Status:SetSize(580, 25)
    av7Status:SetFont("DermaDefault")
    
    local function UpdateAV7Status()
        local count = GetCachedUnmannedAV7Count()
        if count > 0 then
            av7Status:SetText("✓ Unbemannte AV-7: " .. count .. " Einheit(en) verfügbar")
            av7Status:SetTextColor(Color(100, 255, 100))
        else
            av7Status:SetText("❌ KEINE unbemannte AV-7 verfügbar!")
            av7Status:SetTextColor(Color(255, 100, 100))
        end
    end
    UpdateAV7Status()
    
    -- Flak-Panel
    local flakPanel = vgui.Create("DPanel", frame)
    flakPanel:SetPos(10, 60)
    flakPanel:SetSize(580, 80)
    flakPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 255))
        draw.RoundedBox(4, 1, 1, w - 2, h - 2, Color(60, 60, 60, 255))
    end
    
    local flakLabel = vgui.Create("DLabel", flakPanel)
    flakLabel:SetPos(10, 5)
    flakLabel:SetSize(200, 20)
    flakLabel:SetText("Flak-Verteidigung:")
    flakLabel:SetTextColor(Color(255, 255, 255))
    
    local flakToggleBtn = vgui.Create("DButton", flakPanel)
    flakToggleBtn:SetPos(10, 30)
    flakToggleBtn:SetSize(120, 25)
    
    local function UpdateFlakButton()
        if not IsValid(commandCenter) then return end
        local flakMode = commandCenter:GetFlakMode()
        if flakMode then
            flakToggleBtn:SetText("Flak: EIN")
            flakToggleBtn:SetTextColor(Color(100, 255, 100))
        else
            flakToggleBtn:SetText("Flak: AUS")
            flakToggleBtn:SetTextColor(Color(255, 100, 100))
        end
    end
    UpdateFlakButton()
    
    flakToggleBtn.DoClick = function()
        if not IsValid(commandCenter) then return end
        net.Start("cff_artillery_toggle_flak")
        net.WriteEntity(commandCenter)
        net.SendToServer()
        timer.Simple(0.2, UpdateFlakButton)
    end
    
    local heightLabel = vgui.Create("DLabel", flakPanel)
    heightLabel:SetPos(140, 32)
    heightLabel:SetSize(50, 20)
    heightLabel:SetText("Höhe:")
    heightLabel:SetTextColor(Color(255, 255, 255))
    
    local heightCombo = vgui.Create("DComboBox", flakPanel)
    heightCombo:SetPos(190, 30)
    heightCombo:SetSize(100, 25)
    heightCombo:AddChoice("Schicht 1 (500)", 1)
    heightCombo:AddChoice("Schicht 2 (1000)", 2)
    heightCombo:AddChoice("Schicht 3 (1500)", 3)
    heightCombo:AddChoice("Schicht 4 (2000)", 4)
    
    local function UpdateHeightCombo()
        if not IsValid(commandCenter) then return end
        local height = commandCenter:GetFlakHeight()
        heightCombo:ChooseOptionID(height)
    end
    UpdateHeightCombo()
    
    heightCombo.OnSelect = function(self, index, value, data)
        if not IsValid(commandCenter) then return end
        net.Start("cff_artillery_set_flak_height")
        net.WriteEntity(commandCenter)
        net.WriteInt(data, 8)
        net.SendToServer()
    end
    
    local flakStatusLabel = vgui.Create("DLabel", flakPanel)
    flakStatusLabel:SetPos(300, 32)
    flakStatusLabel:SetSize(270, 20)
    
    local function UpdateFlakStatus()
        if not IsValid(commandCenter) then return end
        local flakMode = commandCenter:GetFlakMode()
        if flakMode then
            local height = commandCenter:GetFlakHeight()
            flakStatusLabel:SetText("Status: Aktiv - Schicht " .. height)
            flakStatusLabel:SetTextColor(Color(100, 255, 100))
        else
            flakStatusLabel:SetText("Status: Inaktiv")
            flakStatusLabel:SetTextColor(Color(200, 200, 200))
        end
    end
    UpdateFlakStatus()
    
    -- Anfragen-Liste
    local list = vgui.Create("DListView", frame)
    list:SetPos(10, 150)
    list:SetSize(580, 280)
    
    local colId = list:AddColumn("ID")
    colId:SetWidth(0)
    list:AddColumn("Spieler"):SetWidth(100)
    list:AddColumn("Position"):SetWidth(120)
    list:AddColumn("Typ"):SetWidth(80)
    list:AddColumn("Höhe"):SetWidth(60)
    list:AddColumn("Status"):SetWidth(100)
    list:AddColumn("Aktion"):SetWidth(120)
    
    list.OnRowRightClick = function(panel, lineId, line)
        local requestId = line:GetValue(1)
        if requestId and requests[requestId] and requests[requestId].status == "pending" then
            RespondToRequest(requestId, false)
        end
    end
    
    list.OnRowSelected = function(panel, lineId, line)
        local requestId = line:GetValue(1)
        if requestId and requests[requestId] and requests[requestId].status == "pending" then
            RespondToRequest(requestId, true)
        end
    end
    
    local infoLabel = vgui.Create("DLabel", frame)
    infoLabel:SetPos(10, 440)
    infoLabel:SetSize(580, 20)
    infoLabel:SetText("Linksklick = Annehmen | Rechtsklick = Ablehnen")
    infoLabel:SetTextColor(Color(200, 200, 200))
    
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("Schließen")
    closeBtn:SetPos(10, 465)
    closeBtn:SetSize(580, 30)
    closeBtn.DoClick = function()
        frame:Close()
    end
    
    local function UpdateList()
        list:Clear()
        
        for id, request in pairs(requests) do
            if not IsValid(request.requester) then
                requests[id] = nil
                continue
            end
            
            local pos = request.targetPos
            local posStr = string.format("%.0f, %.0f, %.0f", pos.x, pos.y, pos.z)
            local status = request.status or "pending"
            local requestType = request.isFlakMode and "Flak" or (request.type or "Artillerie")
            local heightStr = request.isFlakMode and ("Schicht " .. (request.flakHeight or 1)) or "-"
            
            local line = list:AddLine(
                id,
                request.requester:Nick(),
                posStr,
                requestType,
                heightStr,
                status,
                ""
            )
            
            if status == "accepted" then
                line:SetColumnText(6, "✓ Angenommen")
                line:SetColumnText(7, "Bearbeitet")
            elseif status == "denied" then
                line:SetColumnText(6, "✗ Abgelehnt")
                line:SetColumnText(7, "Bearbeitet")
            else
                line:SetColumnText(6, "⏳ Ausstehend")
                line:SetColumnText(7, "← Klicken")
            end
        end
    end
    UpdateList()
    
    -- Update-Timer (langsamer = performanter)
    local cfg = CFF_CONFIG or {}
    local updateInterval = cfg.MenuUpdateInterval or 1.0
    
    timer.Create("cff_menu_update", updateInterval, 0, function()
        if not IsValid(frame) or not menuOpen then
            timer.Remove("cff_menu_update")
            return
        end
        
        if IsValid(commandCenter) then
            UpdateList()
            UpdateAV7Status()
            UpdateFlakButton()
            UpdateFlakStatus()
        else
            frame:Close()
        end
    end)
end

-- ============================================================================
-- ANFRAGE-ANTWORT
-- ============================================================================

function RespondToRequest(requestId, accept)
    if not IsValid(commandCenter) then
        LocalPlayer():ChatPrint("❌ Command Center nicht verfügbar!")
        return
    end
    
    if not requests[requestId] then
        LocalPlayer():ChatPrint("❌ Anfrage nicht gefunden!")
        return
    end
    
    local request = requests[requestId]
    
    if request.status ~= "pending" then
        LocalPlayer():ChatPrint("⚠️ Bereits bearbeitet!")
        return
    end
    
    if not IsValid(request.requester) then
        LocalPlayer():ChatPrint("❌ Spieler nicht verfügbar!")
        return
    end
    
    if accept then
        local count = GetCachedUnmannedAV7Count()
        if count == 0 then
            LocalPlayer():ChatPrint("❌ Keine unbemannte AV-7!")
            return
        end
    end
    
    request.status = accept and "accepted" or "denied"
    
    net.Start("cff_artillery_respond_request")
    net.WriteEntity(commandCenter)
    net.WriteString(requestId)
    net.WriteBool(accept)
    net.SendToServer()
    
    if accept then
        LocalPlayer():ChatPrint("✓ Anfrage von " .. request.requester:Nick() .. " angenommen!")
    else
        LocalPlayer():ChatPrint("✗ Anfrage von " .. request.requester:Nick() .. " abgelehnt.")
    end
end

-- ============================================================================
-- 3D TEXT RENDERING (OPTIMIERT)
-- ============================================================================

function ENT:Draw()
    self:DrawModel()
    
    local cfg = CFF_CONFIG or {}
    local maxDist = cfg.Draw3DDistance or 150
    
    -- Frühzeitiger Abbruch für Performance
    local distSqr = LocalPlayer():GetPos():DistToSqr(self:GetPos())
    if distSqr > (maxDist * maxDist) then return end
    
    local ang = self:GetAngles()
    local pos = self:GetPos() + ang:Up() * 50
    
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)
    
    -- Gecachte AV-7 Zählung
    local av7Count = GetCachedUnmannedAV7Count()
    
    cam.Start3D2D(pos, ang, 0.1)
        draw.SimpleText("Republic Forward", "DermaLarge", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Command Center", "DermaLarge", 0, 20, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Anfragen: " .. self:GetRequestCount(), "DermaDefault", 0, 45, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if av7Count > 0 then
            draw.SimpleText("AV-7: " .. av7Count .. " verfügbar", "DermaDefault", 0, 65, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("AV-7: KEINE!", "DermaDefault", 0, 65, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end
