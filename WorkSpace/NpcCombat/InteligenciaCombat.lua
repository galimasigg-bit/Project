local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local rootPart = npc:WaitForChild("HumanoidRootPart")

-- Canais de comunicação e módulos
local CombatModules = ReplicatedStorage:WaitForChild("CombatModules")
local CombatRequest = ReplicatedStorage:WaitForChild("CombatRequest")
local BlockEvent = ReplicatedStorage:WaitForChild("BlockEvent")
local CombatSwingEvent = ReplicatedStorage:WaitForChild("CombatSwingEvent")

-- Configurações dinâmicas de comportamento da IA
local ESTILO_NPC = "Fcombat" 
local RAIO_PERSEGUICAO = 70
local DISTANCIA_IDEAL = 2 -- Mantém a distância polida sem subir na cabeça
local DISTANCIA_ATAQUE = 4.0 
local TEMPO_ENTRE_COMBOS = 0.3

-- Estados internos da Inteligência Artificial
local comboCount = 1
local emCooldownAtaque = false
local hitsRecebidosSeguidos = 0
local defendendoAtualmente = false

-- Carrega os dados direto do seu arquivo modular
local moduloDados = require(CombatModules:WaitForChild(ESTILO_NPC))

-- Função leve para buscar o jogador mais próximo
local function encontrarAlvoProximo()
	local alvoProximo = nil
	local menorDistancia = RAIO_PERSEGUICAO

	for _, player in ipairs(Players:GetPlayers()) do
		local personagem = player.Character
		if personagem and personagem:FindFirstChild("HumanoidRootPart") and personagem:FindFirstChildOfClass("Humanoid") then
			if personagem:FindFirstChildOfClass("Humanoid").Health > 0 then
				local distancia = (rootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
				if distancia < menorDistancia then
					menorDistancia = distancia
					alvoProximo = player.Character
				end
			end
		end
	end
	return alvoProximo
end

-- Mecânica de Ataque M1 do NPC
local function executarAtaqueNpc(alvo)
	if emCooldownAtaque or npc:GetAttribute("Stunned") == true or defendendoAtualmente then return end
	emCooldownAtaque = true

	if alvo and alvo:FindFirstChild("HumanoidRootPart") then
		local posicaoAlvo = Vector3.new(alvo.HumanoidRootPart.Position.X, rootPart.Position.Y, alvo.HumanoidRootPart.Position.Z)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, posicaoAlvo)
	end

	local dadosAtaque = moduloDados.Combo[comboCount]

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = dadosAtaque.AnimId
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track:Play()

		CombatSwingEvent:FireAllClients(npc, dadosAtaque.Membro, dadosAtaque.ParticulaSwing, dadosAtaque.SomSwing)
	end

	-- 2. Sistema de Hitbox por área física frontal com proteção de sobreposição de Stun
	task.wait(0.08)

	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = {npc}
	overlap.FilterType = Enum.RaycastFilterType.Exclude

	local hitboxes = workspace:GetPartBoundsInBox(rootPart.CFrame * CFrame.new(0, 0, -2.5), Vector3.new(4, 5, 4), overlap)
	for _, part in ipairs(hitboxes) do
		local jogadorModel = part.Parent
		local jogadorHumanoid = jogadorModel:FindFirstChildOfClass("Humanoid")
		local jogadorRoot = jogadorModel:FindFirstChild("HumanoidRootPart")

		if jogadorHumanoid and jogadorHumanoid.Health > 0 then
			local danoFinal = dadosAtaque.Dano
			local jogadorEstavaDefendendo = jogadorModel:GetAttribute("ServerBlocking") == true

			if jogadorEstavaDefendendo then
				local estiloDefesa = jogadorModel:GetAttribute("EstiloDefesaAtivo")
				if estiloDefesa then
					local moduloDefesaJg = require(CombatModules:FindFirstChild(estiloDefesa))
					if moduloDefesaJg and moduloDefesaJg.ReducaoDano then
						danoFinal = dadosAtaque.Dano * (1 - moduloDefesaJg.ReducaoDano)
						ReplicatedStorage.CombatVFX:FireAllClients(jogadorRoot.Position, "SomDefesaSFX", "ParticulaDefesaVFX", false, npc, dadosAtaque.Membro, dadosAtaque.Trail)
					end
				end
			else
				-- 🟢 SOLUÇÃO DO BUG: Cria um "Carimbo de Tempo" único para este golpe específico
				local ID_DoHitAtual = tick()
				jogadorModel:SetAttribute("UltimoHitID", ID_DoHitAtual)

				-- Se o jogador já não estava atordoado, salva a velocidade real dele (evita salvar 0 por erro)
				if jogadorModel:GetAttribute("Stunned") ~= true then
					jogadorModel:SetAttribute("VelocidadeAntesDoStun", jogadorHumanoid.WalkSpeed)
				end

				jogadorModel:SetAttribute("Stunned", true)
				jogadorHumanoid.WalkSpeed = 0

				ReplicatedStorage.CombatVFX:FireAllClients(jogadorRoot.Position, dadosAtaque.Som, dadosAtaque.Efeito, dadosAtaque.Knockback, npc, dadosAtaque.Membro, dadosAtaque.Trail)

				-- Define o tempo alto que você escolheu (2 para Knockback, 1 para M1 normal)
				local tempoStunAlvo = dadosAtaque.Knockback and 1.5 or 0.7

				task.delay(tempoStunAlvo, function()
					-- ANTES DE DESTRAVAR: O script verifica se você tomou outro soco depois desse.
					-- Se o ID do ÚltimoHit mudou, significa que você tomou outro soco e essa linha se auto-destrói em silêncio!
					if jogadorModel and jogadorHumanoid and jogadorModel:GetAttribute("UltimoHitID") == ID_DoHitAtual then
						local velRecuperar = jogadorModel:GetAttribute("VelocidadeAntesDoStun") or 16
						if velRecuperar == 0 then velRecuperar = 16 end -- Proteção extra contra travas zero

						jogadorHumanoid.WalkSpeed = velRecuperar
						jogadorModel:SetAttribute("Stunned", nil)
						jogadorModel:SetAttribute("UltimoHitID", nil)
						jogadorModel:SetAttribute("VelocidadeAntesDoStun", nil)
					end
				end)
			end

			jogadorHumanoid:TakeDamage(danoFinal)

			if dadosAtaque.Knockback and jogadorRoot and not jogadorEstavaDefendendo then
				local direcao = (jogadorRoot.Position - rootPart.Position).Unit
				local vel = Instance.new("LinearVelocity")
				vel.MaxForce = 50000
				vel.VectorVelocity = (direcao * 75) + Vector3.new(0, 18, 0)

				local att = Instance.new("Attachment", jogadorRoot)
				vel.Attachment0 = att
				vel.Parent = jogadorRoot
				game.Debris:AddItem(vel, 0.25)
				game.Debris:AddItem(att, 0.25)
			end
			break
		end
	end


	task.wait(dadosAtaque.Cooldown)

	if comboCount >= #moduloDados.Combo then
		comboCount = 1
		task.wait(TEMPO_ENTRE_COMBOS)
	else
		comboCount += 1
	end
	emCooldownAtaque = false
