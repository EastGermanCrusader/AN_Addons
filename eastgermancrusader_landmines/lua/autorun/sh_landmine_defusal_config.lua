-- Landmine Defusal Minigame Configuration (nur Minigame für Crusader-Minen)
LandmineDefusal = LandmineDefusal or {}

LandmineDefusal.DefusalTime = 90
LandmineDefusal.ExplosionDamage = 500
LandmineDefusal.ExplosionRadius = 300

LandmineDefusal.RewardMoney = 1000
LandmineDefusal.SuccessMessage = "Landmine erfolgreich entschärft!"
LandmineDefusal.FailureMessage = "BOOM! Die Landmine ist explodiert!"

LandmineDefusal.WireTypes = {
    {id = 1, name = "Rot", color = Color(255, 0, 0)},
    {id = 2, name = "Blau", color = Color(0, 100, 255)},
    {id = 3, name = "Gelb", color = Color(255, 255, 0)},
    {id = 4, name = "Grün", color = Color(0, 255, 0)},
    {id = 5, name = "Orange", color = Color(255, 128, 0)},
    {id = 6, name = "Schwarz", color = Color(40, 40, 40)},
    {id = 7, name = "Weiß", color = Color(255, 255, 255)},
}

LandmineDefusal.Cases = {
    { id = 1, name = "FALL 1", description = "Wenn es ein gelbes Kabel und mindestens ein blaues Kabel und kein schwarzes Kabel gibt, schneide das rote und dann das blaue Kabel.",
      check = function(wires) local y,b,bl=0,0,0 for _,w in pairs(wires) do if w.name=="Gelb" then y=y+1 end if w.name=="Blau" then b=b+1 end if w.name=="Schwarz" then bl=bl+1 end end return y>=1 and b>=1 and bl==0 end,
      sequence = {"Rot", "Blau"} },
    { id = 2, name = "FALL 2", description = "Wenn es zwei gelbe Kabel und ein grünes Kabel gibt, schneide das linke gelbe Kabel und das schwarze Kabel.",
      check = function(wires) local y,g=0,0 for _,w in pairs(wires) do if w.name=="Gelb" then y=y+1 end if w.name=="Grün" then g=g+1 end end return y>=2 and g>=1 end,
      sequence = {"Gelb", "Schwarz"} },
    { id = 3, name = "FALL 3", description = "Wenn es zwei gelbe Kabel und ein blaues Kabel gibt, schneide das orange und dann das blaue Kabel.",
      check = function(wires) local y,b=0,0 for _,w in pairs(wires) do if w.name=="Gelb" then y=y+1 end if w.name=="Blau" then b=b+1 end end return y>=2 and b>=1 end,
      sequence = {"Orange", "Blau"} },
    { id = 4, name = "FALL 4", description = "Wenn es kein grünes Kabel und ein rotes Kabel gibt, schneide das blaue Kabel.",
      check = function(wires) local g,r=0,0 for _,w in pairs(wires) do if w.name=="Grün" then g=g+1 end if w.name=="Rot" then r=r+1 end end return g==0 and r>=1 end,
      sequence = {"Blau"} },
    { id = 5, name = "FALL 5", description = "Wenn es ein gelbes und ein schwarzes Kabel gibt, schneide das grüne Kabel, dann das schwarze und dann das gelbe Kabel.",
      check = function(wires) local y,b=0,0 for _,w in pairs(wires) do if w.name=="Gelb" then y=y+1 end if w.name=="Schwarz" then b=b+1 end end return y>=1 and b>=1 end,
      sequence = {"Grün", "Schwarz", "Gelb"} },
    { id = 6, name = "FALL 6", description = "Wenn es ein rotes Kabel, ein gelbes und ein weißes Kabel gibt, schneide das rote Kabel.",
      check = function(wires) local r,y,w=0,0,0 for _,x in pairs(wires) do if x.name=="Rot" then r=r+1 end if x.name=="Gelb" then y=y+1 end if x.name=="Weiß" then w=w+1 end end return r>=1 and y>=1 and w>=1 end,
      sequence = {"Rot"} },
}

LandmineDefusal.Sounds = {
    beep = "buttons/button17.wav",
    success = "buttons/button9.wav",
    failure = "buttons/button10.wav",
    tick = "buttons/button24.wav",
    cutWire = "buttons/button18.wav"
}
