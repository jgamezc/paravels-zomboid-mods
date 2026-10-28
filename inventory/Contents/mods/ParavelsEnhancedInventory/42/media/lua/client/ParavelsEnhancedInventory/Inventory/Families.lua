--[[
    Paravel's Enhanced Inventory - item families

    The game has ~80 display categories, too fine for what a player goes out
    looking for ("weapons today", "I need food"). Each one is folded into a
    family by usefulness: an item is in a family only if someone looting for
    that family would want it. The family gives the item its colour (the
    grid cell's background, the list icon's backdrop).

    The top indicator marks what stands out inside a family (a weapon among
    ammo, a magazine among books). It is decided by rules that look only at
    the item, never at its family, and is never given to whole families.

    Families.classify(item) answers both; every display category of the
    game must be taken by a family. Families.tintOf(family) is the
    colour to draw a family's items with, read from the theme when drawn.
    What state an item is in (food gone rotten, a bottle holding a drink)
    can change its family; its colour always follows from the family, and
    its top indicator from the item's own rules.
]]

require "ParavelsEnhancedInventory/Core/PEI"
require "ParavelsUI/Theme/Palette"

local Families = PEI.Families or {}
PEI.Families = Families

-- What a colour says: the kind of need an item serves. Few on purpose, so
-- each reads at a glance. `color` is the number of its category colour in
-- the theme's palette (Paravel's UI, Theme/Palette.lua): which colour that
-- is, is the theme's. The order is the family sort's.
Families.LIST = {
    { id = "Combat",    color = 1 },
    { id = "Food",      color = 2 },
    { id = "Medical",   color = 3 },
    { id = "Clothing",  color = 4 },
    { id = "Workshop",  color = 5 },
    { id = "Survival",  color = 6 },
    { id = "Knowledge", color = 7 },
    { id = "Materials", color = 8 },
    { id = "Electric",  color = 9 },
    { id = "Mechanics", color = 10 },
    -- Every category belongs to a family, but only the ones people go out
    -- looking for have a colour of their own. These have none (no `color`):
    -- they take the neutral grey.
    { id = "Household" },
    { id = "Leisure" },
    { id = "Storage" },
    { id = "Furniture" },
    { id = "Animal" },
    { id = "Body" },
    { id = "Misc" },
}

Families.byId = {}
local rankById = {}
for rank, family in ipairs(Families.LIST) do
    Families.byId[family.id] = family
    rankById[family.id] = rank
end

-- Position in Families.LIST; another mod's family (or none) goes after all.
function Families.rank(family)
    return family and rankById[family.id] or #Families.LIST + 1
end

-- The colour of every item whose family has none, or that has no family:
-- a grey of the palette's fixed row, the same in every theme.
local NEUTRAL_GREY = 10

-- Whether `family` (or nil, for none) has a colour of its own.
function Families.hasColour(family)
    return family ~= nil and family.color ~= nil
end

-- The colour items of `family` are drawn with: the family's own, or the
-- neutral one for a family without one (junk, furniture...) or no family.
-- The theme's own table, the same until the theme changes.
function Families.tintOf(family)
    if Families.hasColour(family) then return PUI.Palette.color(family.color) end
    return PUI.Palette.grey(NEUTRAL_GREY)
end

-- ------------------------------------------------------------------ --
-- Family rules
-- ------------------------------------------------------------------ --

