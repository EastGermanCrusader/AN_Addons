--[[
    Tool: EGC Ship Diagnostic (Technik-Fraktion)
    Zeigt Sektor-Status (Schild %, Hülle %, Breach) und Reparatur in Reichweite.
]]

TOOL.Category = (CRUSADER_CATEGORY_NAME and CRUSADER_CATEGORY_NAME ~= "") and CRUSADER_CATEGORY_NAME or "EastGermanCrusader"
TOOL.Name = "#Tool.egc_ship_diagnostic.name"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("Tool.egc_ship_diagnostic.name", "Schild-Diagnose")
    language.Add("Tool.egc_ship_diagnostic.desc", "Sektor-Status anzeigen und Breach vor Ort reparieren.")
    language.Add("Tool.egc_ship_diagnostic.0", "Linksklick: Diagnose-Panel öffnen.")
end

local REPAIR_RANGE = 300

local function getSectorCenter(sectorId)
    if not EGC_SHIP or not EGC_SHIP.ClientMeshes then return nil end
    local sum = Vector(0, 0, 0)
    local n = 0
    for _, mesh in pairs(EGC_SHIP.ClientMeshes) do
        if mesh.sectorId == sectorId and mesh.vertices then
            for _, v in ipairs(mesh.vertices) do
                sum = sum + v
                n = n + 1
            end
        end
    end
    if n == 0 then return nil end
    return sum / n
end

local function inRepairRange(ply, sectorId)
    local pos = getSectorCenter(sectorId)
    if not pos or not IsValid(ply) then return false end
    return ply:GetPos():Distance(pos) <= REPAIR_RANGE
end

function TOOL:LeftClick(tr)
    if not IsFirstTimePredicted() then return false end
    if CLIENT then
        EGC_SHIP.OpenDiagnosticPanel()
    end
    return true
end

function TOOL:RightClick(tr)
    return false
end

if CLIENT then
    function EGC_SHIP.OpenDiagnosticPanel()
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 420)
        frame:Center()
        frame:SetTitle("Schild-Diagnose – Sektor-Status")
        frame:SetVisible(true)
        frame:SetDraggable(true)
        frame:ShowCloseButton(true)
        frame:MakePopup()

        local sectors = EGC_SHIP.ClientSectors or {}
        local breach = EGC_SHIP.ClientBreach or {}
        local y = 36
        local order = { "bow", "stern", "hangar_port", "hangar_starboard", "hull_port", "hull_starboard", "bridge", "engine", "custom" }
        local names = {
            bow = "Bug", stern = "Heck", hangar_port = "Hangar Stb.", hangar_starboard = "Hangar Bb.",
            hull_port = "Hülle Stb.", hull_starboard = "Hülle Bb.", bridge = "Brücke", engine = "Antrieb", custom = "Sonstige",
        }
        for _, sid in ipairs(order) do
            local s = sectors[sid]
            if s then
            local name = names[sid] or sid
            local shield = tonumber(s.shieldPercent) or 0
            local hull = tonumber(s.hullPercent) or 0
            local isBreached = breach[sid]
            local lab = vgui.Create("DLabel", frame)
            lab:SetPos(12, y)
            lab:SetSize(360, 22)
            lab:SetText(string.format("%s  |  Schild: %d%%  |  Hülle: %d%%  %s", name, shield, hull, isBreached and "[ BREACH ]" or ""))
            lab:SetTextColor(isBreached and Color(255, 100, 100) or Color(200, 200, 200))
            if isBreached then
                local btn = vgui.Create("DButton", frame)
                btn:SetPos(12, y + 24)
                btn:SetSize(120, 22)
                btn:SetText("Reparatur (in Reichweite)")
                btn.DoSleep = false
                btn.Think = function()
                    if btn.DoSleep then return end
                    if not inRepairRange(LocalPlayer(), sid) then
                        btn:SetEnabled(false)
                        btn:SetText("Zu weit entfernt")
                    else
                        btn:SetEnabled(true)
                        btn:SetText("Reparatur starten")
                    end
                end
                btn.DoClick = function()
                    if not inRepairRange(LocalPlayer(), sid) then return end
                    btn.DoSleep = true
                    btn:SetEnabled(false)
                    net.Start("EGC_Ship_RepairSector")
                    net.WriteString(sid)
                    net.SendToServer()
                    timer.Simple(1, function()
                        if IsValid(btn) then btn.DoSleep = false end
                    end)
                end
                y = y + 54
            else
                y = y + 32
            end
            end
        end
    end
end
