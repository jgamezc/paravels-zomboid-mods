--[[
    Paravel's Enhanced Tooltips - books and magazines

    What reading material says on top of what every item does: what reading
    it changes (boredom, stress, unhappiness) until the player has read it,
    its pages and how many were read, the skill it trains, the recipes it
    teaches and whether the player knows them already, and that it was read
    recently.
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local ItemLines = PET.ItemLines
local Format = PET.Format
local Questions = PET.Questions

local Literature = PET.Literature or {}
PET.Literature = Literature

local QUESTIONS = {
    "getLearnedRecipes", "getBoredomChange", "getStressChange",
    "getUnhappyChange", "getNumberOfPages", "getLvlSkillTrained",
    "getMaxLevelTrained", "getModData",
}

local function refusal(item, player)
    if player == nil then return "player" end
    local reason = Questions.firstRefusal(item, QUESTIONS)
    if reason then return reason end
    return Questions.refusalIfMissing(player, "isLiteratureRead")
        or Questions.refusalIfMissing(player, "getAlreadyReadPages")
        or Questions.refusalIfMissing(player, "getKnownRecipes")
        or Questions.refusalIfMissing(player, "getCharacterTraits")
        or Questions.refusalIfMissing(player, "getDescriptor")
        or (Translator.getRecipeName == nil and "getRecipeName (not askable)" or nil)
        or (CharacterProfessionDefinition == nil and "CharacterProfessionDefinition" or nil)
        or (CharacterTraitDefinition == nil and "CharacterTraitDefinition" or nil)
end

-- Whether the player's profession or any of the traits they know gave them
-- the recipe already.
local function grantedByCharacter(player, recipe)
    local profession = CharacterProfessionDefinition.getCharacterProfessionDefinition(player:getDescriptor():getCharacterProfession())
    if profession:isGrantedRecipe(recipe) then return true end
    local known = player:getCharacterTraits():getKnownTraits()
    for index = 0, known:size() - 1 do
        local trait = CharacterTraitDefinition.getCharacterTraitDefinition(known:get(index))
        if trait ~= nil and trait:isGrantedRecipe(recipe) then return true end
    end
    return false
end

-- The recipes a book teaches: each by name, whether the player has read
-- them all, and whether they knew any already from their start.
local function recipeRows(item, player, recipes, illiterate)
    local rows = {}
    local function teaches(recipe)
        return getText("Tooltip_Literature_LearnedRecipes", recipe)
    end
    if illiterate then
        table.insert(rows, { label = teaches(getText("ContextMenu_Illiterate")) })
        return rows
    end
    local allKnown = true
    for _, recipe in ipairs(recipes) do
        table.insert(rows, { label = teaches(Translator.getRecipeName(recipe)) })
        if not player:getKnownRecipes():contains(recipe) then allKnown = false end
    end
    table.insert(rows, { label = getText(allKnown and "Tooltip_literature_HasBeenRead" or "Tooltip_literature_NotBeenRead") })
    if allKnown then
        for _, recipe in ipairs(recipes) do
            if grantedByCharacter(player, recipe) then
                table.insert(rows, { label = getText("Tooltip_literature_AlreadyKnown"), meaning = "good" })
                break
            end
        end
    end
    return rows
end

local function change(key, amount, isGood)
    return { label = Format.label(key), labelMeaning = isGood and "good" or "bad", progress = math.abs(amount) }
end

-- What reading it changes, while the player has not read it.
local function changeRows(item)
    local rows = {}
    local boredom = item:getBoredomChange() * -0.02
    if item:getBoredomChange() ~= 0 then table.insert(rows, change("Tooltip_food_Boredom", boredom, boredom > 0)) end
    if item:getStressChange() ~= 0 then
        -- The game cuts the change to whole hundredths before scaling it.
        local hundredths = item:getStressChange() * 100
        local stress = (hundredths >= 0 and math.floor(hundredths) or -math.floor(-hundredths)) * -0.02
        table.insert(rows, change("Tooltip_literature_Stress_Reduction", stress, stress > 0))
    end
    local unhappy = item:getUnhappyChange() * -0.02
    if item:getUnhappyChange() ~= 0 then table.insert(rows, change("Tooltip_food_Unhappiness", unhappy, unhappy > 0)) end
    return rows
end

local function skillRows(item)
    if item:getLvlSkillTrained() == -1 then return {} end
    local levels = tostring(item:getLvlSkillTrained())
    if item:getLvlSkillTrained() ~= item:getMaxLevelTrained() then levels = levels .. "-" .. item:getMaxLevelTrained() end
    return { { label = getText("Tooltip_Literature_XpMultiplier", levels) } }
end

local function rows(item, context)
    local all = {}
    local player = context.player
    local title = item:getModData().literatureTitle
    local read = title ~= nil and player:isLiteratureRead(title)
    if not read then ItemLines.append(all, changeRows(item)) end
    if item:getNumberOfPages() ~= -1 then
        ItemLines.append(all, { {
            label = Format.label("Tooltip_literature_Number_of_Pages"),
            value = player:getAlreadyReadPages(item:getFullType()) .. " / " .. item:getNumberOfPages(),
        } })
    end
    ItemLines.append(all, skillRows(item))
    local illiterate = player:hasTrait(CharacterTrait.ILLITERATE)
    local learned = item:getLearnedRecipes()
    if learned ~= nil then
        local recipes = {}
        for index = 0, learned:size() - 1 do table.insert(recipes, learned:get(index)) end
        ItemLines.append(all, recipeRows(item, player, recipes, illiterate))
    end
    local single = item:getModData().learnedRecipe
    if single ~= nil then ItemLines.append(all, recipeRows(item, player, { single }, illiterate)) end
    if read then
        local key = item:hasTag(ItemTag.PICTURE) and "ContextMenu_RecentlySeen" or "ContextMenu_RecentlyRead"
        ItemLines.append(all, { { label = getText(key) } })
    end
    return all
end

Common.addKind({ category = "Literature", refusal = refusal, rows = rows })
