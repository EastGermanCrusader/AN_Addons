--[[
    EGC Damage-Zone-Tool – nur Flächen festlegen
    
    LMB: Knoten setzen (an der Weltposition).
    Mindestens 3 Knoten nötig für eine Fläche.
    RMB: Fläche abschließen → wird als Damage-Zone gespeichert.
]]

TOOL.Category = "EastGermanCrusader"
TOOL.Name = "#Tool.egc_damage_zone.name"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("Tool.egc_damage_zone.name", "Damage-Zone (Flächen)")
    language.Add("Tool.egc_damage_zone.desc", "LMB: Knoten setzen (min. 3). RMB: Fläche abschließen.")
    language.Add("Tool.egc_damage_zone.0", "LMB: Knoten | RMB: Fläche | R: Letzten Knoten entfernen")
end

-- Vorschau: aktuelle Punkte der Fläche in Arbeit + Schutz gegen Klick beim Waffenwechsel
if CLIENT then
    EGC_SHIP = EGC_SHIP or {}
    EGC_SHIP._damageZonePreview = EGC_SHIP._damageZonePreview or {
        currentPoints = {},
        lastToolActiveTime = 0,
        wasToolActive = false,
        lmbFramesDown = 0,   -- nur bei 2 Frames gehalten = echter Klick (kein Wechsel-Artefakt)
        rmbFramesDown = 0,
    }
end

function TOOL:LeftClick(tr)
    if not IsFirstTimePredicted() then return false end
    return true
end

function TOOL:RightClick(tr)
    if not IsFirstTimePredicted() then return false end
    return true
end

function TOOL:Think()
    if CLIENT then
        EGC_SHIP._damageZonePreview = EGC_SHIP._damageZonePreview or { currentPoints = {} }
        EGC_SHIP._damageZonePreview.lastTrace = LocalPlayer():GetEyeTrace()
    end
end

