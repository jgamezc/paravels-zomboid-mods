--[[
    Paravel's Enhanced Tooltips - asking the game

    Some of what the game's Java code reads to write a tooltip cannot be
    asked from Lua (the method is not exposed). Each source asks through
    here: an answer that cannot be had is UNKNOWN, and a source refuses an
    item it cannot be sure about, so that item keeps the game's tooltip.
]]

require "ParavelsEnhancedTooltips/Core/PET"

local Questions = PET.Questions or {}
PET.Questions = Questions

Questions.UNKNOWN = Questions.UNKNOWN or {}
local UNKNOWN = Questions.UNKNOWN

-- What `subject:method(...)` answers, or UNKNOWN when Lua cannot ask it.
function Questions.ask(subject, method, ...)
    local fn = subject[method]
    if not fn then return UNKNOWN end
    return fn(subject, ...)
end

-- The reason to refuse if the answer of `subject:method(...)` means a line
-- not rebuilt (`blocks` says so), or if it cannot be asked; else nil.
function Questions.refusalFor(subject, method, blocks, ...)
    local answer = Questions.ask(subject, method, ...)
    if answer == UNKNOWN then return method .. " (not askable)" end
    if blocks(answer) then return method end
    return nil
end

-- The reason to refuse if `subject:method(...)` cannot be asked, whatever
-- the answer is.
function Questions.askRefusal(subject, method, ...)
    return Questions.refusalFor(subject, method, Questions.neverBlocks, ...)
end

function Questions.refuses(subject, method, blocks, ...)
    return Questions.refusalFor(subject, method, blocks, ...) ~= nil
end

-- The reason to refuse if `subject` has no `method` to ask, which is not
-- called: for a method that needs arguments to be called.
function Questions.refusalIfMissing(subject, method)
    if subject[method] == nil then return method .. " (not askable)" end
    return nil
end

-- Whether `subject:method(...)` answers true; false when it cannot be asked.
function Questions.isOn(subject, method, ...)
    return Questions.ask(subject, method, ...) == true
end

-- Answers that block.
function Questions.isPresent(answer) return answer ~= nil end
function Questions.isTrue(answer) return answer == true end
function Questions.isFalse(answer) return answer == false end
function Questions.neverBlocks() return false end

-- The first reason to refuse among `questions` about `subject`, with the
-- extra arguments, or nil. A question is the name of a method that only
-- needs to be askable, or { name, blocks } when some answers refuse too.
function Questions.firstRefusal(subject, questions, ...)
    for _, question in ipairs(questions) do
        local reason
        if type(question) == "string" then
            reason = Questions.askRefusal(subject, question, ...)
        else
            reason = Questions.refusalFor(subject, question[1], question[2], ...)
        end
        if reason then return reason end
    end
    return nil
end
