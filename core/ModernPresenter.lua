-- OmniUI Modern List & Card Presenter
-- Renders normalized screen models with crisp Game Boy / SGB / GBC palette fidelity and snappy inputs.

local Font = require("src.render.Font")
local Theme = require("src.ui.Theme")

local ModernPresenter = {}

function ModernPresenter.draw(state, model)
  if not model then return end

  -- Clear screen to white (DMG Shade 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  love.graphics.setColor(0, 0, 0, 1)

  -- 1. Top Title Header Box
  local title = model.title or "MENU"
  Font.drawBox(0, 0, 20, 3)
  Font.draw(title, 8, 8)

  -- 2. Middle Content Box (rows)
  Font.drawBox(0, 2, 20, 11)

  local rows = model.rows or {}
  local startIdx = (model.scroll or 0) + 1
  local maxVisible = 5
  local curIdx = model.index or 1

  local y = 28
  for i = startIdx, math.min(#rows, startIdx + maxVisible - 1) do
    local row = rows[i]
    if row then
      local isSelected = (curIdx == i)
      if isSelected and row.enabled ~= false then
        Font.drawCode(Theme.cursor, 8, y)
      end

      -- Left Label
      if row.label then
        Font.draw(row.label, 16, y)
      end

      -- Right Value
      if row.value and tostring(row.value) ~= "" then
        local valStr = tostring(row.value)
        local valW = Font.width(valStr)
        Font.draw(valStr, 152 - valW, y)
      end

      y = y + 14
    end
  end

  -- 3. Bottom Footer Box
  Font.drawBox(0, 12, 20, 4)
  if model.footer and #model.footer > 0 then
    local fy = 104
    for _, line in ipairs(model.footer) do
      Font.draw(line, 8, fy)
      fy = fy + 12
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function ModernPresenter.handleInput(state, actions, game)
  local input = game and game.input
  if not input then return false end

  if input:wasPressed("up") then
    if actions and actions.up then actions.up(game, state) end
    return true
  elseif input:wasPressed("down") then
    if actions and actions.down then actions.down(game, state) end
    return true
  elseif input:wasPressed("left") then
    if actions and actions.left then actions.left(game, state) end
    return true
  elseif input:wasPressed("right") then
    if actions and actions.right then actions.right(game, state) end
    return true
  elseif input:wasPressed("a") then
    if actions and actions.select then actions.select(game, state) end
    return true
  elseif input:wasPressed("b") then
    if actions and actions.back then actions.back(game, state) end
    return true
  end

  return false
end

return ModernPresenter
