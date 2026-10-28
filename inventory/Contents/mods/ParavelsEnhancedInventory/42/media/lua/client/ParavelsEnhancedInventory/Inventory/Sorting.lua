--[[
    Paravel's Enhanced Inventory - sorting

    Both views sort with the pane's own itemSortFunc, vanilla's field: the
    footer's sort menu and the list's column headers set it, so the order
    carries over between the views and is saved in layout.ini. Besides
    vanilla's sorts (name, category, weight) there is one by family.
]]

require "ISUI/ISInventoryPane"
require "ParavelsEnhancedInventory/Inventory/Entries"
require "ParavelsEnhancedInventory/Inventory/Families"

local Entries = PEI.Entries
local Families = PEI.Families

local Sorting = PEI.Sorting or {}
PEI.Sorting = Sorting

-- ------------------------------------------------------------------ --
-- Family sort
-- ------------------------------------------------------------------ --

-- What the family sort compares, from an entry's first item. Vanilla sorts
-- before it puts the header copy in front, so entry.items[1] is that item
-- either way. Entries are rebuilt on every refresh, so the key is cached on
-- the entry.
local function familySortKey(entry)
    local key = entry.pei_sortKey
    if key then return key end
    local family, hasTopIndicator = Families.classify(Entries.headerItem(entry))
    key = {
        familyRank = Families.rank(family),
        topIndicatorFirst = hasTopIndicator and 0 or 1,
        -- No colour of its own (Household, Misc, rotten food, another mod's).
        uncoloured = not Families.hasColour(family),
    }
    entry.pei_sortKey = key
    return key
end

-- Equipped items last, as in vanilla's sorts; then the families in the
-- order of Families.LIST (or the reverse), the uncoloured ones last either
-- way; then items with the top indicator first; then by name.
function Sorting.compareByFamily(a, b, descending)
    local aEquipped, bEquipped = a.equipped and true or false, b.equipped and true or false
    if aEquipped ~= bEquipped then return bEquipped end
    local keyA, keyB = familySortKey(a), familySortKey(b)
    if keyA.uncoloured ~= keyB.uncoloured then return keyB.uncoloured end
    if keyA.familyRank ~= keyB.familyRank then
        if descending then return keyA.familyRank > keyB.familyRank end
        return keyA.familyRank < keyB.familyRank
    end
    if keyA.topIndicatorFirst ~= keyB.topIndicatorFirst then
        return keyA.topIndicatorFirst < keyB.topIndicatorFirst
    end
    return not string.sort(a.name, b.name)
end

-- The functions kept in itemSortFunc are made once, so a reload does not
-- break the check of which sort is on; they call the current compare.
Sorting.byFamily = Sorting.byFamily
    or function(a, b) return PEI.Sorting.compareByFamily(a, b, false) end
Sorting.byFamilyDescending = Sorting.byFamilyDescending
    or function(a, b) return PEI.Sorting.compareByFamily(a, b, true) end

-- ------------------------------------------------------------------ --
-- The sorts offered, in menu order
-- ------------------------------------------------------------------ --

-- savedAs: the names layout.ini stores for the sorts vanilla does not save
-- itself (it saves name and category on its own).
Sorting.CHOICES = {
    { titleKey = "IGUI_PEI_SortFamily",
      ascending = Sorting.byFamily, descending = Sorting.byFamilyDescending,
      savedAs = { ascending = "family", descending = "familyDesc" } },
    { titleKey = "IGUI_PEI_SortName",
      ascending = ISInventoryPane.itemSortByNameInc, descending = ISInventoryPane.itemSortByNameDesc },
    { titleKey = "IGUI_PEI_SortCategory",
      ascending = ISInventoryPane.itemSortByCatInc, descending = ISInventoryPane.itemSortByCatDesc },
    { titleKey = "IGUI_PEI_SortWeight",
      ascending = ISInventoryPane.itemSortByWeightAsc, descending = ISInventoryPane.itemSortByWeightDesc,
      savedAs = { ascending = "weightAsc", descending = "weightDesc" } },
}

function Sorting.set(pane, sortFunction)
    if pane.itemSortFunc == sortFunction then return end
    pane.itemSortFunc = sortFunction
    pane:refreshContainer()
end

-- Always the opposite of what the button's icon shows, which is the ascending
-- one under any other sort, so the first click visibly changes it.
function Sorting.toggleFamily(pane)
    local isDescending = pane.itemSortFunc == Sorting.byFamilyDescending
    Sorting.set(pane, isDescending and Sorting.byFamily or Sorting.byFamilyDescending)
end

-- Heaviest first on the first click, then lightest first, and so on.
function Sorting.toggleWeight(pane)
    local isDescending = pane.itemSortFunc == ISInventoryPane.itemSortByWeightDesc
    Sorting.set(pane, isDescending and ISInventoryPane.itemSortByWeightAsc or ISInventoryPane.itemSortByWeightDesc)
end

-- The name layout.ini stores for a sort, or nil when vanilla saves it.
function Sorting.savedName(sortFunction)
    for _, choice in ipairs(Sorting.CHOICES) do
        if choice.savedAs then
            if sortFunction == choice.ascending then return choice.savedAs.ascending end
            if sortFunction == choice.descending then return choice.savedAs.descending end
        end
    end
    return nil
end

function Sorting.fromSavedName(name)
    for _, choice in ipairs(Sorting.CHOICES) do
        if choice.savedAs then
            if name == choice.savedAs.ascending then return choice.ascending end
            if name == choice.savedAs.descending then return choice.descending end
        end
    end
    return nil
end

-- Runs refreshContainer (`refresh`, vanilla's) with items attached to the
-- hotbar slots counted as equipped, as the grid counts them: vanilla's
-- sorts put them with the carried items (or first, by name), and the list's
-- sorts and its divider only look at `equipped`. The entries are new on
-- every refresh, so they are marked as the sort meets them.
function Sorting.refreshWithHotbarAsEquipped(refresh, pane)
    local sortFunction = pane.itemSortFunc
    if not sortFunction then return refresh(pane) end
    local function hotbarAsEquipped(a, b)
        if a.inHotbar then a.equipped = true end
        if b.inHotbar then b.equipped = true end
        return sortFunction(a, b)
    end
    PUI.withFields(pane, { itemSortFunc = hotbarAsEquipped }, refresh, pane)
end

-- The grid's order: the pane's sort, with equipped and attached items last
-- (the grid starts them on a row of their own). Vanilla's sorts put only
-- the equipped last, so the split is applied here.
function Sorting.sortForGrid(pane, entries)
    local sortFunction = pane.itemSortFunc
    table.sort(entries, function(a, b)
        local aEquipped, bEquipped = Entries.isEquipped(a), Entries.isEquipped(b)
        if aEquipped ~= bEquipped then return bEquipped end
        return sortFunction(a, b)
    end)
end
