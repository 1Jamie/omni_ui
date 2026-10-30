-- OmniUI Layout & Vector Typography Engine
-- Provides scalable typography, immediate-mode cards, slots, badges, buttons, and design primitives.

local RetroFont = require("src.render.Font")
local Theme = require("mods.omni_ui.core.Theme")

local Layout = {}

-- nil follows the MENU ANIMATIONS mod option. true/false forces the mode.
Layout.menuAnimations = nil

function Layout.animationsEnabled()
  if Layout.menuAnimations ~= nil then
    return Layout.menuAnimations ~= false
  end
  local overlay = package.loaded["mods.omni_ui.core.ModernOverlay"]
  local opts = overlay and overlay.options
  if opts and type(opts.get) == "function" then
    return opts:get("menu_animations") ~= false
  end
  return true
end

-- Cache of TrueType vector fonts keyed by logical role
local fontCache = {}

local UiFont = nil
local okUi, uiMod = pcall(require, "src.render.UiFont")
if okUi and uiMod then UiFont = uiMod end

local FONT_SIZES = {
  title    = 20,
  headline = 16,
  button   = 14,
  stat     = 20,
  body     = 13,
  caption  = 12,
  tiny     = 11,
}

local COMPACT_FONT_SIZES = {
  title    = 16,
  headline = 14,
  button   = 12,
  stat     = 16,
  body     = 11,
  caption  = 10,
  tiny     = 9,
}

--- Resolves responsive viewport metrics, aspect ratio, orientation, and device breakpoints.
--- @param w number|nil
--- @param h number|nil
--- @param viewport table|nil
--- @return table Context metrics { width, height, aspect, isPortrait, isSquare, isLandscape, isCompact, isUltraCompact, isLarge, isUltrawide, breakpoint, scale, dpiScale, padding }
function Layout.getContext(w, h, viewport)
  local vw = w
  local vh = h
  if not vw or not vh or vw <= 0 or vh <= 0 then
    if type(viewport) == "table" then
      vw = viewport.width or viewport.gameWidth or vw
      vh = viewport.height or viewport.gameHeight or vh
    end
  end
  if not vw or not vh or vw <= 0 or vh <= 0 then
    if love and love.graphics and love.graphics.getDimensions then
      vw, vh = love.graphics.getDimensions()
    end
  end
  vw = vw or 800
  vh = vh or 600

  local aspect = vw / math.max(1, vh)
  local isPortrait = aspect < 0.95
  local isSquare = aspect >= 0.95 and aspect <= 1.25
  local isLandscape = aspect > 1.25

  local isUltraCompact = (vw < 480 or vh < 380)
  local isCompact = (vw < 640 or vh < 460) or isUltraCompact
  local isLarge = (vw >= 1100 and vh >= 700)
  local isUltrawide = (aspect >= 1.9 or vw >= 1600)

  local dpiScale = 1.0
  if love and love.window and love.window.getDPIScale then
    local ok, d = pcall(love.window.getDPIScale)
    if ok and type(d) == "number" and d > 0 then dpiScale = d end
  end

  local breakpoint = "md"
  if isUltraCompact then
    breakpoint = "xs"
  elseif isCompact then
    breakpoint = "sm"
  elseif isLarge or isUltrawide then
    breakpoint = "lg"
  end

  local scale = 1.0
  if isUltraCompact then
    scale = 0.80
  elseif isCompact then
    scale = 0.90
  elseif isLarge then
    scale = 1.10
  end

  local padding = isUltraCompact and 8 or (isCompact and 12 or 16)
  local isTallPortrait = isPortrait and (aspect <= 0.62 or vh >= 660)
  local isUltraTallPortrait = isPortrait and (aspect <= 0.52 or vh >= 780)

  local portraitContainerRatio = 0.64
  if isUltraTallPortrait then
    portraitContainerRatio = 0.74
  elseif isTallPortrait then
    portraitContainerRatio = 0.70
  end

  local safeInsetTop = isPortrait and (vh < 380 and 32 or 48) or 0

  return {
    width = vw,
    height = vh,
    aspect = aspect,
    isPortrait = isPortrait,
    isSquare = isSquare,
    isLandscape = isLandscape,
    isCompact = isCompact,
    isUltraCompact = isUltraCompact,
    isLarge = isLarge,
    isUltrawide = isUltrawide,
    isTallPortrait = isTallPortrait,
    isUltraTallPortrait = isUltraTallPortrait,
    portraitContainerRatio = portraitContainerRatio,
    dpiScale = dpiScale,
    breakpoint = breakpoint,
    scale = scale,
    padding = padding,
    safeInsetTop = safeInsetTop,
  }
