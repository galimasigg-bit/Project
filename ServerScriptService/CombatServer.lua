local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatModules = ReplicatedStorage:WaitForChild("CombatModules")
local CombatRequest = ReplicatedStorage:WaitForChild("CombatRequest")
local BlockEvent = ReplicatedStorage:WaitForChild("BlockEvent")



-- Dicionário para gerenciar cooldowns e evitar hacks de velocidade de ataque
local cooldownsServidor = {}

-- 🟢 Limpa a memória do servidor automaticamente assim que um jogador sai do jogo
game:GetService("Players").PlayerRemoving:Connect(function(player)
	if cooldownsServidor[player] then
		cooldownsServidor[player] = nil
	end
end)


-- 🟢 GERENCIADOR CENTRAL DE DEFESA (BLOCK) NO SERVIDOR
BlockEvent.OnServerEvent:Connect(function(player, ativo, estiloNome)
	local personagem = player.Character
	if not personagem or not personagem:FindFirstChild("HumanoidRootPart") then return end
	local humanoid = personagem:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if ativo then
		personagem:SetAttribute("ServerBlocking", true)
		personagem:SetAttribute("EstiloDefesaAtivo", estiloNome or "Fcombat")

		-- Salva a velocidade e pulo atuais do servidor antes de travar
		personagem:SetAttribute("VelServidorAntes", humanoid.WalkSpeed)
		personagem:SetAttribute("PuloServidorAntes", humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight)

		humanoid.WalkSpeed = 3 --Permite andar bem devagar
		if humanoid.UseJumpPower then humanoid.JumpPower = 0 else humanoid.JumpHeight = 0 end

		-- 🟢 LÊ O ESCUDO MODULAR DO ARQUIVO DE COMBATE EQUIPADO
		local efeitoDoEstilo = "ParticulaDefesaVFX" -- Valor reserva padrão
		local moduloEstilo = CombatModules:FindFirstChild(estiloNome or "")
		if moduloEstilo then
			local dadosCarregados = require(moduloEstilo)
			if dadosCarregados and dadosCarregados.EfeitoEscudo then
				efeitoDoEstilo = dadosCarregados.EfeitoEscudo
			end
		end

		-- Dispara o escudo visual customizado para o canal correto (BlockEvent)
		BlockEvent:FireAllClients("CriarEscudoVisual", {
			Atacante = personagem,
			EfeitoEscudo = efeitoDoEstilo
		})
	else
		personagem:SetAttribute("ServerBlocking", nil)
		personagem:SetAttribute("EstiloDefesaAtivo", nil)

		-- Devolve o valor exato que o jogador tinha antes, respeitando raças e status futuros
		local velOriginal = personagem:GetAttribute("VelServidorAntes") or 16
		local puloOriginal = personagem:GetAttribute("PuloServidorAntes") or 50

		humanoid.WalkSpeed = velOriginal
		if humanoid.UseJumpPower then humanoid.JumpPower = puloOriginal else humanoid.JumpHeight = puloOriginal end

		-- Remove o escudo visual do mapa de todo mundo pelo canal correto (BlockEvent)
		BlockEvent:FireAllClients("RemoverEscudoVisual", {Atacante = personagem})
	end
end)

