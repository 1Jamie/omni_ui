-- Kanto Red Theme
-- High-energy competitive arcade launcher with bold crimson racing stripes, heavy high-contrast badges, and dynamic geometry.

local Layout = nil
local function getLayout()
  if not Layout then Layout = require("mods.omni_ui.core.Layout") end
  return Layout
end

local theme = {
  id = "kanto",
  label = "Kanto Red",
  author = "Cartridge Studio",
  version = "2.1.0",

  colors = {
    bg          = "#140E10",
    surface     = "#22161A",
    surfaceHigh = "#1A1014",
    raised      = "#321F25",
    ink         = "#FAF0F2",

    border       = "#D0304066",
    borderStrong = "#FF3B4E",

    accent       = "#FF2D40",
    accentDark   = "#A81220",
    accentHover  = "#FF5E6D",

    heading     = "#FFF2F4",
    text        = "#FBE4E7",
    detail      = "#D8BFC4",
    textDim     = "#C8A8AE",
    textMuted   = "#8E6E75",
    textInverse = "#160A0D",

    hpGreen     = "#22C55E",
    hpYellow    = "#EAB308",
    hpRed       = "#EF4444",
    expBlue     = "#3B82F6",
  },

  metrics = {
    radius = {
      card     = 4,
      slot     = 3,
      button   = 4,
      badge    = 3,
      modal    = 6,
      dialogue = 6,
      pill     = 6,
    },
    borderWidth = {
      hairline = 1.5,
      normal   = 2,
      focus    = 2.5,
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
    cardStyle   = "bordered",
    buttonStyle = "sharp",
    badgeStyle  = "minimal",
  },

  layout = {
    dock = {
      align         = "right", -- Aggressive right-docked arcade console
      width         = 310,
      marginX       = 22,
      marginY       = 22,
      profileHeight = 76,
      itemHeight    = 44,
      itemGap       = 6,
      footerHeight  = 38,
    },
    dialogue = {
      maxWidth        = 700,
      height          = 114,
      marginBottom    = 22,
      nameplateHeight = 32,
      nameplateAlign  = "left", -- Bold arcade banner dialogue
      nameplateMargin = 20,
    },
    container = {
      maxWidth     = 840,
      maxHeight    = 525,
      headerHeight = 46,
      footerHeight = 38,
      gap          = 14,
    },
    pokedex = {
      leftWidth      = 320,
      rowHeight      = 40,
      rowGap         = 5,
      portraitHeight = 140,
    },
    bag = {
      leftRatio  = 0.54,
      rowHeight  = 42,
      rowGap     = 5,
      tabHeight  = 46,
    },
    party = {
      cardGap         = 6,
      previewBoxWidth = 58,
      meterHeight     = 6,
    },
    summary = {
      leftWidth      = 240,
      portraitHeight = 138,
      tabWidth       = 106,
    },
    shop = {
      leftRatio  = 0.54,
      rowHeight  = 42,
      rowGap     = 5,
    },
    options = {
      rowHeight = 48,
      rowGap    = 6,
    },
  },
}

-- Custom Composition: Bold Arcade Card with Crimson Top Racing Stripe
function theme:drawCard(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surface
  local borderColor = opts.borderColor or self.colors.border
  local radius = opts.radius or (self.metrics and self.metrics.radius.card or 4)

  -- 1. Dark Crimson Graphite Base Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.96)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Top Crimson Racing Stripe
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.90)
  love.graphics.rectangle("fill", x, y, w, 3, radius, radius)

  if opts.border ~= false then
    -- 3. Solid Crimson Border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.45)
    love.graphics.setLineWidth(opts.borderWidth or 1.5)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)

    -- 4. Corner Racing Accent Mark on Bottom-Right
    if w >= 30 and h >= 30 then
      love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.70)
      love.graphics.rectangle("fill", x + w - 8, y + h - 3, 6, 2)
    end
  end
end

-- Custom Composition: Arcade Slot with Bold Left Crimson Tab
function theme:drawSlot(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surfaceHigh
  local borderColor = opts.borderColor or self.colors.border
  local radius = opts.radius or (self.metrics and self.metrics.radius.slot or 3)

  -- 1. Dark Recessed Slot Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.94)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Bold Left Crimson Tab
  local tabColor = opts.tabColor or self.colors.accent
  love.graphics.setColor(tabColor[1], tabColor[2], tabColor[3], 0.85)
  love.graphics.rectangle("fill", x, y, 4, h, radius, radius)

  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Custom Composition: Bold Racing Action Button
