--[[
    EGC Zone-Konfig-Tool
    
    Flächen (Damage-Zonen) verwalten:
    - Flächen zu Gruppen zusammenfügen (groupId)
    - Flächen umbenennen
    - Schild-HP und Hüllen-HP pro Zone festlegen
]]

TOOL.Category = "EastGermanCrusader"
TOOL.Name = "#Tool.egc_zone_config.name"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("Tool.egc_zone_config.name", "Zone-Konfiguration")
    language.Add("Tool.egc_zone_config.desc", "Auf eine Fläche schießen, Konfig-Fenster öffnet sich.")
    language.Add("Tool.egc_zone_config.0", "LMB auf Fläche schießen, Fenster öffnet sich.")
    language.Add("tool.egc_zone_config.name", "Zone-Konfiguration")
    language.Add("tool.egc_zone_config.desc", "Auf eine Fläche schießen, Konfig-Fenster öffnet sich.")
    language.Add("tool.egc_zone_config.0", "LMB auf Fläche schießen, Fenster öffnet sich.")
end

-- ============================================================================
-- TOOL PANEL (Zone auswählen, Name, Gruppe, Schild/Hüllen-HP)
-- ============================================================================

-- Combo mit aktuellen Zonen füllen (nur für unsere DComboBox, nicht Sandbox-Control)
local function RefreshZoneConfigCombo()
    EGC_SHIP = EGC_SHIP or {}
    local combo = EGC_SHIP._zoneConfigCombo
    if not IsValid(combo) or combo.ClassName ~= "DComboBox" then return end
    local zones = EGC_SHIP.DamageZones or {}
    combo:Clear()
    combo:SetSortItems(false)
    combo:AddChoice("-- Zone wählen --", 0, true)
    for i, zone in ipairs(zones) do
        local label = (zone.name and zone.name ~= "") and zone.name or ("Zone " .. i)
        combo:AddChoice(label, i, false)
    end
end
-- Global, damit Client-Autorun nach Sync die Liste aktualisieren kann
EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.RefreshZoneConfigPanel = RefreshZoneConfigCombo