end

function Layout.getFont(name, opts)
  opts = opts or {}
  local isCompact = opts.compact
  local key = tostring(name) .. (isCompact and "_compact" or "_std")
  if fontCache[key] then return fontCache[key] end

  local sizes = isCompact and COMPACT_FONT_SIZES or FONT_SIZES
  local size = opts.size or sizes[name] or FONT_SIZES[name] or 13

  local f = nil
  if love and love.graphics and love.graphics.newFont then
    local ok, res = pcall(love.graphics.newFont, size)
    if ok and res then
      if UiFont and UiFont.attach then
        local okAtt, attached = pcall(UiFont.attach, res, size)
        if okAtt and attached then res = attached end
      end
      f = res
    end
  end
  fontCache[key] = f
  return f
end

--- Cleans and expands cart compressed glyph tokens (e.g. <PO><KE>GEAR -> POKéGEAR, <PK><MN> -> POKéMON, #DEX -> POKéDEX).
--- Also normalizes GBA control escapes (\c[x], \p, \l, \w[x], {PLAYER}, {RIVAL}).
--- @param text string|nil
--- @return string
function Layout.cleanText(text)
  if not text then return "" end
  text = tostring(text)
  -- 1. Gen 1/2 Cart macro glyph tokens
  text = text:gsub("<[Pp][Oo]><[Kk][Ee]>", "POKé")
  text = text:gsub("<[Pp][Kk]><[Mm][Nn]>", "POKéMON")
  text = text:gsub("<[Pp][Oo][Kk][Ee]>", "POKé")
  text = text:gsub("<[Pp][Oo][Kk][Ee][Mm][Oo][Nn]>", "POKéMON")
  text = text:gsub("#[Dd][Ee][Xx]", "POKéDEX")
  text = text:gsub("<[Dd][Ee][Xx]>", "POKéDEX")
  text = text:gsub("<[Ll][Vv]>", "LV ")
  text = text:gsub("<[Pp][Ll][Aa][Yy][Ee][Rr]>", "PLAYER")
  text = text:gsub("<[Rr][Ii][Vv][Aa][Ll]>", "RIVAL")
  text = text:gsub("<[^>]+>", "")

  -- 2. Gen 3 GBA inline control codes & flow tokens
  text = text:gsub("\\c%[%d+%]", "")
  text = text:gsub("\\w%[%d+%]", "")
  text = text:gsub("\\p", "\n")
  text = text:gsub("\\l", " ")
  text = text:gsub("{PLAYER}", "PLAYER")
  text = text:gsub("{RIVAL}", "RIVAL")
  text = text:gsub("{STR_VAR_%d+}", "")
  -- Font glyphs. {LV_2} is the small "Lv" symbol in the trainer memo.
  text = text:gsub("{LV_2}", "Lv.")
  text = text:gsub("{LV}", "Lv.")
  text = text:gsub("{PP}", "PP")
  text = text:gsub("{ID}", "ID")
  text = text:gsub("{PLUS}", "+")
  text = text:gsub("{LEFT_PAREN}", "(")
  text = text:gsub("{RIGHT_PAREN}", ")")
  text = text:gsub("{PKMN}", "POKéMON")

  -- 3. Control byte sanitization
  text = text:gsub("[\f\v\r]", "\n")
  text = text:gsub("[\1-\8\11\12\14-\31]", "")

  return text
end

--- Tokenizes GBA text into clean renderable lines with intelligent widescreen newline normalization.
--- Replaces single mid-sentence '\n' with ' ' while preserving '\n\n' paragraph breaks.
--- @param rawText string|nil
--- @return table Array of clean line strings
function Layout.tokenizeGbaText(rawText)
  if not rawText then return { "" } end
  local str = tostring(rawText)

  -- Clean standard macros & escapes
  str = Layout.cleanText(str)

  -- Preserve double newlines (paragraphs) as a unique separator token
  local PARA_SPLIT = "\1PARA\1"
  str = str:gsub("\n%s*\n", PARA_SPLIT)

  -- Replace single mid-sentence newlines with standard whitespace
  str = str:gsub("([^\n])\n([^\n])", "%1 %2")

  -- Restore paragraph splits
  local paragraphs = {}
  for p in str:gmatch("[^" .. PARA_SPLIT .. "]+") do
    p = p:gsub("^%s+", ""):gsub("%s+$", "")
    if #p > 0 then
      table.insert(paragraphs, p)
    end
  end

  if #paragraphs == 0 then return { "" } end
  return paragraphs
end

function Layout.textWidth(text, fontName, opts)
  text = Layout.cleanText(text)
  local f = Layout.getFont(fontName or "body", opts)
  if f and f.getWidth then
    return f:getWidth(text)
  end
  return #text * 8
end

function Layout.textHeight(fontName, opts)
  local f = Layout.getFont(fontName or "body", opts)
  if f and f.getHeight then
    return f:getHeight()
  end
  return 12
end

function Layout.drawEllipse(mode, x, y, rx, ry)
  if not love or not love.graphics then return end
  if love.graphics.ellipse then
    love.graphics.ellipse(mode, x, y, rx, ry)
  elseif love.graphics.circle then
    local initDepth = love.graphics.getStackDepth and love.graphics.getStackDepth() or 0
    love.graphics.push()
    love.graphics.translate(x, y)
    local sx = 1
    local sy = (ry and rx and rx > 0) and (ry / rx) or 1
    love.graphics.scale(sx, sy)
    love.graphics.circle(mode, 0, 0, rx)
    love.graphics.pop()
    if love.graphics.getStackDepth then
      while love.graphics.getStackDepth() > initDepth do
        love.graphics.pop()
      end
    end
  end
end

-- Stage / Monster Pedestal Primitive (delegates to theme:drawPedestal if implemented)
function Layout.drawPedestal(x, y, rx, ry, opts)
  opts = opts or {}
  local theme = Theme.get()

  if theme.drawPedestal and type(theme.drawPedestal) == "function" then
    return theme:drawPedestal(x, y, rx, ry, opts)
  end

  local color = opts.color or theme.colors.accent or theme.colors.border
  love.graphics.setColor(color[1], color[2], color[3], 0.14)
  Layout.drawEllipse("fill", x, y, rx, ry)
  love.graphics.setColor(color[1], color[2], color[3], 0.35)
  love.graphics.setLineWidth(1)
  Layout.drawEllipse("line", x, y, rx, ry)
end

-- Vector Heart Art Primitive for Contest Appeal & Jam Meters
local HEART_NORM_COORDS = nil
local function getHeartNormCoords()
  if HEART_NORM_COORDS then return HEART_NORM_COORDS end
  local n = 24
  local minY, maxY = -12, 17
  local h = maxY - minY
  HEART_NORM_COORDS = {}
  for i = 0, n - 1 do
    local t = (i / n) * 2 * math.pi
    local px = 16 * math.sin(t)^3
    local py = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
    local nx = (px + 16) / 32
    local ny = (py - minY) / h
    table.insert(HEART_NORM_COORDS, { nx, ny })
  end
  return HEART_NORM_COORDS
end

function Layout.drawHeart(x, y, size, filled, color, outlineColor)
  if not love or not love.graphics or not love.graphics.polygon then return end
  size = size or 12
  local pts = getHeartNormCoords()
  local coords = {}
  for i = 1, #pts do
    coords[#coords + 1] = x + pts[i][1] * size
    coords[#coords + 1] = y + pts[i][2] * size
  end

  if filled then
    local c = color or { 0.95, 0.35, 0.35, 1 }
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
    love.graphics.polygon("fill", coords)
    if outlineColor then
      local oc = outlineColor
      love.graphics.setColor(oc[1], oc[2], oc[3], oc[4] or 0.8)
      love.graphics.setLineWidth(1)
      love.graphics.polygon("line", coords)
    end
  else
    local oc = outlineColor or color or { 0.5, 0.5, 0.5, 0.6 }
    love.graphics.setColor(oc[1], oc[2], oc[3], oc[4] or 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", coords)
  end
end

function Layout.drawHeartsMeter(x, y, count, maxCount, opts)
  if not love or not love.graphics then return 0 end
  opts = opts or {}
  local size = opts.size or 12
  local gap = opts.gap or 3
  local color = opts.color or { 0.95, 0.35, 0.35, 1 }
  local emptyColor = opts.emptyColor or { 0.45, 0.45, 0.50, 0.6 }
  local outlineColor = opts.outlineColor
  maxCount = maxCount or count or 0
  count = math.min(maxCount, math.max(0, tonumber(count) or 0))

  for i = 1, maxCount do
    local hx = x + (i - 1) * (size + gap)
    local isFilled = (i <= count)
    Layout.drawHeart(hx, y, size, isFilled, isFilled and color or emptyColor, isFilled and outlineColor or emptyColor)
  end
  return maxCount * size + math.max(0, maxCount - 1) * gap
end

function Layout.drawText(text, x, y, opts)
  if not love or not love.graphics then return end
  opts = opts or {}
  text = Layout.cleanText(text)
  local fontName = opts.font or "body"
  local theme = Theme.get()
  local color = opts.color or theme.text
  local align = opts.align or "left"
  local w = opts.width or 0
  local isBold = opts.bold or false

  love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)

  local f = Layout.getFont(fontName)
  if f and love.graphics.setFont and love.graphics.print then
    love.graphics.setFont(f)
    if w > 0 then
      local tw = Layout.textWidth(text, fontName)
      if tw > w then
        while #text > 1 and Layout.textWidth(text .. "…", fontName) > w do
          text = text:sub(1, -2)
        end
        text = text .. "…"
      end
    end

    local tw = Layout.textWidth(text, fontName)
    local posX = x
    if align == "center" and w > 0 then
      posX = x + math.max(0, math.floor((w - tw) / 2))
    elseif align == "right" and w > 0 then
      posX = x + math.max(0, w - tw)
    end

    pcall(love.graphics.print, text, posX, y)
    if isBold then
      pcall(love.graphics.print, text, posX + 1, y)
    end
  else
    local tw = #text * 8
    if w > 0 and tw > w then
      local maxChars = math.max(1, math.floor((w - 8) / 8))
      text = text:sub(1, maxChars) .. "…"
      tw = #text * 8
    end

    local posX = x
    if align == "center" and w > 0 then
      posX = x + math.max(0, math.floor((w - tw) / 2))
    elseif align == "right" and w > 0 then
      posX = x + math.max(0, w - tw)
    end
    RetroFont.draw(text, posX, y)
  end
end

function Layout.drawTextWrapped(text, x, y, wrapLimit, opts)
  opts = opts or {}
  text = Layout.cleanText(text)
  local fontName = opts.font or "body"
  local theme = Theme.get()
  local color = opts.color or theme.text
  local align = opts.align or "left"

  love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)

  local f = Layout.getFont(fontName)
  if f and love.graphics.setFont and love.graphics.printf then
    love.graphics.setFont(f)
    pcall(love.graphics.printf, text, x, y, wrapLimit, align)
  else
    RetroFont.draw(text, x, y)
  end
end

-- Standard Card container: graphite surface, rounded corners, quiet hairline border
function Layout.drawCard(x, y, w, h, opts)
  if not love or not love.graphics then return end
  opts = opts or {}
  local theme = Theme.get()

  -- Allow custom theme drawing delegate
  if theme.drawCard and type(theme.drawCard) == "function" then
    return theme:drawCard(x, y, w, h, opts)
  end

  local color = opts.color or theme.colors.surface
  local borderColor = opts.borderColor or theme.colors.border
  local borderWidth = opts.borderWidth or (theme.metrics and theme.metrics.borderWidth.hairline or 1)
  local radius = opts.radius or (theme.metrics and theme.metrics.radius.card or 8)

  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.98)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Inset Row / Slot inside a Card
function Layout.drawSlot(x, y, w, h, opts)
  if not love or not love.graphics then return end
  opts = opts or {}
  local theme = Theme.get()

  if theme.drawSlot and type(theme.drawSlot) == "function" then
    return theme:drawSlot(x, y, w, h, opts)
  end

  local color = opts.color or theme.colors.surfaceHigh
  local borderColor = opts.borderColor or theme.colors.border
  local borderWidth = opts.borderWidth or (theme.metrics and theme.metrics.borderWidth.hairline or 1)
  local radius = opts.radius or (theme.metrics and theme.metrics.radius.slot or 6)

  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.96)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Interactive Button: primary (green), accent (blue), ghost, danger
