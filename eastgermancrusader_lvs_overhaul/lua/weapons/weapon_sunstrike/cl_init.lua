include("shared.lua")

-- Precache Sounds
sound.Add({
    name = "Sunstrike.Growl",
    channel = CHAN_STATIC,
    volume = 0.5,
    level = 75,
    sound = "ambient/energy/force_field_loop1.wav"
})

-- Lokalisierte Strings für deutsches UI (optional)
language.Add("weapon_sunstrike", "Merr-Sonn AA-1 \"Sunstrike\"")
