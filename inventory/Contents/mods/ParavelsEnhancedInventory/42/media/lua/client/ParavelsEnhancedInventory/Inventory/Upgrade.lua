--[[
    Paravel's Enhanced Inventory - gear better than what the player has on

    Says whether an item is better than what the player wears, holds or has
    attached in the same place, for the mark the grid and the list draw on it
    (ItemIcon.drawUpgradeMark). "Better" means worth strictly more by the one
    measure of its kind:

    - Clothing: protection only (bite, scratch and bullet defence), against
      everything the player wears where it goes or in a place that excludes
      it, as the game's own clothing tooltip counts it. Warmth (insulation,
      wind and water resistance) is ignored: only protective clothing gets
      the mark, and weighing warmth too hid it from football pants (more
      protection) when long padded trousers (warmer) were worn. An empty
      place is worth nothing, so any garment that protects at all is better
      than none.
    - Wearable bags: the capacity they give, against the bag worn in that place.
    - Weapons: average damage, against the best weapon of the same kind the
      player has in hand or attached (hotbar, belt, back...): melee, or
      ranged with the same ammunition. With nothing of that kind, melee
      weapons are compared with the bare hands and ranged ones with nothing,
      like an empty clothing place (broken ones are worth nothing, so never
      beat it).
    - Attachable items (weapons, tools, planks...): also better when the game
      lets the player attach them to a hotbar slot (belt, back, holster...)
      that is empty, or where hangs a weapon of the same class that they beat,
      slot by slot. The slots are the ones the player has now, and the game
      says what fits each (ISHotbar:canBeAttached).
    Only items that earn the top indicator (Families.earnsTopIndicator) get
    the mark: plain clothes and tools are not worth flagging. Worn, held,
    attached and broken items never get it, and broken ones are worth nothing
    as the reference.

    What a type is (its kind and place) is worked out once per type. The
    player's gear is read once per drawing pass, when the pass makes its
    reference (Upgrade.newReference), and only as far as the items shown ask
    for it. Items of no kind cost one type lookup.
]]

require "ParavelsEnhancedInventory/Core/PEI"
require "ParavelsEnhancedInventory/Inventory/Families"

local Families = PEI.Families
local Upgrade = PEI.Upgrade or {}
PEI.Upgrade = Upgrade

local CLOTHING, BAG, WEAPON = "clothing", "bag", "weapon"

-- Full type -> { kind, place, key, attachment }, or false for a type with
-- neither a kind nor an attachment type. `place` is the body location
-- (clothing, bags) or the weapon's class, `key` is its text, to tell places
-- apart; `attachment` is what the game attaches it as (hotbar slots), or
-- false. A type that can only be attached has no kind, place or key.
local typeCache = {}

-- A weapon's class: melee, or ranged with its ammunition. Ranged weapons
-- that name no ammunition have none.
local function weaponClass(item)
    if not item:isRanged() then return "melee" end
    local ammo = item:getAmmoType()
    if not ammo then return nil end
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
        armed  weapon class key -> worth of the best weapon of that class in
               hand or attached
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

-- Raises the best worth of the weapon's class in `armed` if `item` is a
-- weapon that beats it.
local function addArmed(armed, item, player)
    local info = item and infoOf(item)
    if not info or info.kind ~= WEAPON then return end
    local itemWorth = worth(WEAPON, item, player)
    if itemWorth > (armed[info.key] or -1) then armed[info.key] = itemWorth end
end

-- What the player has in hand or attached, by weapon class.
local function armedWeapons(reference)
    local armed = {}
    local player = reference.player
    addArmed(armed, player:getPrimaryHandItem(), player)
    addArmed(armed, player:getSecondaryHandItem(), player)
    local attached = player:getAttachedItems()
    for index = 0, attached:size() - 1 do
        addArmed(armed, attached:get(index):getItem(), player)
    end
    return armed
end

-- What the bare hands are worth, the game's own "weapon" for them; a game
-- constant, so read once.
local bareHandsWorth
local function bareHandsWorthOf(player)
    if bareHandsWorth == nil then
        local fists = instanceItem("Base.BareHands")
        bareHandsWorth = fists and worth(WEAPON, fists, player) or 0
    end
    return bareHandsWorth
end

-- What the player has of `info`'s class: the best weapon of it in hand or
-- attached, or nothing at all, which is worth the bare hands for melee (so
-- only what hits harder than fists is better) and zero for ranged.
local function armedWorth(reference, info)
    reference.armed = reference.armed or armedWeapons(reference)
    local armed = reference.armed[info.key]
    if armed then return armed end
    if info.place == "melee" then return bareHandsWorthOf(reference.player) end
    return 0
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

-- Whether `item` could be attached where it would be worth more than what
-- hangs there: an empty slot, or a weapon of the same class that it beats.
local function isBetterAttached(reference, item, info)
    if not info.attachment or item:isBroken() then return false end
    local fits = slotsFor(reference, item, info.attachment)
    local weaponWorth = info.kind == WEAPON and worth(WEAPON, item, reference.player)
    for _, slotIndex in ipairs(fits) do
        local attached = fits.attached[slotIndex]
        if not attached then return true end
        local attachedInfo = weaponWorth and infoOf(attached)
        if attachedInfo and attachedInfo.key == info.key and weaponWorth > worth(WEAPON, attached, reference.player) then
            return true
        end
    end
    return false
end

-- Whether `item` is better than what the player has on, in hand or attached
-- in the same place.
local function isBetterInPlace(reference, item, info)
    if not info.kind then return false end
    local has
    if info.kind == WEAPON then has = armedWorth(reference, info) else has = wornWorth(reference, info) end
    return worth(info.kind, item, reference.player) > has
end

-- Whether `item` is better than what the player has on, in hand or attached
-- in the same place, or fits a hotbar slot where it beats what hangs there
-- (or nothing does); `reference` is Upgrade.newReference's, for the whole pass.
function Upgrade.isBetter(reference, item)
    local info = infoOf(item)
    if not info or item:isEquipped() or isAttached(reference, item) then return false end
    if not Families.earnsTopIndicator(item) then return false end
    return isBetterInPlace(reference, item, info) or isBetterAttached(reference, item, info)
end
