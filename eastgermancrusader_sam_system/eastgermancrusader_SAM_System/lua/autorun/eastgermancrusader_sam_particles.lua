-- EastGermanCrusader SAM System - Partikel & Sound Registrierung
-- Registriert und lädt die JDAM Shockwave Partikel und Sounds für die VLS Torpedos

-- Partikel-Datei registrieren
game.AddParticles("particles/h-shockwave.pcf")

-- Partikel-Systeme vorladen
PrecacheParticleSystem("h_shockwave")
PrecacheParticleSystem("h_shockwave_airburst")
PrecacheParticleSystem("h_water_huge")

-- Sounds vorladen und registrieren
if SERVER then
    -- Sounds für Client-Download registrieren
    resource.AddFile("sound/gbombs_5/explosions/heavy_bomb/explosion_big_6.mp3")
    resource.AddFile("sound/gbombs_5/explosions/heavy_bomb/explosion_big_7.mp3")
end

-- Sounds vorladen (Server und Client)
util.PrecacheSound("gbombs_5/explosions/heavy_bomb/explosion_big_6.mp3")
util.PrecacheSound("gbombs_5/explosions/heavy_bomb/explosion_big_7.mp3")

-- Debug-Ausgabe
if SERVER then
    print("[SAM System] JDAM Shockwave Partikel und Sounds registriert")
end