function TOOL.BuildCPanel(panel)
    panel:ClearControls()

    panel:AddControl("Header", {
        Description = "Damage-Zonen konfigurieren: Name, Gruppe, Schild-HP, Hüllen-HP. Gleiche Gruppe = zusammengehörige Zonen."
    })

    -- Beim Öffnen sofort Sync anfordern, damit Zonen erscheinen
    net.Start("EGC_DamageZones_RequestSync")
    net.SendToServer()

    local zones = EGC_SHIP.DamageZones or {}
    local selectedIndex = 0

    -- Eigene DComboBox (Sandbox-ComboBox erwartet Tabellen als AddChoice-Daten)
    local comboLabel = vgui.Create("DLabel", panel)
    comboLabel:SetText("Zone")
    comboLabel:SizeToContents()
    panel:AddItem(comboLabel)
    local combo = vgui.Create("DComboBox", panel)
    combo:SetSortItems(false)
    EGC_SHIP._zoneConfigCombo = combo
    combo:AddChoice("-- Zone wählen --", 0, true)
    for i, zone in ipairs(zones) do
        local label = (zone.name and zone.name ~= "") and zone.name or ("Zone " .. i)
        combo:AddChoice(label, i, false)
    end
    panel:AddItem(combo)

    local pnl = vgui.Create("DPanel", panel)
    pnl:SetTall(200)
    panel:AddItem(pnl)

    local groupLabel = vgui.Create("DLabel", pnl)
    groupLabel:SetText("Zonen-Gruppe (Zahl):")
    groupLabel:SetPos(10, 8)
    groupLabel:SizeToContents()
    local groupWang = vgui.Create("DNumberWang", pnl)
    groupWang:SetPos(10, 26)
    groupWang:SetWide(120)
    groupWang:SetMin(0)
    groupWang:SetMax(999)
    groupWang:SetValue(0)

    local nameLabel = vgui.Create("DLabel", pnl)
    nameLabel:SetText("Name der Fläche:")
    nameLabel:SetPos(10, 56)
    nameLabel:SizeToContents()
    local nameEntry = vgui.Create("DTextEntry", pnl)
    nameEntry:SetPos(10, 74)
    nameEntry:SetWide(280)
    nameEntry:SetPlaceholderText("z.B. Bug, Brücke, Hangar")

    local shieldLabel = vgui.Create("DLabel", pnl)
    shieldLabel:SetText("Schild HP:")
    shieldLabel:SetPos(10, 104)
    shieldLabel:SizeToContents()
    local shieldWang = vgui.Create("DNumberWang", pnl)
    shieldWang:SetPos(10, 122)
    shieldWang:SetWide(120)
    shieldWang:SetMin(0)
    shieldWang:SetMax(100000)
    shieldWang:SetValue(0)

    local hullLabel = vgui.Create("DLabel", pnl)
    hullLabel:SetText("Hüllen HP:")
    hullLabel:SetPos(150, 104)
    hullLabel:SizeToContents()
    local hullWang = vgui.Create("DNumberWang", pnl)
    hullWang:SetPos(150, 122)
    hullWang:SetWide(120)
    hullWang:SetMin(0)
    hullWang:SetMax(100000)
    hullWang:SetValue(0)

    local function fillFromZone(idx)
        local zonesNow = EGC_SHIP.DamageZones or {}
        if idx < 1 or idx > #zonesNow then return end
        local z = zonesNow[idx]
        nameEntry:SetValue(z.name or "")
        groupWang:SetValue(tonumber(z.groupId) or 0)
        shieldWang:SetValue(z.shieldHP or 0)
        hullWang:SetValue(z.hullHP or 0)
        selectedIndex = idx
    end

    combo.OnSelect = function(_, index, value, data)
        selectedIndex = data
        local zonesNow = EGC_SHIP.DamageZones or {}
        if data and data >= 1 and data <= #zonesNow then
            fillFromZone(data)
        else
            nameEntry:SetValue("")
            groupWang:SetValue(0)
            shieldWang:SetValue(0)
            hullWang:SetValue(0)
        end
    end

    -- Von außen aufrufbar: Zone per Schuss auswählen (setzt Combo + füllt Felder) oder Fenster öffnen
    EGC_SHIP._zoneConfigSelectZone = function(idx)
        local zonesNow = EGC_SHIP.DamageZones or {}
        if idx < 1 or idx > #zonesNow then return end
        selectedIndex = idx
        fillFromZone(idx)
        if IsValid(combo) then
            combo:SetSelected(idx + 1)
        end
    end

    local btn = vgui.Create("DButton", pnl)
    btn:SetText("Übernehmen")
    btn:SetPos(10, 160)
    btn:SetWide(120)
    btn:SetTall(28)
    btn.DoClick = function()
        local zonesNow = EGC_SHIP.DamageZones or {}
        if selectedIndex < 1 or selectedIndex > #zonesNow then
            notification.AddLegacy("Bitte zuerst eine Zone auswählen.", NOTIFY_ERROR, 2)
            return
        end
        net.Start("EGC_ZoneConfig_Update")
        net.WriteUInt(selectedIndex, 16)
        net.WriteString(nameEntry:GetValue() or "")
        net.WriteString(tostring(math.floor(tonumber(groupWang:GetValue()) or 0)))
        net.WriteFloat(tonumber(shieldWang:GetValue()) or 0)
        net.WriteFloat(tonumber(hullWang:GetValue()) or 0)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
        notification.AddLegacy("Zone " .. selectedIndex .. " aktualisiert", NOTIFY_GENERIC, 2)
    end

    panel:AddControl("Label", { Text = "" })
    panel:AddControl("Label", { Text = "LMB auf eine Fläche schießen → es öffnet sich ein Fenster zum Einstellen. Oder hier Zone aus Liste wählen." })
    panel:AddControl("Label", { Text = "Zonen zuerst mit dem Tool „Damage-Zone (Flächen)“ anlegen." })

    local refreshBtn = vgui.Create("DButton", panel)
    refreshBtn:SetText("Liste aktualisieren")
    refreshBtn:SetTall(25)
    refreshBtn.DoClick = function()
        net.Start("EGC_DamageZones_RequestSync")
        net.SendToServer()
        timer.Simple(0.1, RefreshZoneConfigCombo)
    end
    panel:AddItem(refreshBtn)
end