-- Display category -> family. "Kitchenware" is not a family: it is Survival
-- when the item does a job in the kitchen and Household when it does not
-- (see kitchenTool). Ranged weapons and reading matter are told apart in
-- code, since their categories mix them with other things.
local CATEGORY_FAMILY = {
    -- Combat. The "*Weapon" categories exist because the item hits things:
    -- those named for a tool (ToolWeapon...) follow the tool instead, and
    -- those in HYBRID_WEAPON below are Combat only when made to fight.
    Weapon             = "Combat",
    WeaponCrafted      = "Combat",
    Explosives         = "Combat",
    Ammo               = "Combat",
    WeaponPart         = "Combat",
    SportsWeapon       = "Leisure",
    InstrumentWeapon   = "Leisure",
    HouseholdWeapon    = "Household",
    JunkWeapon         = "Misc",
    BrokenWeapon       = "Misc",
    AnimalPartWeapon   = "Animal",
    -- Workshop
    Tool               = "Workshop",
    ToolWeapon         = "Workshop",
    -- Survival
    Camping            = "Survival",
    Fishing            = "Survival",
    FishingWeapon      = "Survival",
    Trapping           = "Survival",
    FireSource         = "Survival",
    Gardening          = "Survival",
    GardeningWeapon    = "Survival",
    Cooking            = "Kitchenware",
    CookingWeapon      = "Kitchenware",
    -- Mechanics
    VehicleMaintenance       = "Mechanics",
    VehicleMaintenanceWeapon = "Mechanics",
    -- Food
    Food               = "Food",
    -- Medical
    FirstAid           = "Medical",
    FirstAidWeapon     = "Medical",
    Bandage            = "Medical",
    -- Clothing
    Clothing           = "Clothing",
    ProtectiveGear     = "Clothing",
    Accessory          = "Clothing",
    Bag                = "Clothing",
    -- Materials
    Material           = "Materials",
    MaterialWeapon     = "Materials",
    Paint              = "Materials",
    -- Knowledge
    SkillBook          = "Knowledge",
    RecipeResource     = "Knowledge",
    Cartography        = "Knowledge",
    -- Electric
    Electronics        = "Electric",
    Communications     = "Electric",
    LightSource        = "Electric",
    -- Never looted for, but still belong somewhere.
    Literature         = "Leisure",   -- only writable ones: notebooks, journals
    Sports             = "Leisure",
    Instrument         = "Leisure",
    Entertainment      = "Leisure",
    Teddy              = "Leisure",
    Household          = "Household",
    Security           = "Household",
    Generic            = "Household",
    Container          = "Storage",
    WaterContainer     = "Storage",
    Water              = "Storage",
    Furniture          = "Furniture",
    AnimalPart         = "Animal",
    Animal             = "Animal",
    Bug                = "Animal",
    Corpse             = "Animal",
    Ears               = "Animal",
    Eye                = "Animal",
    Tail               = "Animal",
    Raccoon            = "Animal",
    Frog               = "Animal",
    Fox                = "Animal",
    Duck               = "Animal",
    Bunny              = "Animal",
    Squirrel           = "Animal",
    Spider             = "Animal",
    Mole               = "Animal",
    Hedgehog           = "Animal",
    Goblin             = "Animal",
    Dog                = "Animal",
    Beaver             = "Animal",
    Bear               = "Animal",
    Badger             = "Animal",
    ZedDmg             = "Body",
    Wound              = "Body",
    Appearance         = "Body",
    MaleBody           = "Body",
    Memento            = "Misc",
    Junk               = "Misc",
    Hidden             = "Misc",
    WeaponImprovised   = "Misc",      -- only a smashed bottle: nobody looks for it to fight
}

-- Single items whose category hides what they are good for.
local ITEM_FAMILY = {
    ["Base.UnusableMetal"] = "Materials",   -- filed as junk, used in metalwork
    ["Base.UnusableWood"]  = "Materials",
    ["Base.Splinters"]     = "Materials",
    ["Base.Pan"]           = "Survival",       -- frying pans carry no cooking tag
    ["Base.PanForged"]     = "Survival",
    ["Base.GridlePan"]     = "Survival",
    ["Base.Tobacco"]       = "Misc",        -- filed as tools
    ["Base.TobaccoDried"]  = "Misc",
    ["Base.FishingTrash"]  = "Misc",
    ["Base.Spork"]         = "Household",   -- camping category, but a plain piece of cutlery
    ["Base.WeldingMask"]   = "Clothing",    -- filed as a tool, but it is worn
    ["Base.Bullhorn"]      = "Electric",    -- filed as a tool
    ["Base.FISH_DEV_ITEM"] = "Misc",        -- developer items that never spawn
    ["Base.TestDebugWater"] = "Misc",
    ["Base.DebugFluid"]    = "Misc",
    -- Another real use beats being swung (question 1 of HYBRID_WEAPON): the
    -- game asks for these in its Fitness exercises.
    ["Base.DumbBell"]        = "Knowledge",
    ["Base.DumbBell_Forged"] = "Knowledge",
    ["Base.BarBell"]         = "Knowledge",
    ["Base.BarBell_Forged"]  = "Knowledge",
}

-- Categories whose item is a weapon only by accident of being swingable
-- (sports gear, instruments, brooms, bones...). The family above is what
-- they are; they are Combat instead when, in this order:
--   1. the game gives them no other real use (ITEM_FAMILY says so when it
--      does: dumbbells train Fitness), and
--   2. they are not marked "improvised" (made to fight, like a bat).
-- Anything else is left with its category's family. The top indicator already says
-- which of these hit things.
local HYBRID_WEAPON = {
    SportsWeapon = true, InstrumentWeapon = true, HouseholdWeapon = true,
    JunkWeapon = true, BrokenWeapon = true, AnimalPartWeapon = true,
}

-- Ranged "weapons" in these categories are toys: they follow their category
-- (Misc) instead of being firearms.
local TOY_CATEGORIES = { Memento = true, Junk = true }

