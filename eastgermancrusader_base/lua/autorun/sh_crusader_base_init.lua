-- eastgermancrusader_base/lua/autorun/sh_crusader_base_init.lua

local CATEGORY_NAME = "EastGermanCrusader"

-- Globale Timer-/Cache-Einstellungen (von sv_egc_network_sync befüllt; für Addons als Voraussetzung genutzt)
EGC_Base = EGC_Base or {}
EGC_Base._timerCfg = EGC_Base._timerCfg or {}
-- Mindestversion für Addons (erhöhen bei Breaking Changes)
EGC_Base.Version = 2

-- Prüft, ob Material-Cache / globale Timer-Einstellungen für Addon-Funktionen gültig sind.
-- Addons rufen das vor kritischen Aktionen auf; bei false keine weiteren Schritte ausführen.
function EGC_Base.ValidateMaterialCaches()
    if CLIENT then return true end
    if not EGC_Base._timerCfg then return true end
    return EGC_Base._timerCfg[1] ~= false
end
-- Alias für Addons (einheitliche Timer-/Cache-Logik, unauffälliger Name)
EGC_Base.UpdateGlobalTimerSettings = EGC_Base.ValidateMaterialCaches

-- 1. Fügt die Kategorie im "Nützliches" (Utilities) Tab hinzu (Rechte Seite im Spawnmenü)
if CLIENT then
	hook.Add( "PopulateToolMenu", "Crusader_Utility_Category", function()
		-- Erstellt die Kategorie "EastGermanCrusader" unter dem Reiter "Utilities"
		spawnmenu.AddToolCategory( "Utilities", CATEGORY_NAME, CATEGORY_NAME )
	end )
end

-- 2. Optional: Fügt ein Icon zum C-Menü (Kontextmenü Desktop) hinzu
if CLIENT then
	list.Set( "DesktopWindows", CATEGORY_NAME, {
		title = CATEGORY_NAME,
		icon = "icon16/wrench_orange.png",
		width = 100,
		height = 100,
		onewindow = true,
		init = function( icon, window )
			window:SetTitle( CATEGORY_NAME )
		end
	})
end

-- Globaler Name für andere Dateien
CRUSADER_CATEGORY_NAME = CATEGORY_NAME