-- ============================================================================
-- CLIENT: Auf Fläche schießen = Konfig-Fenster öffnen
-- ============================================================================
if CLIENT then
    local function IsZoneConfigActive(ply)
        if not IsValid(ply) then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return false end
        local cvar = GetConVar("gmod_toolmode")
        return cvar and cvar:GetString() == "egc_zone_config"
    end

    -- Öffnet ein Fenster zum Konfigurieren der Zone (Name, Gruppe, Schild-HP, Hüllen-HP)
    function EGC_SHIP.OpenZoneConfigFrame(zoneIndex)
        local zones = EGC_SHIP.DamageZones or {}
        if zoneIndex < 1 or zoneIndex > #zones then return end

        -- Vorheriges Fenster schließen
        if IsValid(EGC_SHIP._zoneConfigFrame) then
            EGC_SHIP._zoneConfigFrame:Remove()
        end

        local zone = zones[zoneIndex]
        local zoneLabel = (zone.name and zone.name ~= "") and zone.name or ("Zone " .. zoneIndex)

        local w, h = 340, 280
        local frame = vgui.Create("DFrame")
        frame:SetSize(w, h)
        frame:Center()
        frame:SetTitle("Zone Konfiguration " .. zoneLabel)
        frame:SetVisible(true)
        frame:SetDraggable(true)
        frame:ShowCloseButton(true)
        frame:SetDeleteOnClose(true)
        frame:SetSizable(false)
        -- Eingabe explizit aktivieren (vor dem Befüllen der Kinder)
        frame:SetKeyboardInputEnabled(true)
        frame:SetMouseInputEnabled(true)
        EGC_SHIP._zoneConfigFrame = frame

        local function closeFrame()
            gui.EnableScreenClicker(false)
            if IsValid(frame) then
                frame:Remove()
                if EGC_SHIP._zoneConfigFrame == frame then
                    EGC_SHIP._zoneConfigFrame = nil
                end
            end
        end
        frame.Close = closeFrame

        -- FIX: X-Button der Titelleiste explizit mit closeFrame verbinden
        timer.Simple(0.15, function()
            if not IsValid(frame) then return end
            for _, child in ipairs(frame:GetChildren()) do
                if IsValid(child) and child:GetClassName() == "DButton" then
                    local p = child:GetPos()
                    if p.x > w - 40 then
                        child.DoClick = closeFrame
                        break
                    end
                end
            end
        end)

        local y = 36
        local pad = 12
        local labelW = 110
        local entryW = w - pad * 2 - labelW - 8

        -- Alle Felder als DTextEntry, damit Klick = Fokus und Tippen überall funktioniert
        local groupLabel = vgui.Create("DLabel", frame)
        groupLabel:SetText("Zonen-Gruppe:")
        groupLabel:SetPos(pad, y)
        groupLabel:SizeToContents()
        local groupEntry = vgui.Create("DTextEntry", frame)
        groupEntry:SetPos(pad + labelW, y - 2)
        groupEntry:SetWide(90)
        groupEntry:SetValue(tostring(tonumber(zone.groupId) or 0))
        groupEntry:SetPlaceholderText("Zahl 0-999")
        groupEntry:SetKeyboardInputEnabled(true)
        groupEntry:SetMouseInputEnabled(true)
        y = y + 34

        local nameLabel = vgui.Create("DLabel", frame)
        nameLabel:SetText("Name der Fläche:")
        nameLabel:SetPos(pad, y)
        nameLabel:SizeToContents()
        local nameEntry = vgui.Create("DTextEntry", frame)
        nameEntry:SetPos(pad + labelW, y - 2)
        nameEntry:SetWide(entryW)
        nameEntry:SetValue(zone.name or "")
        nameEntry:SetPlaceholderText("z.B. Bug, Brücke")
        nameEntry:SetKeyboardInputEnabled(true)
        nameEntry:SetMouseInputEnabled(true)
        y = y + 34

        local shieldLabel = vgui.Create("DLabel", frame)
        shieldLabel:SetText("Schild HP:")
        shieldLabel:SetPos(pad, y)
        shieldLabel:SizeToContents()
        local shieldEntry = vgui.Create("DTextEntry", frame)
        shieldEntry:SetPos(pad + labelW, y - 2)
        shieldEntry:SetWide(100)
        shieldEntry:SetValue(tostring(zone.shieldHP or 0))
        shieldEntry:SetPlaceholderText("Zahl")
        shieldEntry:SetKeyboardInputEnabled(true)
        shieldEntry:SetMouseInputEnabled(true)
        y = y + 34

        local hullLabel = vgui.Create("DLabel", frame)
        hullLabel:SetText("Hüllen HP:")
        hullLabel:SetPos(pad, y)
        hullLabel:SizeToContents()
        local hullEntry = vgui.Create("DTextEntry", frame)
        hullEntry:SetPos(pad + labelW, y - 2)
        hullEntry:SetWide(100)
        hullEntry:SetValue(tostring(zone.hullHP or 0))
        hullEntry:SetPlaceholderText("Zahl")
        hullEntry:SetKeyboardInputEnabled(true)
        hullEntry:SetMouseInputEnabled(true)
        y = y + 44

        local btnApply = vgui.Create("DButton", frame)
        btnApply:SetText("Übernehmen")
        btnApply:SetPos(pad, y)
        btnApply:SetWide(140)
        btnApply:SetTall(32)
        btnApply.DoClick = function()
            local g = math.Clamp(tonumber(groupEntry:GetValue()) or 0, 0, 999)
            local sh = math.Clamp(tonumber(shieldEntry:GetValue()) or 0, 0, 100000)
            local hu = math.Clamp(tonumber(hullEntry:GetValue()) or 0, 0, 100000)
            net.Start("EGC_ZoneConfig_Update")
            net.WriteUInt(zoneIndex, 16)
            net.WriteString(nameEntry:GetValue() or "")
            net.WriteString(tostring(g))
            net.WriteFloat(sh)
            net.WriteFloat(hu)
            net.SendToServer()
            surface.PlaySound("buttons/button14.wav")
            notification.AddLegacy("Zone " .. zoneIndex .. " aktualisiert", NOTIFY_GENERIC, 2)
            closeFrame()
        end

        -- Maus freigeben und Fenster als Popup aktivieren – NACH allen Inhalten,
        -- damit Klicks (Schließen, Ziehen, Felder) zuverlässig ankommen
        gui.EnableScreenClicker(true)
        frame:MakePopup()
        frame:SetZPos(100)
        frame:RequestFocus()
    end

    EGC_SHIP._zoneConfigLMBFrames = EGC_SHIP._zoneConfigLMBFrames or 0

    hook.Add("CreateMove", "EGC_ZoneConfig_ShootSelect", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not IsZoneConfigActive(ply) then
            EGC_SHIP._zoneConfigLMBFrames = 0
            return
        end
        -- Wenn das Konfig-Fenster offen ist, keine Schuss-Auswertung – Mausklicks sollen ans Fenster gehen
        if IsValid(EGC_SHIP._zoneConfigFrame) then return end

        local lmbDown = input.IsMouseDown(MOUSE_LEFT)
        EGC_SHIP._zoneConfigLMBFrames = lmbDown and (math.min((EGC_SHIP._zoneConfigLMBFrames or 0) + 1, 10)) or 0

        if EGC_SHIP._zoneConfigLMBFrames ~= 2 then return end
        EGC_SHIP._zoneConfigLMBFrames = 3

        local origin = ply:GetShootPos()
        local dir = ply:GetAimVector()
        local zones = EGC_SHIP.DamageZones or {}
        if not EGC_SHIP.RayPolygonIntersect then return end

        local bestT = nil
        local bestIdx = nil
        for i, zone in ipairs(zones) do
            local verts = zone.vertices
            if verts and #verts >= 3 then
                local t = EGC_SHIP.RayPolygonIntersect(origin, dir, verts)
                if t and t > 0.1 and (not bestT or t < bestT) then
                    bestT = t
                    bestIdx = i
                end
            end
        end

        if bestIdx then
            surface.PlaySound("buttons/button14.wav")
            EGC_SHIP.OpenZoneConfigFrame(bestIdx)
        elseif #zones == 0 then
            notification.AddLegacy("Keine Zonen vorhanden. Zuerst mit Damage-Zone-Tool Flächen anlegen.", NOTIFY_HINT, 3)
        else
            notification.AddLegacy("Keine Fläche getroffen. Genau auf eine Zone zielen.", NOTIFY_HINT, 2)
        end
    end)

    hook.Add("HUDPaint", "EGC_ZoneConfig_HUD", function()
        if not IsZoneConfigActive(LocalPlayer()) then return end
        local boxW, boxH = 380, 36
        local boxX, boxY = ScrW() * 0.5 - boxW * 0.5, 20
        draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(0, 0, 0, 200))
        draw.SimpleText("LMB auf eine Fläche schießen → Konfig-Fenster öffnet sich", "DermaDefaultBold",
            boxX + boxW * 0.5, boxY + boxH * 0.5 - 8, Color(100, 200, 255), TEXT_ALIGN_CENTER)
    end)

    -- Flächen (Zonen) visuell anzeigen, damit man sie anvisieren kann
    hook.Add("PostDrawTranslucentRenderables", "EGC_ZoneConfig_DrawZones", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not IsZoneConfigActive(ply) then return end

        local zones = EGC_SHIP.DamageZones or {}
        if #zones == 0 then return end

        local zoneColor = Color(80, 180, 255, 220)
        local zoneColorFill = Color(80, 180, 255, 25)
        render.SetColorMaterial()

        for _, zone in ipairs(zones) do
            local verts = zone.vertices or {}
            if #verts >= 3 then
                -- Kanten der Fläche
                for i = 1, #verts do
                    local a = verts[i]
                    local b = verts[(i % #verts) + 1]
                    render.DrawBeam(a, b, 8, 0, 1, zoneColor)
                end
                -- Leichte Füllung (Dreiecke vom ersten Knoten)
                for i = 2, #verts - 1 do
                    render.DrawBeam(verts[1], verts[i], 4, 0, 1, zoneColorFill)
                    render.DrawBeam(verts[i], verts[i + 1], 4, 0, 1, zoneColorFill)
                    render.DrawBeam(verts[i + 1], verts[1], 4, 0, 1, zoneColorFill)
                end
            end
        end
    end)
end
