--[[
    EGC Ship Shield Config Tool
    
    STEUERUNG:
    - LMB: Hull-Orientierungspunkt setzen (Außenhülle)
    - RMB: Gate-Eckpunkt setzen (Hangar-Tor)
    - R:   Punkte löschen / Modus wechseln
    
    Nach dem Setzen der Punkte: Tool auf Generator richten und klicken
    um Hull-Scan durchzuführen bzw. Gate zu erstellen.
]]

TOOL.Category = "EastGermanCrusader"
TOOL.Name = "#Tool.egc_shield_config.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["sector"] = "bow"
TOOL.ClientConVar["scan_resolution"] = "50"

if CLIENT then
    language.Add("Tool.egc_shield_config.name", "Schild-Konfiguration")
    language.Add("Tool.egc_shield_config.desc", "Konfiguriert Schildgeneratoren: Hull und Gates")
    language.Add("Tool.egc_shield_config.0", "LMB: Hull-Punkt | RMB: Gate-Punkt | R: Löschen | Auf Generator klicken = Scan")
end

-- Vorschau-Daten
if CLIENT then
    EGC_SHIP = EGC_SHIP or {}
    EGC_SHIP._toolPreview = EGC_SHIP._toolPreview or {
        hullPoints = {},
        gatePoints = {},
        currentGate = {},
        targetGenerator = nil,
    }
end

