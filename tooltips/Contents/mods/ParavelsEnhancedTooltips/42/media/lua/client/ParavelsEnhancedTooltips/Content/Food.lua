--[[
    Paravel's Enhanced Tooltips - food

    What food says on top of what every item does: what eating it changes
    (hunger, thirst, endurance, stress, boredom, unhappiness), how far it is
    cooking, burning or frozen, its nutrition when the player can read it,
    tainted water, fertilized eggs and a few warnings and notes. (The spices
    on food are written with what every item contains: ItemLines.lua.)
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local Fluids = PET.Fluids
local ItemLines = PET.ItemLines
local Format = PET.Format
local Questions = PET.Questions

local Food = PET.Food or {}
PET.Food = Food

-- What the rows read from the food, which must be askable, and what makes
-- the food one this kind does not rebuild.
local QUESTIONS = {
    "isTainted", "isFertilized", "getFertilizedTime", "getTimeToHatch",
    "hasMetal",
    "getHungerChange", "getThirstChange", "getEnduranceChange",
    "getStressChange", "getBoredomChange", "getUnhappyChange",
    "isIsCookable", "isFrozen", "isBurnt", "isCooked",
    "getHeat", "getCookingTime", "getMinutesToCook", "getMinutesToBurn",
    "getFreezingTime", "isPackaged", "isbDangerousUncooked",
    "isGoodHot", "isBadCold", "isCookedInMicrowave", "getMilkType",
    "getCalories", "getCarbohydrates", "getProteins", "getLipids",
    "getModData",
}

-- The script's flag that cooking removes a food's unhappiness is a field
-- Lua cannot read. These are the foods that have it in the game's scripts
-- (Build 42.21; they are raw vegetables, fish and small animals): a food
-- of a later version or of a mod that has it and is not here will miss the
-- line that says so.
local COOKING_REMOVES_UNHAPPINESS = {
    "Base.Acorn", "Base.AligatorGar", "Base.BaitFish", "Base.BlackCrappie", "Base.BlueCatfish", "Base.Bluegill",
    "Base.BrusselSprouts", "Base.ChannelCatfish", "Base.DeadBird", "Base.DeadRabbit", "Base.DeadSquirrel",
    "Base.Eggplant", "Base.FlatheadCatfish", "Base.FreshwaterDrum", "Base.GreenSunfish", "Base.HalloweenPumpkin",
    "Base.LargemouthBass", "Base.Leek", "Base.Muskellunge", "Base.OpenBeans", "Base.Paddlefish", "Base.Potato",
    "Base.Pumpkin", "Base.PumpkinSeed", "Base.PumpkinSmashed", "Base.RedearSunfish", "Base.Sauger",
    "Base.SmallmouthBass", "Base.SpottedBass", "Base.Squash", "Base.StripedBass", "Base.SweetPotato",
    "Base.Walleye", "Base.WhiteBass", "Base.WhiteCrappie", "Base.YellowPerch",
}
local removesUnhappiness = {}
for _, fullType in ipairs(COOKING_REMOVES_UNHAPPINESS) do removesUnhappiness[fullType] = true end

local function cookingRemovesUnhappiness(item)
    local script = item:getScriptItem()
    if script ~= nil and script.removeUnhappinessWhenCooked ~= nil then return script.removeUnhappinessWhenCooked end
    return removesUnhappiness[item:getFullType()] == true
end

local function refusal(item, player)
    if CharacterTrait == nil or CharacterTrait.NUTRITIONIST == nil or Perks == nil then return "CharacterTrait" end
    if player == nil then return "player" end
    return Questions.firstRefusal(item, QUESTIONS)
end

-- Tainted water, when the game's rules say so, in plastic or metal.
local function leadRows(item)
    if not item:isTainted() or not Fluids.separatesTaintedWater() then return {} end
    local key = item:hasMetal() and "Tooltip_item_TaintedWater" or "Tooltip_item_TaintedWater_Plastic"
    return { { label = getText(key), meaning = "bad" } }
end

-- A fertilized egg: how long to hatch in the game's debug mode, and that it
-- is fertilized when it is close to hatching.
local function fertilizedRows(item)
    if not item:isFertilized() then return {} end
    if Questions.isOn(getCore(), "getDebug") then
        -- The game writes this debug label in English only.
        return { { label = "Fertilized :", value = item:getFertilizedTime() .. "/" .. item:getTimeToHatch() } }
    end
    if item:getTimeToHatch() / item:getFertilizedTime() < 4 then
        return { { label = getText("Tooltip_food_fertilized"), meaning = "good" } }
    end
    return {}
end

-- A change as a bar: how much, with the label in the colour of whether it is good.
local function changeBar(key, amount, isGood)
    return { label = Format.label(key), labelMeaning = isGood and "good" or "bad", progress = math.abs(amount) }
end

-- The whole number of hundredths the game shows for a change, cut toward zero.
local function wholePercent(change)
    local percent = change * 100
    return percent >= 0 and math.floor(percent) or -math.floor(-percent)
end

local function changeRows(item)
    local rows = {}
    local hunger = item:getHungerChange()
    if hunger ~= 0 and not item:hasTag(ItemTag.HIDE_HUNGER_CHANGE) then
        local percent = wholePercent(hunger)
        table.insert(rows, { label = Format.label("Tooltip_food_Hunger"), value = Format.signed(percent), meaning = percent > 0 and "bad" or "good" })
    end
    local thirst = item:getThirstChange() * -2
    if item:getThirstChange() ~= 0 then table.insert(rows, changeBar("Tooltip_food_Thirst", thirst, thirst > 0)) end
    local endurance = item:getEnduranceChange()
    if endurance ~= 0 then
        local percent = wholePercent(endurance)
        table.insert(rows, changeBar("Tooltip_food_Endurance", percent / 10, percent > 0))
    end
    local stress = item:getStressChange()
    if stress ~= 0 then table.insert(rows, changeBar("Tooltip_food_Stress", stress * 2, stress < 0)) end
    local boredom = item:getBoredomChange() * -0.02
    if item:getBoredomChange() ~= 0 then table.insert(rows, changeBar("Tooltip_food_Boredom", boredom, boredom > 0)) end
    local unhappy = item:getUnhappyChange() * -0.02
    if item:getUnhappyChange() ~= 0 then table.insert(rows, changeBar("Tooltip_food_Unhappiness", unhappy, unhappy > 0)) end
    return rows
end

-- How far it is cooking, or burning once cooked.
local function cookingRows(item)
    if not item:isIsCookable() or item:isFrozen() or item:isBurnt() or item:getHeat() <= 1.6 then return {} end
    local cooking, toCook = item:getCookingTime(), item:getMinutesToCook()
    if cooking > toCook then
        local progress = (cooking - toCook) / (item:getMinutesToBurn() - toCook)
        return { { label = getText("IGUI_invpanel_Burning") .. ": ", labelMeaning = "bad", progress = progress } }
    end
    return { { label = getText("IGUI_invpanel_Cooking") .. ": ", labelMeaning = "good", progress = cooking / toCook } }
end

local function freezingRows(item)
    local freezing = item:getFreezingTime()
    if freezing >= 100 or freezing <= 0 then return {} end
    return { { label = getText("IGUI_invpanel_FreezingTime") .. ": ", progress = freezing / 100 } }
end

-- The nutrition, or why it is not shown: the package of food can be read
-- by a player who can read and has light, and the nutritionists know it
-- without.
local function nutritionRows(item, player)
    local illiterate = player:hasTrait(CharacterTrait.ILLITERATE)
    local tooDark = player:tooDarkToRead()
    local unlabelled = item:getModData().NoLabel ~= nil
    local canReadPackage = item:isPackaged() and not illiterate and not tooDark and not unlabelled
    local knowsNutrition = player:hasTrait(CharacterTrait.NUTRITIONIST) or player:hasTrait(CharacterTrait.NUTRITIONIST2)
    local nutrition = { label = Format.label("Tooltip_food_Nutrition") }
    if canReadPackage or knowsNutrition then
        return {
            nutrition,
            { label = Format.label("Tooltip_food_Calories"), value = Format.number(item:getCalories()) },
            { label = Format.label("Tooltip_food_Carbs"), value = Format.number(item:getCarbohydrates()) },
            { label = Format.label("Tooltip_food_Prots"), value = Format.number(item:getProteins()) },
            { label = Format.label("Tooltip_food_Fat"), value = Format.number(item:getLipids()) },
        }
    end
    if item:isPackaged() and illiterate then return { nutrition, { label = getText("ContextMenu_Illiterate") } } end
    if item:isPackaged() and tooDark then return { nutrition, { label = getText("ContextMenu_TooDark") } } end
    return {}
end

local function warningRows(item)
    local rows = {}
    if item:isbDangerousUncooked() and not item:isCooked() and not item:isBurnt() then
        local key = item:hasTag(ItemTag.EGG) and "Tooltip_food_SlightDanger_uncooked" or "Tooltip_food_Dangerous_uncooked"
        table.insert(rows, { label = getText(key), meaning = "bad" })
    end
    if cookingRemovesUnhappiness(item) and not item:isCooked() and not item:isBurnt() then
        table.insert(rows, { label = getText("Tooltip_food_CookToRemoveUnhappiness"), meaning = "bad" })
    end
    return rows
end

local function noteRows(item)
    local rows = {}
    if (item:isGoodHot() or item:isBadCold()) and item:getHeat() < 1.3 then
        table.insert(rows, { label = getText("Tooltip_food_BetterHot") })
    end
    if item:isCookedInMicrowave() then table.insert(rows, { label = getText("Tooltip_food_CookedInMicrowave") }) end
    local milk = item:getMilkType()
    if milk ~= nil and milk ~= "" then
        table.insert(rows, { label = Format.label("Tooltip_food_MilkType") .. " ", value = getText("Tooltip_food_" .. milk) })
    end
    return rows
end

local function rows(item, context)
    local all = {}
    ItemLines.append(all, changeRows(item))
    ItemLines.append(all, cookingRows(item))
    ItemLines.append(all, freezingRows(item))
    ItemLines.append(all, fertilizedRows(item))
    if item:isIsCookable() and context.player:getPerkLevel(Perks.Cooking) > 4 then
        ItemLines.append(all, { { label = Format.label("Tooltip_food_MinutesToCook"), value = Format.number(item:getMinutesToCook()) } })
    end
    ItemLines.append(all, nutritionRows(item, context.player))
    ItemLines.append(all, warningRows(item))
    ItemLines.append(all, noteRows(item))
    return all
end

Common.addKind({ category = "Food", refusal = refusal, leadRows = leadRows, rows = rows })