function Layout.drawButton(x, y, w, h, label, opts)
  if not love or not love.graphics then return end
  opts = opts or {}
  local theme = Theme.get()

  if theme.drawButton and type(theme.drawButton) == "function" then
    return theme:drawButton(x, y, w, h, label, opts)
  end

  local kind = opts.kind or "ghost"
  local isSel = opts.selected or false
  local radius = opts.radius or (theme.metrics and theme.metrics.radius.button or 6)

  local fill = theme.colors.surface
  local textColor = theme.colors.text
  local borderColor = theme.colors.border
  local borderWidth = theme.metrics and theme.metrics.borderWidth.hairline or 1
  local isBold = false

  if kind == "primary" or kind == "good" then
    fill = theme.colors.hpGreen
    textColor = theme.colors.textInverse
    borderColor = isSel and theme.colors.borderStrong or theme.colors.hpGreen
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "accent" or (isSel and kind ~= "ghost") then
    fill = theme.colors.accentDark
    textColor = theme.colors.heading
    borderColor = isSel and theme.colors.borderStrong or theme.colors.accent
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "danger" then
    fill = theme.colors.surface
    textColor = theme.colors.hpRed
    borderColor = isSel and theme.colors.borderStrong or theme.colors.hpRed
    borderWidth = isSel and 2 or 1
  elseif isSel then
    fill = theme.colors.accentDark
    textColor = theme.colors.heading
    borderColor = theme.colors.borderStrong
    borderWidth = 2
    isBold = true
  else
    fill = theme.colors.surfaceHigh
    textColor = theme.colors.text
    borderColor = theme.colors.border
    borderWidth = 1
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  if (kind == "primary" or kind == "accent" or isSel) and h > 16 then
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", x + radius, y + 1, w - 2 * radius, 2)
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.rectangle("fill", x + radius, y + h - 3, w - 2 * radius, 2)
  end

  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
  love.graphics.setLineWidth(borderWidth)
  love.graphics.rectangle("line", x, y, w, h, radius, radius)

  if label and label ~= "" then
    local fontName = opts.font or "button"
    local fh = Layout.textHeight(fontName)
    local textY = y + math.floor((h - fh) / 2)
    local align = opts.align or "center"
    local padLeft = (align == "left") and (opts.padX or 16) or 0
    local padRight = (align == "right") and (opts.padRight or opts.padX or 16) or 0
    local textW = (align == "center") and w or (w - padLeft - padRight - 6)
    Layout.drawText(label, x + padLeft, textY, {
      font = fontName,
      color = textColor,
      align = align,
      width = textW,
      bold = isBold or isSel,
    })
  end
