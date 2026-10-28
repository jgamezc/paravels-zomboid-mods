--[[
    Paravel's UI - namespace and shared plumbing

    A framework for mods that restyle or add to the game's interface. It
    holds what every such mod shares: the theme (Theme/), drawing that
    knows no theme (Draw/), shapes drawn in the theme (Shapes/) and themed
    controls (Controls/). It knows nothing of the
    mods built on it; they require its files and read its modules through
    PUI, so a theme the player picks applies to all of them alike.

    PUI is the framework's only global. Every file adds one module to it,
    named after the file (Draw/Draw.lua is PUI.Draw), and keeps everything
    else local. Modules are created with `PUI.X = PUI.X or {}`, and every
    file can run again over the same table: functions are replaced, state
    kept on the table survives, and nothing is installed twice. Mods built
    on it follow the same rules with their own global.

    This file holds what every module needs: how to replace a game method
    (PUI.override) and how to listen to a game event (PUI.listen).
]]

PUI = PUI or {}

-- ------------------------------------------------------------------ --
-- Game method overrides
-- ------------------------------------------------------------------ --

-- The game's own methods, per class table, captured the first time each one
-- is overridden. Kept across reloads, so re-running a file never wraps our
-- own replacement. Shared by every mod on the framework: a method replaced
-- twice keeps only the last replacement.
PUI.vanillaMethods = PUI.vanillaMethods or {}

-- Replaces class[methodName] with `replacement`, which receives the game's
-- version first: replacement(vanilla, self, ...). Call vanilla(self, ...) to
-- run what the game would have run.
function PUI.override(class, methodName, replacement)
    local originals = PUI.vanillaMethods[class]
    if not originals then
        originals = {}
        PUI.vanillaMethods[class] = originals
    end
    if originals[methodName] == nil then originals[methodName] = class[methodName] end
    local vanilla = originals[methodName]
    class[methodName] = function(...) return replacement(vanilla, ...) end
end

-- Runs fn(...) with target's fields set to `fields` ({ name = value }), then
-- puts back what each held before (nil included), even when fn fails, so an
-- error never leaves a game object or function swapped. Returns fn's first
-- result. This is how something the game calls is changed while one of its
-- own methods runs. Only the target's own fields are kept: a method it
-- inherits stays inherited. An error is raised again with where it
-- happened: the game's pcall also returns the failed call's stack trace,
-- which raising the message alone would lose.
function PUI.withFields(target, fields, fn, ...)
    local previous = {}
    for name, value in pairs(fields) do
        previous[name] = rawget(target, name)
        target[name] = value
    end
    local ok, result, stackTrace = pcall(fn, ...)
    for name in pairs(fields) do target[name] = previous[name] end
    if not ok then
        error(stackTrace and (tostring(result) .. "\n" .. tostring(stackTrace)) or result, 0)
    end
    return result
end

-- ------------------------------------------------------------------ --
-- Game events
-- ------------------------------------------------------------------ --

PUI.eventHandlers = PUI.eventHandlers or {}

-- Adds `handler` to a game event (Events.OnGameStart...) under a unique name.
-- Listening again under the same name (a file run again) replaces the
-- previous handler instead of adding a second one. Names start with the
-- module's (and mod's) name, so mods never share one.
function PUI.listen(event, handlerName, handler)
    local previous = PUI.eventHandlers[handlerName]
    if previous then previous.event.Remove(previous.handler) end
    event.Add(handler)
    PUI.eventHandlers[handlerName] = { event = event, handler = handler }
end

-- ------------------------------------------------------------------ --
-- Small helpers
-- ------------------------------------------------------------------ --

-- Kahlua does not provide next(), so emptiness is checked with pairs().
function PUI.isEmpty(t)
    for _ in pairs(t) do return false end
    return true
end

function PUI.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end
