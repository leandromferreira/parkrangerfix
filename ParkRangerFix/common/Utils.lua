-- common/Utils.lua
-- Utilitários compartilhados entre cliente e servidor.
-- Carregado automaticamente pelo PZ antes dos scripts de client/ e server/.

ParkRangerFixUtils = {}

-- Pontos base de criação de personagem no B42 vanilla.
ParkRangerFixUtils.BASE_POINTS = 8

-- Retorna { [traitName] = true } com os traits gratuitos da profissão.
function ParkRangerFixUtils.getFreeTraits(profType)
    local result = {}
    local prof = ProfessionFactory.getProfession(profType)
    if not prof then return result end

    local list = prof:getFreeTraits()
    if not list then return result end

    for i = 0, list:size() - 1 do
        local name = list:get(i)
        if name then result[name] = true end
    end
    return result
end

-- Retorna true se o trait é gratuito para a profissão informada.
function ParkRangerFixUtils.isFreeTrait(traitName, profType)
    return ParkRangerFixUtils.getFreeTraits(profType)[traitName] == true
end

-- Recalcula os pontos restantes legítimos do descritor.
--   < 0 → gastou mais do que devia (exploit detectado)
--   = 0 → dentro do orçamento
--   > 0 → pontos sobrando (não deveria ocorrer ao fim da criação)
function ParkRangerFixUtils.calculateRemaining(descriptor)
    local profType   = descriptor:getProfession()
    local freeTraits = ParkRangerFixUtils.getFreeTraits(profType)

    local points = ParkRangerFixUtils.BASE_POINTS

    -- Bônus legítimo: traits gratuitos removidos pelo jogador devolvem seu custo uma vez
    for traitName in pairs(freeTraits) do
        if not descriptor:hasTrait(traitName) then
            local trait = TraitFactory.getTrait(traitName)
            if trait then
                points = points + trait:getCost()
            end
        end
    end

    -- Desconta o custo de cada trait que o personagem possui (ignora os gratuitos mantidos)
    local charTraits = descriptor:getTraits()
    for i = 0, charTraits:size() - 1 do
        local traitName = charTraits:get(i)
        if not freeTraits[traitName] then
            local trait = TraitFactory.getTrait(traitName)
            if trait then
                -- getCost() > 0 → trait positivo (gasta pontos)
                -- getCost() < 0 → trait negativo (devolve pontos)
                points = points - trait:getCost()
            end
        end
    end

    return points
end

-- Valida o personagem. Retorna (true, nil) ou (false, mensagem).
function ParkRangerFixUtils.validateCharacter(descriptor)
    local remaining = ParkRangerFixUtils.calculateRemaining(descriptor)

    if remaining < 0 then
        return false, string.format(
            "[ParkRangerFix] Personagem inválido: %d pontos a mais do que o permitido (profissão: %s).",
            math.abs(remaining),
            tostring(descriptor:getProfession())
        )
    end

    return true, nil
end
