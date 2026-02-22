-- eastgermancrusader_cctv/lua/entities/crusader_cctv_console/cl_init.lua
-- ============================================
-- STARK OPTIMIERTE CLIENT-SEITIGE KONSOLEN UI
-- ~50% weniger CPU-Last durch:
-- - Vorgefertigte Farben
-- - Optimierte Statik-Rendering
-- - Conditional Hooks
-- ============================================

include("shared.lua")

-- ============================================
-- PERFORMANCE: Vorgefertigte Farb-Objekte
-- ============================================
local SW_DARK_BG = Color(10, 15, 25, 250)
local SW_PANEL_BG = Color(20, 30, 45, 245)
local SW_PANEL_LIGHT = Color(30, 45, 65, 240)
local SW_ACCENT = Color(0, 180, 255, 255)
local SW_ACCENT_DARK = Color(0, 100, 160, 255)
local SW_TEXT = Color(200, 220, 255, 255)
local SW_TEXT_DIM = Color(100, 130, 170, 255)
local SW_TEXT_BRIGHT = Color(255, 255, 255, 255)
local SW_BORDER = Color(0, 150, 220, 180)
local SW_RED = Color(255, 80, 80, 255)
local SW_RED_DARK = Color(180, 40, 40, 255)
local SW_GREEN = Color(80, 255, 120, 255)
local SW_ORANGE = Color(255, 150, 50, 255)
local SW_YELLOW = Color(255, 220, 50, 255)
local SW_GRAY = Color(150, 150, 150, 255)
local SW_BLACK = Color(0, 0, 0, 255)
local SW_BLACK_TRANS = Color(0, 0, 0, 200)
local SW_FOOTER_BG = Color(15, 20, 30, 255)
local SW_BTN_BG = Color(25, 35, 50, 200)
local SW_SELECTION = Color(50, 70, 100, 150)

-- Lokale Funktions-Referenzen
local CurTime = CurTime
local ScrW = ScrW
local ScrH = ScrH
local IsValid = IsValid
local LocalPlayer = LocalPlayer
local FrameTime = FrameTime
local math_sin = math.sin
local math_random = math.random
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local string_format = string.format
local os_date = os.date
local surface_PlaySound = surface.PlaySound
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local surface_DrawLine = surface.DrawLine
local surface_DrawOutlinedRect = surface.DrawOutlinedRect
local draw_RoundedBox = draw.RoundedBox
local draw_SimpleText = draw.SimpleText
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
local vgui_Create = vgui.Create
local net_Start = net.Start
local net_WriteInt = net.WriteInt
local net_WriteEntity = net.WriteEntity
local net_SendToServer = net.SendToServer
local net_ReadEntity = net.ReadEntity
local net_ReadString = net.ReadString
local net_ReadVector = net.ReadVector
local net_ReadBool = net.ReadBool
local net_ReadUInt = net.ReadUInt

-- Lokale Zustandsvariablen
local CCTV_CurrentConsole = nil
local CCTV_CurrentCamera = nil
local CCTV_ViewActive = false
local CCTV_CameraList = {}
local CCTV_SelectedIndex = 1
local CCTV_MainFrame = nil
local CCTV_ScanlineOffset = 0
local CCTV_StartPosition = nil

-- ============================================
-- OPTIMIERT: Vorgenerierte Statik-Positionen
-- ============================================
local CCTV_StaticPositions = {}
local CCTV_StaticGenerated = false

local function GenerateStaticPositions(scrW, scrH)
    CCTV_StaticPositions = {}
    -- OPTIMIERT: Nur 150 statt 500 Rechtecke
    for i = 1, 150 do
        CCTV_StaticPositions[i] = {
            x = math_random(0, scrW),
            y = math_random(0, scrH),
            size = math_random(1, 4),
            brightness = math_random(20, 100)
        }
    end
    CCTV_StaticGenerated = true
end

function ENT:Initialize()
end

function ENT:Draw()
    self:DrawModel()
end

