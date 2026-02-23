-- eastgermancrusader_base/lua/autorun/sh_lvs_parking_init.lua

local CATEGORY_NAME = "EastGermanCrusader"

-- Stellt sicher, dass die Kategorie existiert
if CLIENT then
    hook.Add("PopulateToolMenu", "LVS_Parking_Category", function()
        spawnmenu.AddToolCategory("Utilities", CATEGORY_NAME, CATEGORY_NAME)
    end)
    
    -- Spawnmenü Icon
    list.Set("DesktopWindows", "LVS_Parking", {
        title = "LVS Parking",
        icon = "icon16/car.png",
        width = 200,
        height = 150,
        onewindow = true,
        init = function(icon, window)
            window:SetTitle("LVS Parking System")
            
            local label = vgui.Create("DLabel", window)
            label:SetText("Spawne eine LVS Parking Konsole\naus dem Entities-Menü unter\n'" .. CATEGORY_NAME .. "'")
            label:SizeToContents()
            label:Center()
        end
    })
end

if SERVER then
    if not _LVS_NodeOK then return end
    -- Ressourcen zum Download hinzufügen falls nötig
    -- resource.AddFile("...")
end

print("[LVS Parking] System geladen!")
