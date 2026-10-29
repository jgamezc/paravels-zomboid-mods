--[[
    Paravel's Enhanced Inventory - upgrade marks in attachment options

    The hotbar's attach submenu names each compatible slot. Mark the options
    where the item is an upgrade, using the same icon as the inventory grid.
]]

require "Hotbar/ISHotbar"
require "ParavelsEnhancedInventory/Core/PEI"
require "ParavelsEnhancedInventory/Inventory/ItemIcon"
require "ParavelsEnhancedInventory/Inventory/Upgrade"

local ItemIcon = PEI.ItemIcon
local Options = PEI.Options
local Upgrade = PEI.Upgrade

local function attachSubmenu(context)
    local attachName = getText("ContextMenu_Attach")
    for _, option in ipairs(context.options) do
        if option and option.name == attachName and option.subOption then
            return context:getSubInstance(option.subOption), option
        end
    end
    return nil
end

local function addMissingAttachOptions(submenu, hotbar, item)
    local attachment = item:getAttachmentType()
    local present = {}
    local found = false
    for _, option in ipairs(submenu.options) do
        if option.target == hotbar and option.onSelect == ISHotbar.attachItem and option.param1 == item then
            present[option.param3] = true
            found = true
        end
    end

    for slotIndex, slot in pairs(hotbar.availableSlot or {}) do
        local slotDef = slot.def
        local attachmentLocation
        for attachmentType, location in pairs(slotDef.attachments or {}) do
            if attachmentType == attachment then
                attachmentLocation = location
                break
            end
        end
        if not present[slotIndex] and attachmentLocation then
            local name = slot.name
            if getTextOrNull then name = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or name end
            submenu:addOption(name, hotbar, ISHotbar.attachItem, item, attachmentLocation, slotIndex, slotDef, true)
            found = true
        end
    end
    return found
end

local function ensureAttachSubmenu(context, hotbar, item)
    local submenu, parentOption = attachSubmenu(context)
    if not parentOption then parentOption = context:addOption(getText("ContextMenu_Attach"), nil) end
    if not submenu then
        submenu = context:getNew(context)
        context:addSubMenu(parentOption, submenu)
    end
    if not addMissingAttachOptions(submenu, hotbar, item) then parentOption.notAvailable = true end
    return submenu, parentOption
end

local function improvedSlotSet(reference, item)
    local improved = {}
    for _, slotIndex in ipairs(Upgrade.improvedSlotIndexes(reference, item)) do
        improved[slotIndex] = true
    end
    return improved
end

local function markImprovementOptions(submenu, hotbar, reference)
    if not submenu then return false end
    local improvedByItem = {}
    local hasImprovement = false
    for _, option in ipairs(submenu.options) do
        if option.target == hotbar and option.onSelect == ISHotbar.attachItem then
            local item = option.param1
            local improved = improvedByItem[item]
            if not improved then
                improved = improvedSlotSet(reference, item)
                improvedByItem[item] = improved
            end
            if improved[option.param3] then
                ItemIcon.markUpgradeOption(option)
                hasImprovement = true
            end
        end
    end
    return hasImprovement
end

local function addRemoveOption(context, hotbar, item)
    local slotIndex = item:getAttachedSlot()
    local attachedItem = hotbar.attachedItems and hotbar.attachedItems[slotIndex]
    local slot = hotbar.availableSlot and hotbar.availableSlot[slotIndex]
    if not attachedItem or not slot then return end

    local slotName = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name
    context:addOption(
        getText("ContextMenu_RemoveFromHotbar", attachedItem:getDisplayName(), slotName),
        hotbar,
        ISHotbar.removeItem,
        attachedItem,
        true
    )
end

PUI.override(ISHotbar, "doMenuFromInventory", function(_, playerNum, item, context)
    local hotbar = getPlayerHotbar(playerNum)
    if not hotbar then return end

    if hotbar:isInHotbar(item) and item:getAttachmentType() and item:getAttachedSlot() ~= -1 then
        addRemoveOption(context, hotbar, item)
    end

    local attachment = item:getAttachmentType()
    local replacement = hotbar.replacements and hotbar.replacements[attachment]
    if not attachment or hotbar:isInHotbar(item) or item:isBroken() or replacement == "null" then return end

    local submenu, parentOption = ensureAttachSubmenu(context, hotbar, item)
    if Options.get("showUpgradeMark") then
        if markImprovementOptions(submenu, hotbar, Upgrade.newReference(playerNum)) then
            ItemIcon.markUpgradeOption(parentOption)
        end
    end
end)