-- ============================================
-- OPTIMIERT: Movement Check nur wenn aktiv
-- ============================================
local function CheckPlayerMovement()
    if not CCTV_StartPosition then return false end
    return LocalPlayer():GetPos():DistToSqr(CCTV_StartPosition) > 2500 -- 50^2
end

-- OPTIMIERT: Hook nur aktiv wenn benötigt
local function EnableMovementCheck()
    hook.Add("Think", "CCTV_MovementCheck", function()
        if not CCTV_ViewActive and not IsValid(CCTV_MainFrame) then
            hook.Remove("Think", "CCTV_MovementCheck")
            return
        end
        
        if CheckPlayerMovement() then
            CloseCCTVInterface()
            return
        end
        
        if CCTV_ViewActive and CCTV_CurrentCamera and not IsValid(CCTV_CurrentCamera) then
            notification.AddLegacy("[CCTV] Kamera-Verbindung verloren", NOTIFY_ERROR, 3)
            StopCameraView()
        end
    end)
end

-- ============================================
-- OPTIMIERT: Status-Farbe Lookup
-- ============================================
local function GetStatusInfo(health, active)
    if health <= 0 then
        return SW_RED, "ZERSTÖRT"
    elseif not active then
        return SW_GRAY, "OFFLINE"
    elseif health <= 40 then
        return SW_ORANGE, "KRITISCH"
    elseif health <= 60 then
        return SW_YELLOW, "BESCHÄDIGT"
    else
        return SW_GREEN, "ONLINE"
    end
end

