--[[
    Paravel's Enhanced Tooltips - clothing

    What clothing says on top of what every item does: its condition,
    insulation and resistances, how bloody, dirty and wet it is, its holes,
    what it protects from (compared with what the player wears there when it
    is not worn yet), what filter or tank a mask or breathing apparatus holds
    and how it slows the player.
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local ItemLines = PET.ItemLines
local Format = PET.Format
local Questions = PET.Questions

local Clothing = PET.Clothing or {}
PET.Clothing = Clothing

-- What the rows read from the clothing, which must be askable.
local QUESTIONS = {
    "isCosmetic", "getInsulation", "getWindresistance",
    "getWaterResistance", "getBloodlevel", "getDirtiness",
    "getWetness", "getBiteDefense", "getScratchDefense",
    "getBulletDefense", "getRunSpeedModifier", "getCombatSpeedModifier",
    "getVisual", "getBodyLocation",
}

-- Tags of the clothing that takes a filter or a tank, and the ones that say
-- it has none.
local FILTERED_TAGS = { "GAS_MASK", "RESPIRATOR", "IMPROVISED_GAS_MASK" }
local NO_FILTER_TAGS = { "GAS_MASK_NO_FILTER", "RESPIRATOR_NO_FILTER" }
local BREATHING_QUESTIONS = {
    "hasFilter", "getFilterType", "getUsedDelta", "hasTank",
    "getTankType",
}

local function hasAnyTag(item, names)
    for _, name in ipairs(names) do
        if ItemTag[name] ~= nil and item:hasTag(ItemTag[name]) then return true end
    end
    return false
end

-- What comparing with the worn clothing asks of the game.
local function comparisonRefusal(player)
    local worn = Questions.ask(player, "getWornItems")
    if worn == Questions.UNKNOWN then return "getWornItems (not askable)" end
    return Questions.askRefusal(worn, "size")
        or Questions.refusalIfMissing(worn, "get")
        or Questions.refusalIfMissing(worn, "getBodyLocationGroup")
        or Questions.refusalIfMissing(worn:getBodyLocationGroup(), "isExclusive")
end

local function refusal(item, player)
    if BloodBodyPartType == nil then return "BloodBodyPartType" end
    local reason = Questions.firstRefusal(item, QUESTIONS) or Questions.firstRefusal(item, BREATHING_QUESTIONS)
    if reason then return reason end
    if not item:isEquipped() and player ~= nil then return comparisonRefusal(player) end
    return nil
end

-- A bar of a quality: the more, the better ("up"), or the worse ("down").
local function bar(key, fraction, scale, trailingSpace)
    return { label = getText(key) .. (trailingSpace and ": " or ":"), progress = fraction, scale = scale }
end

local function protectionRows(item)
    local rows = {}
    if item:isCosmetic() then return rows end
    table.insert(rows, bar("Tooltip_weapon_Condition", item:getCondition() / item:getConditionMax(), "up"))
    table.insert(rows, bar("Tooltip_item_Insulation", item:getInsulation(), "up", true))
    if item:getWindresistance() > 0 then
        table.insert(rows, bar("Tooltip_item_Windresist", item:getWindresistance(), "up", true))
    end
    if item:getWaterResistance() > 0 then
        table.insert(rows, bar("Tooltip_item_Waterresist", item:getWaterResistance(), "up", true))
    end
    return rows
end

local function stateRows(item)
    local rows = {}
    if item:getBloodlevel() ~= 0 then
        table.insert(rows, bar("Tooltip_clothing_bloody", item:getBloodlevel() / 100, "down"))
    end
    if item:getDirtiness() >= 1 then
        table.insert(rows, bar("Tooltip_clothing_dirty", item:getDirtiness() / 100, "down"))
    end
    if item:getWetness() ~= 0 then
        table.insert(rows, bar("Tooltip_clothing_wet", item:getWetness() / 100, "down"))
    end
    return rows
end

local function holeRows(item)
    local visual, holes = item:getVisual(), 0
    for index = 0, BloodBodyPartType.MAX:index() - 1 do
        if visual:getHole(BloodBodyPartType.FromIndex(index)) > 0 then holes = holes + 1 end
    end
    if holes == 0 then return {} end
    return { { label = Format.label("Tooltip_clothing_holes"), value = tostring(holes) } }
end

-- The protection of what the player wears where this goes (or in a place
-- that excludes it), as { bite, scratch, bullet }.
local function wornProtection(item, player)
    local worn = player:getWornItems()
    local group = worn:getBodyLocationGroup()
    local location = item:getBodyLocation()
    local bite, scratch, bullet = 0, 0, 0
    for index = 0, worn:size() - 1 do
        local wornItem = worn:get(index)
        local other, otherLocation = wornItem:getItem(), wornItem:getLocation()
        if other:IsClothing() and otherLocation ~= nil
            and (location:equals(otherLocation) or group:isExclusive(location, otherLocation)) then
            bite = bite + other:getBiteDefense()
            scratch = scratch + other:getScratchDefense()
            bullet = bullet + other:getBulletDefense()
        end
    end
    return { bite, scratch, bullet }
end

-- A defense row: its value, and how it compares with what is worn there
-- when the clothing is not worn yet.
local function defenseRow(key, now, before)
    local whole = math.floor(now)
    if before == nil or now == before then
        if now == 0 then return nil end
        return { label = Format.label(key), value = tostring(whole) }
    end
    if now <= 0 and before <= 0 then return nil end
    local gain = now > before
    local change = gain and math.floor(now - before) or math.floor(before - now)
    return {
        label = Format.label(key),
        value = whole .. " (" .. (gain and "+" or "-") .. change .. ")",
        meaning = gain and "good" or "bad",
    }
end

local function defenseRows(item, player)
    local before = {}
    if not item:isEquipped() and player ~= nil then before = wornProtection(item, player) end
    local rows = {}
    local defenses = {
        { "Tooltip_BiteDefense", item:getBiteDefense(), before[1] },
        { "Tooltip_ScratchDefense", item:getScratchDefense(), before[2] },
        { "Tooltip_BulletDefense", item:getBulletDefense(), before[3] },
    }
    for _, defense in ipairs(defenses) do
        local row = defenseRow(defense[1], defense[2], defense[3])
        if row then table.insert(rows, row) end
    end
    return rows
end

-- The name of an item the game has, as the game shows it.
local function nameOf(fullType)
    return getText(getScriptManager():getItem(fullType):getDisplayName())
end

-- What a mask holds (a filter) or breathing apparatus (a tank): its name and
-- how much is left, or that it has none.
local function breathingRows(item)
    local rows = {}
    local function holder(has, typeOf, missingKey)
        if has then
            table.insert(rows, { label = nameOf(typeOf) .. ":", progress = item:getUsedDelta(), scale = "up" })
        else
            table.insert(rows, { label = getText(missingKey) })
        end
    end
    if hasAnyTag(item, FILTERED_TAGS) then
        holder(item:hasFilter(), item:hasFilter() and item:getFilterType(), "Tooltip_NoFilter")
    elseif hasAnyTag(item, NO_FILTER_TAGS) then
        table.insert(rows, { label = getText("Tooltip_NoFilter") })
    end
    if ItemTag.SCBA ~= nil and item:hasTag(ItemTag.SCBA) then
        holder(item:hasTank(), item:hasTank() and item:getTankType(), "Tooltip_NoTank")
    elseif ItemTag.SCBANO_TANK ~= nil and item:hasTag(ItemTag.SCBANO_TANK) then
        table.insert(rows, { label = getText("Tooltip_NoTank") })
    end
    return rows
end

-- How the clothing changes the speed of running and fighting. The game
-- picks the colour of the combat one by the running one.
local function speedRows(item)
    local rows = {}
    local running, fighting = item:getRunSpeedModifier(), item:getCombatSpeedModifier()
    local function speedBar(key, modifier)
        local better = running > 1
        table.insert(rows, {
            label = Format.label(key),
            labelMeaning = better and "good" or "bad",
            progress = better and modifier - 1 or 1 - modifier,
        })
    end
    if running ~= 1 then speedBar("Tooltip_RunSpeedModifier", running) end
    if fighting ~= 1 then speedBar("Tooltip_CombatSpeedModifier", fighting) end
    return rows
end

local function rows(item, context)
    local all = {}
    ItemLines.append(all, protectionRows(item))
    ItemLines.append(all, stateRows(item))
    ItemLines.append(all, holeRows(item))
    ItemLines.append(all, defenseRows(item, context.player))
    ItemLines.append(all, breathingRows(item))
    ItemLines.append(all, speedRows(item))
    return all
end

Common.addKind({ category = "Clothing", equippedWeight = true, ownsCondition = true, refusal = refusal, rows = rows })
