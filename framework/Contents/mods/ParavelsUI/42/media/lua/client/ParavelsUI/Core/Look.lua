--[[
    Paravel's UI - the look changed

    One signal that what is drawn may have to be made again: Look.changed()
    is called whenever something every mod's drawing depends on changes
    (the theme, a mod's player options), and Look.revision goes up.

    Anything worked out from those (a style read once for hundreds of
    draws) is made through Look.derived, which makes it again only after a
    change, so nothing has to be told.
]]

require "ParavelsUI/Core/PUI"

local Look = PUI.Look or {}
PUI.Look = Look

Look.revision = Look.revision or 0

function Look.changed()
    Look.revision = Look.revision + 1
end

-- A function that returns build()'s result, made again only when the look
-- has changed since it was last made.
function Look.derived(build)
    local value, madeAt = nil, nil
    return function()
        if madeAt ~= Look.revision then
            value = build()
            madeAt = Look.revision
        end
        return value
    end
end