-- Worn only for looks: rings, earrings, piercings, necklaces. Misc.
local JEWELLERY = {
    bellybutton = true, ears = true, eartop = true, nose = true,
    necklace = true, necklace_long = true,
    left_middlefinger = true, left_ringfinger = true,
    right_middlefinger = true, right_ringfinger = true,
}

-- The family and top indicator depend only on the item type, so they are
-- cached per full type: { family, hasTopIndicator }. Made again on every run
-- of this file, so edits to the tables above apply at once.
local typeCache = {}

local function hasTag(item, name)
    local tag = ItemTag[name]
    return tag ~= nil and item:hasTag(tag)
end

-- Knives, cleavers, can openers and metal pots and pans do a job; cups,
-- plates and plastic cutlery do not (metal cups are cookable too, but they
-- are the ones tagged as coffee makers).
local function kitchenTool(item)
    return hasTag(item, "SHARP_KNIFE") or hasTag(item, "BUTCHER_ANIMAL") or hasTag(item, "CAN_OPENER")
        or (hasTag(item, "COOKABLE") and hasTag(item, "HAS_METAL") and not hasTag(item, "COFFEE_MAKER"))
end

local function isJewellery(item)
    local loc = item:getScriptItem():getBodyLocation()
    if not loc then return false end
    loc = string.lower(tostring(loc))
    loc = string.gsub(loc, "^.*:", "")
    return JEWELLERY[loc] == true
end

-- The game's own mark for things not made to fight (pens, brooms, rackets).
-- Asked the way vanilla asks for its weapon categories (see XpUpdate.lua).
local function isImprovised(item)
    return item:getScriptItem():containsWeaponCategory(WeaponCategory.IMPROVISED)
end

-- Family id of an item, or nil for one from a category this mod does not
-- know (another mod's).
local function familyId(item)
    local fullType = item:getFullType()
    if ITEM_FAMILY[fullType] then return ITEM_FAMILY[fullType] end
    -- Maps reveal parts of the world map, so they are wanted for themselves.
    if instanceof(item, "MapItem") then return "Knowledge" end
    -- Empty seed packets are filed as recipe resources, but they are the same
    -- gardening item as the full ones (RoseBagSeed_Empty, CarrotBagSeed2_Empty).
    if string.find(item:getType(), "BagSeed%d*_Empty$") then return "Survival" end
    -- Potted plants and planters (in Gardening) are furniture, whatever
    -- their category says.
    if string.find(item:getType(), "^Mov_") then return "Furniture" end

    local cat = item:getDisplayCategory()
    if instanceof(item, "HandWeapon") and item:isRanged() and not (cat and TOY_CATEGORIES[cat]) then
        return "Combat"
    end

    local id = cat and CATEGORY_FAMILY[cat]
    if id == "Kitchenware" then id = kitchenTool(item) and "Survival" or "Household" end
    if cat and HYBRID_WEAPON[cat] and instanceof(item, "HandWeapon") and not isImprovised(item) then id = "Combat" end
    -- The item class is the same whatever a mod does to categories. Food
    -- counts only if it feeds or quenches: cigarettes, feathers and dung are
    -- "food" to the game too.
    if not id then
        if instanceof(item, "Food") then
            id = (item:getHungChange() < 0 or item:getThirstChange() < 0) and "Food" or "Misc"
        elseif instanceof(item, "Clothing") then
            id = "Clothing"
        end
    end
    if id == "Clothing" and isJewellery(item) then id = "Misc" end
    return id
end

-- ------------------------------------------------------------------ --
-- Top indicator rules
-- ------------------------------------------------------------------ --

-- Clothing gets the frame when it protects at all, against bites (leather
-- and padded jackets, armour), bullets or scratches, however little. Plain
-- clothes are worn, not sought out.
-- The game reports a broken garment's protection as zero, and this is
-- cached per type: the first broken pair seen would hide every other pair
-- of its type. So it is read from a new item of the type, which is intact.
local function isProtective(item)
    local intact = instanceItem(item:getFullType()) or item
    return intact:getBiteDefense() > 0 or intact:getBulletDefense() > 0 or intact:getScratchDefense() > 0
end

local function isWearableBag(item)
    if not instanceof(item, "InventoryContainer") then return false end
    local slot = item:canBeEquipped()
    return slot ~= nil and slot ~= ""
end

-- How much of each bad effect a food may have and still be "ready to eat".
-- The game's own units: unhappiness and boredom are on a 0-100 scale (its
-- tooltip draws them at 0.02 per point), stress and thirst on 0-1 (drawn at
-- twice that). A fifth of a bar is a nuisance, not a reason to think twice.
local TOLERATED_UNHAPPINESS = 10
local TOLERATED_BOREDOM = 10
local TOLERATED_STRESS = 0.1
local TOLERATED_THIRST = 0.1

