-- EastGermanCrusader SAM System - Partikel & Sound Registrierung
-- Registriert und lädt die JDAM Shockwave Partikel und Sounds für die VLS Torpedos
if SERVER and not _LVS_NodeOK then return end

-- Partikel-Datei registrieren
game.AddParticles("particles/h-shockwave.pcf")

-- Partikel-Systeme vorladen
PrecacheParticleSystem("h_shockwave")
PrecacheParticleSystem("h_shockwave_airburst")
PrecacheParticleSystem("h_water_huge")

-- gb5_emp für Ionen-Torpedo (EMP) – Partikel im SAM-Addon (particles/gb5_emp.pcf)
game.AddParticles("particles/gb5_emp.pcf")
PrecacheParticleSystem("emp_main")
PrecacheParticleSystem("emp_electrify_model")

-- Sounds vorladen und registrieren
if SERVER then
    -- Sounds für Client-Download registrieren
    resource.AddFile("sound/gbombs_5/explosions/heavy_bomb/explosion_big_6.mp3")
    resource.AddFile("sound/gbombs_5/explosions/heavy_bomb/explosion_big_7.mp3")
    resource.AddFile("sound/gbombs_5/explosions/special/emp.mp3")
end

-- Sounds vorladen (Server und Client)
util.PrecacheSound("gbombs_5/explosions/heavy_bomb/explosion_big_6.mp3")
util.PrecacheSound("gbombs_5/explosions/heavy_bomb/explosion_big_7.mp3")
util.PrecacheSound("gbombs_5/explosions/special/emp.mp3")

-- Debug-Ausgabe
if SERVER then
    print("[SAM System] JDAM Shockwave Partikel und Sounds registriert")
end
