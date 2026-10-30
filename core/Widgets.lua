-- OmniUI Reusable Retained UI Widgets
-- Clean, modern presentation with vector typography and launcher tokens.

local Layout = require("mods.omni_ui.core.Layout")
local TypeChart = require("src.battle.TypeChart")

local Widgets = {}

local TYPE_COLORS = {
  NORMAL   = { 0.55, 0.55, 0.50 },
  FIRE     = { 0.88, 0.38, 0.18 },
  WATER    = { 0.28, 0.48, 0.88 },
  GRASS    = { 0.38, 0.70, 0.24 },
  ELECTRIC = { 0.88, 0.72, 0.12 },
  ICE      = { 0.48, 0.78, 0.78 },
  FIGHTING = { 0.70, 0.18, 0.14 },
  POISON   = { 0.58, 0.22, 0.58 },
  GROUND   = { 0.78, 0.65, 0.35 },
  FLYING   = { 0.58, 0.48, 0.88 },
  PSYCHIC  = { 0.88, 0.28, 0.48 },
  BUG      = { 0.58, 0.65, 0.12 },
  ROCK     = { 0.65, 0.55, 0.18 },
  GHOST    = { 0.38, 0.28, 0.55 },
  DRAGON   = { 0.38, 0.18, 0.88 },
  STEEL    = { 0.65, 0.65, 0.75 },
  DARK     = { 0.38, 0.28, 0.22 },
  FAIRY    = { 0.88, 0.45, 0.62 },
}

local STATUS_COLORS = {
  PSN = { 0.63, 0.25, 0.63 },
  TOX = { 0.50, 0.15, 0.50 },
  PAR = { 0.95, 0.75, 0.15 },
  BRN = { 0.94, 0.44, 0.22 },
  SLP = { 0.55, 0.55, 0.60 },
  FRZ = { 0.40, 0.75, 0.90 },
  FNT = { 0.85, 0.20, 0.20 },
}

function Widgets.getUniqueTypes(types)
  if not types then return {} end
  if type(types) == "string" then return { types:upper():gsub("_TYPE$", "") } end
  local out = {}
  local seen = {}
  for _, t in ipairs(types) do
    if t and t ~= "" then
      local clean = tostring(t):upper():gsub("_TYPE$", "")
      if clean ~= "" and not seen[clean] then
        seen[clean] = true
        out[#out + 1] = clean
      end
    end
  end
  return out
end

function Widgets.drawTypeBadge(typeId, x, y, opts)
  if not typeId or typeId == "" then return 0 end
  opts = opts or {}
  local text = (TypeChart and TypeChart.displayName and TypeChart.displayName(typeId)) or typeId
  text = tostring(text):upper():gsub("_TYPE$", "")
  local color = TYPE_COLORS[text] or TYPE_COLORS[tostring(typeId):upper():gsub("_TYPE$", "")] or { 0.45, 0.45, 0.50 }
  local textW = Layout.textWidth(text, opts.font or "tiny")
  local badgeW = opts.width or (textW + 16)
  local badgeH = opts.height or 18

  if not love or not love.graphics then return badgeW end
  love.graphics.setColor(color[1], color[2], color[3], 0.92)
  love.graphics.rectangle("fill", x, y, badgeW, badgeH, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.25)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, badgeW, badgeH, 4, 4)

  love.graphics.setColor(1, 1, 1, 1)
  Layout.drawText(text, x + math.floor((badgeW - textW) / 2), y + math.floor((badgeH - 12) / 2), { font = opts.font or "tiny", bold = true })
  return badgeW
end

function Widgets.drawStatusBadge(status, x, y)
  if not status or status == "OK" then return 0 end
  local text = tostring(status):sub(1, 3):upper()
  local color = STATUS_COLORS[text] or { 0.85, 0.20, 0.20 }
  local textW = Layout.textWidth(text, "tiny")
  local badgeW = textW + 16
  local badgeH = 18

  if not love or not love.graphics then return badgeW end
  love.graphics.setColor(color[1], color[2], color[3], 0.95)
  love.graphics.rectangle("fill", x, y, badgeW, badgeH, 4, 4)

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, badgeW, badgeH, 4, 4)

  Layout.drawText(text, x + 8, y + 3, { font = "tiny", color = { 1, 1, 1, 1 }, bold = true })
  return badgeW
end

function Widgets.formatNumber(n)
  local str = tostring(math.floor(tonumber(n) or 0))
  local k
  while true do
    str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return str
end

