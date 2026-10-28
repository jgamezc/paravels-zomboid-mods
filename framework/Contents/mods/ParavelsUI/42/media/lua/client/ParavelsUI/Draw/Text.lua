--[[
    Paravel's UI - text measuring and fitting

    A font's line height has room above and below its letters. Themed text
    is placed by the letters themselves, so margins are the space the eye
    sees: CAPITALS is the sample for ordinary text (the capitals' middle is
    what the eye takes as the middle of a line; J and Q are left out, their
    tails reach below the line), FIGURES for numbers, which have no tails.

    Measuring asks the game's text manager, and the same texts are measured
    every frame (tab names, categories, counts), so every answer is cached.
]]

require "ParavelsUI/Core/PUI"

local Text = PUI.Text or {}
PUI.Text = Text

Text.CAPITALS = "ABCDEFGHIKLMNOPRSTUVWXYZ"
Text.FIGURES = "0123456789"
Text.ELLIPSIS = "..."

-- Cached answers, per font and then per text (or text and room). Wiped
-- whole once they hold this many texts, so names of items long gone and
-- widths of every size a window was dragged through do not pile up.
local CACHE_LIMIT = 2000
local widthCache, fitCache, letterCache = {}, {}, {}
local cachedCount = 0

local function cacheFor(cache, font)
    local perFont = cache[font]
    if not perFont then
        perFont = {}
        cache[font] = perFont
    end
    return perFont
end

local function noteCached()
    cachedCount = cachedCount + 1
    if cachedCount > CACHE_LIMIT then
        table.wipe(widthCache)
        table.wipe(fitCache)
        cachedCount = 0
    end
end

function Text.width(text, font)
    font = font or UIFont.Small
    local widths = cacheFor(widthCache, font)
    local width = widths[text]
    if not width then
        width = getTextManager():MeasureStringX(font, text)
        noteCached()
        widths[text] = width
    end
    return width
end

-- The sample's letter height and the room above them, for a font. A few
-- fonts and samples at most, so never wiped.
local function letterMeasures(font, sample)
    sample = sample or Text.CAPITALS
    local measures = cacheFor(letterCache, font)[sample]
    if not measures then
        local textManager = getTextManager()
        measures = { height = textManager:MeasureStringYReal(font, sample),
                     offset = textManager:MeasureStringYOffset(font, sample) }
        letterCache[font][sample] = measures
    end
    return measures
end

-- Height of the sample's letters, without the font's spare room.
function Text.letterHeight(font, sample)
    return letterMeasures(font, sample).height
end

-- The y to draw text at so that its letters' top lands on `lettersTop`.
function Text.yForLettersTop(lettersTop, font, sample)
    return lettersTop - letterMeasures(font, sample).offset
end

-- The y to draw text at so that its letters are centred in a box of
-- `boxHeight` starting at 0.
function Text.yCentredIn(boxHeight, font, sample)
    local lettersTop = math.floor((boxHeight - Text.letterHeight(font, sample)) / 2 + 0.5)
    return Text.yForLettersTop(lettersTop, font, sample)
end

-- The longest start of `text` that fits `room`, found by halving: a few
-- measures instead of one per letter. The starts are measured without
-- keeping them, as they are not asked for again.
local function longestFittingStart(text, room, font)
    local textManager = getTextManager()
    local fits, tooLong = 0, string.len(text) + 1
    while tooLong - fits > 1 do
        local length = math.floor((fits + tooLong) / 2)
        if textManager:MeasureStringX(font, string.sub(text, 1, length)) <= room then
            fits = length
        else
            tooLong = length
        end
    end
    return fits
end

local function fitUncached(text, room, font)
    if Text.width(text, font) <= room then return text end
    local length = longestFittingStart(text, room - Text.width(Text.ELLIPSIS, font), font)
    while length > 0 and string.sub(text, length, length) == " " do length = length - 1 end
    if length == 0 then return "" end
    return string.sub(text, 1, length) .. Text.ELLIPSIS
end

-- A text too long for `room` pixels ends in "...", with no space before the dots.
function Text.fit(text, room, font)
    font = font or UIFont.Small
    local fits = cacheFor(fitCache, font)
    local perRoom = fits[text]
    if not perRoom then
        perRoom = {}
        fits[text] = perRoom
    end
    local fitted = perRoom[room]
    if not fitted then
        fitted = fitUncached(text, room, font)
        noteCached()
        perRoom[room] = fitted
    end
    return fitted
end
