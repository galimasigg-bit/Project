local EstiloCombate = {}

local EstiloCombate = {}

EstiloCombate.ReducaoDano = 0.70 
EstiloCombate.EfeitoEscudo = "ParticulaDefesaVFX" -- 🟢 Nome EXATO da ParticleEmitter na pasta ReplicatedStorage > CombatAssets > VFX

EstiloCombate.Combo = {
	[1] = {
		AnimId = "rbxassetid://84172877935994", 
		Dano = 5, Cooldown = 0.3, Knockback = false, 
		Som = "SocoSom", Efeito = "HitParticula", 
		Membro = "HumanoidRootPart", 
		ParticulaSwing = "SocoEsquerdoVFX", SomSwing = "VentoSocoSFX" 
	},
	[2] = {
		AnimId = "rbxassetid://74529462212195", 
		Dano = 5, Cooldown = 0.3, Knockback = false, 
		Som = "SocoSom", Efeito = "HitParticula", 
		Membro = "HumanoidRootPart", 
		ParticulaSwing = "SocoDireitoVFX", SomSwing = "VentoSocoSFX"
	},
	[3] = {
		AnimId = "rbxassetid://102507540978767", 
		Dano = 5, Cooldown = 0.3, Knockback = false, 
		Som = "SocoSom", Efeito = "HitParticula", 
		Membro = "RightFoot", -- 🟢 Corrigido: Escolhido o pé direito para o rastro do chute 3
		ParticulaSwing = "WooshVFX", SomSwing = "VentoSocoSFX"
	},
	[4] = {
		AnimId = "rbxassetid://71039988190594", 
		Dano = 5, Cooldown = 0.5, Knockback = false, 
		Som = "SocoSom", Efeito = "HitParticula", 
		Membro = "LeftFoot", -- 🟢 Corrigido: Escolhido o pé esquerdo para o rastro do chute 4
		ParticulaSwing = "WooshVFX", SomSwing = "VentoSocoSFX"
	},
	[5] = {
		AnimId = "rbxassetid://130011176668870", 
		Dano = 15, Cooldown = 2, Knockback = true, 
		Som = "KnockBackSom", Efeito = "KnockBackParticula", 
		Membro = "HumanoidRootPart", 
		ParticulaSwing = "KnockBackVFX", SomSwing = "VentoSocoSFX"
	},
}

EstiloCombate.Skills = {
	["MochiPunch"] = {AnimId = "rbxassetid://...", Dano = 25, Cooldown = 5, Som = "MochiSom", Efeito = "MochiEfeito"},
}

return EstiloCombate