-- 🔴 GERENCIADOR DE ATAQUES M1 E SKILLS NO SERVIDOR
CombatRequest.OnServerEvent:Connect(function(player, tipoAcao, dados)
	local personagem = player.Character

	if not personagem or not personagem:FindFirstChild("HumanoidRootPart") then return end

	-- Proteção básica de anticheat por tempo
	if not cooldownsServidor[player] then cooldownsServidor[player] = 0 end
	if tick() - cooldownsServidor[player] < 0.15 then return end -- Cliques rápidos demais são barrados
	cooldownsServidor[player] = tick()

	if tipoAcao == "M1" then
		local moduloDados = require(CombatModules:WaitForChild(dados.Estilo))
		local infoHit = moduloDados.Combo[dados.ComboIndex]

		-- Criação da Hitbox por caixa de colisão frontal
		local overlap = OverlapParams.new()
		overlap.FilterDescendantsInstances = {personagem}
		overlap.FilterType = Enum.RaycastFilterType.Exclude

		local hitboxes = workspace:GetPartBoundsInBox(personagem.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3), Vector3.new(4, 5, 5), overlap)

		for _, part in ipairs(hitboxes) do
			local inimigoModel = part.Parent
			local inimigoHumanoid = inimigoModel:FindFirstChildOfClass("Humanoid")
			local inimigoRoot = inimigoModel:FindFirstChild("HumanoidRootPart")

			if inimigoHumanoid and inimigoHumanoid.Health > 0 then
				local danoFinal = infoHit.Dano
				local estavaDefendendo = inimigoModel:GetAttribute("ServerBlocking") == true

				-- CHECAGEM DE DEFESA: Se o oponente estiver defendendo, calcula a redução por porcentagem
				if estavaDefendendo then
					local estiloDefesa = inimigoModel:GetAttribute("EstiloDefesaAtivo")
					if estiloDefesa then
						local moduloInimigo = require(CombatModules:FindFirstChild(estiloDefesa))
						if moduloInimigo and moduloInimigo.ReducaoDano then
							-- Aplica a redução modular (Ex: 0.7 de redução = recebe apenas 30% do dano)
							danoFinal = infoHit.Dano * (1 - moduloInimigo.ReducaoDano)

							-- Dispara o efeito visual e sonoro metálico de block de forma sincronizada
							ReplicatedStorage.CombatVFX:FireAllClients(inimigoRoot.Position, "SomDefesaSFX", "ParticulaDefesaVFX", false, personagem, infoHit.Membro, infoHit.Trail)
						end
					end
				else
					-- Se NÃO estava defendendo, toca o impacto normal
					ReplicatedStorage.CombatVFX:FireAllClients(inimigoRoot.Position, infoHit.Som, infoHit.Efeito, infoHit.Knockback, personagem, infoHit.Membro, infoHit.Trail)
					
					-- 🟢 PROTEÇÃO PVP: Cria um Carimbo de Tempo único para o golpe entre jogadores
					local ID_DoHitAtual = tick()
					inimigoModel:SetAttribute("UltimoHitID", ID_DoHitAtual)
					
					-- Salva a velocidade real do oponente se ele já não estava em Stun (evita salvar velocidade 0)
					if inimigoModel:GetAttribute("Stunned") ~= true then
						inimigoModel:SetAttribute("VelocidadeAntesDoStun", inimigoHumanoid.WalkSpeed)
					end
					
					inimigoModel:SetAttribute("Stunned", true)
					inimigoHumanoid.WalkSpeed = 0 

					-- CONFIGURAÇÃO SEGURA DO ANIMATOR (Hitstun/Knockback)
					if inimigoHumanoid then
						local animator = inimigoHumanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", inimigoHumanoid)
						if animator then
							local animReacao = Instance.new("Animation")
							animReacao.AnimationId = infoHit.Knockback and "rbxassetid://122303563566140" or "rbxassetid://136058391017410"
							local track = animator:LoadAnimation(animReacao)
							track.Priority = Enum.AnimationPriority.Action4
							track:Play()
							game.Debris:AddItem(animReacao, track.Length + 0.1)
						end
					end

					-- 🟢 CRONÔMETRO BLINDADO CONTRA SOBREPOSIÇÃO NO PVP:
					-- Define dinamicamente o tempo do Stun (0.8 para golpe final, 0.5 ou o tempo que você escolheu para M1 comum)
					local tempoStunAlvo = infoHit.Knockback and 1.5 or 0.7
					
					task.delay(tempoStunAlvo, function()
						-- Só devolve o movimento se o ID do hit continuar sendo o mesmo (nenhum outro player bateu nele depois)
						if inimigoModel and inimigoHumanoid and inimigoModel:GetAttribute("UltimoHitID") == ID_DoHitAtual then
							-- 🟢 SOLUÇÃO DEFINITIVA: Puxa o valor salvo direto do atributo do personagem, eliminando a global desconhecida!
							local velRecuperar = inimigoModel:GetAttribute("VelocidadeAntesDoStun") or 16
							if velRecuperar == 0 then velRecuperar = 16 end -- Segurança contra velocidade nula

							inimigoHumanoid.WalkSpeed = velRecuperar
							inimigoModel:SetAttribute("Stunned", nil)
							inimigoModel:SetAttribute("UltimoHitID", nil)
							inimigoModel:SetAttribute("VelocidadeAntesDoStun", nil)
						end
					end)

				end


				-- Aplica o dano definitivo calculado (mitigado ou cheio)
				inimigoHumanoid:TakeDamage(danoFinal)

				-- Se for o último hit do combo e o inimigo NÃO defendeu, aplica o empurrão físico (Knockback)
				if infoHit.Knockback and inimigoRoot and not estavaDefendendo then
					local direcao = (inimigoRoot.Position - personagem.HumanoidRootPart.Position).Unit
					local vel = Instance.new("LinearVelocity")
					vel.MaxForce = 50000
					vel.VectorVelocity = (direcao * 100) + Vector3.new(0, 18, 0)

					local attachment = Instance.new("Attachment", inimigoRoot)
					vel.Attachment0 = attachment
					vel.Parent = inimigoRoot

					game.Debris:AddItem(vel, 0.25)
					game.Debris:AddItem(attachment, 0.25)
				end

				break
			end
		end

	elseif tipoAcao == "Skill" then
		local moduloDados = require(CombatModules:WaitForChild(dados.Modulo))
		local infoSkill = moduloDados.Skills[dados.NomeSkill]

		print(player.Name .. " usou a habilidade: " .. dados.NomeSkill .. " causando " .. infoSkill.Dano .. " de dano base!")
		-- Adicione a lógica de execução visual e dano da Skill aqui
	end
