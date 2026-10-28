--[[
    Paravel's Enhanced Tooltips - liquids

    What the tooltip of an item with a container of liquid says: how much it
    holds, what the liquid is and how much of the container it fills, in the
    liquid's own colour; for a mixture, the mixture and each liquid in it;
    and that the liquid is poisonous. (In the game's debug mode its fluid
    properties are listed too: those are not rebuilt, and nothing in Lua can
    read them.)
]]

require "ParavelsEnhancedTooltips/Content/Questions"

local Questions = PET.Questions

local Fluids = PET.Fluids or {}
PET.Fluids = Fluids

-- What the rows read from the container.
local CONTAINER_QUESTIONS = {
    "getAmount", "getCapacity", "isEmpty",
    "isPoisonous", "getPoisonEffect", "isTainted", "createFluidSample",
}
local SAMPLE_QUESTIONS = {
    "size",
}
-- The liquids of a sample are asked by position: the game gives their
-- instances to Lua without letting it use them.
-- (and released: asking whether it can be would release it)
local SAMPLE_BY_POSITION = { "getFluid", "getPercentage", "release" }

-- Whether the container is on an item on the ground, which the game also
-- lists.
local function worldContainerRefusal(item)
    local world = item:getWorldItem()
    if world ~= nil and Questions.refuses(world, "getFluidContainer", Questions.isPresent) then return "worldFluid" end
    return nil
end

function Fluids.refusal(item)
    local container = item:getFluidContainer()
    if container == nil then return worldContainerRefusal(item) end
    if FluidUtil == nil or FluidUtil.getFractionFormatted == nil then return "getFractionFormatted (not askable)" end
    if FluidType == nil or PoisonEffect == nil then return "FluidType" end
    local reason = Questions.firstRefusal(container, CONTAINER_QUESTIONS)
    if reason or container:isEmpty() then return reason end
    local sample = container:createFluidSample()
    reason = Questions.firstRefusal(sample, SAMPLE_QUESTIONS)
    for _, method in ipairs(SAMPLE_BY_POSITION) do
        reason = reason or Questions.refusalIfMissing(sample, method)
    end
    if not reason and sample:size() > 0 then
        local fluid = sample:getFluid(0)
        reason = Questions.firstRefusal(fluid, {
            "isPoisonous", "getFluidType", "getTranslatedName",
        })
    end
    sample:release()
    return reason
end

-- Whether the game tells tainted water from other water by its type in the
-- liquids of a mixture (an option of the game's rules).
function Fluids.separatesTaintedWater()
    return SandboxVars ~= nil and SandboxVars.EnableTaintedWaterText == true
end

-- The liquids of a sample, grouped as the game groups them: by name, or by
-- kind when tainted water is told apart. Each has the part of the whole it is.
local function groupedLiquids(sample)
    local liquids = {}
    for index = 0, sample:size() - 1 do
        local fluid = sample:getFluid(index)
        table.insert(liquids, {
            name = fluid:getTranslatedName(), fluid = fluid, share = sample:getPercentage(index),
        })
    end
    table.sort(liquids, function(a, b) return a.name < b.name end)
    local groups = {}
    for _, liquid in ipairs(liquids) do
        local last = groups[#groups]
        local same = last ~= nil and (Fluids.separatesTaintedWater() and last.fluid == liquid.fluid or last.name == liquid.name)
        if same then last.share = last.share + liquid.share else table.insert(groups, liquid) end
    end
    return groups
end

local function liquidRows(container, sample)
    local capacity, amount = container:getCapacity(), container:getAmount()
    local firstName = sample:getFluid(0):getTranslatedName()
    local oneLiquid = sample:size() == 1 or (sample:size() == 2 and sample:getFluid(1):getTranslatedName() == firstName)
    if oneLiquid then
        return { { label = firstName .. ":", progress = amount / capacity } }
    end
    local rows = {
        { label = getText("Fluid_Mixture") .. ":", progress = amount / capacity },
        { label = getText("Fluid_Fluids") .. ":" },
    }
    for _, group in ipairs(groupedLiquids(sample)) do
        table.insert(rows, { label = group.name .. ":", labelMeaning = "muted", progress = group.share })
    end
    return rows
end

-- Whether the poison warning shows: when a liquid other than tainted water is
-- poisonous, or the liquid is not tainted, or tainted water is told apart.
local function poisonShows(sample, container)
    if not container:isPoisonous() or container:getPoisonEffect() == PoisonEffect.None then return false end
    for index = 0, sample:size() - 1 do
        local fluid = sample:getFluid(index)
        if fluid:getFluidType() ~= FluidType.TaintedWater and fluid:isPoisonous() then return true end
    end
    return not container:isTainted() or Fluids.separatesTaintedWater()
end

function Fluids.rows(item)
    local container = item:getFluidContainer()
    if container == nil then return {} end
    local rows = { {
        label = getText("Fluid_Amount") .. ":",
        value = FluidUtil.getFractionFormatted(container:getAmount(), container:getCapacity()),
    } }
    if container:isEmpty() then return rows end
    local sample = container:createFluidSample()
    for _, row in ipairs(liquidRows(container, sample)) do table.insert(rows, row) end
    if poisonShows(sample, container) then table.insert(rows, { label = getText("Tooltip_tainted"), meaning = "bad" }) end
    sample:release()
    return rows
end
