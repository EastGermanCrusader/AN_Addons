-- eastgermancrusader_base/lua/autorun/sh_crusader_base_init.lua
-- VEREINFACHTE VERSION - Fügt nur zum "Other" Tab im Context-Menü hinzu

local CATEGORY_NAME = "EastGermanCrusader"

-- Globaler Name für andere Dateien
CRUSADER_CATEGORY_NAME = CATEGORY_NAME

-- 1. Fügt die Kategorie im "Nützliches" (Utilities) Tab hinzu (Spawnmenü - Q)
if CLIENT then
	hook.Add("PopulateToolMenu", "Crusader_Utility_Category", function()
		-- Erstellt die Kategorie "EastGermanCrusader" unter dem Reiter "Utilities"
		spawnmenu.AddToolCategory("Utilities", CATEGORY_NAME, CATEGORY_NAME)
	end)
end

-- 2. Context-Menü (C-Menü) - Fügt EGC Entities zum "Other" Tab hinzu
if CLIENT then
	hook.Add("PopulateContent", "Crusader_ContextMenu_Content", function(pnlContent, tree, node)
		-- Sammle alle EGC Entities
		local Categorised = {}
		local Entities = list.Get("SpawnableEntities")
		
		for k, v in pairs(Entities) do
			if v.Category == CATEGORY_NAME then
				Categorised[k] = v
			end
		end

		-- Wenn EGC Entities existieren, erstelle einen Node
		if table.Count(Categorised) > 0 then
			local mynode = tree:AddNode(CATEGORY_NAME, "icon16/wrench_orange.png")
			
			-- Füge alle EGC Entities zum Node hinzu
			for k, ent in SortedPairsByMemberValue(Categorised, "PrintName") do
				spawnmenu.CreateContentIcon("entity", mynode, {
					nicename = ent.PrintName or k,
					spawnname = k,
					material = ent.IconOverride or "entities/" .. k .. ".png",
					admin = ent.AdminOnly
				})
			end
		end
	end)
end

-- Debug-Ausgabe (kann nach dem Testen entfernt werden)
if CLIENT then
	print("[EGC Base] Category '" .. CATEGORY_NAME .. "' initialized")
end
