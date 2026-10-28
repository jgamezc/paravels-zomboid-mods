--[[
    Paravel's Enhanced Tooltips - the lines any item can have

    The game's tooltip of an item has, besides its weight, condition and note
    (Common.lua), many lines that appear only when something is the case for
    that item: recipes it can teach, ammunition, what it was repaired,
    whether it is wet, capacity, modifiers of vision and hearing, what it
    contains... This file writes them, in groups in the game's order; Common
    puts each group where the game does.

    Every group has `refusal(item, context)`, answering what in the item
    Lua cannot ask (so that the item keeps the game's tooltip) or nil, and
    `rows(item, context)`.
]]

require "ParavelsEnhancedTooltips/Content/Format"
require "ParavelsEnhancedTooltips/Content/Questions"

local Format = PET.Format
local Questions = PET.Questions

local ItemLines = PET.ItemLines or {}
PET.ItemLines = ItemLines

local function hasTag(item, tagName)
    return ItemTag[tagName] ~= nil and item:hasTag(ItemTag[tagName])
end
ItemLines.hasTag = hasTag

-- Adds the rows of `more` to the end of `rows`.
function ItemLines.append(rows, more)
    for _, row in ipairs(more) do table.insert(rows, row) end
end

local function isHandWeapon(item)
    return instanceof(item, "HandWeapon")
end

local function textOfItem(fullType)
    return getText(instanceItem(fullType):getDisplayName())
end

-- ------------------------------------------------------------------ --
-- What it contains: icons of the items made into it, and of its spices
-- ------------------------------------------------------------------ --

local Contents = {}
ItemLines.contents = Contents

-- Food of one of the kinds can be cooked already; so is what is in it.
local function isCookable(item)
    return item.isIsCookable ~= nil and item:isIsCookable()
end

local function extraItemIcons(item)
    local icons = {}
    local extras = item:getExtraItems()
    for index = 0, extras:size() - 1 do
        local made = instanceItem(extras:get(index))
        if (not isCookable(item) and isCookable(made)) or (item:isCooked() and isCookable(made)) then made:setCooked(true) end
        table.insert(icons, made:getTex())
    end
    return icons
end

local function spiceIcons(item)
    local icons = {}
    local spices = item:getSpices()
    for index = 0, spices:size() - 1 do
        table.insert(icons, instanceItem(spices:get(index)):getTex())
    end
    return icons
end

function Contents.refusal(item)
    local reason = Questions.askRefusal(item, "getExtraItems")
    if reason then return reason end
    local extras = item:getExtraItems()
    if extras ~= nil and not extras:isEmpty() then
        reason = Questions.askRefusal(extras, "size") or Questions.refusalIfMissing(extras, "get")
        if reason then return reason end
        if item.isCooked == nil then return "isCooked (not askable)" end
    end
    if instanceof(item, "Food") and item.getSpices == nil then return "getSpices (not askable)" end
    return nil
end

function Contents.rows(item)
    local rows = {}
    local extras = item:getExtraItems()
    if extras ~= nil and not extras:isEmpty() then
        table.insert(rows, { label = getText("Tooltip_item_Contains"), icons = extraItemIcons(item) })
    end
    if instanceof(item, "Food") and item:hasSpices() then
        table.insert(rows, { label = getText("Tooltip_item_Spices"), icons = spiceIcons(item) })
    end
    return rows
end

-- ------------------------------------------------------------------ --
-- What the player knows to do with it (recipes)
-- ------------------------------------------------------------------ --

local Recipes = {}
ItemLines.recipes = Recipes

function Recipes.refusal(item, context)
    local reason = Questions.firstRefusal(item, { "isNoRecipes", "isUnwanted" }, context.player)
    if reason then return reason end
    local script = item:getScriptItem()
    if script == nil then return nil end
    return Questions.askRefusal(script, "getResearchableRecipes", context.player)
        or Questions.askRefusal(script, "isFavouriteRecipeInput", context.player)
end

function Recipes.rows(item, context)
    local rows, player = {}, context.player
    local script = item:getScriptItem()
    if script ~= nil then
        local researchable = script:getResearchableRecipes(player):size()
        if researchable > 0 then
            table.insert(rows, { label = getText(researchable == 1 and "Tooltip_item_CanResearch" or "Tooltip_item_CanResearchPlural"), meaning = "good" })
        end
        if script:isFavouriteRecipeInput(player) then
            table.insert(rows, { label = getText("Tooltip_item_IsFavouriteInput"), meaning = "good" })
        end
    end
    if item:isNoRecipes(player) then table.insert(rows, { label = getText("Tooltip_NoRecipes_More"), meaning = "bad" }) end
    if item:isUnwanted(player) then table.insert(rows, { label = getText("Tooltip_Unwanted_More"), meaning = "bad" }) end
    return rows
end

-- ------------------------------------------------------------------ --
-- Ammunition of what is not a weapon (magazines, boxes of bullets)
-- ------------------------------------------------------------------ --

local Ammo = {}
ItemLines.ammo = Ammo

function Ammo.refusal(item)
    if isHandWeapon(item) then return nil end
    return Questions.firstRefusal(item, {
        "getMaxAmmo", "getCurrentAmmoCount", "getAmmoType", "getGunType",
        "getGunTypeString",
    })
end

function Ammo.rows(item)
    local rows = {}
    if isHandWeapon(item) then return rows end
    if item:getMaxAmmo() > 0 then
        table.insert(rows, {
            label = Format.label("Tooltip_weapon_AmmoCount"),
            value = item:getCurrentAmmoCount() .. " / " .. item:getMaxAmmo(),
        })
    end
    if item:getAmmoType() ~= nil then
        table.insert(rows, {
            label = Format.label("ContextMenu_AmmoType"),
            value = textOfItem(item:getAmmoType():getItemKey()),
        })
    end
    if item:getGunType() ~= nil then
        table.insert(rows, { label = Format.label("ContextMenu_GunType"), value = item:getGunTypeString() })
    end
    return rows
end

-- ------------------------------------------------------------------ --
-- How tiring it is to have
-- ------------------------------------------------------------------ --

local Fatigue = {}
ItemLines.fatigue = Fatigue

function Fatigue.refusal(item)
    return Questions.askRefusal(item, "getFatigueChange")
end

function Fatigue.rows(item)
    local change = item:getFatigueChange()
    if change == 0 then return {} end
    return { {
        label = getText("Tooltip_item_Fatigue") .. ": ",
        labelMeaning = change < 0 and "good" or "bad",
        progress = math.abs(change),
    } }
end

-- ------------------------------------------------------------------ --
-- Its upkeep and state: repairs, rain, capacity
-- ------------------------------------------------------------------ --

local Upkeep = {}
ItemLines.upkeep = Upkeep

local UPKEEP_QUESTIONS = {
    "getRemoteControlID", "getHaveBeenRepaired", "hasTimesHeadRepaired",
    "getTimesHeadRepaired", "isEquippedNoSprint", "isWet",
    "getWetCooldown", "getMaxCapacity", "isConditionAffectsCapacity",
    "getItemCapacity",
}

-- How much the capacity falls with the item's condition is the game's own
-- calculation for vehicle parts.
local function capacityByCondition(item)
    return VehiclePart.getNumberByCondition(item:getMaxCapacity(), item:getCondition(), 5)
end

function Upkeep.refusal(item)
    local reason = Questions.firstRefusal(item, UPKEEP_QUESTIONS)
    if reason then return reason end
    if item:getMaxCapacity() > 0 and item:isConditionAffectsCapacity()
        and (VehiclePart == nil or VehiclePart.getNumberByCondition == nil) then
        return "getNumberByCondition (not askable)"
    end
    return nil
end

local function repairRows(item)
    local rows = {}
    if item:getHaveBeenRepaired() > 0 then
        local key = item:hasTimesHeadRepaired() and "Tooltip_handle_Repaired" or "Tooltip_weapon_Repaired"
        table.insert(rows, { label = Format.label(key), value = item:getHaveBeenRepaired() .. "x" })
    end
    if item:hasTimesHeadRepaired() and item:getTimesHeadRepaired() > 0 then
        table.insert(rows, { label = Format.label("Tooltip_head_Repaired"), value = item:getTimesHeadRepaired() .. "x" })
    end
    return rows
end

local function capacityRows(item)
    if item:getMaxCapacity() <= 0 then return {} end
    local held = item:getItemCapacity() > -1 and item:getItemCapacity() or 0
    local capacity = item:isConditionAffectsCapacity() and capacityByCondition(item) or item:getMaxCapacity()
    return { {
        label = Format.label("Tooltip_container_Capacity"),
        value = Format.javaFloat(held) .. " / " .. Format.javaFloat(capacity),
    } }
end

function Upkeep.rows(item)
    local rows = {}
    local append = ItemLines.append
    if item:getRemoteControlID() ~= -1 then
        table.insert(rows, { label = getText("Tooltip_TrapControllerID"), value = tostring(item:getRemoteControlID()) })
    end
    append(rows, repairRows(item))
    if item:isEquippedNoSprint() then table.insert(rows, { label = getText("Tooltip_CantSprintEquipped"), meaning = "bad" }) end
    if item:isWet() then
        table.insert(rows, { label = getText("Tooltip_Wetness") .. ": ", progress = item:getWetCooldown() / 10000, scale = "down" })
    end
    append(rows, capacityRows(item))
    return rows
end

-- ------------------------------------------------------------------ --
-- What it is for reading and navigating
-- ------------------------------------------------------------------ --

local Reading = {}
ItemLines.reading = Reading

-- The compass line for each way the player's container faces.
local COMPASS_KEYS = {
    N = "Tooltip_compass_9", NW = "Tooltip_compass_8", W = "Tooltip_compass_7", SW = "Tooltip_compass_4",
    S = "Tooltip_compass_1", SE = "Tooltip_compass_2", E = "Tooltip_compass_3", NE = "Tooltip_compass_6",
}

local function compassRefusal(item)
    if not hasTag(item, "COMPASS") then return nil end
    if IsoDirections == nil then return "IsoDirections" end
    return Questions.firstRefusal(item, { "isInPlayerInventory", "getOutermostContainer" })
end

function Reading.refusal(item, context)
    local reason = Questions.refusalIfMissing(context.player, "hasReadMap") or compassRefusal(item)
    if reason then return reason end
    if item:isRecordedMedia() then
        reason = Questions.firstRefusal(item, { "getMediaData" })
            or Questions.firstRefusal(item, { "hasBeenSeen", "hasBeenHeard" }, context.player)
        if reason then return reason end
        local data = item:getMediaData()
        if data ~= nil then
            reason = Questions.firstRefusal(data, { "getTranslatedTitle", "getTranslatedSubTitle", "getTranslatedAuthor" })
            if reason then return reason end
        end
    end
    return nil
end

-- The line of the compass, by the way the thing carrying it faces: the
-- container it is in, and the object it hangs from or lies in.
local function compassRows(item)
    if not hasTag(item, "COMPASS") or not item:isInPlayerInventory() then return {} end
    local owner = item:getOutermostContainer():getParent()
    local key = owner ~= nil and COMPASS_KEYS[tostring(owner:getDir())]
    if not key then return {} end
    return { { label = getText(key) } }
end

local function mediaRows(item, player)
    local rows = {}
    local data = item:getMediaData()
    if data ~= nil then
        if data:getTranslatedTitle() ~= nil then
            table.insert(rows, { label = Format.label("Tooltip_media_title"), value = data:getTranslatedTitle() })
            if data:getTranslatedSubTitle() ~= nil then table.insert(rows, { label = "", value = data:getTranslatedSubTitle() }) end
        end
        if data:getTranslatedAuthor() ~= nil then
            table.insert(rows, { label = Format.label("Tooltip_media_author"), value = data:getTranslatedAuthor() })
        end
    end
    if item:hasBeenSeen(player) then table.insert(rows, { label = getText("ContextMenu_Watched") }) end
    if item:hasBeenHeard(player) then table.insert(rows, { label = getText("ContextMenu_Heard") }) end
    return rows
end

function Reading.rows(item, context)
    local rows, player = {}, context.player
    if player:hasReadMap(item) then table.insert(rows, { label = getText("Tooltip_literature_HasBeenRead") }) end
    if item:isRecordedMedia() then ItemLines.append(rows, mediaRows(item, player)) end
    ItemLines.append(rows, compassRows(item))
    return rows
end

-- ------------------------------------------------------------------ --
-- How it changes seeing, hearing and comfort
-- ------------------------------------------------------------------ --

local Modifiers = {}
ItemLines.modifiers = Modifiers

function Modifiers.refusal(item)
    return Questions.firstRefusal(item, { "getVisionModifier", "getHearingModifier", "getDiscomfortModifier" })
end

-- A modifier as a bar of how far it is from 1 (or from 0): the label is good
-- when it helps, bad when it hinders.
local function modifierBar(key, amount, helps)
    return { label = getText(key) .. ": ", labelMeaning = helps and "good" or "bad", progress = math.abs(amount) }
end

function Modifiers.rows(item)
    local rows = {}
    local vision, hearing, discomfort = item:getVisionModifier(), item:getHearingModifier(), item:getDiscomfortModifier()
    if vision ~= 1 then table.insert(rows, modifierBar("Tooltip_item_VisionImpariment", vision - 1, vision > 1)) end
    if hearing ~= 1 then table.insert(rows, modifierBar("Tooltip_item_HearingImpariment", hearing - 1, hearing > 1)) end
    if discomfort ~= 0 then table.insert(rows, modifierBar("Tooltip_item_Discomfort", discomfort, discomfort < 0)) end
    return rows
end

-- ------------------------------------------------------------------ --
-- The battery of a part or an item that runs on one
-- ------------------------------------------------------------------ --

local Battery = {}
ItemLines.battery = Battery

function Battery.refusal(part)
    return Questions.firstRefusal(part, { "getPartType", "getName", "getCurrentUsesFloat" })
end

-- The "Remaining" bar of a part that runs on a battery.
function Battery.rows(part)
    if ItemTag.USES_BATTERY == nil or not part:hasTag(ItemTag.USES_BATTERY) or part:hasTag(ItemTag.HIDE_REMAINING) then
        return {}
    end
    return { { label = getText("IGUI_invpanel_Remaining") .. ": ", progress = part:getCurrentUsesFloat(), scale = "up" } }
end