-- ============================================================================
-- LINKSKLICK: Hull-Punkt setzen ODER auf Generator scannen
-- ============================================================================
function TOOL:LeftClick(tr)
    if not IsFirstTimePredicted() then return false end
    
    local ent = tr.Entity
    
    -- Wenn auf Generator geklickt → Hull-Scan starten
    if IsValid(ent) and ent:GetClass() == "egc_shield_generator" then
        if CLIENT then
            local preview = EGC_SHIP._toolPreview
            if #preview.hullPoints < 3 then
                notification.AddLegacy("Mindestens 3 Hull-Punkte setzen!", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button10.wav")
                return false
            end
            
            -- Sende Scan-Anfrage
            local resolution = tonumber(self:GetClientInfo("scan_resolution")) or 50
            
            net.Start("EGC_Shield_ToolFinish")
            net.WriteUInt(ent:EntIndex(), 16)
            net.WriteString("hull")
            net.WriteUInt(resolution, 16)
            net.WriteUInt(#preview.hullPoints, 16)
            for _, p in ipairs(preview.hullPoints) do
                net.WriteVector(p)
            end
            net.SendToServer()
            
            preview.targetGenerator = ent:EntIndex()
            surface.PlaySound("buttons/button9.wav")
        end
        return true
    end
    
    -- Sonst: Hull-Punkt setzen
    if CLIENT then
        local pos = tr.HitPos
        local preview = EGC_SHIP._toolPreview
        
        if #preview.hullPoints >= 32 then
            notification.AddLegacy("Max. Hull-Punkte erreicht!", NOTIFY_ERROR, 2)
            return false
        end
        
        table.insert(preview.hullPoints, Vector(pos.x, pos.y, pos.z))
        surface.PlaySound("buttons/button15.wav")
        
        -- An Server senden
        net.Start("EGC_Shield_ToolPoint")
        net.WriteString("hull")
        net.WriteVector(pos)
        net.SendToServer()
    end
    
    return true
end

-- ============================================================================
-- RECHTSKLICK: Gate-Punkt setzen ODER Gate abschließen
-- ============================================================================
function TOOL:RightClick(tr)
    if not IsFirstTimePredicted() then return false end
    
    local ent = tr.Entity
    
    -- Wenn auf Generator geklickt UND Gate-Punkte vorhanden → Gate erstellen
    if IsValid(ent) and ent:GetClass() == "egc_shield_generator" then
        if CLIENT then
            local preview = EGC_SHIP._toolPreview
            if #preview.currentGate < 3 then
                notification.AddLegacy("Mindestens 3 Gate-Punkte setzen!", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button10.wav")
                return false
            end
            
            -- Sende Gate-Erstellung
            net.Start("EGC_Shield_ToolFinish")
            net.WriteUInt(ent:EntIndex(), 16)
            net.WriteString("gate")
            net.WriteUInt(0, 16)  -- Keine Resolution für Gates
            net.WriteUInt(#preview.currentGate, 16)
            for _, p in ipairs(preview.currentGate) do
                net.WriteVector(p)
            end
            net.SendToServer()
            
            -- Gate-Punkte zurücksetzen, in Liste speichern
            table.insert(preview.gatePoints, table.Copy(preview.currentGate))
            preview.currentGate = {}
            
            surface.PlaySound("buttons/button14.wav")
            notification.AddLegacy("Gate erstellt!", NOTIFY_GENERIC, 2)
        end
        return true
    end
    
    -- Sonst: Gate-Punkt setzen
    if CLIENT then
        local pos = tr.HitPos
        local preview = EGC_SHIP._toolPreview
        
        if #preview.currentGate >= 8 then
            notification.AddLegacy("Max. Gate-Punkte erreicht!", NOTIFY_ERROR, 2)
            return false
        end
        
        table.insert(preview.currentGate, Vector(pos.x, pos.y, pos.z))
        surface.PlaySound("buttons/button17.wav")
        
        -- An Server senden
        net.Start("EGC_Shield_ToolPoint")
        net.WriteString("gate")
        net.WriteVector(pos)
        net.SendToServer()
    end
    
    return true
end

-- ============================================================================
-- RELOAD: Punkte löschen
-- ============================================================================
function TOOL:Reload(tr)
    if not IsFirstTimePredicted() then return false end
    
    if CLIENT then
        local preview = EGC_SHIP._toolPreview
        
        -- Zuerst aktuelle Gate-Punkte löschen
        if #preview.currentGate > 0 then
            preview.currentGate = {}
            notification.AddLegacy("Gate-Punkte gelöscht", NOTIFY_CLEANUP, 2)
        -- Dann Hull-Punkte
        elseif #preview.hullPoints > 0 then
            preview.hullPoints = {}
            notification.AddLegacy("Hull-Punkte gelöscht", NOTIFY_CLEANUP, 2)
        -- Dann alle Gates
        elseif #preview.gatePoints > 0 then
            preview.gatePoints = {}
            notification.AddLegacy("Alle Gates gelöscht", NOTIFY_CLEANUP, 2)
        end
        
        surface.PlaySound("buttons/button15.wav")
        
        net.Start("EGC_Shield_ToolClear")
        net.SendToServer()
    end
    
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
        
        local hullColor = cfg.HullLineColor or Color(60, 200, 255, 200)
        local gateColor = cfg.GateLineColor or Color(255, 180, 60, 200)
        local cursorColor = Color(255, 255, 255, 200)
        
        render.SetColorMaterial()
        
        -- Hull-Punkte zeichnen
        local hullPoints = preview.hullPoints or {}
        for i, p in ipairs(hullPoints) do
            -- Kugel
            render.DrawSphere(p, 15, 12, 12, hullColor)
            
            -- Verbindungslinie
            if i > 1 then
                render.DrawBeam(hullPoints[i-1], p, 6, 0, 1, hullColor)
            end
        end
        
        -- Schließende Linie
        if #hullPoints >= 3 then
            render.DrawBeam(hullPoints[#hullPoints], hullPoints[1], 6, 0, 1, Color(hullColor.r, hullColor.g, hullColor.b, 100))
        end
        
        -- Vorschau-Linie zum Cursor
        if #hullPoints > 0 and tr.HitPos then
            render.DrawBeam(hullPoints[#hullPoints], tr.HitPos, 4, 0, 1, Color(hullColor.r, hullColor.g, hullColor.b, 80))
        end
        
        -- Bounding-Box für Hull
        if #hullPoints >= 3 then
            local mins, maxs = EGC_SHIP.CalculateBoundingBox(hullPoints)
            local scanHeight = 500
            mins.z = mins.z - scanHeight
            maxs.z = maxs.z + scanHeight
            
            -- Box zeichnen (nur Kanten)
            local c = Color(hullColor.r, hullColor.g, hullColor.b, 40)
            render.DrawWireframeBox(Vector(0,0,0), Angle(0,0,0), mins, maxs, c, false)
        end
        
        -- Gate-Punkte zeichnen
        local gatePoints = preview.currentGate or {}
        for i, p in ipairs(gatePoints) do
            render.DrawSphere(p, 12, 10, 10, gateColor)
            
            if i > 1 then
                render.DrawBeam(gatePoints[i-1], p, 8, 0, 1, gateColor)
            end
        end
        
        -- Schließende Gate-Linie
        if #gatePoints >= 3 then
            render.DrawBeam(gatePoints[#gatePoints], gatePoints[1], 8, 0, 1, Color(gateColor.r, gateColor.g, gateColor.b, 150))
        end
        
        -- Vorschau-Linie für Gate
        if #gatePoints > 0 and tr.HitPos then
            render.DrawBeam(gatePoints[#gatePoints], tr.HitPos, 5, 0, 1, Color(gateColor.r, gateColor.g, gateColor.b, 80))
        end
        
        -- Bereits erstellte Gates (transparent)
        for _, gate in ipairs(preview.gatePoints or {}) do
            if #gate >= 3 then
                for i = 1, #gate do
                    local a = gate[i]
                    local b = gate[(i % #gate) + 1]
                    render.DrawBeam(a, b, 4, 0, 1, Color(100, 255, 100, 100))
                end
            end
        end
        
        -- Cursor
        if tr.HitPos then
            render.DrawSphere(tr.HitPos, 8, 8, 8, cursorColor)
        end
        
        -- Generator markieren wenn anvisiert
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "egc_shield_generator" then
            local genPos = tr.Entity:GetPos()
            render.DrawSphere(genPos, 30, 12, 12, Color(100, 255, 100, 100))
        end
    end
    
    hook.Add("PostDrawTranslucentRenderables", "EGC_Shield_ToolPreview", DrawToolPreview)
    
    -- HUD
    hook.Add("HUDPaint", "EGC_Shield_ToolHUD", function()
        local ply = LocalPlayer()
        if not IsToolActive(ply) then return end
        
        local preview = EGC_SHIP._toolPreview
        if not preview then return end
        
        local tr = preview.lastTrace or ply:GetEyeTrace()
        
        -- Info-Box
        local boxW, boxH = 400, 140
        local boxX, boxY = ScrW() * 0.5 - boxW * 0.5, 20
        
        draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(0, 0, 0, 200))
        
        -- Titel
        draw.SimpleText("⚡ Schild-Konfiguration", "DermaDefaultBold", 
            boxX + boxW * 0.5, boxY + 15, Color(60, 200, 255), TEXT_ALIGN_CENTER)
        
        -- Hull-Punkte
        local hullCount = #(preview.hullPoints or {})
        local hullColor = hullCount >= 3 and Color(100, 255, 100) or Color(255, 200, 100)
        draw.SimpleText(string.format("Hull-Punkte: %d (min. 3)", hullCount), "DermaDefault", 
            boxX + 20, boxY + 40, hullColor)
        
        -- Gate-Punkte
        local gateCount = #(preview.currentGate or {})
        local totalGates = #(preview.gatePoints or {})
        local gateColor = Color(255, 180, 60)
        draw.SimpleText(string.format("Gate-Punkte: %d | Fertige Gates: %d", gateCount, totalGates), "DermaDefault", 
            boxX + 20, boxY + 60, gateColor)
        
        -- Anvisiertes Objekt
        local targetText = "---"
        local targetColor = Color(150, 150, 150)
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "egc_shield_generator" then
            targetText = "GENERATOR [Klicken zum Scannen/Erstellen]"
            targetColor = Color(100, 255, 100)
        end
        draw.SimpleText("Ziel: " .. targetText, "DermaDefault", 
            boxX + 20, boxY + 85, targetColor)
        
        -- Steuerung
        draw.SimpleText("LMB: Hull | RMB: Gate | R: Löschen", "DermaDefault", 
            boxX + boxW * 0.5, boxY + 115, Color(120, 120, 120), TEXT_ALIGN_CENTER)
    end)
end

-- ============================================================================
-- TOOL PANEL
-- ============================================================================
function TOOL.BuildCPanel(panel)
    panel:ClearControls()
    
    panel:AddControl("Header", {
        Description = "Konfiguriert Schildgeneratoren für dein Schiff.\n\nLMB = Hull-Orientierungspunkte\nRMB = Gate-Eckpunkte (Hangar-Tore)"
    })
    
    panel:AddControl("Label", { Text = "━━━ Anleitung ━━━" })
    panel:AddControl("Label", { Text = "1. Platziere einen Schildgenerator" })
    panel:AddControl("Label", { Text = "2. LMB: Setze Hull-Punkte um das Schiff" })
    panel:AddControl("Label", { Text = "3. LMB auf Generator: Startet Hull-Scan" })
    panel:AddControl("Label", { Text = "" })
    panel:AddControl("Label", { Text = "4. RMB: Setze Gate-Ecken (Hangar)" })
    panel:AddControl("Label", { Text = "5. RMB auf Generator: Erstellt Gate" })
    panel:AddControl("Label", { Text = "" })
    panel:AddControl("Label", { Text = "Gates = Durchlass für Props/Spieler" })
    
    panel:AddControl("Label", { Text = "" })
    panel:AddControl("Label", { Text = "━━━ Einstellungen ━━━" })
    
    panel:AddControl("Slider", {
        Label = "Scan-Auflösung",
        Type = "Integer",
        Min = 20,
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
