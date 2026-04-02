-- Utils.lua (common — roda em cliente E servidor)
-- Utilitários para calcular e validar pontos de criação de personagem.

ParkRangerFixUtils = {}

-- Pontos base de criação de personagem no B42 vanilla.
-- Se outro mod alterar esse valor, ajuste aqui.
ParkRangerFixUtils.BASE_POINTS = 8

-- Retorna tabela { [traitName] = true } com os traits gratuitos da profissão.
function ParkRangerFixUtils.getFreeTraitsForProfession(profType)
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

-- Recalcula do zero quantos pontos "legítimos" o personagem tinha disponíveis
-- e quanto ele efetivamente gastou, usando apenas os dados do descritor.
--
-- Retorna: (expectedRemaining, details)
--   expectedRemaining < 0  → personagem gastou mais do que devia  (exploit)
--   expectedRemaining == 0 → exatamente dentro do orçamento
--   expectedRemaining > 0  → pontos sobrando (não deveria acontecer normalmente)
--
-- Lógica:
--   Começa com BASE_POINTS.
--   Para cada trait GRATUITO da profissão que foi REMOVIDO:
--       soma o custo de volta (jogador legitimamente ganhou esses pontos).
--   Para cada trait que o personagem TEM (exceto gratuitos mantidos):
--       subtrai getCost()  →  positivo p/ traits bons, negativo p/ traits ruins.
function ParkRangerFixUtils.calculateExpectedRemaining(descriptor)
    local profType  = descriptor:getProfession()
    local freeTraits = ParkRangerFixUtils.getFreeTraitsForProfession(profType)

    local points = ParkRangerFixUtils.BASE_POINTS

    -- Bonus legítimo por traits gratuitos que foram removidos
    for traitName, _ in pairs(freeTraits) do
        if not descriptor:hasTrait(traitName) then
            local trait = TraitFactory.getTrait(traitName)
            if trait then
                points = points + trait:getCost()
            end
        end
    end

    -- Desconta o custo de todos os traits que o personagem possui
    -- (traits gratuitos mantidos custam 0, então pulamos)
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

-- Retorna true se o personagem é válido, false + mensagem se não.
function ParkRangerFixUtils.validateCharacter(descriptor)
    local remaining = ParkRangerFixUtils.calculateExpectedRemaining(descriptor)

    if remaining < 0 then
        return false, string.format(
            "[ParkRangerFix] Personagem inválido: gastou %d pontos a mais do que o permitido (profissão: %s).",
            math.abs(remaining),
            tostring(descriptor:getProfession())
        )
    end

    return true, nil
end
