AddCSLuaFile()

function gb5_physics()
Msg("\n|Gbombs 5 physics module initialized!")
Msg("\n|If you don't want this, delete the gb5_physics.lua file\n")

phys = {}
phys.MaxVelocity = 5000
phys.MaxAngularVelocity = 3636.3637695313
physenv.SetPerformanceSettings(phys)

end

hook.Add( "InitPostEntity", "gb5_physics", gb5_physics )