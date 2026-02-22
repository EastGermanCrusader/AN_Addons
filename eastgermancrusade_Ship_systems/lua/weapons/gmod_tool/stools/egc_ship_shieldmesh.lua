--[[
    Tool: EGC Ship Shield Mesh
    Vertex-basiertes Polygon-Tool für Hull- und Gate-Meshes.
    Kategorie & Admin-Prüfung: eastgermancrusader_base (CRUSADER_CATEGORY_NAME).
]]

-- Kategorie aus eastgermancrusader_base, Fallback falls Base nicht geladen
TOOL.Category = (CRUSADER_CATEGORY_NAME and CRUSADER_CATEGORY_NAME ~= "") and CRUSADER_CATEGORY_NAME or "EastGermanCrusader"
TOOL.Name = "#Tool.egc_ship_shieldmesh.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["mesh_type"] = "hull"
TOOL.ClientConVar["sector_id"] = "hangar_port"

if CLIENT then
    language.Add("Tool.egc_ship_shieldmesh.name", "Shield Mesh (Polygon)")
    language.Add("Tool.egc_ship_shieldmesh.desc", "Punkte setzen für Hull- oder Hangar-Gate-Mesh. Verbindet zu Polygon.")
    language.Add("Tool.egc_ship_shieldmesh.0", "Linksklick: Vertex setzen. Rechtsklick: Mesh abschließen.")
end

function TOOL:LeftClick(tr)
    if not IsFirstTimePredicted() then return false end
    if CLIENT then
        local pos = tr.HitPos
        local meshType = self:GetClientInfo("mesh_type")
        local sectorId = self:GetClientInfo("sector_id")
        net.Start("EGC_Ship_ToolVertex")
        net.WriteVector(pos)
        net.WriteString(meshType)
        net.WriteString(sectorId)
        net.WriteString(self.CurrentMeshId or "")
        net.SendToServer()
        -- Vorschau: gesetzten Punkt merken (immer kopieren, damit Tabelle garantiert clientseitig gefüllt ist)
        if not EGC_SHIP then EGC_SHIP = {} end
        if not EGC_SHIP._shieldmesh_preview then EGC_SHIP._shieldmesh_preview = {} end
        if not EGC_SHIP._shieldmesh_preview.vertices then EGC_SHIP._shieldmesh_preview.vertices = {} end
        table.insert(EGC_SHIP._shieldmesh_preview.vertices, Vector(pos.x, pos.y, pos.z))
    end
    return true
end

function TOOL:RightClick(tr)
    if not IsFirstTimePredicted() then return false end
    if CLIENT then
        self.CurrentMeshId = nil
        net.Start("EGC_Ship_ToolFinishMesh")
        net.WriteString("")
        net.SendToServer()
        -- Vorschau zurücksetzen
        if EGC_SHIP._shieldmesh_preview then
            EGC_SHIP._shieldmesh_preview.vertices = {}
        end
    end
    return true
end

function TOOL:Think()
    if CLIENT then
        if not EGC_SHIP then EGC_SHIP = {} end
        if not EGC_SHIP._shieldmesh_preview then EGC_SHIP._shieldmesh_preview = {} end
        EGC_SHIP._shieldmesh_preview.lastTrace = LocalPlayer():GetEyeTrace()
    end
end

