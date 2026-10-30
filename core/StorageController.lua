-- OmniUI Storage Controller & State Machine
-- Handles user intent, navigation, grab-and-drop transactions, and safety rules.

local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local StorageController = {}
StorageController.__index = StorageController

function StorageController.new(game, opts)
  opts = opts or {}
  local self = setmetatable({}, StorageController)
  self.game = game
  self.adapter = AdapterResolver.resolve(game)
  self.zone = "box" -- "box" | "party" | "header" | "close_btn"
  self.boxSlot = 1
  self.partySlot = 1
  self.currentBoxId = self.adapter:getCurrentBox()
  self.mode = opts.mode or "browse" -- "browse" | "grabbed" | "action_menu" | "confirm_release" | "switch_box"
  self.subMode = opts.subMode or "move" -- "move" | "withdraw" | "deposit"
  self.grabbed = nil -- { mon = mon, sourceLoc = "box"|"party", sourceBox = id, sourceSlot = slot }
  self.actionCursor = 1
  self.boxMenuCursor = self.currentBoxId
  self.message = nil
  self.messageTimer = 0

  self:refresh()
  return self
end

function StorageController:refresh()
  self.boxCapacity = self.adapter:getBoxCapacity()
  self.boxCount = self.adapter:getBoxCount()
  self.partyCapacity = (self.adapter.getPartyCapacity and self.adapter:getPartyCapacity()) or 6
  self.currentBoxId = math.max(1, math.min(self.boxCount, self.currentBoxId or 1))
  self.boxMons = self.adapter:getBoxData(self.currentBoxId)
  self.partyMons = self.adapter:getPartyData()
  self.boxName = self.adapter:getBoxName(self.currentBoxId)
end

function StorageController:getCurrentSelection()
  if self.zone == "box" then
    return self.boxMons[self.boxSlot], "box", self.boxSlot
  elseif self.zone == "party" then
    return self.partyMons[self.partySlot], "party", self.partySlot
  end
  return nil, nil, nil
end

function StorageController:cycleBox(dir)
  local oldBoxId = self.currentBoxId
  local oldBoxMons = self.boxMons
  local oldBoxName = self.boxName
  self.currentBoxId = ((self.currentBoxId - 1 + dir) % self.boxCount) + 1
  self.adapter:setCurrentBox(self.currentBoxId)
  self:refresh()
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  self.boxTransition = {
    dir = dir or 1,
    fromBoxId = oldBoxId,
    fromMons = oldBoxMons or {},
    fromName = oldBoxName or ("BOX " .. oldBoxId),
    toBoxId = self.currentBoxId,
    toMons = self.boxMons or {},
    toName = self.boxName or ("BOX " .. self.currentBoxId),
    startTime = now,
    duration = 0.22,
  }
  if self.game and self.game.data then
    require("src.core.Sound").play(self.game.data, "Press_AB")
  end
end

function StorageController:handleInput(input)
  if not input then return end

  -- Message dismiss
  if self.message then
    if input:wasPressed("a") or input:wasPressed("b") then
      self.message = nil
      return true
    end
    return true
  end

  -- Bumper Quick Box Flip (L / R / tab / pageup / pagedown)
  if input:wasPressed("pageup") or input:wasPressed("l") then
    self:cycleBox(-1)
    return true
  elseif input:wasPressed("pagedown") or input:wasPressed("r") then
    self:cycleBox(1)
    return true
  end

  if self.mode == "action_menu" then
    return self:handleActionMenuInput(input)
  elseif self.mode == "confirm_release" then
    return self:handleReleaseConfirmInput(input)
  elseif self.mode == "switch_box" then
    return self:handleSwitchBoxInput(input)
  elseif self.mode == "grabbed" then
    return self:handleBrowseInput(input, true)
  else
    return self:handleBrowseInput(input, false)
  end
end

