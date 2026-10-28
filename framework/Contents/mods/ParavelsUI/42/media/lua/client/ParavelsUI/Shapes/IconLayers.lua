--[[
    Paravel's UI - icon layers

    Legibility layers drawn under an icon, back to front: a halo in the
    theme's glow and a shadow in the theme's shadow. Windows stay
    translucent, so these separate a sprite from whatever shows through
    instead of hiding it behind a plate. Whether each is drawn, and how
    strong the halo is, is the caller's to decide (a mod's player options).
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local Theme = PUI.Theme

local IconLayers = PUI.IconLayers or {}
PUI.IconLayers = IconLayers

-- The soft glow behind an icon of iconSize at x, y, `scale` times the
-- icon's size (a grid cell's size relative to its icon, so an icon in a
-- row looks as it does in a cell).
function IconLayers.drawHalo(element, x, y, iconSize, scale, alpha)
    alpha = alpha * Theme.glowAlpha()
    if alpha <= 0 then return end
    local haloSize = math.floor(iconSize * scale + 0.5)
    local offset = math.floor((haloSize - iconSize) / 2)
    Draw.spriteScaled(element, "Glow", x - offset, y - offset, haloSize, haloSize, Theme.glowColor(), alpha)
end

-- The icon's silhouette: `texture` drawn as the icon is (`fit`, as
-- Draw.texture takes it) in the theme's shadow colour, offset down and
-- right by the theme's shadow offset, so it always has the icon's size and
-- place.
function IconLayers.drawShadow(element, texture, x, y, iconSize, alpha, fit)
    local offset = Theme.shadowOffset()
    alpha = alpha * Theme.shadowAlpha()
    if not texture or offset <= 0 or alpha <= 0 then return end
    Draw.texture(element, texture, x + offset, y + offset, iconSize, iconSize, Theme.shadowColor(), alpha, fit)
end