end

-- Pill Badge / Status Tag
function Layout.drawBadge(x, y, text, opts)
  if not love or not love.graphics then return 0 end
  opts = opts or {}
  text = tostring(text or ""):upper()
  local theme = Theme.get()

  if theme.drawBadge and type(theme.drawBadge) == "function" then
    return theme:drawBadge(x, y, text, opts)
  end

  local kind = opts.kind or "ghost"
  local fontName = opts.font or "tiny"
  local fw = Layout.textWidth(text, fontName)
  local fh = Layout.textHeight(fontName)
  local padX = opts.padX or 8
  local padY = opts.padY or 3
  local bw = opts.width or (fw + padX * 2)
  local bh = opts.height or (fh + padY * 2)
  local radius = opts.radius or (theme.metrics and theme.metrics.radius.badge or 4)

  local fill = theme.colors.surfaceHigh
  local textColor = theme.colors.textDim
  local borderColor = theme.colors.border

  if kind == "good" or kind == "loaded" or kind == "on" then
    fill = theme.colors.hpGreen
    textColor = theme.colors.textInverse
    borderColor = theme.colors.hpGreen
  elseif kind == "ready" then
    fill = theme.colors.surfaceHigh
    textColor = theme.colors.hpGreen
    borderColor = theme.colors.hpGreen
  elseif kind == "warn" or kind == "staged" then
    fill = theme.colors.hpYellow
    textColor = theme.colors.textInverse
    borderColor = theme.colors.hpYellow
  elseif kind == "danger" or kind == "err" then
    fill = theme.colors.hpRed
    textColor = theme.colors.heading
    borderColor = theme.colors.hpRed
  elseif kind == "accent" or kind == "blue" or kind == "primary" then
    fill = theme.colors.accentDark
    textColor = theme.colors.heading
    borderColor = theme.colors.borderStrong
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, bw, bh, radius, radius)

  if borderColor then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, bw, bh, radius, radius)
  end

  local textY = y + math.floor((bh - fh) / 2)
  Layout.drawText(text, x, textY, {
    font = fontName,
    color = textColor,
    align = "center",
    width = bw,
    bold = (fill == theme.colors.hpGreen or fill == theme.colors.hpYellow or kind == "primary"),
  })

  return bw
