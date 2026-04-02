-- ParkRangerFix.lua
-- Corrige o exploit da profissão Park Ranger no B42:
-- O jogador selecionava Park Ranger (que dá Herbalist grátis),
-- removia Herbalist (ganhando os pontos de volta), trocava de profissão,
-- voltava para Park Ranger e repetia o processo indefinidamente.

local ParkRangerFix = {}

-- Tabela que rastreia, por profissão, quais traits gratuitos já foram
-- removidos manualmente pelo jogador durante esta sessão de criação de personagem.
-- Estrutura: { ["parkranger"] = { ["Herbalist"] = true, ... }, ... }
ParkRangerFix.removedFreeTraits = {}

-- Referências às funções originais para encadeamento (super call)
local original_onProfessionClick = nil
local original_onTraitClick = nil

-- Utilitário: retorna a lista de traits gratuitos de uma profissão como tabela Lua
local function getFreeTraitsForProfession(profType)
    local freeTraits = {}
    local prof = ProfessionFactory.getProfession(profType)
    if not prof then return freeTraits end

    local javaList = prof:getFreeTraits()
    if not javaList then return freeTraits end

    for i = 0, javaList:size() - 1 do
        local traitName = javaList:get(i)
        if traitName then
            freeTraits[traitName] = true
        end
    end
    return freeTraits
end

-- Utilitário: verifica se um trait é gratuito para a profissão atual do descritor
local function isFreeTraitForProfession(traitName, profType)
    local freeTraits = getFreeTraitsForProfession(profType)
    return freeTraits[traitName] == true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Hook: ISCharacterCreationMain.onTraitClick
-- Intercepta quando o jogador clica em um trait para ativar/desativar.
-- Se for um trait gratuito sendo REMOVIDO, registramos para a profissão atual.
-- ─────────────────────────────────────────────────────────────────────────────
local function hooked_onTraitClick(self, trait, ...)
    -- Tenta obter o nome do trait de forma compatível com diferentes versões
    local traitName = nil
    if trait and type(trait) == "string" then
        traitName = trait
    elseif trait and trait.getType then
        traitName = trait:getType()
    elseif trait and trait.getName then
        traitName = trait:getName()
    end

    if traitName then
        local descriptor = self.character and self.character:getDescriptor and self.character:getDescriptor()
        local profType = descriptor and descriptor.getProfession and descriptor:getProfession()

        if profType and isFreeTraitForProfession(traitName, profType) then
            -- O trait está atualmente ATIVO e o jogador está clicando para remover
            local hasTrait = descriptor.hasTrait and descriptor:hasTrait(traitName)
            if hasTrait then
                -- Registra que este trait gratuito foi removido manualmente
                if not ParkRangerFix.removedFreeTraits[profType] then
                    ParkRangerFix.removedFreeTraits[profType] = {}
                end
                ParkRangerFix.removedFreeTraits[profType][traitName] = true
            end
        end
    end

    -- Chama a função original
    original_onTraitClick(self, trait, ...)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Hook: ISCharacterCreationMain.onProfessionClick
-- Intercepta quando o jogador seleciona uma profissão.
-- Após a seleção (que re-adiciona os traits gratuitos), remove novamente os
-- traits que o jogador já havia removido anteriormente para esta profissão,
-- sem devolver os pontos (pois já foram devolvidos antes).
-- ─────────────────────────────────────────────────────────────────────────────
local function hooked_onProfessionClick(self, button, ...)
    -- Chama a função original primeiro (ela adiciona os free traits da profissão)
    original_onProfessionClick(self, button, ...)

    -- Descobre qual profissão foi selecionada após a chamada original
    local descriptor = self.character and self.character:getDescriptor and self.character:getDescriptor()
    local profType = descriptor and descriptor.getProfession and descriptor:getProfession()

    if not profType then return end

    local alreadyRemoved = ParkRangerFix.removedFreeTraits[profType]
    if not alreadyRemoved then return end

    -- Para cada trait gratuito que foi previamente removido nesta profissão,
    -- remove novamente sem devolver pontos (já foram devolvidos antes).
    local needsRefresh = false
    for traitName, _ in pairs(alreadyRemoved) do
        local hasTrait = descriptor.hasTrait and descriptor:hasTrait(traitName)
        if hasTrait then
            -- Remove o trait diretamente do descritor sem ajuste de pontos.
            -- O custo do trait é buscado para não recompensar o jogador novamente.
            local traitObj = TraitFactory.getTrait(traitName)
            if traitObj then
                local cost = traitObj:getCost()
                -- Remove o trait
                if descriptor.removeTrait then
                    descriptor:removeTrait(traitName)
                end
                -- Compensa os pontos que a engine devolveu indevidamente:
                -- a engine normalmente devolve os pontos ao remover um free trait,
                -- mas aqui queremos cancelar essa devolução.
                -- Subtrai os pontos de volta para anular o ganho indevido.
                if cost > 0 then
                    -- Trait positivo (custo > 0): remover devolve pontos → subtrai de volta
                    local currentPoints = self.points or 0
                    self.points = currentPoints - cost
                elseif cost < 0 then
                    -- Trait negativo (custo < 0): remover cobra pontos → adiciona de volta
                    local currentPoints = self.points or 0
                    self.points = currentPoints - cost
                end
            end
            needsRefresh = true
        end
    end

    -- Atualiza a UI se houve mudanças
    if needsRefresh then
        if self.updatePoints then
            self:updatePoints()
        end
        if self.refreshTraits then
            self:refreshTraits()
        elseif self.updateTraits then
            self:updateTraits()
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Instalação dos hooks
-- Aguarda o carregamento do jogo para garantir que ISCharacterCreationMain
-- já está definido antes de aplicar os overrides.
-- ─────────────────────────────────────────────────────────────────────────────
local function installHooks()
    if not ISCharacterCreationMain then
        print("[ParkRangerFix] AVISO: ISCharacterCreationMain não encontrado. Mod pode não funcionar.")
        return
    end

    -- Guarda referências às funções originais
    original_onProfessionClick = ISCharacterCreationMain.onProfessionClick
    original_onTraitClick = ISCharacterCreationMain.onTraitClick

    if not original_onProfessionClick then
        print("[ParkRangerFix] AVISO: onProfessionClick não encontrado em ISCharacterCreationMain.")
        return
    end

    if not original_onTraitClick then
        print("[ParkRangerFix] AVISO: onTraitClick não encontrado em ISCharacterCreationMain.")
        return
    end

    -- Aplica os hooks
    ISCharacterCreationMain.onProfessionClick = hooked_onProfessionClick
    ISCharacterCreationMain.onTraitClick = hooked_onTraitClick

    print("[ParkRangerFix] Hooks instalados com sucesso. Exploit do Park Ranger/Herbalist bloqueado.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Limpa o histórico quando uma nova sessão de criação de personagem inicia
-- (chamado ao abrir o menu principal / iniciar novo jogo)
-- ─────────────────────────────────────────────────────────────────────────────
local function resetTrackingOnNewSession()
    ParkRangerFix.removedFreeTraits = {}
end

-- Registra os eventos
Events.OnGameBoot.Add(function()
    installHooks()
end)

-- Limpa o estado ao voltar ao menu principal (nova sessão de criação)
Events.OnMainScreenRefresh.Add(function()
    resetTrackingOnNewSession()
end)

return ParkRangerFix
