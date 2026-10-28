--[[
    Paravel's Enhanced Tooltips - plain items

    The kind of the items no kind of their own names: the game gives them the
    category "Item". They say nothing of their own beyond what every item
    does, but for the drainable ones (lighters, batteries, candles...), which
    say how much is left and weigh by their equipped state too; and for the
    animals carried as items, which say what animal they are, its sex, age,
    looks and health, by the player's knowledge of animals.
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local Format = PET.Format
local Questions = PET.Questions

local Plain = PET.Plain or {}
PET.Plain = Plain

local function isDrainable(item)
    return instanceof(item, "DrainableComboItem")
end

local function isAnimal(item)
    return instanceof(item, "AnimalInventoryItem")
end

-- What the animal's lines ask of the game. (The game's cheat for animals,
-- from its debug menu, lists more of them: that is not rebuilt, and Lua
-- cannot tell whether it is on.)
local function animalRefusal(item)
    if Perks == nil or Perks.Husbandry == nil then return "Husbandry" end
    local animal = Questions.ask(item, "getAnimal")
    if animal == Questions.UNKNOWN or animal == nil then return "getAnimal (not askable)" end
    return Questions.firstRefusal(animal, { "getAnimalType", "isFemale" })
        or Questions.refusalIfMissing(animal, "getAgeText")
        or Questions.refusalIfMissing(animal, "getAppearanceText")
        or Questions.refusalIfMissing(animal, "getHealthText")
end

local function refusal(item)
    if isAnimal(item) then return "AnimalInventoryItem" end
    if isDrainable(item) then return Questions.askRefusal(item, "getCurrentUsesFloat") end
    return nil
end

local function animalRows(item, context)
    local animal, player = item:getAnimal(), context.player
    local husbandry = player:getPerkLevel(Perks.Husbandry)
    return {
        { label = Format.label("IGUI_AnimalType"), value = getText("IGUI_AnimalType_" .. animal:getAnimalType()) },
        { label = Format.label("UI_characreation_gender"), value = getText(animal:isFemale() and "IGUI_Animal_Female" or "IGUI_Animal_Male") },
        { label = Format.label("IGUI_char_Age"), value = animal:getAgeText(false, husbandry) },
        { label = Format.label("IGUI_Animal_Appearance"), value = animal:getAppearanceText(false) },
        { label = Format.label("IGUI_XP_Health"), value = animal:getHealthText(false, husbandry) },
    }
end

-- How much is left, in the game's bar from empty (bad) to full (good).
local function remainingRows(item)
    if not isDrainable(item) or item:hasTag(ItemTag.HIDE_REMAINING) then return {} end
    return { { label = getText("IGUI_invpanel_Remaining") .. ": ", progress = item:getCurrentUsesFloat(), scale = "up" } }
end

Common.addKind({
    category = "Item",
    equippedWeight = isDrainable,
    refusal = refusal,
    leadRows = remainingRows,
    rows = function() return {} end,
})

-- Animals carried as items have a category of their own.
Common.addKind({
    category = "Animal",
    weightOf = function(item) return item:getWeight() end,
    refusal = animalRefusal,
    rows = animalRows,
})
