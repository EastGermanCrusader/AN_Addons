-- EastGermanCrusader SAM System - VLS Client-seitiger Code
-- Nur visuelle Darstellung - Steuerung erfolgt über Kontrollstation

include("shared.lua")

-- Netzwerk für Nickname (wird bereits serverseitig in init.lua registriert)

-- Farben für Status-Licht
local COLOR_READY = Color(0, 255, 100)      -- Grün = Bereit
local COLOR_LOCKED = Color(255, 50, 50)     -- Rot = Ziel gelockt
local COLOR_TRACKING = Color(255, 200, 0)   -- Gelb = Tracking
local COLOR_EMPTY = Color(100, 100, 100)    -- Grau = Keine Munition

function ENT:Initialize()
    -- Client-Initialisierung
end

-- VLS 3D Rendering
function ENT:Draw()
    self:DrawModel()
    
    -- Status-Licht auf dem VLS
    local pos = self:GetPos() + Vector(0, 0, 45)
    
    local locked = self:GetLocked()
    local hasAmmo = self:GetMissileCount() > 0
    local hasTarget = IsValid(self:GetCurrentTarget())
    
    -- Dynamisches Licht basierend auf Status
    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        dlight.pos = pos
        
        if locked and hasAmmo then
            -- Rot = Locked und bereit
            dlight.r = COLOR_LOCKED.r
            dlight.g = COLOR_LOCKED.g
            dlight.b = COLOR_LOCKED.b
            dlight.brightness = 2 + math.sin(CurTime() * 10) * 1
        elseif hasTarget then
            -- Gelb = Ziel erfasst, noch nicht gelockt
            dlight.r = COLOR_TRACKING.r
            dlight.g = COLOR_TRACKING.g
            dlight.b = COLOR_TRACKING.b
            dlight.brightness = 1.5
        elseif hasAmmo then
            -- Grün = Bereit
            dlight.r = COLOR_READY.r
            dlight.g = COLOR_READY.g
            dlight.b = COLOR_READY.b
            dlight.brightness = 1
        else
            -- Grau = Keine Munition
            dlight.r = COLOR_EMPTY.r
            dlight.g = COLOR_EMPTY.g
            dlight.b = COLOR_EMPTY.b
            dlight.brightness = 0.5
        end
        
        dlight.decay = 1000
        dlight.size = 100
        dlight.dietime = CurTime() + 0.1
    end
end

