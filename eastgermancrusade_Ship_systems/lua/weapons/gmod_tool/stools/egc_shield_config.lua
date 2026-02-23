--[[
    EGC Ship Shield Config Tool – nur Nodes + Gate-Flächen
    
    - LMB: Node setzen (Form/Volumen der Venator; Schild orientiert sich grob daran).
    - RMB: Bereich für Gate definieren – auf Node klicken = Node zur Gate-Fläche hinzufügen.
    - Gate = 4–8 Knotenpunkte = gültige Form (Hangar-Durchlass etc.).
    - R: Gate übernehmen (wenn 4–8 Punkte) / aktuelles Gate verwerfen / letztes Gate löschen.
    - LMB auf Generator: Schild aus allen Nodes bauen (grob/klobig) + Gates anwenden.
]]

TOOL.Category = "EastGermanCrusader"
TOOL.Name = "#Tool.egc_shield_config.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["sector"] = "bow"
TOOL.ClientConVar["scan_resolution"] = "50"

if CLIENT then
    language.Add("Tool.egc_shield_config.name", "Schild-Konfiguration")
    language.Add("Tool.egc_shield_config.desc", "Nodes = Form/Volumen. Gates = Flächen (4–8 Knoten). Schild grob an Nodes.")
    language.Add("Tool.egc_shield_config.0", "LMB: Node | RMB: Node zu Gate (4–8) | R: Gate übernehmen | LMB auf Gen: Bauen")
end

-- Vorschau-Daten: nur aktuelles Gate + fertige Gates
if CLIENT then
    EGC_SHIP = EGC_SHIP or {}
    EGC_SHIP._toolPreview = EGC_SHIP._toolPreview or {
        currentGate = {},   -- Positionen der aktuell gewählten Gate-Nodes (4–8 = gültig)
        completedGates = {}, -- Liste von Gates, jedes Gate = { pos, pos, ... } mit 4–8 Punkten
        targetGenerator = nil,
    }
    local p = EGC_SHIP._toolPreview
    if not p.currentGate then p.currentGate = {} end
    if not p.completedGates then p.completedGates = {} end
end

-- ============================================================================
-- LINKSKLICK: Nur Rückgabewert für Tool-Gun-Anzeige (echte Logik im Client-Hook)
-- In Singleplayer wird LeftClick nur auf dem Server aufgerufen, daher läuft
-- die CLIENT-Logik dort nie. Die Klick-Verarbeitung erfolgt in EGC_Shield_ToolInput.
-- ============================================================================
function TOOL:LeftClick(tr)
    if not IsFirstTimePredicted() then return false end
    return true  -- Beam/Animation anzeigen; Aktion wird im Client-Hook ausgeführt
end

-- ============================================================================
-- RECHTSKLICK: Nur Rückgabewert (echte Logik im Client-Hook)
-- ============================================================================
function TOOL:RightClick(tr)
    if not IsFirstTimePredicted() then return false end
    return true
end

-- ============================================================================
-- RELOAD: Nur Rückgabewert (echte Logik im Client-Hook)
-- ============================================================================
function TOOL:Reload(tr)
    if not IsFirstTimePredicted() then return false end
    return true
end

-- ============================================================================
-- THINK: Trace aktualisieren
-- ============================================================================
function TOOL:Think()
    if CLIENT then
        EGC_SHIP._toolPreview.lastTrace = LocalPlayer():GetEyeTrace()
    end
end

