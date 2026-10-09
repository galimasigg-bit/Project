local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local CombatVFX = ReplicatedStorage:WaitForChild("CombatVFX")
local CombatAssets = ReplicatedStorage:WaitForChild("CombatAssets")
local SFXFolder = CombatAssets:WaitForChild("SFX")
local VFXFolder = CombatAssets:WaitForChild("VFX")

local player = Players.LocalPlayer

-- Função auxiliar para fazer a tela tremer
local function tremerTela(intensidade, duracao)
	local camera = workspace.CurrentCamera
	task.spawn(function()
		local tempoPassado = 0
		while tempoPassado < duracao do
			local offset = Vector3.new(
				math.random(-intensidade, intensidade) / 10,
				math.random(-intensidade, intensidade) / 10,
				math.random(-intensidade, intensidade) / 10
			)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			tempoPassado += task.wait()
		end
	end)
end

-- ESCUTADOR PRINCIPAL DE EFEITOS (VFX, SFX e TRAILS)
CombatVFX.OnClientEvent:Connect(function(posicaoImpacto, nomeSom, nomeEfeito, ehKnockback, atacante, nomeMembro, nomeTrail)

	-- 1. SISTEMA MODULAR DE TRAILS (Rastro do Golpe)
	if atacante and nomeMembro and nomeTrail then
		local membroFisico = atacante:FindFirstChild(nomeMembro)
		local trailOriginal = VFXFolder:FindFirstChild(nomeTrail)

		if membroFisico and trailOriginal then
			local att0 = membroFisico:FindFirstChild("TrailAtt0") or Instance.new("Attachment")
			att0.Name = "TrailAtt0"
			att0.Position = Vector3.new(0, 0.5, 0)
			att0.Parent = membroFisico

			local att1 = membroFisico:FindFirstChild("TrailAtt1") or Instance.new("Attachment")
			att1.Name = "TrailAtt1"
			att1.Position = Vector3.new(0, -0.5, 0)
			att1.Parent = membroFisico

			local trailClonada = trailOriginal:Clone()
			trailClonada.Attachment0 = att0
			trailClonada.Attachment1 = att1
			trailClonada.Enabled = true
			trailClonada.Parent = membroFisico

			task.delay(0.5, function()
				if trailClonada then
					trailClonada.Enabled = false
					game.Debris:AddItem(trailClonada, 0.2)
				end
			end)
		end
	end

	-- 2. EXECUÇÃO DO SOM DE IMPACTO (SFX - Com suporte a som de Escudo)
	local somNomeFinal = nomeSom
	if nomeSom == "SomDefesaSFX" then
		somNomeFinal = "SomDefesaSFX"
	end

	local somOriginal = SFXFolder:FindFirstChild(somNomeFinal)
	if somOriginal then
		local somClone = somOriginal:Clone()
		local somPart = Instance.new("Part")
		somPart.Size = Vector3.new(1,1,1)
		somPart.Position = posicaoImpacto
		somPart.Transparency = 1
		somPart.Anchored = true
		somPart.CanCollide = false
		somPart.Parent = workspace

		somClone.Parent = somPart
		somClone:Play()
		game.Debris:AddItem(somPart, somClone.TimeLength + 0.1)
	end

	-- 3. EXECUÇÃO DAS PARTÍCULAS NO INIMIGO (VFX)
	local efeitoOriginal = VFXFolder:FindFirstChild(nomeEfeito)
	if efeitoOriginal then
		local vfxPart = Instance.new("Part")
		vfxPart.Size = Vector3.new(1,1,1)
		vfxPart.Position = posicaoImpacto
		vfxPart.Transparency = 1
		vfxPart.Anchored = true
		vfxPart.CanCollide = false
		vfxPart.Parent = workspace

		for _, child in ipairs(efeitoOriginal:GetChildren()) do
			if child:IsA("Attachment") then
				local particulaClonada = child:Clone()
				particulaClonada.Parent = vfxPart
			end
		end
		game.Debris:AddItem(vfxPart, 0.7)
	end

	-- 4. EFEITO DE TREMER A TELA E REAÇÃO A DANO LOCAL NO SEU JOGADOR
	local personagem = player.Character
	if personagem and personagem:FindFirstChild("HumanoidRootPart") then
		local distancia = (personagem.HumanoidRootPart.Position - posicaoImpacto).Magnitude
		if distancia <= 200 then
			if ehKnockback then
				tremerTela(3, 0.3)
			else
				tremerTela(0.8, 0.1)
			end
		end

		-- Se o impacto aconteceu em você, o seu cliente força a execução segura da animação de Hit
		if (posicaoImpacto - personagem.HumanoidRootPart.Position).Magnitude < 2 then
			local humanoid = personagem:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
			if animator and personagem:GetAttribute("Blocking") ~= true then
				local anim = Instance.new("Animation")
				anim.AnimationId = ehKnockback and "rbxassetid://122303563566140" or "rbxassetid://136058391017410"

				local track = animator:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action4
				track:Play()
			end
		end
	end
end)