function theme:drawButton(x, y, w, h, label, opts)
  opts = opts or {}
  local L = getLayout()
  local kind = opts.kind or "ghost"
  local isSel = opts.selected or false
  local radius = opts.radius or (self.metrics and self.metrics.radius.button or 4)

  local fill = self.colors.surface
  local textColor = self.colors.text
  local borderColor = self.colors.border
  local borderWidth = 1.5
  local isBold = false

  if kind == "good" then
    fill = self.colors.hpGreen
    textColor = self.colors.textInverse
    borderColor = isSel and self.colors.borderStrong or self.colors.hpGreen
    borderWidth = isSel and 2 or 1.5
    isBold = true
  elseif kind == "primary" or kind == "accent" or isSel then
    fill = self.colors.accent
    textColor = self.colors.heading
    borderColor = isSel and self.colors.heading or self.colors.borderStrong
    borderWidth = isSel and 2.5 or 1.5
    isBold = true
  elseif kind == "danger" then
    fill = self.colors.surface
    textColor = self.colors.hpRed
    borderColor = isSel and self.colors.borderStrong or self.colors.hpRed
    borderWidth = isSel and 2 or 1.5
  else
    fill = self.colors.surfaceHigh
    textColor = self.colors.text
    borderColor = self.colors.border
    borderWidth = 1.5
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  -- 1. Button Base Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Left Racing Chevron Marker on Selection
  if isSel and w >= 24 then
    love.graphics.setColor(self.colors.textInverse[1], self.colors.textInverse[2], self.colors.textInverse[3], 0.9)
    love.graphics.rectangle("fill", x + 6, y + math.floor(h / 2) - 4, 3, 8)
  end

  -- 3. Strong Perimeter Border
  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
  love.graphics.setLineWidth(borderWidth)
  love.graphics.rectangle("line", x, y, w, h, radius, radius)

  -- 4. Label
  if label and label ~= "" then
    local fontName = opts.font or "button"
    local fh = L.textHeight(fontName)
    local textY = y + math.floor((h - fh) / 2)
    local align = opts.align or "center"
    local padLeft = (align == "left") and (opts.padX or (isSel and 20 or 16)) or 0
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

-- Custom Composition: Bold Geometric Racing Status Badge
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
  local radius = opts.radius or (self.metrics and self.metrics.radius.badge or 3)

  local fill = self.colors.surfaceHigh
  local textColor = self.colors.textDim
  local borderColor = self.colors.border

  if kind == "good" or kind == "loaded" or kind == "on" then
    fill = self.colors.hpGreen
    textColor = self.colors.textInverse
    borderColor = self.colors.hpGreen
  elseif kind == "ready" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
  elseif kind == "warn" or kind == "staged" then
    fill = self.colors.hpYellow
    textColor = self.colors.textInverse
    borderColor = self.colors.hpYellow
  elseif kind == "danger" or kind == "err" then
    fill = self.colors.hpRed
    textColor = self.colors.heading
    borderColor = self.colors.hpRed
  elseif kind == "accent" or kind == "blue" or kind == "primary" then
    fill = self.colors.accentDark
    textColor = self.colors.heading
    borderColor = self.colors.accent
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  -- 1. Badge Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, bw, bh, radius, radius)

  -- 2. Border
  if borderColor then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, bw, bh, radius, radius)
  end

  -- 3. Text
  local textY = y + math.floor((bh - fh) / 2)
  L.drawText(text, x, textY, {
    font = fontName,
    color = textColor,
    align = "center",
    width = bw,
    bold = true,
  })

  return bw
end

-- Custom Composition: Heavy Arcade Slider Scrollbar
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
  local rad = 2

  -- 1. Dark Slot Track
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 0.95)
  love.graphics.rectangle("fill", trackX, trackY, trackW, trackH, rad, rad)
  love.graphics.setColor(self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", trackX, trackY, trackW, trackH, rad, rad)

  -- 2. Vivid Crimson Thumb
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.95)
  love.graphics.rectangle("fill", trackX, thumbY, trackW, thumbH, rad, rad)
  love.graphics.setColor(self.colors.borderStrong[1], self.colors.borderStrong[2], self.colors.borderStrong[3], 1.0)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", trackX, thumbY, trackW, thumbH, rad, rad)
end

return theme