end

-- Sleek button prompt hint badge (e.g. [A] Resume Adventure)
function Layout.drawButtonHint(x, y, keyText, labelText, opts)
  opts = opts or {}
  local theme = Theme.get()

  if theme.drawButtonHint and type(theme.drawButtonHint) == "function" then
    return theme:drawButtonHint(x, y, keyText, labelText, opts)
  end

  local fontName = opts.font or "caption"
  local keyFont = opts.keyFont or "tiny"
  local kh = opts.height or 20
  local kw = math.max(kh, Layout.textWidth(keyText, keyFont) + 10)

  local kfh = Layout.textHeight(keyFont)
  local lfh = Layout.textHeight(fontName)

  local keyY = y
  Layout.drawCard(x, keyY, kw, kh, {
    color = opts.keyColor or theme.colors.raised,
    borderColor = opts.keyBorder or theme.colors.border,
    borderWidth = 1,
    radius = 4,
  })

  local keyTextY = keyY + math.floor((kh - kfh) / 2)
  Layout.drawText(keyText, x, keyTextY, {
    font = keyFont,
    color = opts.keyTextColor or theme.colors.heading,
    align = "center",
    width = kw,
    bold = true,
  })

  local labelX = x + kw + 7
  local labelY = keyY + math.floor((kh - lfh) / 2)
  Layout.drawText(labelText, labelX, labelY, {
    font = fontName,
    color = opts.textColor or theme.colors.textDim,
  })

  local lw = Layout.textWidth(labelText, fontName)
  return kw + 7 + lw
