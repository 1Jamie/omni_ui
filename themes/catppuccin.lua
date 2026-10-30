-- Catppuccin Mocha Theme for OmniUI
-- Adheres 100% to the official Catppuccin Mocha Design System & Color Palette.
-- Credits & Attribution: Catppuccin Organization & Community (https://github.com/catppuccin / https://catppuccin.com)
-- License: MIT (https://github.com/catppuccin/catppuccin/blob/main/LICENSE)

local Layout = nil
local function getLayout()
  if not Layout then Layout = require("mods.omni_ui.core.Layout") end
  return Layout
end

-- Full Official Catppuccin Mocha Palette (26 Named Tokens)
local CATPPUCCIN_MOCHA = {
  rosewater = "#F5E0DC",
  flamingo  = "#F2CDCD",
  pink      = "#F5C2E7",
  mauve     = "#CBA6F7",
  red       = "#F38BA8",
  maroon    = "#EBA0AC",
  peach     = "#FAB387",
  yellow    = "#F9E2AF",
  green     = "#A6E3A1",
  teal      = "#94E2D5",
  sky       = "#89DCEB",
  sapphire  = "#74C7EC",
  blue      = "#89B4FA",
  lavender  = "#B4BEFE",
  text      = "#CDD6F4",
  subtext1  = "#BAC2DE",
  subtext0  = "#A6ADC8",
  overlay2  = "#9399B2",
  overlay1  = "#7F849C",
  overlay0  = "#6C7086",
  surface2  = "#585B70",
  surface1  = "#45475A",
  surface0  = "#313244",
  base      = "#1E1E2E",
  mantle    = "#181825",
  crust     = "#11111B",
}

local function toColor(c, defaultAlpha)
  if not c then return { 1, 1, 1, defaultAlpha or 1 } end
  if type(c) == "string" then
    local clean = c:gsub("#", ""):gsub("%s+", "")
    if #clean == 3 then
      local r = tonumber(clean:sub(1, 1):rep(2), 16) or 255
      local g = tonumber(clean:sub(2, 2):rep(2), 16) or 255
      local b = tonumber(clean:sub(3, 3):rep(2), 16) or 255
      return { r / 255, g / 255, b / 255, defaultAlpha or 1.0 }
    elseif #clean == 6 then
      local r = tonumber(clean:sub(1, 2), 16) or 255
      local g = tonumber(clean:sub(3, 4), 16) or 255
      local b = tonumber(clean:sub(5, 6), 16) or 255
      return { r / 255, g / 255, b / 255, defaultAlpha or 1.0 }
    elseif #clean == 8 then
      local r = tonumber(clean:sub(1, 2), 16) or 255
      local g = tonumber(clean:sub(3, 4), 16) or 255
      local b = tonumber(clean:sub(5, 6), 16) or 255
      local a = tonumber(clean:sub(7, 8), 16) or 255
      return { r / 255, g / 255, b / 255, a / 255 }
    end
    return { 1, 1, 1, defaultAlpha or 1.0 }
  end
  if type(c) == "table" then
    return { c[1] or 1, c[2] or 1, c[3] or 1, c[4] or defaultAlpha or 1.0 }
  end
  return { 1, 1, 1, defaultAlpha or 1.0 }
end

local theme = {
  id = "catppuccin",
  label = "Catppuccin Mocha",
  author = "Catppuccin Org (catppuccin.com)",
  credits = "Palette by Catppuccin • catppuccin.com",
  license = "MIT",
  version = "2.1.0",

  -- Full 26-color official palette exposed for mods & extensions
  palette = CATPPUCCIN_MOCHA,

  colors = {
    -- Surface Hierarchy (Crust -> Mantle -> Base -> Surface0 -> Surface1)
    bg          = CATPPUCCIN_MOCHA.base,     -- #1E1E2E: Deep soothing canvas base
    surface     = CATPPUCCIN_MOCHA.mantle,   -- #181825: Primary card surface
    surfaceHigh = CATPPUCCIN_MOCHA.crust,    -- #11111B: Inset recessed slots
    raised      = CATPPUCCIN_MOCHA.surface0, -- #313244: Floating card / button fill
    ink         = CATPPUCCIN_MOCHA.text,     -- #CDD6F4: Primary text

    -- Borders & Highlights
    border       = "#45475A80",              -- Surface1 with 50% opacity
    borderStrong = CATPPUCCIN_MOCHA.mauve,   -- #CBA6F7: High-contrast focus
    borderSubtle = CATPPUCCIN_MOCHA.surface0,-- #313244: Hairline slot separator

    -- Accents (Mauve / Lavender / Pink)
    accent       = CATPPUCCIN_MOCHA.mauve,    -- #CBA6F7: Primary accent
    accentDark   = "#8839EF",                -- Deep mauve
    accentHover  = CATPPUCCIN_MOCHA.pink,     -- #F5C2E7: Secondary hover
    accentAlt    = CATPPUCCIN_MOCHA.lavender, -- #B4BEFE: Secondary badge accent

    -- Typography Hierarchy
    heading     = CATPPUCCIN_MOCHA.rosewater,-- #F5E0DC: Warm high-contrast titles
    text        = CATPPUCCIN_MOCHA.text,     -- #CDD6F4: Standard body text
    detail      = CATPPUCCIN_MOCHA.subtext1, -- #BAC2DE: Secondary subtitles
    textDim     = CATPPUCCIN_MOCHA.subtext0, -- #A6ADC8: Captions & labels
    textMuted   = CATPPUCCIN_MOCHA.overlay1, -- #7F849C: Inactive / disabled text
    textInverse = CATPPUCCIN_MOCHA.crust,    -- #11111B: High contrast dark text on pastel fills

    -- Semantic Status Colors (Accurate Catppuccin Mocha Mappings)
    hpGreen     = CATPPUCCIN_MOCHA.green,    -- #A6E3A1: Success / Healthy HP
    hpYellow    = CATPPUCCIN_MOCHA.yellow,   -- #F9E2AF: Warning / Half HP
    hpRed       = CATPPUCCIN_MOCHA.red,      -- #F38BA8: Danger / Low HP
    expBlue     = CATPPUCCIN_MOCHA.blue,     -- #89B4FA: Experience / Informational
    peach       = CATPPUCCIN_MOCHA.peach,    -- #FAB387: Staged / Pending
    teal        = CATPPUCCIN_MOCHA.teal,     -- #94E2D5: Ready / Loaded
    sapphire    = CATPPUCCIN_MOCHA.sapphire, -- #74C7EC: Info / Dex
    lavender    = CATPPUCCIN_MOCHA.lavender, -- #B4BEFE: Team / Mon
    mauve       = CATPPUCCIN_MOCHA.mauve,    -- #CBA6F7: Save / Action
    maroon      = CATPPUCCIN_MOCHA.maroon,
    flamingo    = CATPPUCCIN_MOCHA.flamingo,
    rosewater   = CATPPUCCIN_MOCHA.rosewater,
    pink        = CATPPUCCIN_MOCHA.pink,
    sky         = CATPPUCCIN_MOCHA.sky,
  },

  metrics = {
    radius = {
      card     = 12,
      slot     = 8,
      button   = 10,
      badge    = 8,
      modal    = 14,
      dialogue = 14,
      pill     = 12,
    },
    borderWidth = {
      hairline = 1,
      normal   = 1.5,
      focus    = 2,
    },
    padding = {
      xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 24,
    },
    gap = {
      xs = 4,
      sm = 6,
      md = 10,
      lg = 16,
    },
  },

  styles = {
    cardStyle   = "soft",
    buttonStyle = "rounded",
    badgeStyle  = "pill",
  },

  layout = {
    dock = {
      align         = "right",
      width         = 300,
      marginX       = 22,
      marginY       = 22,
      profileHeight = 72,
      itemHeight    = 42,
      itemGap       = 6,
      footerHeight  = 38,
    },
    dialogue = {
      maxWidth        = 700,
      height          = 114,
      marginBottom    = 24,
      nameplateHeight = 30,
      nameplateAlign  = "left",
      nameplateMargin = 20,
    },
    container = {
      maxWidth     = 820,
      maxHeight    = 520,
      headerHeight = 44,
      footerHeight = 36,
      gap          = 12,
    },
    pokedex = {
      leftWidth      = 320,
      rowHeight      = 38,
      rowGap         = 4,
      portraitHeight = 140,
    },
    bag = {
      leftRatio  = 0.54,
      rowHeight  = 40,
      rowGap     = 4,
      tabHeight  = 44,
    },
    party = {
      cardGap         = 5,
      previewBoxWidth = 56,
      meterHeight     = 6,
    },
    summary = {
      leftWidth      = 240,
      portraitHeight = 136,
      tabWidth       = 104,
    },
    shop = {
      leftRatio  = 0.54,
      rowHeight  = 40,
      rowGap     = 4,
    },
    options = {
      rowHeight = 46,
      rowGap    = 6,
    },
  },
}

-- Custom Composition: Soothing Mantle Card with Rosewater Accent Pip
function theme:drawCard(x, y, w, h, opts)
  opts = opts or {}
  local color = toColor(opts.color or self.colors.surface)
  local borderColor = toColor(opts.borderColor or self.colors.border)
  local radius = opts.radius or (self.metrics and self.metrics.radius.card or 12)

  -- 1. Base Mantle Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.96)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Surface1 Soft Perimeter Line
  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
    love.graphics.setLineWidth(opts.borderWidth or 1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end

  -- 3. Subtle Rosewater Header Accent Pip
  if w >= 40 and h >= 24 and opts.accentPip ~= false then
    local pipColor = toColor(self.colors.heading)
    love.graphics.setColor(pipColor[1], pipColor[2], pipColor[3], 0.35)
    love.graphics.rectangle("fill", x + 10, y + 4, 14, 2, 1, 1)
  end
end

-- Custom Composition: Crust Recessed Slot
function theme:drawSlot(x, y, w, h, opts)
  opts = opts or {}
  local color = toColor(opts.color or self.colors.surfaceHigh)
  local borderColor = toColor(opts.borderColor or self.colors.border)
  local radius = opts.radius or (self.metrics and self.metrics.radius.slot or 8)

  -- 1. Deep Crust Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.94)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Surface0 Outline
  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Custom Composition: Mauve / Lavender Pastel Action Button
function theme:drawButton(x, y, w, h, label, opts)
  opts = opts or {}
  local L = getLayout()
  local kind = opts.kind or "ghost"
  local isSel = opts.selected or false
  local radius = opts.radius or (self.metrics and self.metrics.radius.button or 10)

  local fill = self.colors.raised
  local textColor = self.colors.text
  local borderColor = self.colors.border
  local borderWidth = 1
  local isBold = false

  if kind == "primary" or (isSel and kind ~= "danger") then
    -- Catppuccin Mocha Primary Focus: Mauve (#CBA6F7) fill with Crust (#11111B) text
    fill = self.colors.accent
    textColor = self.colors.textInverse
    borderColor = self.colors.heading
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "accent" then
    fill = self.colors.accentAlt
    textColor = self.colors.textInverse
    borderColor = self.colors.heading
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "good" then
    -- Semantic Success / Confirmation
    fill = self.colors.hpGreen
    textColor = self.colors.textInverse
    borderColor = isSel and self.colors.borderStrong or self.colors.hpGreen
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "danger" then
    fill = self.colors.hpRed
    textColor = self.colors.textInverse
    borderColor = isSel and self.colors.borderStrong or self.colors.hpRed
    borderWidth = isSel and 2 or 1
    isBold = true
  else
    fill = self.colors.raised
    textColor = self.colors.text
    borderColor = self.colors.border
    borderWidth = 1
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  fill = toColor(fill)
  textColor = toColor(textColor)
  borderColor = toColor(borderColor)

  -- 1. Rounded Button Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Focus Border
  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
  love.graphics.setLineWidth(borderWidth)
  love.graphics.rectangle("line", x, y, w, h, radius, radius)

  -- 3. Label
  if label and label ~= "" then
    local fontName = opts.font or "button"
    local fh = L.textHeight(fontName)
    local textY = y + math.floor((h - fh) / 2)
    local align = opts.align or "center"
    local padLeft = (align == "left") and (opts.padX or 16) or 0
    local padRight = (align == "right") and (opts.padRight or opts.padX or 16) or 0
    local textW = (align == "center") and w or (w - padLeft - padRight - 6)
    L.drawText(label, x + padLeft, textY, {
      font = fontName,
      color = textColor,
      align = align,
      width = textW,
      bold = isBold or isSel,
    })
  end
end

-- Custom Composition: Catppuccin Pastel Capsule Badge (Surface0 Background with Tinted Pastel Borders/Text)
function theme:drawBadge(x, y, text, opts)
  opts = opts or {}
  local L = getLayout()
  text = tostring(text or ""):upper()

  local kind = opts.kind or "ghost"
  local fontName = opts.font or "tiny"
  local fw = L.textWidth(text, fontName)
  local fh = L.textHeight(fontName)
  local padX = opts.padX or 8
  local padY = opts.padY or 3
  local bw = opts.width or (fw + padX * 2)
  local bh = opts.height or (fh + padY * 2)
  local radius = opts.radius or (self.metrics and self.metrics.radius.badge or 8)

  local fill = self.colors.surfaceHigh
  local textColor = self.colors.textDim
  local borderColor = self.colors.border

  if kind == "good" or kind == "loaded" or kind == "on" then
    fill = self.colors.raised
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
  elseif kind == "ready" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
  elseif kind == "warn" or kind == "staged" or kind == "peach" or kind == "bag" then
    fill = self.colors.raised
    textColor = self.colors.peach
    borderColor = self.colors.peach
  elseif kind == "danger" or kind == "err" then
    fill = self.colors.raised
    textColor = self.colors.hpRed
    borderColor = self.colors.hpRed
  elseif kind == "primary" or kind == "mauve" or kind == "save" or kind == "mods" then
    fill = self.colors.raised
    textColor = self.colors.accent
    borderColor = self.colors.accent
  elseif kind == "team" or kind == "lavender" then
    fill = self.colors.raised
    textColor = self.colors.accentAlt
    borderColor = self.colors.accentAlt
  elseif kind == "dex" or kind == "blue" or kind == "accent" then
    fill = self.colors.raised
    textColor = self.colors.sapphire or CATPPUCCIN_MOCHA.sapphire
    borderColor = self.colors.sapphire or CATPPUCCIN_MOCHA.sapphire
  else
    fill = self.colors.raised
    textColor = self.colors.textDim
    borderColor = self.colors.border
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  fill = toColor(fill)
  textColor = toColor(textColor)
  borderColor = toColor(borderColor)

  -- 1. Capsule Pill Fill (Recessed Surface0/Crust)
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 0.95)
  love.graphics.rectangle("fill", x, y, bw, bh, radius, radius)

  -- 2. Outline
  if borderColor then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, bw, bh, radius, radius)
  end

  -- 3. Pastel Text
  local textY = y + math.floor((bh - fh) / 2)
  L.drawText(text, x, textY, {
    font = fontName,
    color = textColor,
    align = "center",
    width = bw,
    bold = (kind ~= "ghost"),
  })

  return bw
