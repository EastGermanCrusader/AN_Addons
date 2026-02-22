--[[
    Power-Distribution-Terminal (Brücken-Crew)
    Schieberegler pro Sektor, R_total-Anzeige, Überlast-Warnung
]]

local SECTOR_NAMES = {
    bow = "Bug",
    stern = "Heck",
    hangar_port = "Hangar Steuerbord",
    hangar_starboard = "Hangar Backbord",
    hull_port = "Hülle Steuerbord",
    hull_starboard = "Hülle Backbord",
    bridge = "Brücke",
    engine = "Antrieb",
    custom = "Sonstige",
}

function EGC_SHIP.OpenPowerTerminal()
    if not EGC_SHIP or not EGC_SHIP.Config then return end
    local cfg = EGC_SHIP.Config
    local R_total = cfg.ReactorTotalOutput or 1000
    local maxPerSector = cfg.MaxPowerPerSector or 150

    local frame = vgui.Create("DFrame")
    frame:SetSize(420, 520)
    frame:Center()
    frame:SetTitle("Energieverteilung – Reaktor R_total = " .. tostring(R_total))
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()

    local totalLabel = vgui.Create("DLabel", frame)
    totalLabel:SetPos(20, 38)
    totalLabel:SetSize(380, 22)
    totalLabel:SetText("Zugewiesen: 0 / " .. tostring(R_total))
    totalLabel:SetFont("DermaDefaultBold")

    local sliders = {}
    local y = 70
    local order = { "bow", "stern", "hangar_port", "hangar_starboard", "hull_port", "hull_starboard", "bridge", "engine", "custom" }
    for _, sid in ipairs(order) do
        local name = SECTOR_NAMES[sid] or sid
        local lab = vgui.Create("DLabel", frame)
        lab:SetPos(20, y)
        lab:SetSize(160, 20)
        lab:SetText(name)
        local sld = vgui.Create("DNumSlider", frame)
        sld:SetPos(20, y + 20)
        sld:SetSize(380, 30)
        sld:SetMin(0)
        sld:SetMax(maxPerSector * 1.2)
        sld:SetDecimals(0)
        sld:SetValue(EGC_SHIP.ClientPower and EGC_SHIP.ClientPower[sid] and EGC_SHIP.ClientPower[sid].powerAllocated or 0)
        sld:SetText("")
        sld.DataSectorId = sid
        sld.OnValueChanged = function(_, val)
            net.Start("EGC_Ship_PowerSlider")
            net.WriteString(sid)
            net.WriteFloat(tonumber(val) or 0)
            net.SendToServer()
            EGC_SHIP.UpdatePowerTerminalTotal(frame, totalLabel, sliders, R_total)
        end
        sliders[sid] = sld
        y = y + 54
    end

    EGC_SHIP.UpdatePowerTerminalTotal(frame, totalLabel, sliders, R_total)

    frame.Think = function()
        if not IsValid(frame) then return end
        -- Power-State vom Server aktualisieren (ohne Slider zu bewegen, nur Anzeige)
        for sid, p in pairs(EGC_SHIP.ClientPower or {}) do
            if sliders[sid] and IsValid(sliders[sid]) then
                local cur = sliders[sid]:GetValue()
                local newv = p.powerAllocated or 0
                if math.abs(cur - newv) > 0.5 then
                    sliders[sid]:SetValue(newv)
                end
            end
        end
    end
end

function EGC_SHIP.UpdatePowerTerminalTotal(frame, totalLabel, sliders, R_total)
    if not IsValid(frame) or not totalLabel then return end
    local sum = 0
    for _, sld in pairs(sliders or {}) do
        if IsValid(sld) then sum = sum + (sld:GetValue() or 0) end
    end
    totalLabel:SetText("Zugewiesen: " .. math.floor(sum) .. " / " .. tostring(R_total))
    if sum > R_total then
        totalLabel:SetTextColor(Color(255, 80, 80))
    else
        totalLabel:SetTextColor(Color(200, 200, 200))
    end
end
