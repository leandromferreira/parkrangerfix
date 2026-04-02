-- server/ParkRangerFix/ServerValidation.lua
-- Valida o personagem no servidor ao ser criado.
-- Rejeita personagens com mais pontos gastos do que o permitido.
-- Depende de ParkRangerFixUtils (common/Utils.lua).

local function onCreatePlayer(playerIndex, player)
    if not player then return end

    local descriptor = player:getDescriptor and player:getDescriptor()
    if not descriptor then return end

    local valid, reason = ParkRangerFixUtils.validateCharacter(descriptor)

    if not valid then
        local username = player:getUsername()
        print("[ParkRangerFix] EXPLOIT DETECTADO — jogador: " .. tostring(username) .. " | " .. tostring(reason))

        if username then
            ServerCommands.kickPlayer(
                username,
                "Personagem inválido: pontos de criação excedem o limite permitido. Crie um novo personagem."
            )
        end
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)

print("[ParkRangerFix] Server-side ativo. Validação de personagem habilitada.")
