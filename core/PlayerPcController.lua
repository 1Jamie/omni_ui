-- OmniUI Player PC Controller & State Machine
-- Unified Item Storage Manager: Seamlessly browse PC storage and Bag inventory,
-- transfer items with integrated quantity steppers, safe toss confirms, and tab switching.

local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local PlayerPcController = {}
PlayerPcController.__index = PlayerPcController

function PlayerPcController.new(game, opts)
  opts = opts or {}
  local self = setmetatable({}, PlayerPcController)
  self.game = game
  self.adapter = AdapterResolver.resolve(game)
  self.tab = opts.tab or (opts.mode == "deposit" and "bag") or "pc" -- "pc" | "bag"
  self.pcIndex = 1
  self.bagIndex = 1
  self.pcScroll = 0
  self.bagScroll = 0
  self.mode = "browse" -- "browse" | "action_menu" | "quantity" | "confirm_toss" | "message"
  self.actionCursor = 1
  self.qty = 1
  self.maxQty = 1
  self.activeAction = nil
  self.message = nil
  self.messageKind = "good"

  self:refresh()
  return self
end

function PlayerPcController:refresh()
  self.pcItems = self.adapter:getItemStorage() or {}
  self.bagItems = self.adapter:getBagItems() or {}

  local detectedBagCap = (self.adapter and self.adapter.getBagCapacity and self.adapter:getBagCapacity()) or 20
  local detectedPcCap = (self.adapter and self.adapter.getPcCapacity and self.adapter:getPcCapacity()) or 50

  self.maxBagItems = math.max(detectedBagCap, #self.bagItems)
  self.maxPcItems = math.max(detectedPcCap, #self.pcItems)

  if #self.pcItems > 0 then
    self.pcIndex = math.max(1, math.min(#self.pcItems, self.pcIndex))
  else
    self.pcIndex = 1
  end

  if #self.bagItems > 0 then
    self.bagIndex = math.max(1, math.min(#self.bagItems, self.bagIndex))
  else
    self.bagIndex = 1
  end
end

function PlayerPcController:getActiveList()
  if self.tab == "bag" then
    return self.bagItems, self.bagIndex, "bag"
  else
    return self.pcItems, self.pcIndex, "pc"
  end
end

function PlayerPcController:getSelectedItem()
  local list, idx = self:getActiveList()
  return list[idx]
end

function PlayerPcController:switchTab(targetTab)
  local nextTab = targetTab or ((self.tab == "pc") and "bag" or "pc")
  if nextTab == self.tab then return end
  self.tab = nextTab
  self:refresh()
  self:playSfx("Press_AB")
end

function PlayerPcController:playSfx(name)
  if self.game and self.game.data then
    local Sound = require("src.core.Sound")
    if Sound and Sound.play then
      pcall(Sound.play, self.game.data, name or "Press_AB")
    end
  end
end

function PlayerPcController:handleInput(input)
  if not input then return false end

  -- 1. Message dismissal
  if self.mode == "message" then
    if input:wasPressed("a") or input:wasPressed("b") or input:wasPressed("space") or input:wasPressed("return") or input:wasPressed("escape") or input:wasPressed("start") or input:wasPressed("backspace") then
      self.mode = "browse"
      self.message = nil
      self:playSfx("Press_AB")
      return true
    end
    return true
  end

  -- 2. Quantity Stepper Modal
  if self.mode == "quantity" then
    local maxVal = math.max(1, self.maxQty or 1)
    if input:wasPressed("up") then
      local step = (maxVal >= 10) and 10 or 1
      self.qty = math.min(maxVal, self.qty + step)
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("down") then
      local step = (maxVal >= 10) and 10 or 1
      self.qty = math.max(1, self.qty - step)
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("right") then
      self.qty = self.qty + 1
      if self.qty > maxVal then self.qty = 1 end
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("left") then
      self.qty = self.qty - 1
      if self.qty < 1 then self.qty = maxVal end
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("a") or input:wasPressed("return") or input:wasPressed("space") then
      if self.activeAction == "TOSS" then
        self.mode = "confirm_toss"
        self.actionCursor = 1
        self:playSfx("Press_AB")
        return true
      else
        return self:executeTransfer()
      end
    elseif input:wasPressed("b") or input:wasPressed("escape") or input:wasPressed("start") or input:wasPressed("backspace") then
      self.mode = "action_menu"
      self:playSfx("Press_AB")
      return true
    end
    return true
  end

  -- 3. Confirm Toss Modal
  if self.mode == "confirm_toss" then
    if input:wasPressed("left") or input:wasPressed("right") or input:wasPressed("up") or input:wasPressed("down") then
      self.actionCursor = (self.actionCursor == 1) and 2 or 1
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("a") or input:wasPressed("return") or input:wasPressed("space") then
      if self.actionCursor == 1 then
        return self:executeToss()
      else
        self.mode = "browse"
        self:playSfx("Press_AB")
        return true
      end
    elseif input:wasPressed("b") or input:wasPressed("escape") or input:wasPressed("start") or input:wasPressed("backspace") then
      self.mode = "browse"
      self:playSfx("Press_AB")
      return true
    end
    return true
  end

  -- 4. Action Submenu Modal
  if self.mode == "action_menu" then
    local actions = (self.tab == "pc") and { "WITHDRAW", "TOSS", "CANCEL" } or { "DEPOSIT", "TOSS", "CANCEL" }
    if input:wasPressed("up") then
      self.actionCursor = self.actionCursor - 1
      if self.actionCursor < 1 then self.actionCursor = #actions end
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("down") then
      self.actionCursor = self.actionCursor + 1
      if self.actionCursor > #actions then self.actionCursor = 1 end
      self:playSfx("Press_AB")
      return true
    elseif input:wasPressed("a") or input:wasPressed("return") or input:wasPressed("space") then
      local act = actions[self.actionCursor]
      if act == "WITHDRAW" or act == "DEPOSIT" then
        local it = self:getSelectedItem()
        if not it then self.mode = "browse" return true end
        local count = it.count or it.stack or 1
        if count > 1 then
          self.mode = "quantity"
          self.activeAction = act
          self.qty = 1
          self.maxQty = count
          self:playSfx("Press_AB")
        else
          self.qty = 1
          self.activeAction = act
          return self:executeTransfer()
        end
      elseif act == "TOSS" then
        local it = self:getSelectedItem()
        if not it then self.mode = "browse" return true end
        local def = it.def or (self.game and self.game.data and self.game.data.items and self.game.data.items[it.id])
        if (def and def.keyItem) or (type(it.id) == "string" and it.id:find("^HM_")) then
          self.mode = "message"
          self.message = "That's too important to toss!"
          self.messageKind = "danger"
          self:playSfx("Press_AB")
          return true
        end
        local count = it.count or it.stack or 1
        if count > 1 then
          self.mode = "quantity"
          self.activeAction = "TOSS"
          self.qty = 1
          self.maxQty = count
          self:playSfx("Press_AB")
        else
          self.qty = 1
          self.mode = "confirm_toss"
          self.actionCursor = 1
          self:playSfx("Press_AB")
        end
      else
        self.mode = "browse"
        self:playSfx("Press_AB")
      end
      return true
    elseif input:wasPressed("b") or input:wasPressed("escape") or input:wasPressed("start") or input:wasPressed("backspace") then
      self.mode = "browse"
      self:playSfx("Press_AB")
      return true
    end
    return true
  end

  -- 5. Standard Browsing Mode
  -- Tab switching via Left / Right / Tab / L / R / PageUp / PageDown
  if input:wasPressed("tab") or input:wasPressed("l") or input:wasPressed("r") or input:wasPressed("pageup") or input:wasPressed("pagedown") then
    self:switchTab()
    return true
  end

  local list, curIdx, tabName = self:getActiveList()
  local total = #list

  if input:wasPressed("left") then
    if self.tab == "bag" then
      self:switchTab("pc")
    else
      self:switchTab("bag")
    end
    return true
  elseif input:wasPressed("right") then
    if self.tab == "pc" then
      self:switchTab("bag")
    else
      self:switchTab("pc")
    end
    return true
  elseif input:wasPressed("up") then
    if total > 0 then
      curIdx = curIdx - 1
      if curIdx < 1 then curIdx = total end
      if tabName == "bag" then self.bagIndex = curIdx else self.pcIndex = curIdx end
      self:playSfx("Press_AB")
    end
    return true
  elseif input:wasPressed("down") then
    if total > 0 then
      curIdx = curIdx + 1
      if curIdx > total then curIdx = 1 end
      if tabName == "bag" then self.bagIndex = curIdx else self.pcIndex = curIdx end
      self:playSfx("Press_AB")
    end
    return true
  elseif input:wasPressed("a") or input:wasPressed("return") or input:wasPressed("space") then
    local item = self:getSelectedItem()
    if not item or item.cancel then
      return "close"
    end
    self.mode = "action_menu"
    self.actionCursor = 1
    self:playSfx("Press_AB")
    return true
  elseif input:wasPressed("b") or input:wasPressed("escape") or input:wasPressed("start") or input:wasPressed("backspace") then
    return "close"
  end

  return false
end

function PlayerPcController:executeTransfer()
  local item = self:getSelectedItem()
  if not item then self.mode = "browse" return true end

  local id = item.id or item.value
  local qty = self.qty or 1
  local name = item.label or item.name or id
  local slot = item.slot

  if self.tab == "pc" or self.activeAction == "WITHDRAW" then
    local ok, err = self.adapter:withdrawItem(id, qty, slot)
    if ok then
      self:refresh()
      self:playSfx("Withdraw_Deposit")
      self.mode = "message"
      self.message = ("Withdrew %dx %s."):format(qty, name)
      self.messageKind = "good"
    else
      self.mode = "message"
      self.message = err or "Could not withdraw item."
      self.messageKind = "danger"
      self:playSfx("Press_AB")
    end
  else
    local ok, err = self.adapter:depositItem(id, qty, slot)
    if ok then
      self:refresh()
      self:playSfx("Withdraw_Deposit")
      self.mode = "message"
      self.message = ("Stored %dx %s in PC."):format(qty, name)
      self.messageKind = "good"
    else
      self.mode = "message"
      self.message = err or "Could not store item."
      self.messageKind = "danger"
      self:playSfx("Press_AB")
    end
  end
  return true
end

function PlayerPcController:executeToss()
  local item = self:getSelectedItem()
  if not item then self.mode = "browse" return true end

  local id = item.id or item.value
  local qty = self.qty or 1
  local name = item.label or item.name or id
  local slot = item.slot

  if self.tab == "pc" then
    self.adapter:tossItem(id, qty, slot)
  else
    local save = self.game and self.game.save
    local data = self.game and self.game.data
    local Bag = require("src.inventory.Bag")
    if save then Bag.remove(save, id, qty, data, slot) end
  end

  self:refresh()
  self:playSfx("Withdraw_Deposit")
  self.mode = "message"
  self.message = ("Threw away %dx %s."):format(qty, name)
  self.messageKind = "good"
  return true
end

function PlayerPcController:close()
  local stk = (self.game and self.game.stack)
  if stk and stk.pop then
    stk:pop()
  end
  local g3Stack = package.loaded["src.ui.game3.stack"]
  if g3Stack and g3Stack.has and g3Stack.has("item_pc") then
    local okItemPc, ItemPc = pcall(require, "src.ui.game3.item_pc")
    if okItemPc and ItemPc then
      ItemPc.open = false
      g3Stack.pop("item_pc")
      if ItemPc._onClose then
        local cb = ItemPc._onClose
        ItemPc._onClose = nil
        cb()
      end
    end
  end
  self:playSfx("Turn_Off_PC")
end

return PlayerPcController