function StorageController:handleBrowseInput(input, isGrabbed)
  local cols = 6
  local rows = math.ceil(self.boxCapacity / cols)
  local pCap = self.partyCapacity or 6

  local moved = false
  if self.zone == "box" then
    if input:wasPressed("left") then
      if (self.boxSlot - 1) % cols == 0 then
        -- Wrap or cycle box
        self:cycleBox(-1)
        self.boxSlot = self.boxSlot + (cols - 1)
      else
        self.boxSlot = self.boxSlot - 1
      end
      moved = true
    elseif input:wasPressed("right") then
      if self.boxSlot % cols == 0 then
        -- Wrap or cycle box
        self:cycleBox(1)
        self.boxSlot = self.boxSlot - (cols - 1)
      else
        self.boxSlot = self.boxSlot + 1
      end
      moved = true
    elseif input:wasPressed("up") then
      if self.boxSlot <= cols then
        self.zone = "header"
      else
        self.boxSlot = self.boxSlot - cols
      end
      moved = true
    elseif input:wasPressed("down") then
      if self.boxSlot + cols > self.boxCapacity then
        self.zone = "party"
        local partyCol = math.max(1, math.min(pCap, (self.boxSlot - 1) % cols + 1))
        self.partySlot = partyCol
      else
        self.boxSlot = self.boxSlot + cols
      end
      moved = true
    end
  elseif self.zone == "party" then
    if input:wasPressed("left") then
      self.partySlot = math.max(1, self.partySlot - 1)
      moved = true
    elseif input:wasPressed("right") then
      self.partySlot = math.min(pCap, self.partySlot + 1)
      moved = true
    elseif input:wasPressed("up") then
      self.zone = "box"
      self.boxSlot = math.min(self.boxCapacity, (rows - 1) * cols + math.min(cols, self.partySlot))
      moved = true
    end
  elseif self.zone == "header" then
    if input:wasPressed("left") then
      self:cycleBox(-1)
      return true
    elseif input:wasPressed("right") then
      self:cycleBox(1)
      return true
    elseif input:wasPressed("down") then
      self.zone = "box"
      self.boxSlot = 1
      moved = true
    elseif input:wasPressed("a") then
      self.mode = "switch_box"
      self.boxMenuCursor = self.currentBoxId
      if self.game and self.game.data then require("src.core.Sound").play(self.game.data, "Press_AB") end
      return true
    end
  end

  if moved then
    if self.game and self.game.data then
      require("src.core.Sound").play(self.game.data, "Press_AB")
    end
    return true
  end

  -- Action 'A' button
  if input:wasPressed("a") then
    local selMon, loc, slot = self:getCurrentSelection()
    if isGrabbed then
      -- Drop / Swap grabbed mon into current slot
      self:performDrop(loc, slot)
      return true
    else
      if selMon then
        -- Open Action Menu (MOVE, WITHDRAW/DEPOSIT, SUMMARY/STATS, RELEASE, CANCEL)
        self.mode = "action_menu"
        self.actionCursor = 1
        if self.game and self.game.data then
          pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
        end
        return true
      end
    end
  end

  -- Action 'B' button
  if input:wasPressed("b") then
    if isGrabbed then
      -- Cancel grab
      self.grabbed = nil
      self.mode = "browse"
      return true
    else
      -- Close PC storage
      return "close"
    end
  end

  return false
end