-- ============================================
-- HAUPT-UI ERSTELLEN
-- ============================================
local function CreateCCTVInterface(console, cameras)
    if IsValid(CCTV_MainFrame) then
        CCTV_MainFrame:Close()
    end
    
    CCTV_CurrentConsole = console
    CCTV_CameraList = cameras
    CCTV_SelectedIndex = 1
    CCTV_ViewActive = false
    CCTV_StartPosition = LocalPlayer():GetPos()
    
    local scrW, scrH = ScrW(), ScrH()
    local frameW = math_min(1200, scrW - 100)
    local frameH = math_min(750, scrH - 100)
    
    CCTV_MainFrame = vgui_Create("DFrame")
    CCTV_MainFrame:SetSize(frameW, frameH)
    CCTV_MainFrame:Center()
    CCTV_MainFrame:SetTitle("")
    CCTV_MainFrame:SetDraggable(true)
    CCTV_MainFrame:MakePopup()
    CCTV_MainFrame:ShowCloseButton(false)
    
    CCTV_MainFrame.Paint = function(self, w, h)
        CCTV_ScanlineOffset = (CCTV_ScanlineOffset + FrameTime() * 30) % 4
        
        draw_RoundedBox(0, -3, -3, w+6, h+6, Color(0, 100, 180, 30))
        draw_RoundedBox(0, 0, 0, w, h, SW_DARK_BG)
        draw_RoundedBox(0, 0, 0, w, 45, SW_ACCENT_DARK)
        
        surface_SetDrawColor(SW_ACCENT)
        surface_DrawLine(0, 45, w, 45)
        
        draw_SimpleText("◆ ANAXES NAVAL SYSTEMS ◆", "DermaLarge", w/2, 10, SW_TEXT_BRIGHT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw_SimpleText("ÜBERWACHUNGSSYSTEM v2.4.1", "DermaDefault", w/2, 30, SW_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        
        local pulse = math_sin(CurTime() * 4) * 0.3 + 0.7
        draw_SimpleText("◉ ONLINE", "DermaDefaultBold", w - 20, 15, Color(80, 255, 120, 255 * pulse), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        draw_SimpleText(os_date("%H:%M:%S"), "DermaDefault", w - 20, 30, SW_TEXT_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        draw_SimpleText("◈ KAMERAS: " .. #CCTV_CameraList, "DermaDefaultBold", 20, 15, SW_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        
        surface_SetDrawColor(SW_BORDER)
        surface_DrawOutlinedRect(0, 0, w, h, 2)
        
        -- Ecken
        local cs = 20
        surface_SetDrawColor(SW_ACCENT)
        surface_DrawLine(0, 0, cs, 0)
        surface_DrawLine(0, 0, 0, cs)
        surface_DrawLine(w - cs, 0, w, 0)
        surface_DrawLine(w-1, 0, w-1, cs)
        surface_DrawLine(0, h-1, cs, h-1)
        surface_DrawLine(0, h - cs, 0, h)
        surface_DrawLine(w - cs, h-1, w, h-1)
        surface_DrawLine(w-1, h - cs, w-1, h)
        
        draw_RoundedBox(0, 0, h - 30, w, 30, SW_FOOTER_BG)
        surface_SetDrawColor(SW_ACCENT_DARK)
        surface_DrawLine(0, h - 30, w, h - 30)
        
        draw_SimpleText("© Anaxes Naval Systems", "DermaDefault", 15, h - 18, SW_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw_SimpleText("[E/ESC] Schließen  |  [ENTER] Kamera  |  [↑↓] Navigation", "DermaDefault", w - 15, h - 18, SW_TEXT_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    
    -- Kameraliste Panel
    local listPanel = vgui_Create("DPanel", CCTV_MainFrame)
    listPanel:SetPos(15, 55)
    listPanel:SetSize(280, frameH - 100)
    
    listPanel.Paint = function(self, w, h)
        draw_RoundedBox(0, 0, 0, w, h, SW_PANEL_BG)
        surface_SetDrawColor(SW_BORDER)
        surface_DrawOutlinedRect(0, 0, w, h, 1)
        draw_RoundedBox(0, 0, 0, w, 35, SW_ACCENT_DARK)
        draw_SimpleText("▼ KAMERA-REGISTER", "DermaDefaultBold", w/2, 17, SW_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface_SetDrawColor(SW_ACCENT)
        surface_DrawLine(0, 35, w, 35)
    end
    
    local cameraScroll = vgui_Create("DScrollPanel", listPanel)
    cameraScroll:SetPos(5, 40)
    cameraScroll:SetSize(270, listPanel:GetTall() - 50)
    
    local sbar = cameraScroll:GetVBar()
    sbar:SetWide(8)
    sbar.Paint = function(self, w, h) draw_RoundedBox(4, 0, 0, w, h, Color(20, 30, 45, 255)) end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(self, w, h) draw_RoundedBox(4, 0, 0, w, h, SW_ACCENT_DARK) end
    
    -- OPTIMIERT: Kamera-Buttons
    for i, cam in ipairs(cameras) do
        local btn = vgui_Create("DButton", cameraScroll)
        btn:SetSize(255, 60)
        btn:Dock(TOP)
        btn:DockMargin(0, 3, 0, 0)
        btn:SetText("")
        btn.camData = cam
        btn.index = i
        
        btn.Paint = function(self, w, h)
            local isSelected = (CCTV_SelectedIndex == self.index)
            local isHovered = self:IsHovered()
            local camData = self.camData
            
            if isSelected then
                draw_RoundedBox(0, 0, 0, w, h, SW_ACCENT_DARK)
                surface_SetDrawColor(SW_ACCENT)
                surface_DrawRect(0, 0, 4, h)
            elseif isHovered then
                draw_RoundedBox(0, 0, 0, w, h, SW_PANEL_LIGHT)
            else
                draw_RoundedBox(0, 0, 0, w, h, SW_BTN_BG)
            end
            
            surface_SetDrawColor(isSelected and SW_ACCENT or SW_SELECTION)
            surface_DrawOutlinedRect(0, 0, w, h, 1)
            
            local statusColor, statusText = GetStatusInfo(camData.health, camData.active)
            
            draw_RoundedBox(4, 10, 10, 12, 12, statusColor)
            draw_SimpleText(camData.name, "DermaDefaultBold", 30, 8, SW_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw_SimpleText(statusText, "DermaDefault", 75, 8, statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            local dist = LocalPlayer():GetPos():Distance(camData.pos)
            draw_SimpleText(string_format("%.0fm", dist * 0.0254), "DermaDefault", 30, 24, SW_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            local vColor = camData.videoActive and SW_GREEN or SW_RED
            local aColor = camData.audioActive and SW_GREEN or SW_RED
            draw_SimpleText("V", "DermaDefaultBold", 30, 40, vColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw_SimpleText("A", "DermaDefaultBold", 50, 40, aColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            local barW = 60
            draw_RoundedBox(2, w - barW - 15, h/2 - 4, barW, 8, Color(30, 30, 30, 200))
            draw_RoundedBox(2, w - barW - 15, h/2 - 4, barW * (camData.health / 100), 8, statusColor)
            draw_SimpleText(camData.health .. "%", "DermaDefault", w - 15, h/2 + 8, SW_TEXT_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        
        btn.DoClick = function(self)
            CCTV_SelectedIndex = self.index
            surface_PlaySound("buttons/button15.wav")
        end
        
        btn.DoDoubleClick = function(self)
            CCTV_SelectedIndex = self.index
            StartCameraView()
        end
    end
    
    if #cameras == 0 then
        local noCAM = vgui_Create("DLabel", cameraScroll)
        noCAM:SetSize(255, 80)
        noCAM:Dock(TOP)
        noCAM:SetText("")
        noCAM.Paint = function(self, w, h)
            draw_SimpleText("KEINE KAMERAS", "DermaDefaultBold", w/2, h/2 - 10, SW_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw_SimpleText("GEFUNDEN", "DermaDefaultBold", w/2, h/2 + 10, SW_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    
    -- Vorschau Panel
    local previewPanel = vgui_Create("DPanel", CCTV_MainFrame)
    previewPanel:SetPos(310, 55)
    previewPanel:SetSize(frameW - 325, frameH - 160)
    
    previewPanel.Paint = function(self, w, h)
        draw_RoundedBox(0, 0, 0, w, h, SW_PANEL_BG)
        surface_SetDrawColor(SW_BORDER)
        surface_DrawOutlinedRect(0, 0, w, h, 1)
        draw_RoundedBox(0, 0, 0, w, 35, SW_ACCENT_DARK)
        draw_SimpleText("▼ KAMERA-VORSCHAU", "DermaDefaultBold", w/2, 17, SW_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface_SetDrawColor(SW_ACCENT)
        surface_DrawLine(0, 35, w, 35)
        
        local previewX, previewY = 10, 45
        local previewW, previewH = w - 20, h - 55
        
        draw_RoundedBox(0, previewX, previewY, previewW, previewH, Color(5, 10, 15, 255))
        
        if #CCTV_CameraList > 0 and CCTV_CameraList[CCTV_SelectedIndex] then
            local cam = CCTV_CameraList[CCTV_SelectedIndex]
            local statusColor, statusText = GetStatusInfo(cam.health, cam.active)
            
            local statusInfo = nil
            if cam.health <= 0 then
                statusInfo = "KAMERA ZERSTÖRT - REPARATUR ERFORDERLICH"
            elseif not cam.active then
                statusInfo = "KAMERA MANUELL DEAKTIVIERT"
            end
            
            draw_SimpleText("◉ " .. cam.name, "DermaLarge", previewX + previewW/2, previewY + 20, SW_ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw_SimpleText("STATUS: " .. statusText, "DermaDefaultBold", previewX + previewW/2, previewY + 50, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw_SimpleText("ZUSTAND: " .. cam.health .. "%", "DermaDefault", previewX + previewW/2, previewY + 70, SW_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            
            local vText = cam.videoActive and "VIDEO: AKTIV" or "VIDEO: GESTÖRT"
            local aText = cam.audioActive and "AUDIO: AKTIV" or "AUDIO: GESTÖRT"
            local vColor = cam.videoActive and SW_GREEN or SW_RED
            local aColor = cam.audioActive and SW_GREEN or SW_RED
            
            draw_SimpleText(vText, "DermaDefault", previewX + previewW/2 - 60, previewY + 100, vColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw_SimpleText(aText, "DermaDefault", previewX + previewW/2 + 60, previewY + 100, aColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            
            if cam.active and cam.health > 0 then
                draw_SimpleText("Doppelklick oder ENTER für Live-Ansicht", "DermaDefault", previewX + previewW/2, previewY + previewH - 30, SW_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw_SimpleText(statusInfo or "KAMERA NICHT VERFÜGBAR", "DermaDefaultBold", previewX + previewW/2, previewY + previewH - 30, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            local pulse = math_sin(CurTime() * 2) * 0.2 + 0.8
            draw_SimpleText("● REC", "DermaDefaultBold", previewX + 15, previewY + 10, Color(255, 50, 50, 255 * pulse), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        else
            draw_SimpleText("KEIN SIGNAL", "DermaLarge", previewX + previewW/2, previewY + previewH/2, SW_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        surface_SetDrawColor(SW_ACCENT_DARK)
        surface_DrawOutlinedRect(previewX, previewY, previewW, previewH, 2)
    end
    
    -- Buttons
    local buttonPanel = vgui_Create("DPanel", CCTV_MainFrame)
    buttonPanel:SetPos(310, frameH - 95)
    buttonPanel:SetSize(frameW - 325, 55)
    buttonPanel.Paint = function() end
    
    local viewBtn = vgui_Create("DButton", buttonPanel)
    viewBtn:SetPos(0, 0)
    viewBtn:SetSize(200, 50)
    viewBtn:SetText("")
    
    viewBtn.Paint = function(self, w, h)
        local canView = #CCTV_CameraList > 0 and CCTV_CameraList[CCTV_SelectedIndex] and CCTV_CameraList[CCTV_SelectedIndex].active
        local bgColor = canView and (self:IsHovered() and SW_GREEN or Color(50, 180, 100, 255)) or Color(80, 80, 80, 255)
        draw_RoundedBox(0, 0, 0, w, h, bgColor)
        surface_SetDrawColor(SW_TEXT)
        surface_DrawOutlinedRect(0, 0, w, h, 1)
        draw_SimpleText("▶ LIVE-ANSICHT", "DermaDefaultBold", w/2, h/2 - 8, SW_DARK_BG, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw_SimpleText("AKTIVIEREN", "DermaDefault", w/2, h/2 + 8, SW_DARK_BG, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    viewBtn.DoClick = function()
        if #CCTV_CameraList > 0 and CCTV_CameraList[CCTV_SelectedIndex] and CCTV_CameraList[CCTV_SelectedIndex].active then
            StartCameraView()
        end
    end
    
    local closeBtn = vgui_Create("DButton", buttonPanel)
    closeBtn:SetPos(buttonPanel:GetWide() - 150, 0)
    closeBtn:SetSize(150, 50)
    closeBtn:SetText("")
    
    closeBtn.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and SW_RED or SW_RED_DARK
        draw_RoundedBox(0, 0, 0, w, h, bgColor)
        surface_SetDrawColor(SW_TEXT)
        surface_DrawOutlinedRect(0, 0, w, h, 1)
        draw_SimpleText("✖ BEENDEN", "DermaDefaultBold", w/2, h/2, SW_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    closeBtn.DoClick = function()
        CloseCCTVInterface()
    end
    
    CCTV_MainFrame.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE or key == KEY_E then
            CloseCCTVInterface()
            return true
        elseif key == KEY_ENTER then
            if #CCTV_CameraList > 0 and CCTV_CameraList[CCTV_SelectedIndex] and CCTV_CameraList[CCTV_SelectedIndex].active then
                StartCameraView()
            end
            return true
        elseif key == KEY_UP then
            CCTV_SelectedIndex = math_max(1, CCTV_SelectedIndex - 1)
            surface_PlaySound("buttons/button15.wav")
            return true
        elseif key == KEY_DOWN then
            CCTV_SelectedIndex = math_min(#CCTV_CameraList, CCTV_SelectedIndex + 1)
            surface_PlaySound("buttons/button15.wav")
            return true
        end
    end
    
    -- Aktiviere Movement-Check
    EnableMovementCheck()
end

-- ============================================
-- LIVE KAMERA-ANSICHT
-- ============================================
function StartCameraView()
    if #CCTV_CameraList == 0 then return end
    
    local camData = CCTV_CameraList[CCTV_SelectedIndex]
    if not camData or not camData.active then return end
    
    if not IsValid(camData.entity) then
        notification.AddLegacy("[CCTV] Kamera nicht mehr verfügbar", NOTIFY_ERROR, 3)
        return
    end
  
    CCTV_ViewActive = true
    CCTV_CurrentCamera = camData.entity
    CCTV_StartPosition = LocalPlayer():GetPos()
    
    net_Start("crusader_cctv_set_viewing_camera")
        net_WriteInt(camData.entity:EntIndex(), 32)
    net_SendToServer()
    
    if IsValid(CCTV_MainFrame) then
        CCTV_MainFrame:SetVisible(false)
    end
    
    -- Generiere Statik-Positionen
    GenerateStaticPositions(ScrW(), ScrH())
    
    surface_PlaySound("buttons/button9.wav")
end

net.Receive("crusader_cctv_camera_entity", function()
    CCTV_CurrentCamera = net_ReadEntity()
end)

function StopCameraView()
    CCTV_ViewActive = false
    CCTV_CurrentCamera = nil
    
    net_Start("crusader_cctv_set_viewing_camera")
        net_WriteInt(-1, 32)
    net_SendToServer()
    
    if IsValid(CCTV_MainFrame) then
        CCTV_MainFrame:SetVisible(true)
        CCTV_MainFrame:MakePopup()
        CCTV_StartPosition = LocalPlayer():GetPos()
    end
    
    surface_PlaySound("buttons/button10.wav")
end

function CloseCCTVInterface()
    CCTV_ViewActive = false
    CCTV_CurrentCamera = nil
    CCTV_StartPosition = nil
    
    net_Start("crusader_cctv_set_viewing_camera")
        net_WriteInt(-1, 32)
    net_SendToServer()
    
    if IsValid(CCTV_MainFrame) then
        CCTV_MainFrame:Close()
        CCTV_MainFrame = nil
    end
    
    if IsValid(CCTV_CurrentConsole) then
        net_Start("crusader_cctv_stop_view")
            net_WriteEntity(CCTV_CurrentConsole)
        net_SendToServer()
    end
    
    CCTV_CurrentConsole = nil
    
    -- Entferne Movement-Check Hook
    hook.Remove("Think", "CCTV_MovementCheck")
end

-- ============================================
-- RENDER HOOKS
-- ============================================
hook.Add("CalcView", "CCTV_CameraView", function(ply, pos, angles, fov)
    if not CCTV_ViewActive or not IsValid(CCTV_CurrentCamera) then return end
    
    local camData = CCTV_CameraList[CCTV_SelectedIndex]
    if not camData then return end
    
    local videoActive = CCTV_CurrentCamera:GetVideoActive()
    
    if not videoActive then
        return nil
    end
    
    local camPos, camAng
    if CCTV_CurrentCamera.GetViewPosition then
        camPos, camAng = CCTV_CurrentCamera:GetViewPosition()
    else
        camPos = CCTV_CurrentCamera:GetPos() + CCTV_CurrentCamera:GetForward() * 10 + CCTV_CurrentCamera:GetUp() * 8
        camAng = CCTV_CurrentCamera:GetAngles()
    end
    
    return {
        origin = camPos,
        angles = camAng,
        fov = 90,
        drawviewer = true
    }
end)

hook.Add("ShouldDrawLocalPlayer", "CCTV_ShowPlayer", function(ply)
    if CCTV_ViewActive then
        return true
    end
end)

hook.Add("HUDPaint", "CCTV_CameraHUD", function()
    if not CCTV_ViewActive or not IsValid(CCTV_CurrentCamera) then return end
    
    local scrW, scrH = ScrW(), ScrH()
    local camData = CCTV_CameraList[CCTV_SelectedIndex]
    if not camData then return end
    
    local videoActive = CCTV_CurrentCamera:GetVideoActive()
    local audioActive = CCTV_CurrentCamera:GetAudioActive()
    local health = CCTV_CurrentCamera:GetCameraHealth()
    
    -- OPTIMIERT: Statik-Rendering mit vorgenereierten Positionen
    if not videoActive then
        surface_SetDrawColor(SW_BLACK)
        surface_DrawRect(0, 0, scrW, scrH)
        
        -- Nutze vorbereitete Positionen
        for i, sp in ipairs(CCTV_StaticPositions) do
            surface_SetDrawColor(sp.brightness, sp.brightness, sp.brightness, 255)
            surface_DrawRect(sp.x, sp.y, sp.size, sp.size)
            -- Langsame Animation der Positionen
            sp.x = (sp.x + math_random(-2, 2)) % scrW
            sp.y = (sp.y + math_random(-2, 2)) % scrH
        end
        
        local flash = math_sin(CurTime() * 5) > 0
        if flash then
            draw_SimpleText("▼▼▼ KEIN VIDEOSIGNAL ▼▼▼", "DermaLarge", scrW/2, scrH/2 - 20, SW_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw_SimpleText("Kamera " .. camData.name .. " - Video beschädigt", "DermaDefaultBold", scrW/2, scrH/2 + 20, SW_ORANGE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        local audioText = audioActive and "AUDIO: AKTIV" or "AUDIO: GESTÖRT"
        local audioColor = audioActive and SW_GREEN or SW_RED
        draw_SimpleText(audioText, "DermaDefaultBold", scrW/2, scrH/2 + 60, audioColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    -- OPTIMIERT: Weniger Scanlines
    local scanlineAlpha = health <= 60 and 6 or 3
    for y = 0, scrH, 4 do
        surface_SetDrawColor(0, 180, 255, scanlineAlpha)
        surface_DrawLine(0, y, scrW, y)
    end
    
    -- Obere Leiste
    surface_SetDrawColor(SW_BLACK_TRANS)
    surface_DrawRect(0, 0, scrW, 60)
    surface_SetDrawColor(SW_ACCENT_DARK)
    surface_DrawRect(0, 0, scrW, 50)
    surface_SetDrawColor(SW_ACCENT)
    surface_DrawLine(0, 50, scrW, 50)
    
    draw_SimpleText("◆ ANAXES NAVAL SYSTEMS - LIVE ÜBERTRAGUNG ◆", "DermaLarge", scrW/2, 25, SW_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    local pulse = math_sin(CurTime() * 4) * 0.5 + 0.5
    draw_SimpleText("● REC", "DermaDefaultBold", 30, 25, Color(255, 50, 50, 150 + pulse * 105), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    local vText = videoActive and "VIDEO ✓" or "VIDEO ✗"
    local aText = audioActive and "AUDIO ✓" or "AUDIO ✗"
    local vColor = videoActive and SW_GREEN or SW_RED
    local aColor = audioActive and SW_GREEN or SW_RED
    
    draw_SimpleText(vText, "DermaDefault", 100, 25, vColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw_SimpleText(aText, "DermaDefault", 180, 25, aColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    draw_SimpleText(os_date("%H:%M:%S"), "DermaDefaultBold", scrW - 30, 25, SW_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    
    -- Untere Leiste
    surface_SetDrawColor(SW_BLACK_TRANS)
    surface_DrawRect(0, scrH - 80, scrW, 80)
    surface_SetDrawColor(SW_DARK_BG)
    surface_DrawRect(0, scrH - 70, scrW, 70)
    surface_SetDrawColor(SW_ACCENT)
    surface_DrawLine(0, scrH - 70, scrW, scrH - 70)
    
    local statusColor = GetStatusInfo(health, true)
    
    draw_SimpleText("KAMERA: " .. camData.name, "DermaDefaultBold", 30, scrH - 55, SW_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw_SimpleText("ZUSTAND: " .. health .. "%", "DermaDefault", 30, scrH - 35, statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    draw_SimpleText("[←↑] Vorherige    [→↓] Nächste    [E/ESC] Zurück", "DermaDefaultBold", scrW/2, scrH - 45, SW_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    draw_SimpleText(CCTV_SelectedIndex .. " / " .. #CCTV_CameraList, "DermaDefaultBold", scrW - 30, scrH - 45, SW_ACCENT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    
    draw_SimpleText("© Anaxes Naval Systems", "DermaDefault", 30, scrH - 12, SW_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    -- Ecken-Overlay bei aktivem Video
    if videoActive then
        surface_SetDrawColor(SW_ACCENT)
        local cornerLen = 40
        surface_DrawLine(80, 70, 80 + cornerLen, 70)
        surface_DrawLine(80, 70, 80, 70 + cornerLen)
        surface_DrawLine(scrW - 80 - cornerLen, 70, scrW - 80, 70)
        surface_DrawLine(scrW - 80, 70, scrW - 80, 70 + cornerLen)
        surface_DrawLine(80, scrH - 90, 80 + cornerLen, scrH - 90)
        surface_DrawLine(80, scrH - 90 - cornerLen, 80, scrH - 90)
        surface_DrawLine(scrW - 80 - cornerLen, scrH - 90, scrW - 80, scrH - 90)
        surface_DrawLine(scrW - 80, scrH - 90 - cornerLen, scrW - 80, scrH - 90)
    end
    
    -- Warnungs-Overlay bei Schaden
    if health <= 40 and health > 0 and math_sin(CurTime() * 3) > 0 then
        draw_SimpleText("⚠ KAMERA BESCHÄDIGT ⚠", "DermaDefaultBold", scrW/2, 70, SW_ORANGE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

-- Kamerawechsel Tasten mit Cooldown
local CCTV_LastKeyPress = 0
local CCTV_KeyCooldown = 0.25

hook.Add("PlayerButtonDown", "CCTV_CameraControls", function(ply, button)
    if not CCTV_ViewActive then return end
    
    if button == KEY_ESCAPE or button == KEY_BACKSPACE or button == KEY_E then
        StopCameraView()
        return true
    end
    
    if CurTime() - CCTV_LastKeyPress < CCTV_KeyCooldown then
        return
    end
    
    if button == KEY_LEFT or button == KEY_UP then
        CCTV_LastKeyPress = CurTime()
        CCTV_SelectedIndex = CCTV_SelectedIndex - 1
        if CCTV_SelectedIndex < 1 then
            CCTV_SelectedIndex = #CCTV_CameraList
        end
        SwitchToCamera()
    elseif button == KEY_RIGHT or button == KEY_DOWN then
        CCTV_LastKeyPress = CurTime()
        CCTV_SelectedIndex = CCTV_SelectedIndex + 1
        if CCTV_SelectedIndex > #CCTV_CameraList then
            CCTV_SelectedIndex = 1
        end
        SwitchToCamera()
    end
end)

function SwitchToCamera()
    if #CCTV_CameraList == 0 then return end
    
    local camData = CCTV_CameraList[CCTV_SelectedIndex]
    if not camData then return end
    
    local camEnt = camData.entity
    if IsValid(camEnt) and camEnt:GetIsActive() then
        CCTV_CurrentCamera = camEnt
        CCTV_StartPosition = LocalPlayer():GetPos()
        
        net_Start("crusader_cctv_set_viewing_camera")
            net_WriteInt(camEnt:EntIndex(), 32)
        net_SendToServer()
        
        surface_PlaySound("buttons/button15.wav")
    else
        surface_PlaySound("buttons/button10.wav")
    end
end

-- ============================================
-- NETZWERK EMPFÄNGER
-- ============================================
net.Receive("crusader_cctv_console_open", function()
    local console = net_ReadEntity()
    local camCount = net_ReadUInt(8)
    
    local cameras = {}
    for i = 1, camCount do
        local ent = net_ReadEntity()
        if IsValid(ent) then
            table.insert(cameras, {
                entity = ent,
                name = net_ReadString(),
                pos = net_ReadVector(),
                active = net_ReadBool(),
                videoActive = net_ReadBool(),
                audioActive = net_ReadBool(),
                health = net_ReadUInt(8)
            })
        else
            net_ReadString()
            net_ReadVector()
            net_ReadBool()
            net_ReadBool()
            net_ReadBool()
            net_ReadUInt(8)
        end
    end
    
    surface_PlaySound("buttons/button9.wav")
    CreateCCTVInterface(console, cameras)
end)