-- ESCUTADOR EXCLUSIVO PARA O VENTO DO GOLPE
ReplicatedStorage.CombatSwingEvent.OnClientEvent:Connect(function(atacante, nomeMembro, nomeParticulaVento, nomeSomVento)
	if nomeSomVento and nomeSomVento ~= "" then
		local somOriginal = SFXFolder:FindFirstChild(nomeSomVento)
		if somOriginal and atacante:FindFirstChild("HumanoidRootPart") then
			local somClone = somOriginal:Clone()
			somClone.Parent = atacante.HumanoidRootPart
			somClone:Play()
			game.Debris:AddItem(somClone, somClone.TimeLength + 0.1)
		end
	end

	if atacante and nomeMembro and nomeParticulaVento then
		local membroFisico = atacante:FindFirstChild(nomeMembro)
		local efeitoGolpeOriginal = VFXFolder:FindFirstChild(nomeParticulaVento)

		if membroFisico and efeitoGolpeOriginal then
			local emissorClonado = efeitoGolpeOriginal:Clone()
			emissorClonado.Parent = membroFisico

			local AttachmentVFXparticula = emissorClonado:FindFirstChildOfClass("ParticleEmitter")
			if AttachmentVFXparticula then
				local quantidadeEmitir = AttachmentVFXparticula:GetAttribute("EmitCount") or 1
				AttachmentVFXparticula:Emit(quantidadeEmitir)
			end

			game.Debris:AddItem(emissorClonado, 0.5)
		end
	end
end)

-- ESCUTADOR PARA CRIAR O ESCUDO VISUAL DE DEFESA (BlockEvent)
ReplicatedStorage:WaitForChild("BlockEvent").OnClientEvent:Connect(function(tipoAcao, dados)
	local atacante = dados.Atacante
	if not atacante or not atacante:FindFirstChild("HumanoidRootPart") then return end

	if tipoAcao == "CriarEscudoVisual" then
		if atacante.HumanoidRootPart:FindFirstChild("AttachmentEscudo") then return end

		local attEscudo = Instance.new("Attachment")
		attEscudo.Name = "AttachmentEscudo"
		attEscudo.Position = Vector3.new(0, 0, -1.8)
		attEscudo.Parent = atacante.HumanoidRootPart

		local escudoOriginal = VFXFolder:FindFirstChild(dados.EfeitoEscudo or "ParticulaDefesaVFX")
		if escudoOriginal then
			local escudoClonado = escudoOriginal:Clone()
			escudoClonado.Name = "EmissorEscudo"
			escudoClonado.Parent = attEscudo
		end

	elseif tipoAcao == "RemoverEscudoVisual" then
		local attEscudo = atacante.HumanoidRootPart:FindFirstChild("AttachmentEscudo")
		if attEscudo then
			local emissor = attEscudo:FindFirstChild("EmissorEscudo")
			if emissor and emissor:IsA("ParticleEmitter") then 
				emissor.Enabled = false 
			end
			game.Debris:AddItem(attEscudo, 0.5)
		end
	end
end)

-----------------
----------------- DASH
-----------------

-- 🟢 ESCUTADOR GLOBAL DE RENDERIZAÇÃO DE VFX DE DASH MODULAR
-- 🟢 ESCUTADOR ATUALIZADO COM SUPORTE A SOM DE DASH MODULAR
ReplicatedStorage:WaitForChild("DashEvent").OnClientEvent:Connect(function(atacante, nomeVfxVento, nomeVfxPoeira, nomeSomDash)
	if not atacante or not atacante:FindFirstChild("HumanoidRootPart") then return end
	local root = atacante.HumanoidRootPart

	-- 🟢 NOVO: Toca o som do dash modular colado na root part de quem usou
	if nomeSomDash and nomeSomDash ~= "" then
		local somOriginal = SFXFolder:FindFirstChild(nomeSomDash)
		if somOriginal then
			local somClone = somOriginal:Clone()
			somClone.Parent = root
			somClone:Play()
			game.Debris:AddItem(somClone, somClone.TimeLength + 0.1)
		end
	end

	-- (O resto do seu código de VFX de vento e poeira do dash continua igual abaixo...)


	-- 1. CRIA O EFEITO DE VENTO (Injetado direto na HumanoidRootPart, sem Attachment!)
	if nomeVfxVento and nomeVfxVento ~= "" then
		local particulaVentoOriginal = VFXFolder:FindFirstChild(nomeVfxVento)
		if particulaVentoOriginal then
			-- Clona o emissor direto para dentro da peça principal do corpo do atacante
			local ventoClone = particulaVentoOriginal:Clone()
			ventoClone.Name = "VentoDashTemporario"
			ventoClone.Parent = root -- 🟢 O PULO DO GATO: Gruda direto na HumanoidRootPart!

			-- Ativa a emissão visual do vento
			ventoClone.Enabled = true

			-- Se você configurou com EmitCount via Atributo, ele solta a explosão instantânea:
			if ventoClone:IsA("ParticleEmitter") then
				local quantidade = ventoClone:GetAttribute("EmitCount") or 20
				ventoClone:Emit(quantidade)
			end

			-- Desliga e limpa a partícula direto da peça após o término do impulso (0.3 segundos)
			task.delay(0.3, function()
				if ventoClone then 
					ventoClone.Enabled = false -- Para de fabricar novas partículas
					game.Debris:AddItem(ventoClone, 0.5) -- Deleta o arquivo da memória após sumir suavemente
				end
			end)
		end
	end

	-- 2. CRIA O EFEITO DE POEIRA NO CHÃO (Levantando poeira dos pés)
	if nomeVfxPoeira and nomeVfxPoeira ~= "" then
		local particulaPoeiraOriginal = VFXFolder:FindFirstChild(nomeVfxPoeira)
		if particulaPoeiraOriginal then
			local attPoeira = Instance.new("Attachment")
			attPoeira.Name = "AttDashPoeira"
			attPoeira.Position = Vector3.new(0, -3, 0) -- Força a poeira a nascer no chão
			attPoeira.Parent = root

			local poeiraClone = particulaPoeiraOriginal:Clone()
			poeiraClone.Parent = attPoeira

			if poeiraClone then
				--poeiraClone.Enabled = true
				task.delay(0.2, function()
					--poeiraClone.Enabled = false
					game.Debris:AddItem(attPoeira, 0.6)
				end)
			end
		end
	end
end)