end

-- DEFESA INTELIGENTE ADAPTATIVA DO NPC (Toca a animação física e o escudo modular)
npc:GetAttributeChangedSignal("Stunned"):Connect(function()
	if npc:GetAttribute("Stunned") == true and not defendendoAtualmente then
		hitsRecebidosSeguidos += 1
------------ defende a partir de X cliques
		if hitsRecebidosSeguidos >= 4 then
			hitsRecebidosSeguidos = 0
			defendendoAtualmente = true

			task.spawn(function()
				npc:SetAttribute("ServerBlocking", true)
				npc:SetAttribute("EstiloDefesaAtivo", ESTILO_NPC)
				humanoid.WalkSpeed = 0

				local trackNpcBlock = nil
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					local animB = Instance.new("Animation")
					animB.AnimationId = "rbxassetid://72067526497230"
					trackNpcBlock = animator:LoadAnimation(animB)
					trackNpcBlock.Priority = Enum.AnimationPriority.Action4
					trackNpcBlock:Play()
				end

				BlockEvent:FireAllClients("CriarEscudoVisual", {
					Atacante = npc,
					EfeitoEscudo = moduloDados.EfeitoEscudo or "ParticulaDefesaVFX"
				})
---------------- Tempo defendendo
				task.wait(2)

				if trackNpcBlock then trackNpcBlock:Stop() end

				npc:SetAttribute("ServerBlocking", nil)
				npc:SetAttribute("EstiloDefesaAtivo", nil)
				BlockEvent:FireAllClients("RemoverEscudoVisual", {Atacante = npc})

				defendendoAtualmente = false
			end)
		end
	end
end)

-- CONFIGURAÇÃO DE ANIMAÇÃO DE ANDAR PADRÃO DO NPC (Passos no Rig)
local trackCorrerNpc = nil
local animatorNpc = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local animRun = Instance.new("Animation")
animRun.AnimationId = "rbxassetid://180426354"
if animatorNpc then
	trackCorrerNpc = animatorNpc:LoadAnimation(animRun)
	trackCorrerNpc.Priority = Enum.AnimationPriority.Movement
end

humanoid.Running:Connect(function(speed)
	if speed > 0.1 then
		if trackCorrerNpc and not trackCorrerNpc.IsPlaying and not defendendoAtualmente then
			trackCorrerNpc:Play()
		end
	else
		if trackCorrerNpc then trackCorrerNpc:Stop() end
	end
end)

-- LOOP PRINCIPAL DE DECISÕES DA IA
task.spawn(function()
	while task.wait(0.05) do
		if humanoid.Health <= 0 then break end

		local alvo = encontrarAlvoProximo()

		if npc:GetAttribute("Stunned") == true or defendendoAtualmente then
			humanoid:MoveTo(rootPart.Position)
		elseif alvo and alvo:FindFirstChild("HumanoidRootPart") then
			local direcaoAteAlvo = (alvo.HumanoidRootPart.Position - rootPart.Position)
			local distancia = direcaoAteAlvo.Magnitude

			if distancia <= DISTANCIA_ATAQUE then
				humanoid:MoveTo(rootPart.Position)
				executarAtaqueNpc(alvo)
			else
				humanoid.WalkSpeed = 18
				local posicaoParadaInteligente = alvo.HumanoidRootPart.Position - (direcaoAteAlvo.Unit * DISTANCIA_IDEAL)
				humanoid:MoveTo(posicaoParadaInteligente)
			end
		else
			humanoid:MoveTo(rootPart.Position)
		end
	end
end)
