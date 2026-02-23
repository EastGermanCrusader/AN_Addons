AddCSLuaFile()


if (CLIENT) then
     function gbehelp( ply, text, public)
         if (string.find(text, "!gb5") != nil) then
			 chat.AddText("Console commands:")
             chat.AddText("gb5_easyuse [0/1] - Should fireworks interact on use?")
	         chat.AddText("gb5_fragility [0/1] - Should fireworks arm, launch on damage?")
	         chat.AddText("gb5_unfreeze [0/1] - Should fireworks unfreeze stuff?")
			 chat.AddText("gb5_deleteconstraints [0/1] - Should fireworks delete constraints?")
			 chat.AddText("gb5_explosion_damage  [0/1] - Should fireworks do damage upon explosion?")
		 end
     end
end
hook.Add( "OnPlayerChat", "gb5help", gb5help )