-- Kleine 3D Status-Anzeige direkt über dem VLS
function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    
    -- Nur anzeigen wenn sehr nah (200 Units)
    if dist > 200 then return end
    
    local pos = self:GetPos() + Vector(0, 0, 55)
    local ang = (ply:EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    
    local scale = 0.08
    
    cam.Start3D2D(pos, ang, scale)
        -- Kleines Status-Display
        local ammo = self:GetMissileCount()
        local maxAmmo = self.SAM_MissileCount or 4
        
        -- Munitionsanzeige
        local ammoCol = ammo > 0 and Color(0, 255, 100) or Color(255, 100, 100)
        draw.SimpleText(string.format("%d/%d", ammo, maxAmmo), "DermaLarge", 0, 0, ammoCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Nickname anzeigen (falls gesetzt)
        local nickname = self:GetNickname()
        if nickname and nickname ~= "" then
            draw.SimpleText(nickname, "DermaDefault", 0, -25, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

-- ============================================
-- KONTEXTMENÜ (C-Taste + Rechtsklick)
-- ============================================

-- Funktion zum Öffnen des Nickname-Menüs
local function OpenNicknameMenu(ent)
    if not IsValid(ent) then return end
    
    local frame = vgui.Create("DFrame")
    frame:SetTitle("VLS Eigenschaften bearbeiten")
    frame:SetSize(400, 150)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    
    local currentNickname = ent:GetNickname() or ""
    
    -- Text-Eingabefeld
    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:SetPos(20, 40)
    textEntry:SetSize(360, 30)
    textEntry:SetValue(currentNickname)
    textEntry:SetPlaceholderText("Nickname eingeben (max. 30 Zeichen)")
    textEntry:RequestFocus()
    
    -- Label
    local label = vgui.Create("DLabel", frame)
    label:SetPos(20, 20)
    label:SetSize(360, 20)
    label:SetText("Nickname:")
    label:SetTextColor(Color(255, 255, 255))
    
    -- OK Button
    local okBtn = vgui.Create("DButton", frame)
    okBtn:SetPos(20, 85)
    okBtn:SetSize(170, 35)
    okBtn:SetText("OK")
    okBtn.DoClick = function()
        local nickname = textEntry:GetValue()
        net.Start("EGC_SAM_SetVLSNickname")
        net.WriteEntity(ent)
        net.WriteString(nickname)
        net.SendToServer()
        frame:Close()
    end
    
    -- Entfernen Button
    local removeBtn = vgui.Create("DButton", frame)
    removeBtn:SetPos(210, 85)
    removeBtn:SetSize(170, 35)
    removeBtn:SetText("Entfernen")
    removeBtn.DoClick = function()
        net.Start("EGC_SAM_SetVLSNickname")
        net.WriteEntity(ent)
        net.WriteString("")
        net.SendToServer()
        frame:Close()
    end
    
    -- Enter-Taste für OK
    textEntry.OnEnter = function()
        okBtn:DoClick()
    end
end

-- Netzwerk-Empfänger für Kontextmenü
net.Receive("EGC_SAM_OpenVLSNicknameMenu", function()
    local vls = net.ReadEntity()
    if not IsValid(vls) then return end
    
    -- Öffne Nickname-Menü
    OpenNicknameMenu(vls)
end)

-- Hook um das Standard-Kontextmenü zu erweitern (wenn C + Rechtsklick)
-- Verwende einen Frame-basierten Hook, der das Menü erweitert, wenn es geöffnet wird
local lastCheckedEntity = nil
local lastCheckTime = 0

hook.Add("Think", "EGC_SAM_VLS_CheckContextMenu", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Prüfe nur alle 0.1 Sekunden
    if CurTime() - lastCheckTime < 0.1 then return end
    lastCheckTime = CurTime()
    
    -- Prüfe ob Kontextmenü geöffnet ist
    local contextMenu = g_ContextMenu
    if not IsValid(contextMenu) then
        lastCheckedEntity = nil
        return
    end
    
    -- Prüfe ob wir auf eine VLS-Entity zeigen
    local tr = ply:GetEyeTrace()
    if not IsValid(tr.Entity) then return end
    
    local ent = tr.Entity
    if ent:GetClass() ~= "lvs_sam_turret" then return end
    
    -- Prüfe ob wir diese Entity bereits behandelt haben
    if lastCheckedEntity == ent then return end
    
    -- Prüfe Entfernung
    if ply:GetPos():Distance(ent:GetPos()) > 500 then return end
    
    -- Füge Option hinzu (nur einmal)
    lastCheckedEntity = ent
    
    -- #region agent log
    local logFile = file.Open("addons/.cursor/debug.log", "a", "DATA")
    if logFile then
        local logData = {
            sessionId = "debug-session",
            runId = "run1",
            hypothesisId = "A",
            location = "cl_init.lua:208",
            message = "ContextMenu type check",
            data = {
                contextMenuType = type(contextMenu),
                isDMenu = contextMenu and contextMenu.ClassName == "DMenu" or false,
                hasAddOption = contextMenu and type(contextMenu.AddOption) == "function" or false,
                contextMenuClassName = contextMenu and contextMenu.ClassName or "nil"
            },
            timestamp = os.time() * 1000
        }
        logFile:Write(util.TableToJSON(logData) .. "\n")
        logFile:Close()
    end
    -- #endregion
    
    -- Prüfe ob contextMenu ein DMenu ist und AddOption hat
    if not contextMenu or contextMenu.ClassName ~= "DMenu" or type(contextMenu.AddOption) ~= "function" then
        -- #region agent log
        local logFile2 = file.Open("addons/.cursor/debug.log", "a", "DATA")
        if logFile2 then
            local logData2 = {
                sessionId = "debug-session",
                runId = "run1",
                hypothesisId = "A",
                location = "cl_init.lua:227",
                message = "ContextMenu is not DMenu, skipping AddOption",
                data = {
                    contextMenuType = type(contextMenu),
                    className = contextMenu and contextMenu.ClassName or "nil"
                },
                timestamp = os.time() * 1000
            }
            logFile2:Write(util.TableToJSON(logData2) .. "\n")
            logFile2:Close()
        end
        -- #endregion
        return
    end
    
    -- Prüfe ob Option bereits vorhanden ist
    local hasOption = false
    for _, option in pairs(contextMenu:GetChildren()) do
        if IsValid(option) and option:GetText() == "Eigenschaften bearbeiten" then
            hasOption = true
            break
        end
    end
    
    if not hasOption then
        -- #region agent log
        local logFile3 = file.Open("addons/.cursor/debug.log", "a", "DATA")
        if logFile3 then
            local logData3 = {
                sessionId = "debug-session",
                runId = "run1",
                hypothesisId = "A",
                location = "cl_init.lua:255",
                message = "Calling AddOption",
                data = {},
                timestamp = os.time() * 1000
            }
            logFile3:Write(util.TableToJSON(logData3) .. "\n")
            logFile3:Close()
        end
        -- #endregion
        contextMenu:AddOption("Eigenschaften bearbeiten", function()
            OpenNicknameMenu(ent)
        end)
    end
end)

-- Zusätzlich: Hook für OnContextMenuOpen (falls verfügbar)
hook.Add("OnContextMenuOpen", "EGC_SAM_VLS_AddContextOption", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = ply:GetEyeTrace()
    if not IsValid(tr.Entity) then return end
    
    local ent = tr.Entity
    if ent:GetClass() ~= "lvs_sam_turret" then return end
    
    -- Prüfe Entfernung
    if ply:GetPos():Distance(ent:GetPos()) > 500 then return end
    
    -- Warte kurz, damit das Standard-Menü erstellt wird
    timer.Simple(0.1, function()
        if not IsValid(ent) then return end
        
        local contextMenu = g_ContextMenu
        if IsValid(contextMenu) then
            -- #region agent log
            local logFile = file.Open("addons/.cursor/debug.log", "a", "DATA")
            if logFile then
                local logData = {
                    sessionId = "debug-session",
                    runId = "run1",
                    hypothesisId = "B",
                    location = "cl_init.lua:280",
                    message = "ContextMenu type check in timer",
                    data = {
                        contextMenuType = type(contextMenu),
                        isDMenu = contextMenu and contextMenu.ClassName == "DMenu" or false,
                        hasAddOption = contextMenu and type(contextMenu.AddOption) == "function" or false,
                        contextMenuClassName = contextMenu and contextMenu.ClassName or "nil"
                    },
                    timestamp = os.time() * 1000
                }
                logFile:Write(util.TableToJSON(logData) .. "\n")
                logFile:Close()
            end
            -- #endregion
            
            -- Prüfe ob contextMenu ein DMenu ist und AddOption hat
            if contextMenu.ClassName ~= "DMenu" or type(contextMenu.AddOption) ~= "function" then
                -- #region agent log
                local logFile2 = file.Open("addons/.cursor/debug.log", "a", "DATA")
                if logFile2 then
                    local logData2 = {
                        sessionId = "debug-session",
                        runId = "run1",
                        hypothesisId = "B",
                        location = "cl_init.lua:299",
                        message = "ContextMenu is not DMenu in timer, skipping AddOption",
                        data = {
                            contextMenuType = type(contextMenu),
                            className = contextMenu and contextMenu.ClassName or "nil"
                        },
                        timestamp = os.time() * 1000
                    }
                    logFile2:Write(util.TableToJSON(logData2) .. "\n")
                    logFile2:Close()
                end
                -- #endregion
                return
            end
            
            -- Prüfe ob Option bereits vorhanden ist
            local hasOption = false
            for _, option in pairs(contextMenu:GetChildren()) do
                if IsValid(option) and option:GetText() == "Eigenschaften bearbeiten" then
                    hasOption = true
                    break
                end
            end
            
            if not hasOption then
                -- #region agent log
                local logFile3 = file.Open("addons/.cursor/debug.log", "a", "DATA")
                if logFile3 then
                    local logData3 = {
                        sessionId = "debug-session",
                        runId = "run1",
                        hypothesisId = "B",
                        location = "cl_init.lua:325",
                        message = "Calling AddOption in timer",
                        data = {},
                        timestamp = os.time() * 1000
                    }
                    logFile3:Write(util.TableToJSON(logData3) .. "\n")
                    logFile3:Close()
                end
                -- #endregion
                contextMenu:AddOption("Eigenschaften bearbeiten", function()
                    OpenNicknameMenu(ent)
                end)
            end
        end
    end)
end)

