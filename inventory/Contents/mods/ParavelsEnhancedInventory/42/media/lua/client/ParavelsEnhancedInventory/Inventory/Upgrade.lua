--[[
    Paravel's Enhanced Inventory - character equipment improvements

    The mark means an item improves protection, damage or capacity. Any
    positive difference counts, even if another attribute is worse:

    - Clothing: total bite, scratch and bullet defence against clothing worn
      in the same or an excluding body location. Warmth and weather protection
      are ignored.
    - Wearable bags: effective capacity against the bag worn in that place.
    - Weapons: average damage against a weapon of the same class in a
      compatible hotbar slot. The class is melee, or ranged with the same
      ammunition. An empty compatible slot is worth zero; other occupied slots
      do not affect the comparison. Slot compatibility follows
      ISHotbar:canBeAttached.

    Item groups and the top indicator do not determine eligibility. Already
    equipped items and broken candidates never get the mark; broken reference
    items are worth nothing. Item types are described once, and the player's
    worn gear and compatible slots are read lazily per drawing pass.
]]

require "ParavelsEnhancedInventory/Core/PEI"
local Upgrade = PEI.Upgrade or {}
PEI.Upgrade = Upgrade

local CLOTHING, BAG, WEAPON = "clothing", "bag", "weapon"

-- Full type -> { kind, place, key, attachment }, or false for a type with
-- neither a kind nor an attachment type. `place` is the body location
-- (clothing, bags) or the weapon's class, `key` is its text, to tell places
-- apart; `attachment` is what the game attaches it as (hotbar slots), or
-- false. A type that can only be attached has no kind, place or key.
local typeCache = {}

-- A weapon's class: melee, or ranged with its ammunition when known.
local function weaponClass(item)
    if not item:isRanged() then return "melee" end
    local ammo = item:getAmmoType()
    if not ammo then return "ranged" end
    return "ranged:" .. tostring(ammo:getItemKey())
end

local function wearableBagPlace(item)
    local slot = item:canBeEquipped()
    if slot == nil or slot == "" then return nil end
    return item:getBodyLocation() or slot
end

local function describe(item)
    local kind, place
    if instanceof(item, "Clothing") then
        kind, place = CLOTHING, item:getBodyLocation()
    elseif instanceof(item, "InventoryContainer") then
        kind, place = BAG, wearableBagPlace(item)
    elseif instanceof(item, "HandWeapon") then
        kind, place = WEAPON, weaponClass(item)
    end
    local attachment = item:getAttachmentType() or false
    if not place and not attachment then return false end
    return { kind = place and kind or nil, place = place, key = place and tostring(place) or nil, attachment = attachment }
end

local function infoOf(item)
    local fullType = item:getFullType()
    local info = typeCache[fullType]
    if info == nil then
        info = describe(item)
        typeCache[fullType] = info
    end
    return info
end

-- What an item of that kind is worth. Broken items are worth nothing.
local function worth(kind, item, player)
    if item:isBroken() then return 0 end
    if kind == CLOTHING then
        return item:getBiteDefense() + item:getScratchDefense() + item:getBulletDefense()
    elseif kind == BAG then
        return item:getItemContainer():getEffectiveCapacity(player)
    end
    return (item:getMinDamage() + item:getMaxDamage()) / 2
end

--[[
    What the player's gear is worth, read as the items shown ask for it:
        player
        hotbar the player's hotbar, nil without one
        worn   place key -> what the player wears there is worth
        fits   attachment type -> the hotbar slot indexes that take it, with
               what hangs on the hotbar (`attached`: slot index -> item)
]]
function Upgrade.newReference(playerNum)
    return { player = getSpecificPlayer(playerNum), hotbar = getPlayerHotbar(playerNum), worn = {}, fits = {} }
end

-- Whether the hotbar holds `item`, as the game's own windows decide it
-- (ISHotbar:isInHotbar). Not by the item's attached slot: it is saved with
-- the item and can outlive the attachment (another item took the slot, or
-- it was never cleared), and then the item is loose in every window of the
-- game, only moving it (which clears the slot) made the mark come back.
local function isAttached(reference, item)
    return reference.hotbar ~= nil and reference.hotbar:isInHotbar(item)
end

-- Whether what the player wears at `location` is in the way of an item
-- going there: the same place, or one the game says excludes it.
local function takesPlaceOf(group, location, wornLocation)
    return location == wornLocation or group:isExclusive(location, wornLocation)
end

