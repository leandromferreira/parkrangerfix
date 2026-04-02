-- ServerValidation.lua (server only)
-- Valida o personagem no momento em que ele é criado no servidor.
-- Impede que um jogador que bypassou o fix client-side entre no servidor
-- com um personagem gerado pelo exploit do Park Ranger / Herbalist.

local function onCreatePlayer(playerIndex, player)
    if not player then return end

    local descriptor = player:getDescriptor and player:getDescriptor()
    if not descriptor then return end

    local valid, reason = ParkRangerFixUtils.validateCharacter(descriptor)

    if not valid then
        print("[ParkRangerFix] EXPLOIT DETECTADO para o jogador: "
              .. tostring(player:getUsername()) .. " — " .. tostring(reason))

        -- Desconecta o jogador com uma mensagem explicativa.
        -- ServerCommands.kickPlayer encerra a conexão de forma limpa.
        local username = player:getUsername()
        if username then
            local msg = "Personagem inválido detectado pelo servidor: pontos de criação excedem o limite permitido. "
                     .. "Por favor, crie um novo personagem sem usar exploits."
            ServerCommands.kickPlayer(username, msg)
        end
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)

print("[ParkRangerFix] Validação server-side ativa.")
