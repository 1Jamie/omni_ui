-- Classic Pocket Retro Theme
-- Authentic Game Boy Pocket / Gen 1 Pokémon window aesthetic:
-- Crisp light parchment surfaces, iconic double-line corner-notched frames,
-- high-contrast dark ink typography, and authentic inverted selection bars with pixel cursor.

local Layout = nil
local function getLayout()
  if not Layout then Layout = require("mods.omni_ui.core.Layout") end
  return Layout
end

local theme = {
  id = "classic",
  label = "Classic Pocket",
  author = "Cartridge Studio",
  version = "2.2.0",

  colors = {
    bg          = "#DCE2D2",
    surface     = "#F8FAF2",
    surfaceHigh = "#E8EDE0",
    raised      = "#FFFFFF",
    ink         = "#121A0E",

    border       = "#1E2818",
    borderStrong = "#0E160A",

    accent       = "#346224",
    accentDark   = "#C6D6B4",
    accentHover  = "#B4C8A0",

    heading     = "#10180C",
    text        = "#1C2618",
    detail      = "#3E4E38",
    textDim     = "#566850",
    textMuted   = "#7A8C74",
    textInverse = "#FFFFFF",

    hpGreen     = "#287820",
    hpYellow    = "#B88A14",
    hpRed       = "#C83224",
    expBlue     = "#2464A8",
  },

  metrics = {
    radius = {
      card     = 0,
      slot     = 0,
      button   = 0,
      badge    = 0,
      modal    = 0,
      dialogue = 0,
      pill     = 0,
    },
    borderWidth = {
      hairline = 1,
      normal   = 2,
      focus    = 2,
    },
    padding = {
      xs = 3,
      sm = 6,
      md = 10,
      lg = 14,
      xl = 20,
    },
    gap = {
      xs = 3,
      sm = 5,
      md = 8,
      lg = 12,
    },
  },

  styles = {
    cardStyle   = "bordered",
    buttonStyle = "sharp",
    badgeStyle  = "minimal",
  },

  layout = {
    dock = {
      align         = "right", -- Compact right-docked retro panel
      width         = 270,
      marginX       = 18,
      marginY       = 18,
      profileHeight = 62,
      itemHeight    = 38,
      itemGap       = 4,
      footerHeight  = 34,
    },
    dialogue = {
      maxWidth        = 660,
      height          = 108,
      marginBottom    = 18,
      nameplateHeight = 28,
      nameplateAlign  = "left", -- Classic framed nameplate
      nameplateMargin = 16,
    },
    container = {
      maxWidth     = 780,
      maxHeight    = 490,
      headerHeight = 42,
      footerHeight = 34,
      gap          = 10,
    },
    pokedex = {
      leftWidth      = 300,
      rowHeight      = 36,
      rowGap         = 4,
      portraitHeight = 130,
    },
    bag = {
      leftRatio  = 0.54,
      rowHeight  = 36,
      rowGap     = 4,
      tabHeight  = 40,
    },
    party = {
      cardGap         = 4,
      previewBoxWidth = 52,
      meterHeight     = 6,
    },
    summary = {
      leftWidth      = 230,
      portraitHeight = 130,
      tabWidth       = 98,
    },
    shop = {
      leftRatio  = 0.54,
      rowHeight  = 36,
      rowGap     = 4,
    },
    options = {
      rowHeight = 44,
      rowGap    = 5,
    },
  },
}

-- Custom Composition: Iconic Gen 1 Game Boy Double-Line Window Frame
function theme:drawCard(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surface
  local borderColor = opts.borderColor or self.colors.border

  -- 1. Crisp Light Parchment Base Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h)

  if opts.border ~= false then
    -- 2. Outer Solid 2px Dark Ink Border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)

    -- 3. Inner 1px Fine Frame Hairline (Classic Game Boy double border)
    if w >= 16 and h >= 16 then
      love.graphics.setColor(0.72, 0.78, 0.68, 0.8)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6)
    end

    -- 4. Corner Notches / Pixel Brackets (┌ ┐ └ ┘)
    if w >= 24 and h >= 24 then
      love.graphics.setColor(self.colors.borderStrong[1], self.colors.borderStrong[2], self.colors.borderStrong[3], 0.9)
      love.graphics.rectangle("fill", x + 1, y + 1, 2, 2)
      love.graphics.rectangle("fill", x + w - 3, y + 1, 2, 2)
      love.graphics.rectangle("fill", x + 1, y + h - 3, 2, 2)
      love.graphics.rectangle("fill", x + w - 3, y + h - 3, 2, 2)
    end
  end
end

-- Custom Composition: Crisp Inset Light Cream Slot
function theme:drawSlot(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surfaceHigh

  -- 1. Soft Light Cream Recessed Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h)

  if opts.border ~= false then
    local borderCol = opts.borderColor or { 0.76, 0.82, 0.72, 0.9 }
    love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4] or 1.0)
    love.graphics.setLineWidth(opts.borderWidth or 1)
    love.graphics.rectangle("line", x, y, w, h)
  end
end

