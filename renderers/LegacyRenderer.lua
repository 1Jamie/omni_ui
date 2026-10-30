-- OmniUI Legacy V1 Screen Renderer
-- Renders custom screen models registered via the v1 adapter contract.

local Layout = require("mods.omni_ui.core.Layout")

local LegacyRenderer = {}

function LegacyRenderer.draw(game, state, screenDef, w, h, theme)
  if not screenDef or not screenDef.model then return end
  local model = screenDef.model(game, state)
  if not model then return end

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(model.title or "MENU", 18, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - 120, 12, "ADAPTER V1", { kind = "ghost" })

  local bodyH = h - 96

  -- 2. Content Card
  Layout.drawCard(0, 52, w, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })
  local rows = model.rows or {}
  local curIdx = model.index or 1

  local rowH = 40
  for i, row in ipairs(rows) do
    local isSel = (curIdx == i)
    local ry = 64 + (i - 1) * (rowH + 6)
    if ry + rowH > 52 + bodyH - 12 then break end

    if isSel and row.enabled ~= false then
      Layout.drawCard(10, ry, w - 20, rowH, {
        color = theme.accentDark,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 6,
      })
    else
      Layout.drawSlot(10, ry, w - 20, rowH, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 6,
      })
    end

    if row.label then
      Layout.drawText(row.label, 24, ry + 11, {
        font = "button",
        color = isSel and theme.heading or theme.text,
        bold = isSel,
      })
    end

    if row.value and tostring(row.value) ~= "" then
      Layout.drawBadge(w - 110, ry + 8, tostring(row.value), {
        kind = isSel and "good" or "ghost",
      })
    end
  end

  -- 3. Footer Hint Bar
  local footY = h - 38
  local hints = {
    { key = "▲ ▼", label = "Navigate" },
    { key = "A", label = "Select", primary = true },
    { key = "B", label = "Back" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = 16, columns = { 0, 100, 190 } })
end

return LegacyRenderer