end)

-- 🟢 Escuta o clique de vento e avisa todo mundo no servidor para renderizar o arco visual
ReplicatedStorage.CombatSwingEvent.OnServerEvent:Connect(function(player, estiloNome, comboIndex)
	local personagem = player.Character
	if not personagem then return end

	local moduloDados = require(CombatModules:FindFirstChild(estiloNome))
	if moduloDados then
		local infoHit = moduloDados.Combo[comboIndex]
		if infoHit then
			-- Avisa todos os computadores para criarem a partícula no braço/perna do atacante
			ReplicatedStorage.CombatSwingEvent:FireAllClients(personagem, infoHit.Membro, infoHit.ParticulaSwing, infoHit.SomSwing)
		end
	end
end)

-----------------
----------------- DASH
-----------------

local DashModules = ReplicatedStorage:WaitForChild("DashModules")
local DashEvent = ReplicatedStorage:WaitForChild("DashEvent")

DashEvent.OnServerEvent:Connect(function(player, nomeModuloDash, direcaoMover)
	local personagem = player.Character
	if not personagem or not personagem:FindFirstChild("HumanoidRootPart") then return end

	-- Proteção contra Stun/Block no Servidor
	if personagem:GetAttribute("Stunned") == true or personagem:GetAttribute("ServerBlocking") == true then return end

	local modulo = require(DashModules:WaitForChild(nomeModuloDash))
	if modulo then
		-- Reclica o efeito visual para todos os clientes renderizarem de forma leve
		-- Mude a linha de disparo para enviar também o info do som (modulo.SFX_Dash)
		DashEvent:FireAllClients(personagem, modulo.VFX_Vento, modulo.VFX_Poeira, modulo.SFX_Dash)

	end
end)