local CONTEST_AXES = {
  { key = "cool",   label = "COOL",   angle = -math.pi / 2,                  color = { 0.95, 0.35, 0.30 } },
  { key = "beauty", label = "BEAUTY", angle = -math.pi / 2 + 2 * math.pi / 5, color = { 0.30, 0.65, 0.95 } },
  { key = "cute",   label = "CUTE",   angle = -math.pi / 2 + 4 * math.pi / 5, color = { 0.95, 0.45, 0.75 } },
  { key = "smart",  label = "SMART",  angle = -math.pi / 2 + 6 * math.pi / 5, color = { 0.35, 0.85, 0.45 } },
  { key = "tough",  label = "TOUGH",  angle = -math.pi / 2 + 8 * math.pi / 5, color = { 0.95, 0.75, 0.20 } },
}

function Widgets.drawConditionRadar(cx, cy, radius, mon, opts)
  if not love or not love.graphics then return end
  opts = opts or {}
  local theme = opts.theme or { border = { 0.2, 0.3, 0.4, 0.6 }, textDim = { 0.6, 0.7, 0.8, 1 } }
  local r = radius or 80

  -- 1. Concentric Guide Pentagons (25%, 50%, 75%, 100%)
  love.graphics.setLineWidth(1)
  for _, frac in ipairs({ 0.25, 0.50, 0.75, 1.0 }) do
    local ringR = r * frac
    local ringPts = {}
    for _, ax in ipairs(CONTEST_AXES) do
      ringPts[#ringPts + 1] = cx + math.cos(ax.angle) * ringR
      ringPts[#ringPts + 1] = cy + math.sin(ax.angle) * ringR
    end
    love.graphics.setColor(theme.border[1] or 0.2, theme.border[2] or 0.3, theme.border[3] or 0.4, (frac == 1.0) and 0.55 or 0.25)
    love.graphics.polygon("line", ringPts)
  end

  -- 2. Spoke Lines from Center
  love.graphics.setColor(theme.border[1] or 0.2, theme.border[2] or 0.3, theme.border[3] or 0.4, 0.35)
  for _, ax in ipairs(CONTEST_AXES) do
    local ex = cx + math.cos(ax.angle) * r
    local ey = cy + math.sin(ax.angle) * r
    love.graphics.line(cx, cy, ex, ey)
  end

  -- 3. Pokémon Stat Data Polygon
  local monStats = {}
  local statPts = {}
  for _, ax in ipairs(CONTEST_AXES) do
    local val = 0
    if mon then
      val = mon[ax.key] or (mon.contest and mon.contest[ax.key]) or 0
      val = math.max(0, math.min(255, tonumber(val) or 0))
    end
    monStats[ax.key] = val
    local frac = math.max(0.06, val / 255)
    statPts[#statPts + 1] = cx + math.cos(ax.angle) * (r * frac)
    statPts[#statPts + 1] = cy + math.sin(ax.angle) * (r * frac)
  end

  -- Luminous fill & outline
  love.graphics.setColor(0.20, 0.85, 0.70, 0.35)
  love.graphics.polygon("fill", statPts)
  love.graphics.setColor(0.35, 1.00, 0.85, 0.90)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", statPts)

  -- Center Core Pip
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.circle("fill", cx, cy, 3)

  -- 4. Stat Vertex Points & Labels
  for i, ax in ipairs(CONTEST_AXES) do
    local val = monStats[ax.key] or 0
    local lx = cx + math.cos(ax.angle) * (r + 18)
    local ly = cy + math.sin(ax.angle) * (r + 18)
    local valStr = ("%d"):format(val)
    local tag = ("%s %s"):format(ax.label, valStr)
    local tw = Layout.textWidth(tag, "tiny")
    local th = 14
    local bx = math.floor(lx - tw / 2)
    local by = math.floor(ly - th / 2)

    love.graphics.setColor(ax.color[1], ax.color[2], ax.color[3], 0.95)
    Layout.drawText(tag, bx, by, { font = "tiny", color = ax.color, bold = true })
  end

  -- 5. Sheen Level Indicator (0..255)
  local sheen = mon and (mon.sheen or (mon.contest and mon.contest.sheen)) or 0
  sheen = math.max(0, math.min(255, tonumber(sheen) or 0))
  local sheenLabel = ("SHEEN: %d / 255"):format(sheen)
  local sheenW = Layout.textWidth(sheenLabel, "tiny") + 20
  local sheenX = cx - math.floor(sheenW / 2)
  local sheenY = cy + r + 26
  Layout.drawBadge(sheenX, sheenY, sheenLabel, {
    kind = (sheen >= 255) and "gold" or "accent",
    font = "tiny",
    width = sheenW,
    height = 20,
  })
end

return Widgets
