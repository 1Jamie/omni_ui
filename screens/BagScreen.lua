-- OmniUI Modern Bag Screen
-- Pocket-based item browser with SGB palette fidelity, full input responsiveness, and item actions.

local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
local Theme = require("src.ui.Theme")
local Bag = require("src.inventory.Bag")
local ItemEffects = require("src.inventory.ItemEffects")
local Screens = require("src.ui.Screens")

local BagScreen = { isMenu = true, isOpaque = true }
BagScreen.__index = BagScreen

local DEFAULT_POCKETS = {
  { id = "items", label = "ITEMS" },
  { id = "balls", label = "BALLS" },
  { id = "key",   label = "KEY ITEMS" },
  { id = "tmhm",  label = "TMs & HMs" },
}

function BagScreen.new(game, opts)
  opts = opts or {}
  local self = setmetatable({}, BagScreen)
  self.game = game
  self.opts = opts
  self.battle = opts.battle
  self.screenId = "BagMenu"

  -- Pocket initialization
  self.pockets = DEFAULT_POCKETS
  local bagPocketsMod = package.loaded["mods.gen1_bag_pockets.bag_pockets"]
  if bagPocketsMod and bagPocketsMod.activePockets then
    self.pockets = bagPocketsMod.activePockets()
  end
  self.pocketIdx = 1
  self.cursor = 1
  self.scroll = 0
  self.visibleRows = 4

  self:refreshItems()
  return self
end

function BagScreen:refreshItems()
  local inv = (self.game and self.game.save and self.game.save.inventory) or {}
  local order = Bag.order(self.game.save)
  local currentPocket = self.pockets[self.pocketIdx] and self.pockets[self.pocketIdx].id or "items"

  self.items = {}
  local bagPocketsMod = package.loaded["mods.gen1_bag_pockets.bag_pockets"]
  for _, id in ipairs(order) do
    local def = self.game.data.items[id]
    local pocket = "items"
    if bagPocketsMod and bagPocketsMod.classify then
      pocket = bagPocketsMod.classify(id, def)
    elseif def and def.keyItem then
      pocket = "key"
    elseif id:find("^HM_") or id:find("^TM_") then
      pocket = "tmhm"
    elseif id:find("BALL") then
      pocket = "balls"
    end

    if pocket == currentPocket then
      local count = inv[id]
      self.items[#self.items + 1] = {
        id = id,
        label = (def and def.name) or id,
        count = (def and def.keyItem) and nil or count,
        def = def,
      }
    end
  end

  self.items[#self.items + 1] = { cancel = true, label = Strings("CANCEL") }
  self.cursor = math.max(1, math.min(#self.items, self.cursor))
end

function BagScreen:update(dt)
  local input = self.game and self.game.input
  if not input then return end

  if self.game.data and (input:wasPressed("a") or input:wasPressed("b")) then
    local Sound = package.loaded["src.core.Sound"] or require("src.core.Sound")
    if Sound and Sound.play then
      Sound.play(self.game.data, "Press_AB")
    end
  end

  if input:wasPressed("left") then
    self.pocketIdx = (self.pocketIdx > 1) and (self.pocketIdx - 1) or #self.pockets
    self.cursor = 1
    self.scroll = 0
    self:refreshItems()
  elseif input:wasPressed("right") then
    self.pocketIdx = (self.pocketIdx < #self.pockets) and (self.pocketIdx + 1) or 1
    self.cursor = 1
    self.scroll = 0
    self:refreshItems()
  elseif input:wasPressed("up") then
    if self.cursor > 1 then
      self.cursor = self.cursor - 1
      if self.cursor <= self.scroll then
        self.scroll = self.cursor - 1
      end
    end
  elseif input:wasPressed("down") then
    if self.cursor < #self.items then
      self.cursor = self.cursor + 1
      if self.cursor > self.scroll + self.visibleRows then
        self.scroll = self.cursor - self.visibleRows
      end
    end
  elseif input:wasPressed("b") then
    self:close()
  elseif input:wasPressed("a") then
    self:onSelect()
  end
end

function BagScreen:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)

  -- Top Pocket Header Box
  Font.drawBox(0, 0, 20, 3)
  local curPocket = self.pockets[self.pocketIdx]
  local pocketLabel = curPocket and curPocket.label or "ITEMS"
  Font.draw(("< %s >"):format(pocketLabel), 16, 8)

  -- Items List Box
  Font.drawBox(0, 2, 20, 9)

  local startIdx = self.scroll + 1
  for r = 1, self.visibleRows do
    local idx = startIdx + r - 1
    local item = self.items[idx]
    if item then
      local isSel = (self.cursor == idx)
      local ry = 28 + (r - 1) * 14

      if isSel then
        Font.drawCode(Theme.cursor, 8, ry)
      end

      Font.draw(item.label, 16, ry)

      if item.count then
        local countStr = ("x%2d"):format(item.count)
        Font.draw(countStr, 128, ry)
      end
    end
  end

  -- Bottom Description Box
  Font.drawBox(0, 10, 20, 6)
  local curItem = self.items[self.cursor]
  if curItem and not curItem.cancel then
    local desc = (curItem.def and curItem.def.description) or "A useful item."
    if type(desc) == "table" then desc = table.concat(desc, " ") end
    Font.draw(desc:sub(1, 36), 8, 92)
    if #desc > 36 then
      Font.draw(desc:sub(37, 72), 8, 106)
    end
  else
    Font.draw("Close the Bag.", 8, 96)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function BagScreen:onSelect()
  local item = self.items[self.cursor]
  if not item or item.cancel then
    self:close()
    return
  end

  if self.battle then
    if self.opts.onUse then
      self.opts.onUse(item.id)
    end
    self:close()
    return
  end

  self:openItemActions(item)
end

function BagScreen:openItemActions(item)
  local actions = {
    { label = Strings("USE"), onSelect = function()
      self:useItem(item.id)
    end },
  }

  local def = item.def
  if not (def and def.keyItem) then
    actions[#actions + 1] = { label = Strings("TOSS"), onSelect = function()
      Bag.remove(self.game.save, item.id, 1)
      self:refreshItems()
    end }
  end

  actions[#actions + 1] = { label = Strings("CANCEL"), onSelect = function() end }

  local ChoiceBox = require("src.ui.ChoiceBox")
  self.game.stack:push(ChoiceBox.new(self.game, actions, {
    x = 100, y = 35, w = 56,
  }))
end

function BagScreen:useItem(itemId)
  local def = self.game.data.items[itemId]
  if def and (def.target == "PARTY" or def.machine) then
    Screens.push(self.game, "PartyMenu", {
      prompt = "Use on which POKéMON?",
      onSwitch = function(slot, mon)
        local ok, msg = ItemEffects.use(self.game.data, self.game.save, itemId, mon, self.battle, nil, self.game.overworld)
        self:refreshItems()
      end,
    })
  else
    ItemEffects.use(self.game.data, self.game.save, itemId, nil, self.battle, nil, self.game.overworld)
    self:refreshItems()
  end
end

function BagScreen:close()
  if self.game and self.game.stack then
    if self.game.stack:top() == self then
      self.game.stack:pop()
    else
      self.game.stack:pop()
    end
  end
  if self.opts.onClose then self.opts.onClose() end
end

return BagScreen
