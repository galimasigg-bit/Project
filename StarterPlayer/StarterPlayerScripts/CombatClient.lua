local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local CombatRequest = ReplicatedStorage:WaitForChild("CombatRequest")
local CombatModules = ReplicatedStorage:WaitForChild("CombatModules")
local BlockEvent = ReplicatedStorage:WaitForChild("BlockEvent")

local player = Players.LocalPlayer
local comboCount = 1
local ultimoClique = 0
local emCooldown = false
local defendendo = false

-- Variáveis separadas para as tracks de animação não se sobreporem ou quebrarem
local trackAtaqueCurrent = nil
local trackDefesaCurrent = nil

-- Estado atualizado com o seu estilo "Fcombat"
local EstadoDoJogador = {
	EstiloM1 = "Fcombat", 
	SkillsEquipadas = {
		["Z"] = {Modulo = "ExemploEstilo", NomeSkill = "MochiPunch"},
		["X"] = {Modulo = "ExemploEstilo", NomeSkill = "AirSlash"}
	}
}

local function tentarAtaqueM1()
	-- Impede o ataque se estiver defendendo
	if defendendo then return end

	local personagem = player.Character
	if not personagem or emCooldown then return end

	-- Anticheat local: Se o jogador estiver atordoado, ele não pode atacar
	if personagem:GetAttribute("Stunned") == true then return end

	local moduloDados = require(CombatModules:WaitForChild(EstadoDoJogador.EstiloM1))
	local dadosAtaque = moduloDados.Combo[comboCount]

	local tempoAtual = tick()
	-- Reseta o combo se demorar mais de X segundos entre os cliques
	if tempoAtual - ultimoClique > 2 then --- X segundos
		comboCount = 1
		dadosAtaque = moduloDados.Combo[comboCount]
	end

	emCooldown = true
	ultimoClique = tempoAtual

	-- Executa animação de ataque de forma limpa pelo Animator
	local humanoid = personagem:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local anim = Instance.new("Animation")
		anim.AnimationId = dadosAtaque.AnimId
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

		trackAtaqueCurrent = animator:LoadAnimation(anim)
		trackAtaqueCurrent:Play()

		-- Dispara o efeito visual e sonoro de vento no ar
		if ReplicatedStorage:FindFirstChild("CombatSwingEvent") then
			ReplicatedStorage.CombatSwingEvent:FireServer(EstadoDoJogador.EstiloM1, comboCount)
		end
	end

	-- Avisa o servidor para fazer a Hitbox e aplicar dano
	CombatRequest:FireServer("M1", {
		Estilo = EstadoDoJogador.EstiloM1,
		ComboIndex = comboCount
	})

	task.wait(dadosAtaque.Cooldown)
	emCooldown = false

	-- Avança no combo ou reinicia
	if comboCount >= #moduloDados.Combo then
		comboCount = 1
	else
		comboCount += 1
	end
end

-- Escuta cliques do mouse e teclas Z / X para Skills
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tentarAtaqueM1()
	elseif input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.X then
		local tecla = input.KeyCode.Name
		local skillData = EstadoDoJogador.SkillsEquipadas[tecla]
		if skillData then
			CombatRequest:FireServer("Skill", skillData)
		end
	end
end)

-- FUNÇÃO DE DEFESA MODIFICADA E CORRIGIDA VISANDO ALINHAMENTO DE BLOCOS
local function gerenciarDefesa(actionName, inputState, inputObject)
	local personagem = player.Character
	if not personagem then return end

	-- Se tomar Stun enquanto defende, força a saída da defesa imediatamente para não travar a animação!
	if personagem:GetAttribute("Stunned") == true then 
		if defendendo then
			defendendo = false
			local humanoid = personagem:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local puloOriginal = personagem:GetAttribute("PuloAntesDoBlock") or 50
				if humanoid.UseJumpPower then humanoid.JumpPower = puloOriginal else humanoid.JumpHeight = puloOriginal end
			end
			if trackDefesaCurrent then trackDefesaCurrent:Stop() trackDefesaCurrent = nil end
			BlockEvent:FireServer(false)
		end
		return 
	end

	local humanoid = personagem:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if inputState == Enum.UserInputState.Begin then
		defendendo = true

		personagem:SetAttribute("VelocidadeAntesDoBlock", humanoid.WalkSpeed)
		if humanoid.UseJumpPower then
			personagem:SetAttribute("PuloAntesDoBlock", humanoid.JumpPower)
			humanoid.JumpPower = 0 
		else
			personagem:SetAttribute("PuloAntesDoBlock", humanoid.JumpHeight)
			humanoid.JumpHeight = 0 
		end

		humanoid.WalkSpeed = 3 -- Permite andar bem devagar bloqueando se quiser, ou mude para 0 para congelar totalmente

		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://72067526497230"

		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		trackDefesaCurrent = animator:LoadAnimation(anim)
		trackDefesaCurrent.Priority = Enum.AnimationPriority.Action4 
		trackDefesaCurrent:Play()

		BlockEvent:FireServer(true, EstadoDoJogador.EstiloM1)

	elseif inputState == Enum.UserInputState.End and defendendo then
		defendendo = false

		local velOriginal = personagem:GetAttribute("VelocidadeAntesDoBlock") or 16
		local puloOriginal = personagem:GetAttribute("PuloAntesDoBlock") or 50

		humanoid.WalkSpeed = velOriginal
		if humanoid.UseJumpPower then
			humanoid.JumpPower = puloOriginal
		else
			humanoid.JumpHeight = puloOriginal
		end

		if trackDefesaCurrent then
			trackDefesaCurrent:Stop()
			trackDefesaCurrent = nil
		end

		BlockEvent:FireServer(false)
	end