end

-- Full Footer Hint Bar with locked spacing & fixed column anchors
function Layout.drawHintBar(x, y, w, h, hints, opts)
  opts = opts or {}
  local theme = Theme.get()

  Layout.drawSlot(x, y, w, h, {
    color = opts.color or theme.colors.surfaceHigh,
    borderColor = opts.borderColor or theme.colors.border,
    borderWidth = 1,
    radius = opts.radius or (theme.metrics and theme.metrics.radius.slot or 6),
  })

  local kh = 20
  local itemY = y + math.floor((h - kh) / 2)
  local padX = opts.paddingX or (theme.metrics and theme.metrics.padding.lg or 16)
  local startX = x + padX
  local curX = startX
  local gap = opts.gap or 20

  for i, it in ipairs(hints) do
    local isPrimary = it.primary or false
    local desiredX = curX
    if opts.columns and opts.columns[i] then
      desiredX = startX + opts.columns[i]
    elseif it.xOffset then
      desiredX = startX + it.xOffset
    end

    local colX = math.max(curX, desiredX)

    local itemW = Layout.drawButtonHint(colX, itemY, it.key, it.label, {
      keyColor = isPrimary and theme.colors.accentDark or theme.colors.raised,
      keyBorder = isPrimary and theme.colors.borderStrong or theme.colors.border,
      keyTextColor = theme.colors.heading,
      textColor = isPrimary and theme.colors.heading or theme.colors.textDim,
    })

    curX = colX + (itemW or 60) + gap
  end
