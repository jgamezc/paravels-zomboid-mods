--[[
    Paravel's Enhanced Inventory - list, grid and compact views

    Each inventory pane shows the list (vanilla's "details" mode, in the
    theme), the grid, or the compact view: the grid in a window with no
    more than it needs (no footer, tabs without names, an unseen resize
    corner). The grid reuses vanilla's dormant "icons" mode:
    ISInventoryPane:prerender() and render() already dispatch to
    rendericons() when pane.mode == "icons"; the compact view is that mode
    too, so everything about the grid applies to it (ViewMode.isGrid), and
    only the window asks for ViewMode.isCompact. The pane's view is
    pane.pei_view (ViewMode.setView), which pane.mode follows. It is saved per
    window in layout.ini (Inventory/SavedLayout.lua).

    Pane methods are replaced for one view only, with ViewMode.overrideForGrid
    or ViewMode.overrideForList: in a view with no version of its own the
    game's method runs. A method can have a version for each view.
    Everything that does not depend on rows or cells (context menus,
    transfers, drop targets, double-click actions) is left to vanilla code.
]]

require "ISUI/ISInventoryPane"
require "ParavelsEnhancedInventory/Inventory/Grid/GridState"

local GridState = PEI.GridState

local ViewMode = PEI.ViewMode or {}
PEI.ViewMode = ViewMode

ViewMode.GRID = "icons"
ViewMode.LIST = "details"

-- The views, in the order the title bar's button goes through them.
ViewMode.VIEWS = { "list", "grid", "compact" }

-- Whether `name` is one of ViewMode.VIEWS.
function ViewMode.isView(name)
    for _, view in ipairs(ViewMode.VIEWS) do
        if view == name then return true end
    end
    return false
end

-- "list", "grid" or "compact".
function ViewMode.viewOf(pane)
    return pane.pei_view or "list"
end

-- The grid's cells, in the grid or the compact view.
function ViewMode.isGrid(pane)
    return ViewMode.viewOf(pane) ~= "list"
end

function ViewMode.isCompact(pane)
    return ViewMode.viewOf(pane) == "compact"
end

-- Each replaced method's versions, by method name: { [ViewMode.GRID] = fn,
-- [ViewMode.LIST] = fn }. One replacement of the game's method picks the
-- pane's view's, so a method can have one for each view.
ViewMode.versions = ViewMode.versions or {}

local function overrideFor(view, methodName, version)
    local versions = ViewMode.versions[methodName] or {}
    ViewMode.versions[methodName] = versions
    versions[view] = version
    PUI.override(ISInventoryPane, methodName, function(vanilla, pane, ...)
        local own = ViewMode.versions[methodName][ViewMode.isGrid(pane) and ViewMode.GRID or ViewMode.LIST]
        if not own then return vanilla(pane, ...) end
        return own(vanilla, pane, ...)
    end)
end

-- Replaces an ISInventoryPane method while the pane shows the grid:
-- gridVersion(vanilla, pane, ...) runs for the grid.
function ViewMode.overrideForGrid(methodName, gridVersion)
    overrideFor(ViewMode.GRID, methodName, gridVersion)
end

-- The same for the list: listVersion(vanilla, pane, ...) runs for the list.
function ViewMode.overrideForList(methodName, listVersion)
    overrideFor(ViewMode.LIST, methodName, listVersion)
end

-- `view`: one of ViewMode.VIEWS. Between the grid and the compact view only
-- the window changes; the cells, their selection and open stacks stay.
function ViewMode.setView(pane, view)
    local wasGrid = ViewMode.isGrid(pane)
    pane.pei_view = view
    if ViewMode.isGrid(pane) == wasGrid then return end
    pane.mode = ViewMode.isGrid(pane) and ViewMode.GRID or ViewMode.LIST
    GridState.reset(pane)
    -- The entries are listed again in the new view's order: the grid's
    -- (Grid/GridState.lua), or vanilla's back in the list.
    if pane.itemslist then pane:refreshContainer() end
    pane.mouseOverOption = 0
    pane.smoothScrollTargetY = nil
    pane:setYScroll(0)
end

-- The view after `view` in ViewMode.VIEWS, back to the first after the last.
function ViewMode.nextView(view)
    for index, each in ipairs(ViewMode.VIEWS) do
        if each == view then return ViewMode.VIEWS[index % #ViewMode.VIEWS + 1] end
    end
    return ViewMode.VIEWS[1]
end

function ViewMode.cycle(pane)
    ViewMode.setView(pane, ViewMode.nextView(ViewMode.viewOf(pane)))
end