local function wornWorth(reference, info)
    local total = reference.worn[info.key]
    if total then return total end
    total = 0
    local player = reference.player
    local wornItems = player:getWornItems()
    local group = wornItems:getBodyLocationGroup()
    for index = 0, wornItems:size() - 1 do
        local worn = wornItems:get(index)
        local item = worn:getItem()
        local wornInfo = infoOf(item)
        if wornInfo and wornInfo.kind == info.kind and takesPlaceOf(group, info.place, worn:getLocation()) then
            total = total + worth(info.kind, item, player)
        end
    end
    reference.worn[info.key] = total
    return total
end

-- Whether wearing `candidate` creates more distinct hotbar slots than the
-- clothing it would replace. ISHotbar refreshes the same slot types from
-- worn items, deduplicating slots that multiple items provide.
local function addsAttachmentSlots(reference, candidate, info)
    local player = reference.player
    local hotbar = reference.hotbar
    if not hotbar or not player then return false end

    local wornItems = player:getWornItems()
    local group = wornItems:getBodyLocationGroup()
    local currentSlots = {}
    local candidateSlots = {}

    local function addProvidedSlots(slots, item)
        if not item or (player.isHandItem and player:isHandItem(item)) then return end
        local provided = item:getAttachmentsProvided()
        if not provided then return end
        for index = 0, provided:size() - 1 do
            local slotDef = hotbar:getSlotDef(provided:get(index))
            if slotDef then slots[slotDef.type] = true end
        end
    end

    currentSlots.Back = true
    candidateSlots.Back = true
    for index = 0, wornItems:size() - 1 do
        local worn = wornItems:get(index)
        local item = worn:getItem()
        addProvidedSlots(currentSlots, item)
        if not takesPlaceOf(group, info.place, worn:getLocation()) then
            addProvidedSlots(candidateSlots, item)
        end
    end
    addProvidedSlots(candidateSlots, candidate)

    local currentCount = 0
    local candidateCount = 0
    for _ in pairs(currentSlots) do currentCount = currentCount + 1 end
    for _ in pairs(candidateSlots) do candidateCount = candidateCount + 1 end
    return candidateCount > currentCount
end

-- The slots of the player's hotbar (belt, back, holsters...) that take an
-- item attached as `attachment`, by slot index; the game's own question
-- (ISHotbar:canBeAttached), also when a worn bag takes the place of the back
-- one. Worked out once per attachment type and pass.
local function slotsFor(reference, item, attachment)
    local fits = reference.fits[attachment]
    if fits then return fits end
    fits = {}
    local hotbar = reference.hotbar
    if hotbar and hotbar.replacements and hotbar.replacements[attachment] ~= "null" then
        for slotIndex, slot in pairs(hotbar.availableSlot) do
            if hotbar:canBeAttached(slot, item) then table.insert(fits, slotIndex) end
        end
        fits.attached = hotbar.attachedItems
    end
    reference.fits[attachment] = fits
    return fits
end

-- The slots where `item` improves the weapon already attached, or fits an
-- empty slot. Occupied slots of another weapon class are ignored.
local function improvedSlots(reference, item, info)
    if info.kind ~= WEAPON or not info.attachment or item:isBroken() then return {} end
    local fits = slotsFor(reference, item, info.attachment)
    local weaponWorth = worth(WEAPON, item, reference.player)
    local improved = {}
    for _, slotIndex in ipairs(fits) do
        local attached = fits.attached[slotIndex]
        if not attached then
            if weaponWorth > 0 then improved[#improved + 1] = slotIndex end
        else
            local attachedInfo = infoOf(attached)
            if attachedInfo and attachedInfo.key == info.key and weaponWorth > worth(WEAPON, attached, reference.player) then
                improved[#improved + 1] = slotIndex
            end
        end
    end
    return improved
end

local function isBetterAttached(reference, item, info)
    return #improvedSlots(reference, item, info) > 0
end

-- The compatible hotbar slots where the item earns its upgrade mark.
function Upgrade.improvedSlotIndexes(reference, item)
    local info = infoOf(item)
    if not info or isAttached(reference, item) then return {} end
    return improvedSlots(reference, item, info)
end

-- Whether `item` improves what the player wears in the same body location.
local function isBetterInPlace(reference, item, info)
    if info.kind ~= CLOTHING and info.kind ~= BAG then return false end
    if worth(info.kind, item, reference.player) > wornWorth(reference, info) then return true end
    return (info.kind == CLOTHING or info.kind == BAG) and addsAttachmentSlots(reference, item, info)
end

-- Whether `item` improves worn gear or a weapon in a compatible slot.
function Upgrade.isBetter(reference, item)
    local info = infoOf(item)
    if not info or isAttached(reference, item) then return false end
    return isBetterInPlace(reference, item, info) or isBetterAttached(reference, item, info)
end
