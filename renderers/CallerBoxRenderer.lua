-- OmniUI Modern Caller ID HUD Interface Renderer
-- Floating caller ID pill HUD card docked at the top of the overworld displaying contact name, trainer class, and phone status.
-- Fully responsive for portrait safe insets and compact viewports.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local CallerBoxRenderer = {}

function CallerBoxRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local name = state.name and state.name ~= "" and state.name or "UNKNOWN CALLER"
  local className = state.className

  -- Docked at top center respecting safeInsetTop
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local pillW = math.min(460, math.max(260, vw - pad * 2))
  local pillH = className and (isCompact and 48 or 56) or (isCompact and 40 or 46)
  local pillX = math.floor((vw - pillW) / 2)
  local pillY = ctx.safeInsetTop or (isCompact and 10 or 16)

  -- Master Glassmorphic Floating Pill Card
  Layout.drawCard(pillX, pillY, pillW, pillH, {
    color = theme.colors.surface,
    borderColor = theme.colors.accent,
    borderWidth = 1.5,
    radius = isCompact and 8 or 12,
  })

  -- Phone Glyph Badge
  local iconSize = isCompact and 24 or 30
  Layout.drawBadge(pillX + (isCompact and 8 or 12), pillY + math.floor((pillH - iconSize) / 2), "☎", {
    kind = "accent",
    font = isCompact and "button" or "headline",
    width = iconSize,
    height = iconSize,
    radius = 5,
  })

  -- Caller Name
  local textX = pillX + iconSize + (isCompact and 14 or 20)
  Layout.drawText(tostring(name):upper(), textX, pillY + (className and (isCompact and 6 or 8) or math.floor((pillH - Layout.textHeight("button")) / 2)), {
    font = isCompact and "button" or "headline",
    color = theme.colors.heading,
    bold = true,
  })

  -- Trainer Class Badge if applicable
  if className and className ~= "" then
    Layout.drawText(tostring(className):upper(), textX, pillY + (isCompact and 26 or 32), {
      font = "tiny",
      color = theme.colors.textDim,
      bold = true,
    })
  end

  -- Live Connection Status Badge
  local statusStr = isCompact and "LIVE" or "LIVE CALL"
  local statusW = Layout.textWidth(statusStr, "tiny") + 14
  Layout.drawBadge(pillX + pillW - statusW - (isCompact and 8 or 12), pillY + math.floor((pillH - 20) / 2), statusStr, {
    kind = "good",
    font = "tiny",
    height = 20,
    width = statusW,
    radius = 4,
  })
end

return CallerBoxRenderer