end

-- 🟢 SEGURANÇA EXTRA: Se o Atributo Stunned mudar no meio da defesa, cancela a animação na hora!
player.CharacterAdded:Connect(function(char)
	char:GetAttributeChangedSignal("Stunned"):Connect(function()
		if char:GetAttribute("Stunned") == true and defendendo then
			defendendo = false
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local puloOriginal = char:GetAttribute("PuloAntesDoBlock") or 50
				if humanoid.UseJumpPower then humanoid.JumpPower = puloOriginal else humanoid.JumpHeight = puloOriginal end
				char.Humanoid.WalkSpeed = char:GetAttribute("VelocidadeAntesDoBlock") or 16
			end
			if trackDefesaCurrent then trackDefesaCurrent:Stop() trackDefesaCurrent = nil end
		end
	end)
end)


-- Liga a tecla F ao sistema de Defesa de forma segura
ContextActionService:BindAction("DefenderAction", gerenciarDefesa, true, Enum.KeyCode.F)

------------ 
------------ DASH
------------

local ContextActionService = game:GetService("ContextActionService")
local DashModules = ReplicatedStorage:WaitForChild("DashModules")
local DashEvent = ReplicatedStorage:WaitForChild("DashEvent")

local emCooldownDash = false

-- Simulando qual Dash o jogador escolheu no Menu (Modular)
local EstadoDashJogador = {
	DashAtivo = "FDash" -- Nome do ModuleScript ativo na pasta DashModules
}

-- Função inteligente para descobrir a direção do Dash baseada no teclado/analógico
local function obterDirecaoEAnimacao(humanoid, character, modulo)
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude == 0 then
		-- Se o jogador estiver parado, o dash padrão vai para a FRENTE do personagem
		return character.HumanoidRootPart.CFrame.LookVector, modulo.Animacoes.Frente
	end

	-- Transforma o vetor de movimento global em eixos locais do personagem
	local rootCFrame = character.HumanoidRootPart.CFrame
	local localDir = rootCFrame:VectorToWorldSpace(moveDir)
	local dotFrente = moveDir:Dot(rootCFrame.LookVector)
	local dotDireita = moveDir:Dot(rootCFrame.RightVector)

	-- Compara os eixos para decidir qual das 4 animações tocar
	if math.abs(dotFrente) > math.abs(dotDireita) then
		if dotFrente > 0 then
			return moveDir, modulo.Animacoes.Frente
		else
			return moveDir, modulo.Animacoes.Tras
		end
	else
		if dotDireita > 0 then
			return moveDir, modulo.Animacoes.Direita
		else
			return moveDir, modulo.Animacoes.Esquerda
		end
	end
end

local function tentarExecutarDash(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin or emCooldownDash then return end

	local personagem = player.Character
	if not personagem or not personagem:FindFirstChild("HumanoidRootPart") then return end

	if personagem:GetAttribute("Stunned") == true or personagem:GetAttribute("Blocking") == true then return end

	local humanoid = personagem:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local modulo = require(DashModules:WaitForChild(EstadoDashJogador.DashAtivo))
	local direcaoFisica, idAnimacao = obterDirecaoEAnimacao(humanoid, personagem, modulo)

	emCooldownDash = true

	-- 1. Desativa os estados que fazem o boneco inclinar ou deitar
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)

	-- 2. Toca a animação correta
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = idAnimacao
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track:Play()
	end

	-- 3. Aplica a força física sem influência vertical
	local root = personagem.HumanoidRootPart
	local attachment = Instance.new("Attachment", root)

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis

	-- TRAVA MÁXIMA RÍGIDA: Colocamos '0' de força no eixo Y. 
	-- Isso impede que colisões inclinadas com pedras empurrem o personagem para cima!
	linearVelocity.MaxAxesForce = Vector3.new(999999, 0, 999999) 
	linearVelocity.VectorVelocity = Vector3.new(direcaoFisica.X, 0, direcaoFisica.Z).Unit * modulo.Velocidade
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = root

	-- Avisa as partículas e sons do dash
	DashEvent:FireServer(EstadoDashJogador.DashAtivo, direcaoFisica)

	-- Desliga a força física após o tempo de duração
	task.wait(modulo.Duracao)
	linearVelocity:Destroy()
	attachment:Destroy()

	-- 🟢 FREIO DE MÃO DE REDE: Zera completamente toda e qualquer velocidade linear residual em todos os eixos (X, Y, Z)
	-- para cortar pela raiz o efeito estilingue ao desgrudar de quinas e pedras.
	if root and humanoid and humanoid.Health > 0 then
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	task.wait(modulo.Cooldown - modulo.Duracao)
	emCooldownDash = false
end




-- Vincula a tecla "Q" para acionar o Dash (Compatível com PC e botões Mobile automáticos)
ContextActionService:BindAction("DashAction", tentarExecutarDash, true, Enum.KeyCode.Q)

-- 🟢 PERMITE QUE O MENU DE INTEFACE ALTERE O SEU DASH NO FUTURO
_G.MudarDashAtivo = function(novoDashModule)
	EstadoDashJogador.DashAtivo = novoDashModule
end
