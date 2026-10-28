--[[
    Paravel's Enhanced Tooltips - weapons

    What a hand weapon says on top of what every item does: its sharpness,
    condition (and the head's, when it has one), damage, blood, the line,
    hook and bait of a fishing rod, the range of a firearm and its fire mode,
    its ammunition, chamber and clip, the parts attached to it, whether it
    takes both hands, and a few notes.
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local ItemLines = PET.ItemLines
local Format = PET.Format
local Questions = PET.Questions

local Weapon = PET.Weapon or {}
PET.Weapon = Weapon

-- What the rows read from the weapon, which must be askable.
local QUESTIONS = {
    "isRanged", "getAllWeaponParts", "getMagazineType", "getFireMode",
    "getHeadCondition", "getHeadConditionMax", "getMaxDamage",
    "getMinDamage", "getBloodLevel", "isTwoHandWeapon",
    "isRequiresEquippedBothHands", "isCantAttackWithLowestEndurance",
    "getSharpness", "getMaxAmmo", "getCurrentAmmoCount", "getAmmoType",
    "isRoundChambered", "isSpentRoundChambered", "getSpentRoundCount",
    "isJammed", "haveChamber", "isContainsClip", "getModData",
}

local function refusal(item, player)
    if ItemTag.FISHING_ROD == nil then return "FISHING_ROD" end
    if getScriptManager().FindItem == nil then return "FindItem (not askable)" end
    local reason = Questions.firstRefusal(item, QUESTIONS)
    if reason then return reason end
    if item:isRanged() then
        local reason = Questions.askRefusal(item, "getMaxRange", player)
        if reason then return reason end
    end
    local parts = item:getAllWeaponParts()
    if parts:size() > 0 then return ItemLines.battery.refusal(parts:get(0)) end
    return nil
end

-- The name of an item the game has, as the game shows it.
local function nameOf(fullType)
    local script = getScriptManager():FindItem(fullType)
    return script ~= nil and getText(script:getDisplayName()) or nil
end

-- A wear bar: the lower, the worse.
local function wearBar(key, fraction)
    return { label = Format.label(key), progress = fraction, scale = "up" }
end

local function wearRows(item)
    local rows = {}
    if item:hasSharpness() then table.insert(rows, wearBar("Tooltip_weapon_Sharpness", item:getSharpness())) end
    local key = item:hasHeadCondition() and "Tooltip_weapon_HandleCondition" or "Tooltip_weapon_Condition"
    table.insert(rows, wearBar(key, item:getCondition() / item:getConditionMax()))
    if item:hasHeadCondition() then
        table.insert(rows, wearBar("Tooltip_weapon_HeadCondition", item:getHeadCondition() / item:getHeadConditionMax()))
    end
    return rows
end

-- How hard it hits, against the game's best weapon (damage 5).
local MOST_DAMAGE = 5

local function damageRows(item)
    if item:getMaxDamage() <= 0 then return {} end
    return { wearBar("Tooltip_weapon_Damage", (item:getMaxDamage() + item:getMinDamage()) / MOST_DAMAGE) }
end

-- The more blood on it, the worse.
local function bloodRows(item)
    if item:getBloodLevel() == 0 then return {} end
    return { { label = Format.label("Tooltip_clothing_bloody"), progress = item:getBloodLevel(), scale = "down" } }
end

-- The line, hook and bait of a fishing rod, as they are kept in its data.
local function fishingRows(item)
    if not item:hasTag(ItemTag.FISHING_ROD) then return {} end
    local data = item:getModData()
    local lineCondition = data.fishing_LineCondition or 1
    local line, hook, bait = data.fishing_LineType, data.fishing_HookType, data.fishing_Lure
    local function partName(kept, default, key)
        return nameOf(kept or default) or getText(key)
    end
    local baitRow = { label = Format.label("Tooltip_fishing_bait") }
    if bait == nil then
        baitRow.value, baitRow.meaning = getText("UI_None"), "bad"
    else
        baitRow.value = nameOf(bait) or getText("Tooltip_fishing_bait")
    end
    return {
        wearBar("Tooltip_fishing_line_Condition", lineCondition),
        { label = Format.label("Tooltip_fishing_line"), value = partName(line, "Base.FishingLine", "Tooltip_fishing_line") },
        { label = Format.label("Tooltip_fishing_hook"), value = partName(hook, "Base.FishingHook", "Tooltip_fishing_hook") },
        baitRow,
    }
end

-- The farthest it shoots, against the game's best range (40).
local MOST_RANGE = 40

local function rangeRows(item, player)
    if not item:isRanged() then return {} end
    return { wearBar("Tooltip_weapon_Range", item:getMaxRange(player) / MOST_RANGE) }
end

local function handRows(item)
    local rows = {}
    if item:isTwoHandWeapon() and not item:isRequiresEquippedBothHands() then
        table.insert(rows, { label = getText("Tooltip_item_TwoHandWeapon") })
    end
    local mode = item:getFireMode()
    if mode ~= nil and mode ~= "" then
        table.insert(rows, { label = Format.label("Tooltip_item_FireMode"), value = getText("ContextMenu_FireMode_" .. mode) })
    end
    if item:isCantAttackWithLowestEndurance() then
        table.insert(rows, { label = getText("Tooltip_weapon_Unusable_at_max_exertion"), meaning = "bad" })
    end
    return rows
end

-- What it shoots, how many rounds it holds and what is wrong with them.
local function ammoRows(item)
    local rows = {}
    if item:getMaxAmmo() > 0 then
        local loaded = tostring(item:getCurrentAmmoCount()) .. (item:isRoundChambered() and "+1" or "")
        local magazine = item:getMagazineType()
        local bullet = magazine ~= nil and instanceItem(magazine):getDisplayName() or instanceItem(item:getAmmoType():getItemKey()):getDisplayName()
        table.insert(rows, { label = bullet .. ":", value = loaded .. " / " .. item:getMaxAmmo() })
    end
    if item:isJammed() then
        table.insert(rows, { label = getText("Tooltip_weapon_Jammed"), meaning = "bad" })
    elseif item:haveChamber() and not item:isRoundChambered() and item:getCurrentAmmoCount() > 0 then
        local key = item:isSpentRoundChambered() and "Tooltip_weapon_SpentRoundChambered" or "Tooltip_weapon_NoRoundChambered"
        table.insert(rows, { label = getText(key), meaning = "bad" })
    elseif item:getSpentRoundCount() > 0 then
        table.insert(rows, {
            label = Format.label("Tooltip_weapon_SpentRounds"),
            labelMeaning = "bad",
            value = item:getSpentRoundCount() .. " / " .. item:getMaxAmmo(),
        })
    end
    local magazine = item:getMagazineType()
    if magazine ~= nil and magazine ~= "" then
        table.insert(rows, { label = getText(item:isContainsClip() and "Tooltip_weapon_ContainsClip" or "Tooltip_weapon_NoClip") })
    end
    return rows
end

-- The parts attached to it (sights, silencers, slings...), each with its
-- battery if it has one.
local function partRows(item)
    local rows = {}
    local parts = item:getAllWeaponParts()
    for index = 0, parts:size() - 1 do
        local part = parts:get(index)
        table.insert(rows, { label = Format.label("Tooltip_weapon_" .. part:getPartType()), value = part:getName() })
        ItemLines.append(rows, ItemLines.battery.rows(part))
    end
    return rows
end

local function maintenanceRows(item)
    if not item:hasTag(ItemTag.NO_MAINTENANCE_XP) then return {} end
    return { { label = getText("Tooltip_weapon_NoMaintenanceXp") } }
end

local function rows(item, context)
    local all = {}
    ItemLines.append(all, wearRows(item))
    ItemLines.append(all, damageRows(item))
    ItemLines.append(all, bloodRows(item))
    ItemLines.append(all, fishingRows(item))
    ItemLines.append(all, rangeRows(item, context.player))
    ItemLines.append(all, handRows(item))
    ItemLines.append(all, ammoRows(item))
    ItemLines.append(all, partRows(item))
    ItemLines.append(all, maintenanceRows(item))
    return all
end

Common.addKind({
    category = "Weapon", equippedWeight = true, ownsSharpness = true, ownsCondition = true,
    refusal = refusal, rows = rows,
})