-- Custom Composition: Authentic Gen 1 Inverted Selection Button with Triangle Cursor
function theme:drawButton(x, y, w, h, label, opts)
  opts = opts or {}
  local L = getLayout()
  local kind = opts.kind or "ghost"
  local isSel = opts.selected or false

  local fill = self.colors.surface
  local textColor = self.colors.text
  local isBold = false

  if isSel then
    -- Active Focus: Light Sage Highlight Fill with Crisp Dark Text
    fill = self.colors.accentDark or self.colors.surfaceHigh
    textColor = self.colors.heading
    isBold = true
  elseif kind == "primary" or kind == "good" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpGreen
    isBold = true
  elseif kind == "accent" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.accent
    isBold = true
  elseif kind == "danger" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpRed
    isBold = true
  else
    fill = self.colors.surface
    textColor = self.colors.text
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end

  -- 1. Base Button Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h)

  -- 2. Clean Border
  if isSel then
    love.graphics.setColor(self.colors.borderStrong[1], self.colors.borderStrong[2], self.colors.borderStrong[3], 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
  else
    love.graphics.setColor(0.78, 0.84, 0.74, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
  end

  -- 3. Authentic Gen 1 Pixel Cursor Pointer (▶) on Selection
  if isSel and w >= 28 then
    local pSize = 5
    local py = y + math.floor((h - pSize * 2) / 2)
    love.graphics.setColor(self.colors.heading[1], self.colors.heading[2], self.colors.heading[3], 1.0)
    for row = 0, pSize do
      love.graphics.rectangle("fill", x + 8, py + row, row + 1, 1)
      love.graphics.rectangle("fill", x + 8, py + pSize * 2 - row, row + 1, 1)
    end
  end

  -- 4. Label Typography with Padding Support
  if label and label ~= "" then
    local fontName = opts.font or "button"
    local fh = L.textHeight(fontName)
    local textY = y + math.floor((h - fh) / 2)
    local align = opts.align or "center"
    local pointerPad = (isSel and 18 or 0)
    local padLeft = (align == "left") and math.max(pointerPad, opts.padX or 18) or pointerPad
    local padRight = (align == "right") and (opts.padRight or opts.padX or 18) or 0
    local textW = (align == "center") and (w - pointerPad) or (w - padLeft - padRight - 6)
    L.drawText(label, x + padLeft, textY, {
      font = fontName,
      color = textColor,
      align = align,
      width = textW,
      bold = isBold,
    })
  end
end

-- Custom Composition: Crisp High-Contrast Status Badge
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

  local fill = self.colors.surfaceHigh
  local textColor = self.colors.textDim
  local borderColor = self.colors.border

  if kind == "good" or kind == "loaded" or kind == "on" then
    fill = self.colors.hpGreen
    textColor = self.colors.textInverse
    borderColor = self.colors.borderStrong
  elseif kind == "ready" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
  elseif kind == "warn" or kind == "staged" or kind == "gold" then
    fill = self.colors.hpYellow
    textColor = self.colors.textInverse
    borderColor = self.colors.borderStrong
  elseif kind == "danger" or kind == "err" then
    fill = self.colors.hpRed
    textColor = self.colors.textInverse
    borderColor = self.colors.borderStrong
  elseif kind == "accent" or kind == "blue" or kind == "primary" then
    fill = self.colors.accentDark
    textColor = self.colors.heading
    borderColor = self.colors.borderStrong
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  -- 1. Pixel Tag Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, bw, bh)

  -- 2. Crisp Border
  if borderColor then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, bw, bh)
  end

  -- 3. Label Text
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

-- Custom Composition: Retro Inset Scrollbar
function theme:drawScrollBar(trackX, trackY, trackW, trackH, totalItems, visibleCount, scrollOffset, opts)
  opts = opts or {}
  if not totalItems or not visibleCount or totalItems <= visibleCount then return end
  trackW = trackW or 6
  local minThumbH = opts.minThumbH or 18
  local thumbH = math.max(minThumbH, math.floor(trackH * (visibleCount / totalItems)))
  local maxScroll = math.max(1, totalItems - visibleCount)
  local curScroll = scrollOffset or 0
  if opts.is1Indexed then curScroll = curScroll - 1 end
  curScroll = math.max(0, math.min(maxScroll, curScroll))
  local thumbY = trackY + math.floor((trackH - thumbH) * (curScroll / maxScroll))

  -- 1. Inset Light Cream Track
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 1.0)
  love.graphics.rectangle("fill", trackX, trackY, trackW, trackH)
  love.graphics.setColor(0.72, 0.78, 0.68, 0.8)
  love.graphics.rectangle("line", trackX, trackY, trackW, trackH)

  -- 2. Solid Dark Ink Thumb
  love.graphics.setColor(self.colors.accentDark[1], self.colors.accentDark[2], self.colors.accentDark[3], 1.0)
  love.graphics.rectangle("fill", trackX, thumbY, trackW, thumbH)
  love.graphics.setColor(self.colors.borderStrong[1], self.colors.borderStrong[2], self.colors.borderStrong[3], 1.0)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", trackX, thumbY, trackW, thumbH)
end

return theme
