--[[
    Paravel's UI - draw recording

    Drawing from Lua is slow in the game: every helper call and every call
    into Java costs, and something drawn every frame from a few dozen of
    them (a grid cell) adds up to milliseconds. What it draws only changes
    now and then, so it can be drawn once into a recording, a flat list of
    the Java draw calls it made, and the list replayed every frame: one Java
    call per shape and nothing else.

    DrawRecording.record(draw, ...) runs draw(element, ...) with a stand-in
    element whose javaObject writes the calls down instead of drawing.
    Everything in Draw/Draw.lua draws through element.javaObject, so any
    drawing built from it can be recorded. DrawRecording.replay(element,
    recording, dx, dy) draws it on a real element, moved by dx, dy.
    DrawRecording.replayCached keeps recordings by a key, for shapes drawn
    the same way in many places or frames (rounded outlines).
]]

require "ParavelsUI/Core/PUI"

local DrawRecording = PUI.DrawRecording or {}
PUI.DrawRecording = DrawRecording

-- The recorded methods; each recorded call is { kind, its arguments... }.
local SCALED_COLOR = 1    -- DrawTextureScaledColor(texture, x, y, w, h, r, g, b, a)
local SUB_TEXTURE = 2     -- DrawSubTextureRGBA(texture, subX, subY, subW, subH, x, y, w, h, r, g, b, a)
local TEXT = 3            -- DrawText(font, text, x, y, r, g, b, a)
local SCALED_ASPECT = 4   -- DrawTextureScaledAspect(texture, x, y, w, h, r, g, b, a)
local TEXTURE_ICON = 5    -- DrawTextureIcon(texture, x, y, w, h, r, g, b, a)
local ITEM_ICON = 6       -- DrawItemIcon(item, x, y, a, w, h)

local recorder = { calls = nil }

function recorder:DrawTextureScaledColor(texture, x, y, w, h, r, g, b, a)
    local calls = self.calls
    calls[#calls + 1] = { SCALED_COLOR, texture, x, y, w, h, r, g, b, a }
end

function recorder:DrawSubTextureRGBA(texture, subX, subY, subW, subH, x, y, w, h, r, g, b, a)
    local calls = self.calls
    calls[#calls + 1] = { SUB_TEXTURE, texture, subX, subY, subW, subH, x, y, w, h, r, g, b, a }
end

function recorder:DrawText(font, text, x, y, r, g, b, a)
    local calls = self.calls
    calls[#calls + 1] = { TEXT, font, text, x, y, r, g, b, a }
end

function recorder:DrawTextureScaledAspect(texture, x, y, w, h, r, g, b, a)
    local calls = self.calls
    calls[#calls + 1] = { SCALED_ASPECT, texture, x, y, w, h, r, g, b, a }
end

function recorder:DrawTextureIcon(texture, x, y, w, h, r, g, b, a)
    local calls = self.calls
    calls[#calls + 1] = { TEXTURE_ICON, texture, x, y, w, h, r, g, b, a }
end

function recorder:DrawItemIcon(item, x, y, a, w, h)
    local calls = self.calls
    calls[#calls + 1] = { ITEM_ICON, item, x, y, a, w, h }
end

local RECORDING_ELEMENT = { javaObject = recorder }

-- The draw calls draw(element, ...) makes, as a recording. A recording
-- made while another is (a recorded shape that draws a cached one) goes
-- on with the outer one afterwards: what the inner one replays onto the
-- recording element is written into the outer one.
function DrawRecording.record(draw, ...)
    local outer = recorder.calls
    local calls = {}
    recorder.calls = calls
    draw(RECORDING_ELEMENT, ...)
    recorder.calls = outer
    return calls
end

-- Draws a recording on `element`, moved by dx, dy.
function DrawRecording.replay(element, recording, dx, dy)
    local java = element.javaObject
    for i = 1, #recording do
        local c = recording[i]
        local kind = c[1]
        if kind == SCALED_COLOR then
            java:DrawTextureScaledColor(c[2], c[3] + dx, c[4] + dy, c[5], c[6], c[7], c[8], c[9], c[10])
        elseif kind == TEXT then
            java:DrawText(c[2], c[3], c[4] + dx, c[5] + dy, c[6], c[7], c[8], c[9])
        elseif kind == SUB_TEXTURE then
            java:DrawSubTextureRGBA(c[2], c[3], c[4], c[5], c[6], c[7] + dx, c[8] + dy, c[9], c[10],
                c[11], c[12], c[13], c[14])
        elseif kind == ITEM_ICON then
            java:DrawItemIcon(c[2], c[3] + dx, c[4] + dy, c[5], c[6], c[7])
        elseif kind == SCALED_ASPECT then
            java:DrawTextureScaledAspect(c[2], c[3] + dx, c[4] + dy, c[5], c[6], c[7], c[8], c[9], c[10])
        elseif kind == TEXTURE_ICON then
            java:DrawTextureIcon(c[2], c[3] + dx, c[4] + dy, c[5], c[6], c[7], c[8], c[9], c[10])
        end
    end
end

-- Recordings by key, for replayCached. Wiped whole when they grow past the
-- limit, so the sizes a window was dragged through do not pile up.
local CACHE_LIMIT = 500
local cached, cachedCount = {}, 0

-- Draws what draw(element, ...) draws at 0, 0, moved to x, y. It is recorded
-- the first time `key` is asked for and replayed afterwards, so the key must
-- name everything the drawing depends on.
function DrawRecording.replayCached(element, key, x, y, draw, ...)
    local recording = cached[key]
    if not recording then
        if cachedCount >= CACHE_LIMIT then
            table.wipe(cached)
            cachedCount = 0
        end
        recording = DrawRecording.record(draw, ...)
        cached[key] = recording
        cachedCount = cachedCount + 1
    end
    DrawRecording.replay(element, recording, x, y)
end
