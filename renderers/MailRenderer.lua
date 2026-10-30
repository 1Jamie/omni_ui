-- OmniUI Modern Mail & Stationery Postcard Renderer
-- Vector stationery postcards tailored to all 10 Gen 2 mail themes with author stamps and party mail actions.
-- Dynamically adapts card dimensions, stationery slots, and typography across mobile, portrait, and desktop displays.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Mail = require("src.core.gen2.Mail")

local MailRenderer = {}

local MAIL_THEMES = {
  FLOWER_MAIL   = { bg = { 0.96, 0.90, 0.94 }, border = { 0.85, 0.45, 0.65 }, stamp = "FLOWER", icon = "FLOWER" },
  SURF_MAIL     = { bg = { 0.88, 0.94, 0.98 }, border = { 0.25, 0.55, 0.85 }, stamp = "SURF", icon = "SURF" },
  LITEBLUE_MAIL = { bg = { 0.90, 0.95, 0.98 }, border = { 0.35, 0.70, 0.90 }, stamp = "LITEBLUE", icon = "LITEBLUE" },
  PORTRAITMAIL  = { bg = { 0.95, 0.92, 0.86 }, border = { 0.75, 0.55, 0.35 }, stamp = "PORTRAIT", icon = "PORTRAIT" },
  LOVELY_MAIL   = { bg = { 0.98, 0.88, 0.92 }, border = { 0.90, 0.35, 0.55 }, stamp = "LOVELY", icon = "LOVELY" },
  EON_MAIL      = { bg = { 0.92, 0.90, 0.98 }, border = { 0.55, 0.35, 0.85 }, stamp = "EON", icon = "EON" },
  MORPH_MAIL    = { bg = { 0.90, 0.96, 0.90 }, border = { 0.35, 0.75, 0.45 }, stamp = "MORPH", icon = "MORPH" },
  BLUESKY_MAIL  = { bg = { 0.88, 0.96, 0.98 }, border = { 0.25, 0.65, 0.85 }, stamp = "BLUESKY", icon = "BLUESKY" },
  MUSIC_MAIL    = { bg = { 0.98, 0.95, 0.88 }, border = { 0.85, 0.65, 0.25 }, stamp = "MUSIC", icon = "MUSIC" },
  MIRAGE_MAIL   = { bg = { 0.94, 0.90, 0.96 }, border = { 0.65, 0.45, 0.75 }, stamp = "MIRAGE", icon = "MIRAGE" },
}

local DEFAULT_THEME = { bg = { 0.92, 0.92, 0.94 }, border = { 0.50, 0.50, 0.60 }, stamp = "MAIL", icon = "MAIL" }

function MailRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local entry = state.entry or (state.mon and state:mon() and state:mon().mail) or (state.save and state.slot and Mail.get(state.save, state.slot)) or {}
  local mailType = entry.type or entry.item or "FLOWER_MAIL"
  local style = MAIL_THEMES[mailType] or DEFAULT_THEME

  local top, bottom = Mail.lines(entry)
  local author = entry.author or (state.save and state.save.player and state.save.player.name) or "TRAINER"

  -- 1. Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Postcard Dimensions
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(620, vw - pad * 2)
  local cardH = math.min(420, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Postcard Container (Themed Stationery Texture)
  love.graphics.setColor(style.bg[1], style.bg[2], style.bg[3], 0.96)
  love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 10, 10)

  love.graphics.setColor(style.border[1], style.border[2], style.border[3], 0.85)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 10, 10)

  -- Inner decorative border
  love.graphics.setColor(style.border[1], style.border[2], style.border[3], 0.35)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", cardX + 6, cardY + 6, cardW - 12, cardH - 12, 6, 6)

  -- 3. Top Stamp & Header Bar
  local stampW = isCompact and 90 or 110
  local stampH = isCompact and 24 or 30
  local stampX = cardX + cardW - stampW - (isCompact and 12 or 18)
  local stampY = cardY + (isCompact and 12 or 16)

  -- Postage Stamp Badge
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.rectangle("fill", stampX, stampY, stampW, stampH, 4, 4)
  love.graphics.setColor(style.border[1], style.border[2], style.border[3], 0.8)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", stampX, stampY, stampW, stampH, 4, 4)

  Layout.drawText(style.stamp, stampX, stampY + math.floor((stampH - Layout.textHeight("tiny")) / 2), {
    font = "tiny",
    color = style.border,
    align = "center",
    width = stampW,
    bold = true,
  })

  -- Watermark Header
  Layout.drawText("STATIONERY LETTER", cardX + (isCompact and 14 or 20), cardY + (isCompact and 14 or 20), {
    font = "caption",
    color = style.border,
    bold = true,
  })

  -- 4. Central Message Body
  local msgBoxY = cardY + (isCompact and 46 or 64)
  local footerH = isCompact and 22 or 28
  local authorH = isCompact and 22 or 28
  local msgBoxW = cardW - (isCompact and 28 or 36)
  local msgBoxX = cardX + (isCompact and 14 or 18)
  local msgBoxH = cardH - (msgBoxY - cardY) - authorH - footerH - (isCompact and 6 or 10)

  -- Letter message background slot
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.rectangle("fill", msgBoxX, msgBoxY, msgBoxW, msgBoxH, 6, 6)
  love.graphics.setColor(style.border[1], style.border[2], style.border[3], 0.3)
  love.graphics.rectangle("line", msgBoxX, msgBoxY, msgBoxW, msgBoxH, 6, 6)

  -- Line 1
  local textFont = (isCompact or isPortrait) and "button" or "headline"
  local line1Y = msgBoxY + (isCompact and 12 or 20)
  Layout.drawText(top or "", msgBoxX + 16, line1Y, {
    font = textFont,
    color = { 0.15, 0.15, 0.20, 1 },
    bold = true,
  })

  -- Line 2
  if bottom and #bottom > 0 and msgBoxH >= 50 then
    local line2Y = line1Y + (isCompact and 26 or 38)
    Layout.drawText(bottom, msgBoxX + 16, line2Y, {
      font = textFont,
      color = { 0.15, 0.15, 0.20, 1 },
      bold = true,
    })
  end

  -- Ruled writing guidelines
  love.graphics.setColor(style.border[1], style.border[2], style.border[3], 0.25)
  local guide1Y = line1Y + (isCompact and 20 or 28)
  love.graphics.line(msgBoxX + 12, guide1Y, msgBoxX + msgBoxW - 12, guide1Y)
  if msgBoxH >= 64 then
    local guide2Y = guide1Y + (isCompact and 26 or 38)
    love.graphics.line(msgBoxX + 12, guide2Y, msgBoxX + msgBoxW - 12, guide2Y)
  end

  -- 5. Author Signature (Bottom Right)
  if author and #author > 0 then
    local signStr = ("From:  %s"):format(tostring(author):upper())
    local signY = msgBoxY + msgBoxH + (isCompact and 4 or 6)
    Layout.drawText(signStr, cardX + cardW - 200, signY, {
      font = "caption",
      color = { 0.20, 0.20, 0.25, 1 },
      bold = true,
    })
  end

  -- 6. Party Mail Action Submenu
  if state.screenId == "MailMenu" or state.isMailMenu or state.index then
    local subW = isCompact and 140 or 160
    local subH = isCompact and 96 or 116
    local subX = cardX + 18
    local subY = cardY + cardH - subH - 18

    Layout.drawCard(subX, subY, subW, subH, {
      color = theme.colors.surface,
      borderColor = theme.colors.borderStrong,
      borderWidth = 1.5,
      radius = 8,
    })

    local entries = { "READ MAIL", "TAKE ITEM", "QUIT" }
    local selIdx = state.index or 1
    local btnH = isCompact and 24 or 28
    for i, eLabel in ipairs(entries) do
      local isSel = (i == selIdx)
      Layout.drawButton(subX + 6, subY + 6 + (i - 1) * (btnH + 4), subW - 12, btnH, eLabel, {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = "tiny",
      })
    end
  end

  -- 7. Footer Hint
  Layout.drawText("Press A, B or START to close letter", cardX, cardY + cardH - footerH + 2, {
    font = "tiny",
    color = style.border,
    align = "center",
    width = cardW,
  })
end

return MailRenderer