function StorageController:handleActionMenuInput(input)
  local actions = self:getAvailableActions()
  if input:wasPressed("up") then
    self.actionCursor = math.max(1, self.actionCursor - 1)
  elseif input:wasPressed("down") then
    self.actionCursor = math.min(#actions, self.actionCursor + 1)
  elseif input:wasPressed("a") then
    local act = actions[self.actionCursor]
    if act then self:executeAction(act.id) end
    return true
  elseif input:wasPressed("b") then
    self.mode = "browse"
    return true
  end
  return true
end

function StorageController:getAvailableActions()
  local selMon, loc = self:getCurrentSelection()
  if not selMon then return {} end

  local acts = {}
  if self.subMode == "withdraw" and loc == "box" then
    acts[#acts + 1] = { id = "withdraw", label = "WITHDRAW", primary = true }
    acts[#acts + 1] = { id = "move", label = "MOVE PKMN" }
  elseif self.subMode == "deposit" and loc == "party" then
    acts[#acts + 1] = { id = "deposit", label = "DEPOSIT", primary = true }
    acts[#acts + 1] = { id = "move", label = "MOVE PKMN" }
  else
    acts[#acts + 1] = { id = "move", label = "MOVE PKMN", primary = true }
    if loc == "box" then
      acts[#acts + 1] = { id = "withdraw", label = "WITHDRAW" }
    else
      acts[#acts + 1] = { id = "deposit", label = "DEPOSIT" }
    end
  end
  acts[#acts + 1] = { id = "stats", label = "SUMMARY" }
  acts[#acts + 1] = { id = "release", label = "RELEASE", danger = true }
  acts[#acts + 1] = { id = "cancel", label = "CANCEL" }
  return acts
end

function StorageController:executeAction(actionId)
  local selMon, loc, slot = self:getCurrentSelection()
  if not selMon then self.mode = "browse" return end

  if actionId == "move" then
    self.grabbed = {
      mon = selMon,
      sourceLoc = loc,
      sourceBox = self.currentBoxId,
      sourceSlot = slot,
    }
    self.mode = "grabbed"
  elseif actionId == "withdraw" then
    local ok, err = self.adapter:withdrawMon(self.currentBoxId, slot)
    if not ok then self.message = err else self:refresh() end
    self.mode = "browse"
  elseif actionId == "deposit" then
    local ok, err = self.adapter:depositMon(slot, self.currentBoxId)
    if not ok then self.message = err else self:refresh() end
    self.mode = "browse"
  elseif actionId == "stats" then
    local rawMon = selMon.raw or selMon
    local okGV, GV = pcall(require, "src.core.GameVersion")
    local isGen2 = (okGV and GV and GV.generation and GV.generation() == 2) or (self.game and self.game.save and (self.game.save.johtoBadges ~= nil or self.game.save.kantoBadges ~= nil))
    local isGen3 = (self.adapter and (self.adapter.generation == 3 or self.adapter.isGen3)) or (okGV and GV and GV.generation and GV.generation() == 3)
    if isGen3 then
      local okSumm, SummaryMenu = pcall(require, "src.ui.game3.summary_menu")
      if okSumm and SummaryMenu and SummaryMenu.openMenu then
        local mons = {}
        local startIndex = 1
        if loc == "box" then
          for s = 1, self.boxCapacity do
            local m = self.boxMons[s]
            if m then
              mons[#mons + 1] = m.raw or m
              if s == slot then startIndex = #mons end
            end
          end
        else
          for p = 1, self.partyCapacity do
            local m = self.partyMons[p]
            if m then
              mons[#mons + 1] = m.raw or m
              if p == slot then startIndex = #mons end
            end
          end
        end
        if #mons == 0 then mons = { rawMon } end
        local sess = (self.adapter.getSession and self.adapter:getSession()) or (self.game and (self.game.session or self.game.playerState))
        SummaryMenu.openMenu(mons, startIndex, {
          session = sess,
          context = loc,
          onClose = function()
            self:refresh()
          end,
        })
      end
    elseif isGen2 then
      local okScr, Screens = pcall(require, "src.ui.Screens")
      if okScr and Screens and Screens.push then
        Screens.push(self.game, "Gen2SummaryMenu", { mon = rawMon, list = { rawMon }, index = 1 })
      end
    else
      local okScr, Screens = pcall(require, "src.ui.Screens")
      if okScr and Screens and Screens.push then
        Screens.push(self.game, "SummaryMenu", rawMon)
      end
    end
    self.mode = "browse"
  elseif actionId == "release" then
    self.mode = "confirm_release"
    self.releaseChoice = 2 -- Default to NO for safety
  elseif actionId == "cancel" then
    self.mode = "browse"
  end
end

function StorageController:performDrop(targetLoc, targetSlot)
  if not self.grabbed then return end
  local g = self.grabbed
  local ok, err = self.adapter:swapSlots(g.sourceLoc, g.sourceSlot, targetLoc, targetSlot, g.sourceBox, self.currentBoxId)
  if not ok then
    self.message = err
  else
    self:refresh()
    if self.game and self.game.data then
      pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
    end
  end
  self.grabbed = nil
  self.mode = "browse"
end

function StorageController:handleReleaseConfirmInput(input)
  if input:wasPressed("up") or input:wasPressed("down") or input:wasPressed("left") or input:wasPressed("right") then
    self.releaseChoice = (self.releaseChoice == 1) and 2 or 1
  elseif input:wasPressed("a") then
    if self.releaseChoice == 1 then
      -- Confirmed YES release
      local selMon, loc, slot = self:getCurrentSelection()
      local ok, err = self.adapter:releaseMon(loc, slot, self.currentBoxId)
      if not ok then
        self.message = err
      else
        self:refresh()
      end
    end
    self.mode = "browse"
    return true
  elseif input:wasPressed("b") then
    self.mode = "browse"
    return true
  end
  return true
end

function StorageController:handleSwitchBoxInput(input)
  local cols = 4
  local total = self.boxCount
  if input:wasPressed("left") then
    self.boxMenuCursor = math.max(1, self.boxMenuCursor - 1)
  elseif input:wasPressed("right") then
    self.boxMenuCursor = math.min(total, self.boxMenuCursor + 1)
  elseif input:wasPressed("up") then
    self.boxMenuCursor = math.max(1, self.boxMenuCursor - cols)
  elseif input:wasPressed("down") then
    self.boxMenuCursor = math.min(total, self.boxMenuCursor + cols)
  elseif input:wasPressed("a") then
    if self.boxMenuCursor ~= self.currentBoxId then
      local oldBoxId = self.currentBoxId
      local oldBoxMons = self.boxMons
      local oldBoxName = self.boxName
      local dir = (self.boxMenuCursor >= oldBoxId) and 1 or -1
      self.currentBoxId = self.boxMenuCursor
      self.adapter:setCurrentBox(self.currentBoxId)
      self:refresh()
      local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
      self.boxTransition = {
        dir = dir,
        fromBoxId = oldBoxId,
        fromMons = oldBoxMons or {},
        fromName = oldBoxName or ("BOX " .. oldBoxId),
        toBoxId = self.currentBoxId,
        toMons = self.boxMons or {},
        toName = self.boxName or ("BOX " .. self.currentBoxId),
        startTime = now,
        duration = 0.22,
      }
    end
    self.mode = "browse"
    return true
  elseif input:wasPressed("b") then
    self.mode = "browse"
    return true
  end
  return true
end

return StorageController
