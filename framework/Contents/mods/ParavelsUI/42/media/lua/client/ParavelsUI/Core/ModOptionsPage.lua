--[[
    Paravel's UI - entries on the game's Mods options page

    The Mods options page (PZAPI.ModOptions) is how players set what a mod
    lets them set, and the game saves those values in ModOptions.ini. A mod
    describes its settings as data and ModOptionsPage.register does the
    rest: it makes the entry, keeps a plain table of the current values
    up to date and calls the mod back whenever they change.

    What the game makes this take care of:
    - It takes each mod's entry once: a file run again would add a second
      one, so the previous entry is dropped first and its values kept.
    - Each control copies the entry's onChange as it is added, so it is set
      before any control.
    - A control writes its option's value only when the player clicks
      Apply; values are stored as the control moves, so they apply at once.
      Leaving the page with Back keeps them for the session (the game does
      not take them back) without saving them.
    - ModOptions.ini is only read when the Mods page opens; it is read once
      at game start, so saved values apply from the first frame.
]]

require "ParavelsUI/Core/PUI"
require "PZAPI/ModOptions"

local ModOptionsPage = PUI.ModOptionsPage or {}
PUI.ModOptionsPage = ModOptionsPage

-- Each registered entry by mod id: { options, spec, values }. Kept across
-- reloads, so the values table a mod holds stays the same.
ModOptionsPage.entries = ModOptionsPage.entries or {}

-- A saved value from an older version (a choice that no longer exists, a
-- setting added since) gives way to the default.
local function validOrDefault(def, value)
    if value == nil or (def.type == "choice" and not def.choices[value]) then return def.default end
    return value
end

local function labelKey(spec, def)
    return spec.keyPrefix .. "Opt_" .. def.id
end

-- The entry made for `modId` by an earlier run, taken off the page; and its
-- values by option id (empty the first time).
local function takeOffPrevious(modId)
    local kept = {}
    local previous = PZAPI.ModOptions:getOptions(modId)
    if not previous then return kept end
    for id, option in pairs(previous.dict) do kept[id] = option:getValue() end
    for i, registered in ipairs(PZAPI.ModOptions.Data) do
        if registered == previous then
            table.remove(PZAPI.ModOptions.Data, i)
            break
        end
    end
    PZAPI.ModOptions.Dict[modId] = nil
    return kept
end

local function addControl(options, spec, def, value)
    local label = labelKey(spec, def)
    if def.type == "slider" then
        options:addSlider(def.id, label, def.min, def.max, def.step, value)
    elseif def.type == "choice" then
        local combo = options:addComboBox(def.id, label)
        for i, choice in ipairs(def.choices) do combo:addItem(choice, i == value) end
    else
        options:addTickBox(def.id, label, value)
    end
end

-- Copies every option's value into the entry's values and tells the mod.
local function readValues(entry)
    for _, def in ipairs(entry.spec.definitions) do
        local option = entry.options.dict[def.id]
        entry.values[def.id] = validOrDefault(def, option and option:getValue())
    end
    entry.spec.onChange(entry.values)
end

-- Keeps what a control reports as it moves, so the option's getValue()
-- gives the new value at once instead of after Apply.
local function store(option, value)
    if option.type == "combobox" then option.selected = value
    else option.value = value end
end

function ModOptionsPage.onControlMoved(modId, option, value)
    local entry = ModOptionsPage.entries[modId]
    if not entry then return end
    store(option, value)
    readValues(entry)
end

--[[
    Adds a mod's entry to the page and returns the table of its values, by
    setting id, which stays up to date. `spec`:
        modId        the mod's id
        titleKey     translation key of the entry's title
        keyPrefix    start of the mod's translation keys ("IGUI_PEI_"): a
                     setting's label is <keyPrefix>Opt_<id>, a section's
                     title <keyPrefix>Section_<section>
        definitions  the settings, in the order shown: { id, type =
                     "tickbox" | "slider" | "choice", default, min,
                     max, step (sliders), choices (translation keys),
                     section (optional) }
        onChange     function(values), called once the values are read and
                     whenever they change
]]
function ModOptionsPage.register(spec)
    local kept = takeOffPrevious(spec.modId)
    local options = PZAPI.ModOptions:create(spec.modId, spec.titleKey)
    local modId = spec.modId
    -- Looked up through PUI each time, so a file run again takes effect.
    options.onChange = function(option, value) PUI.ModOptionsPage.onControlMoved(modId, option, value) end

    local section
    for _, def in ipairs(spec.definitions) do
        if def.section and def.section ~= section then
            section = def.section
            options:addTitle(spec.keyPrefix .. "Section_" .. section)
        end
        addControl(options, spec, def, validOrDefault(def, kept[def.id]))
    end

    local entry = ModOptionsPage.entries[modId] or { values = {} }
    entry.options, entry.spec = options, spec
    ModOptionsPage.entries[modId] = entry
    readValues(entry)
    return entry.values
end

PUI.listen(Events.OnGameStart, "PUI.ModOptionsPage.loadSaved", function()
    PZAPI.ModOptions:load()
    for _, entry in pairs(PUI.ModOptionsPage.entries) do readValues(entry) end
end)