-- ============================================================================
-- CLIENT: Klick-Verarbeitung
-- ============================================================================
if CLIENT then
    local function IsToolActive(ply)
        if not IsValid(ply) then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return false end
        local cvar = GetConVar("gmod_toolmode")
        return cvar and cvar:GetString() == "egc_damage_zone"
    end

    local TOOL_GRACE_TIME = 0.2  -- Sekunden nach Waffenwechsel: Klicks ignorieren (kein versehentliches Schuss/Setzen)

    hook.Add("CreateMove", "EGC_DamageZone_ToolInput", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local preview = EGC_SHIP._damageZonePreview
        if not preview then return end
        if not preview.currentPoints then preview.currentPoints = {} end
        if preview.wasToolActive == nil then preview.wasToolActive = false end

        local toolActive = IsToolActive(ply)
        -- Zeitpunkt merken, wenn gerade zur Tool-Waffe gewechselt wurde
        if toolActive and not preview.wasToolActive then
            preview.lastToolActiveTime = CurTime()
        end
        preview.wasToolActive = toolActive

        if not toolActive then
            preview.lmbFramesDown = 0
            preview.rmbFramesDown = 0
            return
        end

        -- Direkt nach Waffenwechsel keine Klicks auslösen (verhindert Schuss beim Wechseln)
        if (CurTime() - preview.lastToolActiveTime) < TOOL_GRACE_TIME then return end

        -- R: Letzten Knoten entfernen
        if input.WasKeyPressed(KEY_R) then
            if #preview.currentPoints > 0 then
                table.remove(preview.currentPoints)
                surface.PlaySound("buttons/button15.wav")
                notification.AddLegacy("Letzter Knoten entfernt (" .. #preview.currentPoints .. " übrig)", NOTIFY_GENERIC, 2)
            else
                notification.AddLegacy("Keine Knoten zum Entfernen.", NOTIFY_HINT, 2)
            end
            return
        end

        -- Nur Klicks zählen, die mind. 2 Frames gehalten wurden (verhindert Knoten beim Wechsel zu anderer Waffe)
        local lmbDown = input.IsMouseDown(MOUSE_LEFT)
        local rmbDown = input.IsMouseDown(MOUSE_RIGHT)
        preview.lmbFramesDown = lmbDown and (math.min((preview.lmbFramesDown or 0) + 1, 10)) or 0
        preview.rmbFramesDown = rmbDown and (math.min((preview.rmbFramesDown or 0) + 1, 10)) or 0

        local tr = ply:GetEyeTrace()

        -- LMB: Knoten setzen (nur wenn LMB 2 Frames gehalten = echter Klick)
        if preview.lmbFramesDown == 2 then
            if tr.HitPos then
                table.insert(preview.currentPoints, Vector(tr.HitPos.x, tr.HitPos.y, tr.HitPos.z))
                surface.PlaySound("buttons/button15.wav")
                local n = #preview.currentPoints
                local msg = n >= 3 and " (RMB: Fläche abschließen)" or ""
                notification.AddLegacy(string.format("Knoten %d%s", n, msg), NOTIFY_GENERIC, 2)
            end
            preview.lmbFramesDown = 3  -- bis Loslassen nicht erneut auslösen
            return
        end

        -- RMB: Fläche abschließen (min. 3 Knoten), nur bei 2 Frames gehalten
        if preview.rmbFramesDown == 2 then
            if #preview.currentPoints < 3 then
                notification.AddLegacy("Mindestens 3 Knoten nötig für eine Fläche.", NOTIFY_ERROR, 2)
                surface.PlaySound("buttons/button10.wav")
            else
                net.Start("EGC_DamageZone_Finish")
                net.WriteUInt(#preview.currentPoints, 16)
                for _, p in ipairs(preview.currentPoints) do
                    net.WriteVector(p)
                end
                net.SendToServer()
                preview.currentPoints = {}
                surface.PlaySound("buttons/button14.wav")
                notification.AddLegacy("Fläche abgeschlossen (Damage-Zone gespeichert)", NOTIFY_GENERIC, 2)
            end
            preview.rmbFramesDown = 3
        end
    end)
end

-- ============================================================================
-- CLIENT: 3D-Vorschau (aktuelle Punkte + Linien, fertige Zonen)
-- ============================================================================
if CLIENT then
    local function IsToolActive(ply)
        if not IsValid(ply) then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return false end
        local cvar = GetConVar("gmod_toolmode")
        return cvar and cvar:GetString() == "egc_damage_zone"
    end

    local function DrawDamageZonePreview()
        local ply = LocalPlayer()
        if not IsToolActive(ply) then return end

        local preview = EGC_SHIP._damageZonePreview
        if not preview then return end
        local tr = preview.lastTrace or ply:GetEyeTrace()
        local cfg = EGC_SHIP.Config or {}
        local lineColor = cfg.HullLineColor or Color(60, 200, 255, 200)
        local zoneColor = Color(255, 120, 60, 180)
        local cursorColor = Color(255, 255, 255, 200)

        render.SetColorMaterial()

        -- Aktuelle Punkte (in Arbeit)
        local pts = preview.currentPoints or {}
        for i, p in ipairs(pts) do
            render.DrawSphere(p, 12, 10, 10, lineColor)
            if i > 1 then
                render.DrawBeam(pts[i - 1], p, 6, 0, 1, lineColor)
            end
        end
        if #pts >= 3 then
            render.DrawBeam(pts[#pts], pts[1], 6, 0, 1, Color(lineColor.r, lineColor.g, lineColor.b, 150))
        end

        -- Fertige Damage-Zonen (alle gespeicherten Flächen)
        local zones = EGC_SHIP.DamageZones or {}
        for _, zone in ipairs(zones) do
            local verts = zone.vertices or {}
            if #verts >= 3 then
                for i = 1, #verts do
                    local a = verts[i]
                    local b = verts[(i % #verts) + 1]
                    render.DrawBeam(a, b, 5, 0, 1, zoneColor)
                end
            end
        end

        -- Cursor-Knoten
        if tr.HitPos then
            render.DrawSphere(tr.HitPos, 8, 8, 8, cursorColor)
        end
    end

    hook.Add("PostDrawTranslucentRenderables", "EGC_DamageZone_ToolPreview", DrawDamageZonePreview)

    hook.Add("HUDPaint", "EGC_DamageZone_ToolHUD", function()
        local ply = LocalPlayer()
        if not IsToolActive(ply) then return end

        local preview = EGC_SHIP._damageZonePreview or {}
        local pts = preview.currentPoints or {}
        local zones = EGC_SHIP.DamageZones or {}

        local boxW, boxH = 380, 90
        local boxX, boxY = ScrW() * 0.5 - boxW * 0.5, 20
        draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(0, 0, 0, 200))

        draw.SimpleText("Damage-Zone (Flächen)", "DermaDefaultBold",
            boxX + boxW * 0.5, boxY + 12, Color(255, 140, 80), TEXT_ALIGN_CENTER)

        draw.SimpleText(string.format("Aktuelle Fläche: %d Knoten (min. 3)", #pts), "DermaDefault",
            boxX + 20, boxY + 32, #pts >= 3 and Color(100, 255, 100) or Color(255, 200, 100))

        draw.SimpleText(string.format("Gespeicherte Zonen: %d", #zones), "DermaDefault",
            boxX + 20, boxY + 50, Color(200, 200, 200))

        draw.SimpleText("LMB: Knoten | RMB: Fläche | R: Letzten Knoten entfernen", "DermaDefault",
            boxX + boxW * 0.5, boxY + 72, Color(150, 150, 150), TEXT_ALIGN_CENTER)
    end)
end

-- ============================================================================
-- TOOL PANEL
-- ============================================================================
function TOOL.BuildCPanel(panel)
    panel:ClearControls()
    panel:AddControl("Header", {
        Description = "Flächen für Damage-Zonen festlegen: LMB = Knoten setzen (mind. 3), RMB = Fläche abschließen."
    })
    panel:AddControl("Label", { Text = "LMB: Knoten an der angezielten Position setzen." })
    panel:AddControl("Label", { Text = "RMB: Aktuelle Fläche abschließen und als Zone speichern." })
    panel:AddControl("Label", { Text = "R: Letzten gesetzten Knoten entfernen." })
end