end

-- Custom Composition: Catppuccin Lavender Scrollbar
function theme:drawScrollBar(trackX, trackY, trackW, trackH, totalItems, visibleCount, scrollOffset, opts)
  opts = opts or {}
  if not totalItems or not visibleCount or totalItems <= visibleCount then return end
  trackW = trackW or 6
  local minThumbH = opts.minThumbH or 20
  local thumbH = math.max(minThumbH, math.floor(trackH * (visibleCount / totalItems)))
  local maxScroll = math.max(1, totalItems - visibleCount)
  local curScroll = scrollOffset or 0
  if opts.is1Indexed then curScroll = curScroll - 1 end
  curScroll = math.max(0, math.min(maxScroll, curScroll))
  local thumbY = trackY + math.floor((trackH - thumbH) * (curScroll / maxScroll))
  local rad = 3

  local trackFill = toColor(self.colors.raised)
  local thumbFill = toColor(self.colors.accent)
  local thumbBorder = toColor(self.colors.heading)

  -- 1. Surface0 Track
  love.graphics.setColor(trackFill[1], trackFill[2], trackFill[3], 0.9)
  love.graphics.rectangle("fill", trackX, trackY, trackW, trackH, rad, rad)

  -- 2. Lavender Thumb with Rosewater Highlight
  love.graphics.setColor(thumbFill[1], thumbFill[2], thumbFill[3], 0.9)
  love.graphics.rectangle("fill", trackX, thumbY, trackW, thumbH, rad, rad)
  love.graphics.setColor(thumbBorder[1], thumbBorder[2], thumbBorder[3], 0.8)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", trackX, thumbY, trackW, thumbH, rad, rad)
end

return theme