end

-- 3-Column Metric Display
function Layout.drawStatMetric(x, y, w, value, label)
  local theme = Theme.get()
  Layout.drawText(tostring(value or "0"), x, y, {
    font = "stat",
    color = theme.colors.heading,
    align = "center",
    width = w,
    bold = true,
  })
  local vh = Layout.textHeight("stat")
  Layout.drawText(tostring(label or ""):lower(), x, y + vh + 1, {
    font = "caption",
    color = theme.colors.textDim,
    align = "center",
    width = w,
  })
end

-- Health Bar Meter
function Layout.drawHealthBar(x, y, w, h, current, max, opts)
  if not love or not love.graphics then return end
  opts = opts or {}
  local theme = Theme.get()

  if theme.drawHealthBar and type(theme.drawHealthBar) == "function" then
    return theme:drawHealthBar(x, y, w, h, current, max, opts)
  end

  local ratio = math.max(0, math.min(1, max > 0 and (current / max) or 0))
  local fillW = math.floor(w * ratio)
  local radius = opts.radius or math.min(h / 2, 4)

  local trackColor = opts.trackColor or theme.colors.surfaceHigh
  love.graphics.setColor(trackColor[1], trackColor[2], trackColor[3], 1.0)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  local color = opts.color
  if not color then
    color = theme.colors.hpGreen
    if ratio <= 0.20 then
      color = theme.colors.hpRed
    elseif ratio <= 0.50 then
      color = theme.colors.hpYellow
    end
  end

  if fillW > 0 then
    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    love.graphics.rectangle("fill", x, y, fillW, h, radius, radius)
  end

  local borderColor = opts.borderColor or theme.colors.border
  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, radius, radius)
end

-- Horizontal Divider Line
function Layout.drawDivider(x, y, w, opts)
  opts = opts or {}
  local theme = Theme.get()
  local color = opts.color or theme.colors.border
  local thickness = opts.thickness or 1

  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.35)
  love.graphics.rectangle("fill", x, y, w, thickness)
end

