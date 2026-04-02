-- client/ParkRangerFix/ParkRangerFix.lua
-- Bloqueia o exploit do Park Ranger / Herbalist na tela de criação de personagem.
-- Depende de ParkRangerFixUtils (common/Utils.lua).

local ParkRangerFix = {}

-- Rastreia, por profissão, quais traits gratuitos foram removidos manualmente
-- durante esta sessão de criação. { ["parkranger"] = { ["Herbalist"] = true } }
ParkRangerFix.removedFreeTraits = {}

local original_onProfessionClick = nil
local original_onTraitClick      = nil

-- ─────────────────────────────────────────────────────────────────────────────
-- Hook: onTraitClick
-- Quando o jogador remove um trait gratuito, registra para a profissão atual.
-- ─────────────────────────────────────────────────────────────────────────────
local function hooked_onTraitClick(self, trait, ...)
    local traitName
    if     type(trait) == "string" then traitName = trait
    elseif trait and trait.getType then traitName = trait:getType()
    elseif trait and trait.getName then traitName = trait:getName()
    end

    if traitName then
        local descriptor = self.character and self.character:getDescriptor and self.character:getDescriptor()
        local profType   = descriptor and descriptor.getProfession and descriptor:getProfession()

        if profType and ParkRangerFixUtils.isFreeTrait(traitName, profType) then
            if descriptor:hasTrait(traitName) then
                -- Trait gratuito está ativo e vai ser removido → memoriza
                if not ParkRangerFix.removedFreeTraits[profType] then
                    ParkRangerFix.removedFreeTraits[profType] = {}
                end
                ParkRangerFix.removedFreeTraits[profType][traitName] = true
            end
        end
    end

    original_onTraitClick(self, trait, ...)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Hook: onProfessionClick
-- Após trocar de profissão, re-remove os traits gratuitos que o jogador já
-- havia removido antes nessa mesma profissão, sem devolver os pontos.
-- ─────────────────────────────────────────────────────────────────────────────
local function hooked_onProfessionClick(self, button, ...)
    original_onProfessionClick(self, button, ...)

    local descriptor = self.character and self.character:getDescriptor and self.character:getDescriptor()
    local profType   = descriptor and descriptor.getProfession and descriptor:getProfession()
    if not profType then return end

    local alreadyRemoved = ParkRangerFix.removedFreeTraits[profType]
    if not alreadyRemoved then return end

    local needsRefresh = false
    for traitName in pairs(alreadyRemoved) do
        if descriptor:hasTrait(traitName) then
            local traitObj = TraitFactory.getTrait(traitName)
            if traitObj then
                local cost = traitObj:getCost()
                descriptor:removeTrait(traitName)
                -- Cancela a devolução de pontos que a engine faria
                self.points = (self.points or 0) - cost
            end
            needsRefresh = true
        end
    end

    if needsRefresh then
        if self.updatePoints  then self:updatePoints()  end
        if self.refreshTraits then self:refreshTraits()
        elseif self.updateTraits then self:updateTraits() end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Instalação dos hooks
-- ─────────────────────────────────────────────────────────────────────────────
local function installHooks()
    if not ISCharacterCreationMain then
        print("[ParkRangerFix] AVISO: ISCharacterCreationMain não encontrado.")
        return
    end

    original_onProfessionClick = ISCharacterCreationMain.onProfessionClick
    original_onTraitClick      = ISCharacterCreationMain.onTraitClick

    if not original_onProfessionClick or not original_onTraitClick then
        print("[ParkRangerFix] AVISO: métodos de hook não encontrados.")
        return
    end

    ISCharacterCreationMain.onProfessionClick = hooked_onProfessionClick
    ISCharacterCreationMain.onTraitClick      = hooked_onTraitClick

    print("[ParkRangerFix] Client-side ativo. Exploit do Park Ranger bloqueado.")
end

Events.OnGameBoot.Add(installHooks)

-- Limpa o histórico ao voltar ao menu (nova sessão de criação)
Events.OnMainScreenRefresh.Add(function()
    ParkRangerFix.removedFreeTraits = {}
end)

return ParkRangerFix