-- Nur Client: 3D-Vorschau – wo der nächste Punkt landet + Linien der gesetzten Punkte
if CLIENT then
    hook.Add("PostDrawTranslucentRenderables", "EGC_Ship_ShieldMesh_DrawPreview", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return end
        if wep:GetMode() ~= "egc_ship_shieldmesh" then return end

        if not EGC_SHIP then return end
        local prev = EGC_SHIP._shieldmesh_preview
        if not prev or not prev.lastTrace then return end

        local hitPos = prev.lastTrace.HitPos
        local hitNormal = prev.lastTrace.HitNormal
        local vertices = prev.vertices or {}

        -- Farbe: Hull = blau, Gate = orange (kräftig, gut sichtbar)
        local cv = GetConVar and GetConVar("egc_ship_shieldmesh_mesh_type")
        local meshType = (cv and cv:GetString()) or "hull"
        local col = (meshType == "gate") and Color(255, 180, 60, 250) or Color(60, 200, 255, 250)
        local colLine = Color(col.r, col.g, col.b, 220)  -- Linien kräftig
        local colDim = Color(col.r, col.g, col.b, 180)

        render.SetColorMaterial()

        -- 1) Gesetzte Polygon-Punkte: große Kugeln (gut sichtbar)
        for idx, v in ipairs(vertices) do
            if type(v) == "Vector" or (v and v.x and v.y and v.z) then
                local pos = type(v) == "Vector" and v or Vector(v.x, v.y, v.z)
                render.DrawSphere(pos, 14, 12, 12, col)
            end
        end

        -- 2) Polygon-Umriss: alle Kanten (dicke Linien) + Schließlinie (Feld sichtbar)
        local lineW = 10
        for i = 1, #vertices do
            local a = vertices[i]
            local b = (i < #vertices) and vertices[i + 1] or vertices[1]  -- letzte Kante schließt zum ersten Punkt
            if a and b then
                local va = type(a) == "Vector" and a or Vector(a.x, a.y, a.z)
                local vb = type(b) == "Vector" and b or Vector(b.x, b.y, b.z)
                render.DrawBeam(va, vb, lineW, 0, 0, colLine)
            end
        end
        -- Linie vom letzten gesetzten Punkt zur aktuellen Fadenkreuz-Position (nächster Klick)
        if #vertices > 0 then
            local last = vertices[#vertices]
            local lastV = type(last) == "Vector" and last or Vector(last.x, last.y, last.z)
            render.DrawBeam(lastV, hitPos, lineW, 0, 0, colDim)
        end

        -- 3) Marker am Fadenkreuz (wo der nächste Klick landet)
        render.DrawSphere(hitPos, 8, 10, 10, col)
        local right = hitNormal:Cross(Vector(0, 0, 1))
        if right:LengthSqr() < 0.01 then right = hitNormal:Cross(Vector(0, 1, 0)) end
        right:Normalize()
        local up = right:Cross(hitNormal):GetNormalized()
        local s = 20
        render.DrawBeam(hitPos - right * s, hitPos + right * s, 5, 0, 0, colDim)
        render.DrawBeam(hitPos - up * s, hitPos + up * s, 5, 0, 0, colDim)
    end)
end

function TOOL.BuildCPanel(panel)
    panel:ClearControls()
    panel:AddControl("Header", { Description = "#Tool.egc_ship_shieldmesh.desc" })
    panel:AddControl("ComboBox", {
        Label = "Mesh-Typ",
        Options = {
            ["Hull (Hüllenschutz)"] = { egc_ship_shieldmesh_mesh_type = "hull" },
            ["Gate (Hangar-Barriere)"] = { egc_ship_shieldmesh_mesh_type = "gate" },
        },
    })
    panel:AddControl("ComboBox", {
        Label = "Sektor",
        Options = {
            ["Bug"] = { egc_ship_shieldmesh_sector_id = "bow" },
            ["Heck"] = { egc_ship_shieldmesh_sector_id = "stern" },
            ["Hangar Steuerbord"] = { egc_ship_shieldmesh_sector_id = "hangar_port" },
            ["Hangar Backbord"] = { egc_ship_shieldmesh_sector_id = "hangar_starboard" },
            ["Hülle Steuerbord"] = { egc_ship_shieldmesh_sector_id = "hull_port" },
            ["Hülle Backbord"] = { egc_ship_shieldmesh_sector_id = "hull_starboard" },
            ["Brücke"] = { egc_ship_shieldmesh_sector_id = "bridge" },
            ["Antrieb"] = { egc_ship_shieldmesh_sector_id = "engine" },
        },
    })
end
