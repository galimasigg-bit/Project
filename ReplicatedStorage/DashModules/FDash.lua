local DashModule = {}

-- Configurações modulares do Dash
DashModule.Velocidade = 80 -- Força do impulso
DashModule.Duracao = 0.2 -- Quanto tempo o impulso dura no ar
DashModule.Cooldown = 0.8 -- Tempo de espera para usar de novo

-- Efeitos visuais que serão puxados da pasta ReplicatedStorage > CombatAssets > VFX
DashModule.SFX_Dash = "SomVentoDash" 
DashModule.VFX_Vento = "VentoDashVFX"    -- Partícula que gruda no peito/RootPart
DashModule.VFX_Poeira = "PoeiraDashVFX"  -- Partícula que espalha no chão

-- IDs das 4 animações direcionais
DashModule.Animacoes = {
	["Frente"]   = "rbxassetid://90590760760621",
	["Tras"]     = "rbxassetid://84765361564290",
	["Esquerda"] = "rbxassetid://74130248267355",
	["Direita"]  = "rbxassetid://135321830854107",
}

return DashModule