-- Food that can be eaten as it is: not an ingredient the game refuses to
-- let you eat (dried beans, flour, sealed cans: its `CantEat` flag, the one
-- the eat menu checks), not spoiled, not poisonous or needing a cook, and
-- with no bad effect beyond the tolerated ones. Unlike the other rules this
-- depends on the state of the item, so it is asked of the item itself, never
-- cached by type. The unhappiness of food that cooking cures (raw fish,
-- potatoes) is what keeps it from counting until it is cooked.
local function isReadyToEat(item)
    if not instanceof(item, "Food") then return false end
    if item:getScriptItem():isCantEat() then return false end
    if item:isRotten() or item:isBurnt() or item:isTainted() then return false end
    if item:isbDangerousUncooked() and not item:isCooked() then return false end
    return item:getUnhappyChange() <= TOLERATED_UNHAPPINESS
        and item:getBoredomChange() <= TOLERATED_BOREDOM
        and item:getStressChange() <= TOLERATED_STRESS
        and item:getThirstChange() <= TOLERATED_THIRST
end

-- Single items that earn the top indicator though no rule below can tell them apart.
local TOP_INDICATOR_ITEMS = {
    ["Base.Antibiotics"] = true,   -- medicine, but typed as food like the herbs
    ["Base.AntibioticsBox"] = true,   -- twelve of them in one parcel
}

-- What earns the top indicator: things that are kept, looked after or hard to find,
-- as opposed to materials and consumables that are used up. Each rule looks
-- only at the item, never at its family; one match is enough. The top indicator is
-- drawn in the item's tint: its family's colour, or the neutral one.
local TOP_INDICATOR_RULES = {
    function(item) return instanceof(item, "HandWeapon") end,
    function(item) return hasTag(item, "MAGAZINE") end,
    function(item) return instanceof(item, "Clothing") and isProtective(item) end,
    function(item) return isWearableBag(item) end,
    -- Pill bottles (painkillers, sleeping, antidepressants...), not dressings.
    function(item) return hasTag(item, "CONSUMABLE") end,
    function(item) return TOP_INDICATOR_ITEMS[item:getFullType()] == true end,
}

local function hasTopIndicator(item)
    for _, rule in ipairs(TOP_INDICATOR_RULES) do
        if rule(item) then return true end
    end
    return false
end

-- ------------------------------------------------------------------ --
-- Classification
-- ------------------------------------------------------------------ --

-- The volume (1 to 5) of a skill book, or nil for anything else. The scripts
-- number the volumes by the skill level each starts to teach at: 1, 3, 5, 7
-- and 9 (-1 for a book that teaches no skill).
local function skillVolumeOf(item)
    if not item:IsLiterature() then return nil end
    local level = item:getLvlSkillTrained()
    if level < 1 then return nil end
    return math.floor((level + 1) / 2)
end

-- An item type's family, top indicator and skill volume, worked out once.
local function typeInfo(item)
    local fullType = item:getFullType()
    local info = typeCache[fullType]
    if not info then
        info = { family = Families.byId[familyId(item)], hasTopIndicator = hasTopIndicator(item),
                 skillVolume = skillVolumeOf(item) }
        typeCache[fullType] = info
    end
    return info
end

-- Which volume of its skill a book is (1 to 5), or nil when it is not a skill book.
function Families.skillVolume(item)
    return typeInfo(item).skillVolume
end

-- Whether the item's type earns the top indicator by its rules (not food
-- that is ready to eat, which depends on the item's state).
function Families.earnsTopIndicator(item)
    return typeInfo(item).hasTopIndicator
end

-- A bottle or a jug is food only while it holds something to drink: the same
-- test vanilla's double-click uses to choose "drink". Its contents change, so
-- this part is checked on the item itself, not cached by type.
local function holdsBeverage(item)
    local fluid = item:getFluidContainer()
    if not fluid or fluid:isEmpty() then return false end
    local primary = fluid:getPrimaryFluid()
    return primary ~= nil and primary:isCategory(FluidCategory.Beverage)
end

-- An item's family (a Families.LIST table, or nil for none) and whether it
-- has the top indicator: by its type's rules, or for food, by being ready
-- to eat now. Rotten food is no longer food to anyone looting
-- for it: it is an item with no use, Misc. A container with no colour of
-- its own holding a drink is Food.
function Families.classify(item)
    local info = typeInfo(item)
    local family = info.family
    local food = Families.byId.Food
    if family == food and instanceof(item, "Food") and item:isRotten() then
        family = Families.byId.Misc
    elseif not Families.hasColour(family) and holdsBeverage(item) then
        family = food
    end
    return family, info.hasTopIndicator or (family == food and isReadyToEat(item))
end