-- Progress / Exp / Generic Value Bar
function Layout.drawProgressBar(x, y, w, h, current, max, opts)
  if type(max) == "table" and opts == nil then
    opts = max
    max = 1.0
  end
  opts = opts or {}
  local theme = Theme.get()

  if theme.drawProgressBar and type(theme.drawProgressBar) == "function" then
    return theme:drawProgressBar(x, y, w, h, current, max, opts)
  end

  if not (love and love.graphics and love.graphics.setColor) then return end

  max = (type(max) == "number") and max or 1.0
  current = (type(current) == "number") and current or 0
  local ratio = math.max(0, math.min(1, max > 0 and (current / max) or 0))
  local fillW = math.floor(w * ratio)
  local radius = opts.radius or math.min(h / 2, 3)

  local trackColor = opts.trackColor or opts.bgColor or theme.colors.surfaceHigh
  love.graphics.setColor(trackColor[1], trackColor[2], trackColor[3], 1.0)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  local barColor = opts.color or opts.fillColor or theme.colors.expBlue or theme.colors.accent
  if fillW > 0 then
    love.graphics.setColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1.0)
    love.graphics.rectangle("fill", x, y, fillW, h, radius, radius)
  end

  if opts.border ~= false and opts.borderColor then
    local borderColor = opts.borderColor or theme.colors.border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Dynamic Scrollbar Primitive
function Layout.drawScrollBar(trackX, trackY, trackW, trackH, totalItems, visibleCount, scrollOffset, opts)
  opts = opts or {}
  if not totalItems or not visibleCount or totalItems <= visibleCount then return end
  local theme = Theme.get()

  trackW = trackW or 6
  local minThumbH = opts.minThumbH or 20
  local thumbH = math.max(minThumbH, math.floor(trackH * (visibleCount / totalItems)))
  local maxScroll = math.max(1, totalItems - visibleCount)
  local curScroll = scrollOffset or 0
  if opts.is1Indexed then curScroll = curScroll - 1 end
  curScroll = math.max(0, math.min(maxScroll, curScroll))
  local thumbY = trackY + math.floor((trackH - thumbH) * (curScroll / maxScroll))

  local trackColor = opts.trackColor or theme.colors.surfaceHigh
  local thumbColor = opts.thumbColor or theme.colors.accentDark
  local thumbBorder = opts.thumbBorder or theme.colors.borderStrong
  local radius = opts.radius or 3

  -- Allow custom theme drawing delegate
  if theme.drawScrollBar and type(theme.drawScrollBar) == "function" then
    return theme:drawScrollBar(trackX, trackY, trackW, trackH, totalItems, visibleCount, scrollOffset, opts)
  end

  Layout.drawSlot(trackX, trackY, trackW, trackH, {
    color = trackColor,
    borderColor = opts.trackBorderColor or theme.colors.border,
    border = opts.trackBorder ~= false,
    radius = radius,
  })

  Layout.drawCard(trackX, thumbY, trackW, thumbH, {
    color = thumbColor,
    borderColor = thumbBorder,
    borderWidth = 1,
    radius = radius,
  })
end

-- Staggered list cascade helper for juicy entrance animations
function Layout.getCascadeOffset(i, animProgress, delayPerItem, maxSlide)
  if not Layout.animationsEnabled() or type(animProgress) ~= "number" or animProgress >= 1.0 then
    return 0, 1.0
  end
  delayPerItem = delayPerItem or 0.025
  maxSlide = maxSlide or 18
  local totalDuration = 0.30
  local itemDelay = (i - 1) * delayPerItem
  local itemTime = animProgress * totalDuration - itemDelay
  if itemTime <= 0 then
    return maxSlide, 0.0
  end
  local itemP = math.min(1.0, itemTime / 0.16)
  local eased = 1.0 - (2 ^ (-10 * itemP))
  local offsetX = math.floor((1.0 - eased) * maxSlide)
  local alpha = eased
  return offsetX, alpha
end

-- Backward compatibility alias
Layout.drawPanel = Layout.drawCard

return Layout