-- ============================================================================
-- CLIENT: Klick-Verarbeitung (läuft immer auf dem Client, auch in Singleplayer)
-- CreateMove läuft vor Think und ist der richtige Ort für input.WasMousePressed.
-- ============================================================================
if CLIENT then
    local function IsToolActive(ply)
        if not IsValid(ply) then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return false end
        local cvar = GetConVar("gmod_toolmode")
        return cvar and cvar:GetString() == "egc_shield_config"
    end

    hook.Add("CreateMove", "EGC_Shield_ToolInput", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not IsToolActive(ply) then return end

        local preview = EGC_SHIP._toolPreview
        if not preview then return end

        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if not preview.currentGate then preview.currentGate = {} end
        if not preview.completedGates then preview.completedGates = {} end

        -- LMB: Node setzen ODER auf Generator = Schild aus Nodes bauen + Gates anwenden
        if input.WasMousePressed(MOUSE_LEFT) then
            if IsValid(ent) and ent:GetClass() == "egc_shield_generator" then
                net.Start("EGC_Shield_BuildFromNodes")
                net.WriteUInt(ent:EntIndex(), 16)
                net.WriteUInt(#preview.completedGates, 16)
                for _, gate in ipairs(preview.completedGates) do
                    if #gate >= 4 and #gate <= 8 then
                        net.WriteUInt(#gate, 16)
                        for _, p in ipairs(gate) do net.WriteVector(p) end
                    end
                end
                net.SendToServer()
                preview.targetGenerator = ent:EntIndex()
                surface.PlaySound("buttons/button9.wav")
                notification.AddLegacy("Schild aus Nodes + Gates angefordert", NOTIFY_GENERIC, 2)
            else
                if tr.HitPos then
                    net.Start("EGC_Shield_PlaceNode")
                    net.WriteVector(tr.HitPos)
                    net.SendToServer()
                    surface.PlaySound("buttons/button15.wav")
                    notification.AddLegacy("Node gesetzt (RMB auf Node = zu Gate hinzufügen)", NOTIFY_GENERIC, 2)
                end
            end
            return
        end

        -- RMB: Node anvisiert = diesen Node zur aktuellen Gate-Fläche hinzufügen (4–8 = gültig)
        if input.WasMousePressed(MOUSE_RIGHT) then
            if IsValid(ent) and ent:GetClass() == "egc_shield_node" then
                local pos = ent:GetPos()
                if #preview.currentGate >= 8 then
                    notification.AddLegacy("Gate: max. 8 Knoten. R = Gate übernehmen.", NOTIFY_ERROR, 2)
                    surface.PlaySound("buttons/button10.wav")
                else
                    table.insert(preview.currentGate, Vector(pos.x, pos.y, pos.z))
                    surface.PlaySound("buttons/button17.wav")
                    local n = #preview.currentGate
                    local msg = n >= 4 and n <= 8 and " (gültige Form – R: übernehmen)" or ""
                    notification.AddLegacy(string.format("Gate: %d Knoten%s", n, msg), NOTIFY_GENERIC, 2)
                end
            else
                notification.AddLegacy("RMB auf einen Node: Node zur Gate-Fläche hinzufügen (4–8)", NOTIFY_HINT, 2)
            end
            return
        end

        -- R: Gate übernehmen (wenn 4–8 Punkte) / aktuelles Gate verwerfen / letztes Gate löschen
        if input.WasKeyPressed(KEY_R) then
            local cur = #preview.currentGate
            local completed = #preview.completedGates
            if cur >= 4 and cur <= 8 then
                table.insert(preview.completedGates, table.Copy(preview.currentGate))
                preview.currentGate = {}
                surface.PlaySound("buttons/button14.wav")
                notification.AddLegacy("Gate übernommen (" .. cur .. " Knoten)", NOTIFY_GENERIC, 2)
            elseif cur > 0 then
                preview.currentGate = {}
                surface.PlaySound("buttons/button15.wav")
                notification.AddLegacy("Aktuelles Gate verworfen", NOTIFY_CLEANUP, 2)
            elseif completed > 0 then
                table.remove(preview.completedGates)
                surface.PlaySound("buttons/button15.wav")
                notification.AddLegacy("Letztes Gate gelöscht", NOTIFY_CLEANUP, 2)
            end
            net.Start("EGC_Shield_ToolClear")
            net.SendToServer()
        end
    end)
end

-- ============================================================================
-- CLIENT: 3D-Vorschau
-- ============================================================================
if CLIENT then
    local function IsToolActive(ply)
        if not IsValid(ply) then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return false end
        local cvar = GetConVar("gmod_toolmode")
        return cvar and cvar:GetString() == "egc_shield_config"
    end
    
    local function DrawToolPreview()
        local ply = LocalPlayer()
        if not IsToolActive(ply) then return end

        local preview = EGC_SHIP._toolPreview
        if not preview then return end

        local tr = preview.lastTrace or ply:GetEyeTrace()
        local cfg = EGC_SHIP.Config or {}
        local gateColor = cfg.GateLineColor or Color(255, 180, 60, 200)
        local gateDoneColor = Color(100, 255, 100, 180)
        local cursorColor = Color(255, 255, 255, 200)

        render.SetColorMaterial()

        -- Aktuelles Gate (Knoten + Linien, 4–8 = gültige Form)
        local currentGate = preview.currentGate or {}
        for i, p in ipairs(currentGate) do
            render.DrawSphere(p, 14, 10, 10, gateColor)
            if i > 1 then
                render.DrawBeam(currentGate[i - 1], p, 8, 0, 1, gateColor)
            end
        end
        if #currentGate >= 3 then
            render.DrawBeam(currentGate[#currentGate], currentGate[1], 8, 0, 1, Color(gateColor.r, gateColor.g, gateColor.b, 150))
        end

        -- Fertige Gates (Umriss)
        for _, gate in ipairs(preview.completedGates or {}) do
            if #gate >= 4 and #gate <= 8 then
                for i = 1, #gate do
                    local a = gate[i]
                    local b = gate[(i % #gate) + 1]
                    render.DrawBeam(a, b, 6, 0, 1, gateDoneColor)
                end
            end
        end

        -- Cursor
        if tr.HitPos then
            render.DrawSphere(tr.HitPos, 8, 8, 8, cursorColor)
        end

        -- Generator markieren
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "egc_shield_generator" then
            render.DrawSphere(tr.Entity:GetPos(), 30, 12, 12, Color(100, 255, 100, 150))
        end
        -- Node markieren (für RMB)
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "egc_shield_node" then
            render.DrawSphere(tr.Entity:GetPos(), 25, 10, 10, Color(255, 220, 100, 180))
        end
    end
    
    hook.Add("PostDrawTranslucentRenderables", "EGC_Shield_ToolPreview", DrawToolPreview)
    
    -- HUD
    hook.Add("HUDPaint", "EGC_Shield_ToolHUD", function()
        local ply = LocalPlayer()
        if not IsToolActive(ply) then return end

        local preview = EGC_SHIP._toolPreview
        if not preview then return end
        local currentGate = preview.currentGate or {}
        local completedGates = preview.completedGates or {}
        local tr = preview.lastTrace or ply:GetEyeTrace()

        local boxW, boxH = 420, 130
        local boxX, boxY = ScrW() * 0.5 - boxW * 0.5, 20
        draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(0, 0, 0, 200))

        draw.SimpleText("Schild: Nodes + Gates", "DermaDefaultBold",
            boxX + boxW * 0.5, boxY + 12, Color(60, 200, 255), TEXT_ALIGN_CENTER)

        local gateOk = #currentGate >= 4 and #currentGate <= 8
        draw.SimpleText(string.format("Aktuelles Gate: %d Knoten (4–8 = gültig)%s", #currentGate, gateOk and " [R: übernehmen]" or ""), "DermaDefault",
            boxX + 20, boxY + 36, gateOk and Color(100, 255, 100) or Color(255, 200, 100))

        draw.SimpleText(string.format("Fertige Gates: %d", #completedGates), "DermaDefault",
            boxX + 20, boxY + 54, Color(255, 180, 60))

        local targetText = "LMB = Node setzen"
        local targetColor = Color(180, 180, 180)
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "egc_shield_generator" then
            targetText = "GENERATOR – LMB: Schild aus Nodes + Gates bauen"
            targetColor = Color(100, 255, 100)
        elseif IsValid(tr.Entity) and tr.Entity:GetClass() == "egc_shield_node" then
            targetText = "NODE – RMB: Zu Gate hinzufügen"
            targetColor = Color(255, 220, 100)
        end
        draw.SimpleText("Ziel: " .. targetText, "DermaDefault",
            boxX + 20, boxY + 72, targetColor)

        draw.SimpleText("LMB: Node | RMB: Node zu Gate (4–8) | R: Gate übernehmen", "DermaDefault",
            boxX + boxW * 0.5, boxY + 108, Color(120, 120, 120), TEXT_ALIGN_CENTER)
    end)
end

-- ============================================================================
-- TOOL PANEL
-- ============================================================================
function TOOL.BuildCPanel(panel)
    panel:ClearControls()

    panel:AddControl("Header", {
        Description = "Nur Nodes + Gate-Flächen. Nodes geben Form/Volumen vor, Schild orientiert sich grob daran. Gates = 4–8 Knoten = gültige Fläche (Durchlass)."
    })

    panel:AddControl("Label", { Text = "━━━ Ablauf ━━━" })
    panel:AddControl("Label", { Text = "1. LMB: Nodes setzen (an der Venator-Form)" })
    panel:AddControl("Label", { Text = "2. RMB auf Node: Node zur Gate-Fläche hinzufügen (4–8 = gültig)" })
    panel:AddControl("Label", { Text = "3. R: Gate übernehmen (wenn 4–8 Knoten)" })
    panel:AddControl("Label", { Text = "4. LMB auf Generator: Schild aus Nodes bauen (grob/klobig) + Gates anwenden" })
    panel:AddControl("Label", { Text = "" })
    panel:AddControl("Label", { Text = "━━━ Einstellungen ━━━" })
    
    panel:AddControl("Slider", {
        Label = "Scan-Auflösung",
        Type = "Integer",
        Min = 10,
        Max = 200,
        Command = "egc_shield_config_scan_resolution",
    })
    
    panel:AddControl("ComboBox", {
        Label = "Sektor",
        Options = {
            ["Bug"] = { egc_shield_config_sector = "bow" },
            ["Heck"] = { egc_shield_config_sector = "stern" },
            ["Backbord"] = { egc_shield_config_sector = "port" },
            ["Steuerbord"] = { egc_shield_config_sector = "starboard" },
            ["Brücke"] = { egc_shield_config_sector = "bridge" },
            ["Haupthangar"] = { egc_shield_config_sector = "hangar_main" },
            ["Nebenhangar"] = { egc_shield_config_sector = "hangar_aux" },
            ["Antrieb"] = { egc_shield_config_sector = "engine" },
        },
    })
end
