-- OmniUI: Unified Cross-Generation Modern UI Framework (Gen 1-3)
-- High-resolution visual overlay layer + multi-gen compatibility + rich input navigation.

local PublicApi = require("mods.omni_ui.api.PublicApi")
local Theme = require("mods.omni_ui.core.Theme")
local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")

local currentGame = nil

local function hostIsGen2(g)
  local version = g and (g.gameVersion or (g.cart and g.cart.gameVersion) or g.version or (g.save and (g.save.version or g.save.gameVersion)))
  if type(version) == "string" then
    version = version:lower()
    if version == "gold" or version == "silver" or version == "crystal" then return true end
    if version == "red" or version == "blue" or version == "yellow"
      or version == "firered" or version == "leafgreen" or version == "emerald"
      or version == "ruby" or version == "sapphire" then
      return false
    end
  end
  local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
  local adapter = AdapterResolver.resolve(g)
  return adapter and adapter.generation == 2
end

local function normalizeSelf(self, dt, fallbackState)
  if type(self) == "number" and dt == nil then
    return fallbackState, self
  end
  return (type(self) == "table" and self) or fallbackState, dt
end

-- Attach navigation hooks for SummaryMenu (Page 1-3 tab cycling with Left/Right, B to close)
local function attachSummaryControls(state, game)
  if not state or state.__omniUiControlsAttached then return end
  state.__omniUiControlsAttached = true

  local isGen3Summary = (state == package.loaded["src.ui.game3.summary_menu"] or state == package.loaded["src.ui.game3.rse.summary_menu"] or (state._party ~= nil and state._page ~= nil))
  if isGen3Summary then
    -- Gen 3 SummaryMenu possesses complete native controller & page slider in handleInput;
    -- initialize defaults without mutating state.update so regression tests pass untouched
    state.page = state.page or 1
    state.moveIndex = state.moveIndex or 1
    state.movesSubTab = state.movesSubTab or "battle"
    return
  end

  state._expMaxPage = state._expMaxPage or 3
  state.page = state.page or 1
  state.moveIndex = state.moveIndex or 1
  state.movesSubTab = state.movesSubTab or "battle"

  local baseUpdate = state.update
  state.update = function(self, dt)
    if self.closing then return end
    if self.whiteHold and self.whiteHold > 0 then
      self.whiteHold = self.whiteHold - 1
      if self.whiteHold == 0 then
        if self.game and self.game.data and self.mon then
          require("src.core.Sound").playCry(self.game.data, self.mon.species)
        end
      end
      return
    end

    local input = (self.game and self.game.input) or (game and game.input)
    if not input then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    local maxP = self._expMaxPage or 3

    -- If in Moves Submenu (entered by pressing A on Tab 2)
    local inMovesSubmenu = (self.page or 1) == 2 and (self.inMovesSubmenu == true or self.moveDetail == true)
    if inMovesSubmenu then
      local moves = (self.mon and self.mon.moves) or {}
      local moveCount = 0
      for _, mv in ipairs(moves) do
        local mid = (type(mv) == "table" and mv.id) or mv
        if mid then moveCount = moveCount + 1 end
      end
      moveCount = math.max(1, math.min(4, moveCount))

      -- Left / Right or Select / Tab swaps between Normal (Battle) View and Contest View (Gen 3 Only)
      local isGen3 = isGen3Summary or (self.game and self.game.save and (self.game.save.session or self.game.save.game3))
      if not isGen3 and self.adapter and self.adapter.generation == 3 then isGen3 = true end
      if not isGen3 and self.game and self.game.gameVersion then
        local gv = tostring(self.game.gameVersion):lower()
        if gv == "emerald" or gv == "ruby" or gv == "sapphire" or gv == "firered" or gv == "leafgreen" then
          isGen3 = true
        end
      end

      if isGen3 and (input:wasPressed("right") or input:wasPressed("left") or input:wasPressed("select") or input:wasPressed("tab")) then
        self.movesSubTab = (self.movesSubTab == "contest") and "battle" or "contest"
        if self.game and self.game.data then
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end
        return
      end

      if input:wasPressed("up") then
        self.moveIndex = ((self.moveIndex or 1) - 2 + moveCount) % moveCount + 1
        if self.game and self.game.data then
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("down") then
        self.moveIndex = ((self.moveIndex or 1) % moveCount) + 1
        if self.game and self.game.data then
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("a") then
        if self.swapSlot == nil then
          -- Pick up move to swap
          self.swapSlot = self.moveIndex or 1
        else
          -- Drop / swap moves
          local s1 = self.swapSlot
          local s2 = self.moveIndex or 1
          if s1 ~= s2 then
            if self.swapMoves and type(self.swapMoves) == "function" then
              pcall(self.swapMoves, self, s1, s2)
            else
              local mon = self.mon
              if mon then
                if mon.moves then mon.moves[s1], mon.moves[s2] = mon.moves[s2], mon.moves[s1] end
                if mon.pp then mon.pp[s1], mon.pp[s2] = mon.pp[s2], mon.pp[s1] end
              end
            end
          end
          self.swapSlot = nil
        end
        if self.game and self.game.data then
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("b") then
        if self.swapSlot ~= nil then
          self.swapSlot = nil
        else
          -- Exit moves submenu back to Tab 2 view
          self.inMovesSubmenu = false
          self.moveDetail = false
        end
        if self.game and self.game.data then
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end
        return
      end
      return
    end

    if input:wasPressed("left") then
      self.swapSlot = nil
      self.inMovesSubmenu = false
      self.page = (self.page == 1) and maxP or (self.page - 1)
      if self.game and self.game.data then
        require("src.core.Sound").play(self.game.data, "Press_AB")
      end
      return
    elseif input:wasPressed("right") then
      self.swapSlot = nil
      self.inMovesSubmenu = false
      self.page = (self.page == maxP) and 1 or (self.page + 1)
      if self.game and self.game.data then
        require("src.core.Sound").play(self.game.data, "Press_AB")
      end
      return
    elseif (self.page or 1) == 2 and input:wasPressed("a") then
      -- Enter moves submenu on Tab 2!
      self.inMovesSubmenu = true
      self.moveIndex = 1
      self.swapSlot = nil
      if self.game and self.game.data then
        require("src.core.Sound").play(self.game.data, "Press_AB")
      end
      return
    elseif input:wasPressed("a") and (self.page or 1) ~= 2 then
      self.page = (self.page == maxP) and 1 or (self.page + 1)
      if self.game and self.game.data then
        require("src.core.Sound").play(self.game.data, "Press_AB")
      end
      return
    elseif input:wasPressed("b") then
      if self.game and self.game.data then
        require("src.core.Sound").play(self.game.data, "Press_AB")
      end
      self.closing = true
      local stk = (self.game and self.game.stack) or (game and game.stack)
      if stk and stk.pop then
        stk:pop()
      end
      return
    end
  end
end

-- Attach navigation hooks for BagMenu (Pocket switching with Left/Right)
local function attachBagControls(state, game)
  if not state or state.__omniUiControlsAttached then return end
  state.__omniUiControlsAttached = true

  local isGen3Bag = (state == package.loaded["src.ui.game3.bag_menu"] or state == package.loaded["src.ui.game3.rse.bag_menu"] or state.POCKET_KEYS ~= nil or (state.pocketIdx ~= nil and state.currentPocket ~= nil))
  if isGen3Bag then
    local thisState = state
    local baseUpdate = state.update
    local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
    local adapter = AdapterResolver.resolve(game or (state and state.game) or currentGame)
    local pockets = (adapter and adapter.getBagPockets and adapter:getBagPockets()) or {
      { id = "ITEMS", label = "ITEMS" },
      { id = "KEY_ITEMS", label = "KEY ITEMS" },
      { id = "POKE_BALLS", label = "POKé BALLS" },
      { id = "TM_CASE", label = "TM CASE" },
      { id = "BERRY_POUCH", label = "BERRY POUCH" },
    }

    state.currentPocket = function()
      local idx = thisState.pocketIdx or 1
      local p = pockets[idx]
      return p and p.id or "ITEMS"
    end

    local function movePocket(self, dir)
      local cur = self.pocketIdx or 1
      local nextIdx = ((cur - 1 + dir) % #pockets) + 1
      self.pocketIdx = nextIdx
      if thisState and thisState ~= self then thisState.pocketIdx = nextIdx end
      local g3Bag = package.loaded["src.ui.game3.bag_menu"]
      if g3Bag and g3Bag ~= self then g3Bag.pocketIdx = nextIdx end
      self.cursor = 1
      self.scroll = 0
      local g = (self.game or game or currentGame)
      if g and g.data then pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end) end
    end

    -- Cart-visible pockets. FRLG's list is Items, Key Items, Poké Balls.
    local function visiblePocketCount()
      local ok, ItemsData = pcall(require, "src.core.game3.items_data")
      if ok and ItemsData and ItemsData.BAG_POCKET_ORDER then
        local n = #ItemsData.BAG_POCKET_ORDER
        if n > 0 then return n end
      end
      if adapter and adapter.region == "KANTO" then
        return math.min(3, #pockets)
      end
      return #pockets
    end

    local function extendPastVisiblePockets(self, input)
      if self.mode and self.mode ~= "list" then return false end
      local loc = self._location or self.location or thisState._location or thisState.location
      if loc == "itempc" or loc == "berry_tree" or loc == "blender" then return false end
      local nVisible = visiblePocketCount()
      if nVisible >= #pockets then return false end
      local cur = self.pocketIdx or 1
      local lr = false
      local okOpt, Options = pcall(require, "src.core.game3.options")
      if okOpt and Options and Options.lrMode then
        local session = self._session or thisState._session or (game and (game.session or (game.save and game.save.session)))
        local okLr, mode = pcall(Options.lrMode, session)
        lr = okLr and mode or false
      end
      local dir = 0
      if cur >= nVisible and input:wasPressed("right") then
        dir = 1
      elseif cur >= nVisible and lr and input:wasPressed("r") then
        dir = 1
      elseif cur <= 1 and input:wasPressed("left") then
        dir = -1
      elseif cur <= 1 and lr and input:wasPressed("l") then
        dir = -1
      end
      if dir == 0 then return false end
      movePocket(self, dir)
      return true
    end

    state.update = function(self, dt)
      self, dt = normalizeSelf(self, dt, thisState)
      local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
      local isBrowsing = (not self.mode or self.mode == "list")
      if isBrowsing and input then
        local dir = 0
        local isItemPc = (self._location == "itempc" or self.location == "itempc")
          or (thisState and (thisState._location == "itempc" or thisState.location == "itempc"))
          or (package.loaded["src.ui.game3.bag_menu"] and package.loaded["src.ui.game3.bag_menu"]._location == "itempc")
        if isItemPc then
          -- In deposit flow, native BagMenu suppresses left/right/l/r. Handle all pocket navigation keys here.
          if input:wasPressed("left") or input:wasPressed("l") or input:wasPressed("q") then
            dir = -1
          elseif input:wasPressed("right") or input:wasPressed("r") or input:wasPressed("e") or input:wasPressed("tab") then
            dir = 1
          end
        else
          -- ONLY handle keyboard shoulder bumpers (q, e, tab) in normal bag browsing.
          -- Do NOT handle "left" or "right" or "l" or "r" here, because native BagMenu.handleInput(input)
          -- already natively processes left/right/L/R! Handling them here caused double-switching (skipping tabs 2 at a time).
          if input:wasPressed("q") then
            dir = -1
          elseif input:wasPressed("e") or input:wasPressed("tab") then
            dir = 1
          end
        end
        if dir ~= 0 then
          movePocket(self, dir)
          return
        end
      end
      if baseUpdate then baseUpdate(self, dt) end
    end

    -- FRLG's cart bag stops at Poké Balls. handleInput runs before update and
    -- still consumes Left/Right when it refuses to move, so the TM Case and
    -- Berry Pouch tabs never see that press. Take the press on those edges.
    local baseHandle = state.handleInput
    state.handleInput = function(input)
      if input and extendPastVisiblePockets(thisState, input) then
        local blocked = {
          wasPressed = function(_, key)
            if key == "left" or key == "right" or key == "l" or key == "r" then return false end
            return input:wasPressed(key)
          end,
          isDown = function(_, key)
            if input.isDown then return input:isDown(key) end
            return false
          end,
        }
        if baseHandle then return baseHandle(blocked) end
        return
      end
      if baseHandle then return baseHandle(input) end
    end
    return
  end

  local isGen2Pack = (state.isPackMenu or state.pocketIndex ~= nil or state.pocketItems ~= nil or state.staleRows ~= nil or (type(state.rows) == "table" and not state.party))
  if isGen2Pack then
    -- Gen 2 PackMenu already possesses complete native controls (switchPocket, Up/Down, openSubmenu, toss, etc.)
    -- We only add shoulder bumper controls (Q/E or L/R) for extra responsiveness
    local baseUpdate = state.update
    state.update = function(self, dt)
      local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
      if input and not self.submenu and not self.qtyState and not self.confirm and not self.switching and not self.message then
        if input:wasPressed("l") or input:wasPressed("q") then
          if self.switchPocket then self:switchPocket(-1) end
          return
        elseif input:wasPressed("r") or input:wasPressed("e") then
          if self.switchPocket then self:switchPocket(1) end
          return
        end
      end
      if baseUpdate then baseUpdate(self, dt) end
    end
    return
  end

  local BASE_POCKETS = {
    { id = "items", label = "ITEMS" },
    { id = "balls", label = "BALLS" },
    { id = "key",   label = "KEY ITEMS" },
    { id = "tmhm",  label = "TMs & HMs" },
  }

  local function hasBerries()
    local inv = (game and game.save and game.save.inventory) or {}
    for id in pairs(inv) do
      if type(id) == "string" and (id == "BERRY" or id:match("_BERRY$")) then
        return true
      end
    end
    return false
  end

  local function getPockets()
    local p = {}
    for _, item in ipairs(BASE_POCKETS) do p[#p + 1] = item end
    if hasBerries() then
      p[#p + 1] = { id = "berries", label = "BERRIES" }
    end
    return p
  end

  local function classify(id)
    if not id then return "items" end
    if id == "BERRY" or id:match("_BERRY$") then return "berries" end
    local def = game and game.data and game.data.items and game.data.items[id]
    if (def and def.machine) or (type(id) == "string" and (id:find("^TM_") or id:find("^HM_") or id:find("^TM%d") or id:find("^HM%d"))) then
      return "tmhm"
    end
    if (def and def.keyItem) or (type(id) == "string" and (id:find("^HM_") or id == "BICYCLE" or id == "TOWN_MAP" or id == "SILPH_SCOPE" or id == "ITEMFINDER" or id == "OLD_ROD" or id == "GOOD_ROD" or id == "SUPER_ROD" or id == "POKE_FLUTE" or id == "EXP_ALL" or id == "COIN_CASE" or id == "CARD_KEY" or id == "GOLD_TEETH" or id == "SECRET_KEY" or id == "LIFT_KEY" or id == "OAKS_PARCEL" or id == "SS_TICKET" or id == "HELIX_FOSSIL" or id == "DOME_FOSSIL" or id == "OLD_AMBER")) then
      return "key"
    end
    if (def and def.ball) or (type(id) == "string" and (id:find("_BALL$") or id == "POKE_BALL" or id == "GREAT_BALL" or id == "ULTRA_BALL" or id == "MASTER_BALL" or id == "SAFARI_BALL")) then
      return "balls"
    end
    return "items"
  end

  local function rebuildPocketItems(pocketId)
    local Bag = require("src.inventory.Bag")
    local Strings = require("src.core.Strings")
    local items = {}
    local order = Bag.order(game.save)
    for _, id in ipairs(order) do
      if classify(id) == pocketId then
        local def = game.data and game.data.items and game.data.items[id]
        local unsellable = (def and def.keyItem) or (type(id) == "string" and id:find("^HM_") ~= nil)
        table.insert(items, {
          value = id,
          label = (def and def.name) or id,
          count = (not unsellable) and game.save.inventory[id] or nil,
        })
      end
    end
    table.insert(items, { cancel = true, label = Strings("CANCEL") })
    return items
  end

  if state.__pocketIds and type(state.__pocketIds) == "table" and #state.__pocketIds > 0 then
    local POCKET_LABELS = {
      items = "ITEMS",
      balls = "BALLS",
      key = "KEY ITEMS",
      tmhm = "TMs & HMs",
      berries = "BERRIES",
    }
    local p = {}
    for _, pid in ipairs(state.__pocketIds) do
      p[#p + 1] = { id = pid, label = POCKET_LABELS[pid] or pid:upper() }
    end
    state.pockets = p
  else
    state.pockets = getPockets()
  end
  state.__pocketIndex = state.__pocketIndex or 1

  local function showPocket(pocketId)
    state.__omniPocketView = true
    state.__omniPocketItems = rebuildPocketItems(pocketId)
  end

  local function setPocket(delta)
    local n = #state.pockets
    state.__pocketIndex = ((state.__pocketIndex - 1 + delta) % n) + 1
    state.pocketIdx = state.__pocketIndex
    local curPocket = state.pockets[state.__pocketIndex]
    state.title = curPocket.label
    showPocket(curPocket.id)
    state.index = 1
    state.cursor = 1
    state.scroll = 0
    state.swapIndex = nil
    local g = (state and state.game) or game or currentGame
    if g and g.data then
      pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end)
    end
  end

  -- Pocket tabs stay. The rows are a fresh read of the live bag, not a rewrite of state.items.
  if not state.__pocketIds and not state.gen1ModernUi then
    local curPocket = state.pockets[state.__pocketIndex]
    showPocket(curPocket.id)
    state.index = 1
    state.cursor = 1
    state.scroll = 0
  end

  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
    if input then
      if input:wasPressed("left") or input:wasPressed("l") or input:wasPressed("q") then
        if self.gen1ModernUi and self.gen1ModernUi.switchPocket then
          self.gen1ModernUi:switchPocket(-1)
        elseif self.switchPocket then
          self:switchPocket(-1)
        else
          setPocket(-1)
        end
        return
      elseif input:wasPressed("right") or input:wasPressed("r") or input:wasPressed("e") then
        if self.gen1ModernUi and self.gen1ModernUi.switchPocket then
          self.gen1ModernUi:switchPocket(1)
        elseif self.switchPocket then
          self:switchPocket(1)
        else
          setPocket(1)
        end
        return
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
    if self.__omniPocketView and self.pockets and self.pockets[self.__pocketIndex or 1] then
      self.__omniPocketItems = rebuildPocketItems(self.pockets[self.__pocketIndex or 1].id)
    end
    local items = (self.__omniPocketView and self.__omniPocketItems) or self.items or {}
    local curIdx = self.index or self.cursor or 1
    local visibleCount = 8
    local scroll = self.scroll or 0
    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    self.scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
  end
end

-- Attach navigation hooks for Shop / Poké Mart
local function attachShopControls(state, game)
  if not state or state.__omniUiShopAttached then return end
  state.__omniUiShopAttached = true

  local baseHandle = state.handleInput
  if baseHandle then
    local ShopRenderer = require("mods.omni_ui.renderers.ShopRenderer")
    state.handleInput = function(input)
      if ShopRenderer.holdClerkPage(state, input) then return end
      local phase = state.state or state.mode
      if input and (phase == "buy_confirm" or phase == "confirm")
          and (input:wasPressed("left") or input:wasPressed("right")) then
        if state.yesNoCursor then
          state.yesNoCursor = (state.yesNoCursor == 1) and 2 or 1
          return
        elseif state.yesCursor then
          state.yesCursor = (state.yesCursor == 1) and 2 or 1
          return
        end
      end
      return baseHandle(input)
    end
  end

  local baseUpdate = state.update
  state.update = function(self, dt)
    if baseUpdate then baseUpdate(self, dt) end
    local items = self.items or self.rows or {}
    local curIdx = self.index or self.cursor or 1
    local visibleCount = 8
    local scroll = self.scroll or 0
    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    self.scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
  end
end

-- Attach quick stepper controls for QuantityBox:
-- Left/Right: step +/- 1 (with wrap/clamp)
-- Up/Down: step +/- 10 or Min/Max
local function attachQuantityControls(state, game)
  if not state or state.__omniUiQtyAttached then return end
  state.__omniUiQtyAttached = true

  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if input and self.qty and self.max then
      local maxVal = math.max(1, self.max or 99)
      local step = 10

      if input:wasPressed("left") then
        local prev = self.qty
        self.qty = self.qty - 1
        if self.qty < 1 then self.qty = maxVal end
        if self.qty ~= prev and game and game.data then
          require("src.core.Sound").play(game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("right") then
        local prev = self.qty
        self.qty = self.qty + 1
        if self.qty > maxVal then self.qty = 1 end
        if self.qty ~= prev and game and game.data then
          require("src.core.Sound").play(game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("up") then
        local prev = self.qty
        if maxVal <= 10 then
          self.qty = maxVal
        else
          self.qty = math.min(maxVal, self.qty + step)
        end
        if self.qty ~= prev and game and game.data then
          require("src.core.Sound").play(game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("down") then
        local prev = self.qty
        if maxVal <= 10 then
          self.qty = 1
        else
          self.qty = math.max(1, self.qty - step)
        end
        if self.qty ~= prev and game and game.data then
          require("src.core.Sound").play(game.data, "Press_AB")
        end
        return
      elseif input:wasPressed("a") then
        if not self.keepOpen and self.game and self.game.stack and self.game.stack.top and self.game.stack:top() == self then
          self.game.stack:pop()
        end
        if self.onDone then self.onDone(self.qty) end
        return
      elseif input:wasPressed("b") then
        if not self.keepOpen and self.game and self.game.stack and self.game.stack.top and self.game.stack:top() == self then
          self.game.stack:pop()
        end
        if self.onDone then self.onDone(nil) end
        return
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

-- Helper to get accurate visible row count
local function getPokedexVisibleRows(state)
  if state and state.visibleRows and state.visibleRows > 0 then
    return state.visibleRows
  end
  local gh = (love and love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 600
  local bodyH = gh - 96
  local rowH = 38
  local vr = math.max(1, math.floor((bodyH - 24) / (rowH + 4)))
  if state then state.visibleRows = vr end
  return vr
end

local function playMenuSound(game, soundType)
  soundType = soundType or "select"
  pcall(function()
    local Kit = package.loaded["src.ui.game3.rse.scene_kit"]
    if Kit and Kit.playSe then
      Kit.playSe(soundType == "hazard" and "SE_HAZARD" or "SE_SELECT")
      return
    end
    local Audio = package.loaded["src.core.game3.audio"]
    local SE = package.loaded["src.core.game3.se_ids"]
    if Audio and Audio.playSe and SE then
      Audio.playSe(soundType == "hazard" and (SE.SE_HAZARD or 5) or (SE.SE_SELECT or 1))
      return
    end
  end)
  if game and game.data then
    pcall(function()
      require("src.core.Sound").play(game.data, soundType == "hazard" and "Collision" or "Press_AB")
    end)
  end
end

local function playPokemonCry(game, species)
  if not species or species == 0 or species == "???" or species == "UNKNOWN" then return end
  pcall(function()
    local Audio = package.loaded["src.core.game3.audio"] or require("src.core.game3.audio")
    if Audio then
      if Audio.stopCry then Audio.stopCry() end
      if Audio.playCry then Audio.playCry(species) end
    end
  end)
  if game and game.data then
    pcall(function() require("src.core.Sound").playCry(game.data, species) end)
  end
end

-- Attach navigation hooks for Pokédex (Up/Down single scroll, Left/Right page down/up)
local function attachPokedexControls(state, game)
  if not state or state.__omniUiPokedexAttached then return end
  state.__omniUiPokedexAttached = true

  local isGen3Dex = (state == package.loaded["src.ui.game3.pokedex"]
    or state == package.loaded["src.ui.game3.rse.pokedex"]
    or state == package.loaded["src.ui.game3.rs.pokedex"]
    or state._dex ~= nil
    or state.pokeBallRotation ~= nil
    or state.bgPalSet ~= nil
    or state.currentOrder ~= nil
    or state.categorySlot ~= nil
    or state.isSearchResults ~= nil
    or (state.dexMode ~= nil and state.dexOrder ~= nil)
    or state.listCursor ~= nil
    or (type(state.selected) == "number" and state.page ~= nil))

  local isGen2Dex = (state.view ~= nil
    or type(state.rows) == "table"
    or state.modeIndex ~= nil
    or state.updateArea ~= nil
    or state.unownMode ~= nil)

  local isUnifiedDex = isGen2Dex or isGen3Dex
  if isUnifiedDex then
    if state.view == nil then
      if state.screen == "data" or (state.page == 1 and not isGen2Dex) then
        state.view = "entry"
      elseif state.screen == "area" or (state.page == 5 and not isGen2Dex) then
        state.view = "area"
      else
        state.view = "list"
      end
    end

    local function handleUnifiedPokedexInput(self, input)
      if not input then return false end

      local g = self.game or game or currentGame
      local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
      local adapter = AdapterResolver.resolve(g)
      local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")

      -- 1. Helper to resolve current active rows and selected row
      local activeRows = self.filteredRows
      if not activeRows or #activeRows == 0 then
        activeRows = PokedexFilter.buildRows(g, self, adapter)
        self.filteredRows = activeRows
      end
      local totalCount = (activeRows and #activeRows) or 0
      local curIdx = self.listCursor or self.index or self.cursor or self._cursor or (type(self.selected) == "number" and (self.selected + 1)) or 1
      curIdx = math.max(1, math.min(math.max(1, totalCount), curIdx))
      local row = (activeRows and activeRows[curIdx])
        or (self.current and self:current())
        or (type(self.rows) == "table" and self.rows[curIdx])
        or (type(self.items) == "table" and self.items[curIdx])

      local species = (row and (row.species or row.speciesId))
        or self.selectedSpecies
        or self.nestSpecies
        or curIdx

      -- 2. Entry View
      local isEntry = (self.view == "entry") or (self.screen == "data") or (self.page == 1 and self.view ~= "list") or (self.page == "entry")
      if isEntry and not (self.view == "list" or self.screen == "ordered_list") then
        local isRowSeen = row and (row.seen == true or row.isSeen == true)
        if not isRowSeen and species and adapter then
          isRowSeen = (adapter.hasSeen and adapter:hasSeen(species)) or (adapter.hasCaught and adapter:hasCaught(species))
        end

        local function findAdjacentSeenIndex(rows, startIdx, step, ad)
          if not rows or #rows == 0 then return startIdx end
          local n = #rows
          local idx = startIdx
          for _ = 1, n do
            idx = idx + step
            if idx > n then idx = 1
            elseif idx < 1 then idx = n end
            if idx == startIdx then break end
            local r = rows[idx]
            local seen = r and (r.seen == true or r.isSeen == true)
            if not seen and r and (r.species or r.speciesId) and ad then
              local spKey = r.species or r.speciesId
              if ad.hasSeen and ad:hasSeen(spKey) then seen = true
              elseif ad.hasCaught and ad:hasCaught(spKey) then seen = true end
            end
            if seen then return idx end
          end
          return startIdx
        end

        if input:wasPressed("start") or input:wasPressed("select") then
          if isRowSeen then
            playPokemonCry(g, species)
          end
          return true
        elseif input:wasPressed("a") then
          if isRowSeen then
            self.view = "area"
            self.page = 5
            if self.screen ~= nil then self.screen = "area" end
            self.nestSpecies = species
            self.areaRegion = nil
            playMenuSound(g, "select")
          else
            playMenuSound(g, "hazard")
          end
          return true
        elseif input:wasPressed("b") then
          self.view = "list"
          self.page = 0
          if self.screen ~= nil then self.screen = "ordered_list" end
          if self.fn ~= nil then self.fn = "mainInput" end
          playMenuSound(g, "select")
          return true
        elseif input:wasPressed("up") then
          local nextIdx = findAdjacentSeenIndex(activeRows, curIdx, -1, adapter)
          if nextIdx and nextIdx ~= curIdx then
            curIdx = nextIdx
            self.index = curIdx
            self.cursor = curIdx
            self.listCursor = curIdx
            if type(self.selected) == "number" then self.selected = curIdx - 1 end
            local newRow = activeRows and activeRows[curIdx]
            local newSp = (newRow and (newRow.species or newRow.speciesId)) or curIdx
            self.selectedSpecies = newSp
            self.species = newSp
            playPokemonCry(g, newSp)
          end
          return true
        elseif input:wasPressed("down") then
          local nextIdx = findAdjacentSeenIndex(activeRows, curIdx, 1, adapter)
          if nextIdx and nextIdx ~= curIdx then
            curIdx = nextIdx
            self.index = curIdx
            self.cursor = curIdx
            self.listCursor = curIdx
            if type(self.selected) == "number" then self.selected = curIdx - 1 end
            local newRow = activeRows and activeRows[curIdx]
            local newSp = (newRow and (newRow.species or newRow.speciesId)) or curIdx
            self.selectedSpecies = newSp
            self.species = newSp
            playPokemonCry(g, newSp)
          end
          return true
        end
        return true
      end

      -- 3. Area View
      local isArea = (self.view == "area") or (self.screen == "area") or (self.page == 5 and self.view ~= "list")
      if isArea and not (self.view == "list" or self.screen == "ordered_list") then
        if input:wasPressed("b") or input:wasPressed("a") then
          self.view = "list"
          self.page = 0
          if self.screen ~= nil then self.screen = "ordered_list" end
          if self.fn ~= nil then self.fn = "mainInput" end
          playMenuSound(g, "select")
          return true
        end
        local curSpecies = self.nestSpecies or species
        local areaInfo = adapter and adapter.getAreaInfo and adapter:getAreaInfo(curSpecies, self.areaRegion)
        if areaInfo and areaInfo.canSwapRegion then
          local regs = areaInfo.availableRegions or { "kanto", "sevii" }
          if input:wasPressed("left") or input:wasPressed("right") or input:wasPressed("select") then
            self.areaRegion = (self.areaRegion == regs[1]) and regs[2] or regs[1]
            self.nestScroll = 0
            playMenuSound(g, "select")
            return true
          end
        end
        if input:wasPressed("up") then
          self.nestScroll = math.max(0, (self.nestScroll or 0) - 1)
          return true
        elseif input:wasPressed("down") then
          self.nestScroll = (self.nestScroll or 0) + 1
          return true
        end
        return true
      end

      -- 4. Search / Option / Filter modal view (2D spatial grid)
      local isFilter = (self.view == "option") or (self.view == "search") or (self.view == "filter") or (self._filterModalOpen == true) or (self.page == 2 and self.view ~= "list")
      if isFilter then
        local gw = (love and love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 800
        local gh = (love and love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 600
        local isNarrow = (gw < 560) or (gh > gw)
        if PokedexFilter.handleGridInput(self, g, input, isNarrow) then
          self.filteredRows = PokedexFilter.buildRows(g, self, adapter)
          return true
        end
        return true
      end

      -- 5. Unown view
      if self.view == "unown" then
        if input:wasPressed("a") or input:wasPressed("b") then
          self.view = "list"
          self.page = 0
          if self.screen ~= nil then self.screen = "ordered_list" end
          if self.fn ~= nil then self.fn = "mainInput" end
          playMenuSound(g, "select")
          return true
        end
        return true
      end

      -- 6. Main List View: Submenu Modal Open (DATA / CRY / AREA / UNOWN / PRNT / QUIT)
      if self.submenu and self.submenu.items and #self.submenu.items > 0 then
        if input:wasPressed("b") then
          self.submenu = nil
          playMenuSound(g, "select")
          return true
        elseif input:wasPressed("up") then
          self.submenu.index = (self.submenu.index > 1) and (self.submenu.index - 1) or #self.submenu.items
          playMenuSound(g, "select")
          return true
        elseif input:wasPressed("down") then
          self.submenu.index = (self.submenu.index < #self.submenu.items) and (self.submenu.index + 1) or 1
          playMenuSound(g, "select")
          return true
        elseif input:wasPressed("a") then
          local selectedItem = self.submenu.items[self.submenu.index or 1]
          local action = selectedItem and (selectedItem.action or selectedItem.id or selectedItem.label)
          action = tostring(action):lower()
          local subRow = self.submenu.row or row
          local sp = (subRow and (subRow.species or subRow.speciesId)) or species
          local isSubSeen = subRow and (subRow.seen == true or subRow.isSeen == true)
          if not isSubSeen and sp and adapter then
            isSubSeen = (adapter.hasSeen and adapter:hasSeen(sp)) or (adapter.hasCaught and adapter:hasCaught(sp))
          end

          if action == "data" then
            if not isSubSeen then
              playMenuSound(g, "hazard")
              return true
            end
            self.submenu = nil
            self.view = "entry"
            self.page = 1
            if self.screen ~= nil then
              self.screen = "data"
              self.dataPage = 1
            end
            if self.fn ~= nil then self.fn = "openInfo" end
            self.selectedSpecies = sp
            self.species = sp
            playPokemonCry(g, sp)
          elseif action == "cry" then
            if isSubSeen then
              playPokemonCry(g, sp)
            else
              playMenuSound(g, "hazard")
            end
          elseif action == "area" then
            self.submenu = nil
            self.view = "area"
            self.page = 5
            if self.screen ~= nil then self.screen = "area" end
            self.nestSpecies = sp
            self.areaRegion = nil
          elseif action == "unown" then
            self.submenu = nil
            self.view = "unown"
          elseif action == "prnt" then
            if self.printEntry then self:printEntry() end
          elseif action == "quit" or action == "cancel" then
            self.submenu = nil
          end
          playMenuSound(g, "select")
          return true
        end
        return true
      end

      -- 7. Main List View: Normal Navigation
      local totalRowsCount = (activeRows and #activeRows) or (type(self.rows) == "table" and #self.rows) or (type(self.items) == "table" and #self.items) or 1
      if input:wasPressed("b") then
        if (self._dexSearchQuery and self._dexSearchQuery ~= "") or (self._dexFilterMode and self._dexFilterMode ~= "ALL") then
          self._dexSearchQuery = ""
          self._dexFilterMode = "ALL"
          self.filteredRows = PokedexFilter.buildRows(g, self, adapter)
          self.index = 1
          self.cursor = 1
          self.listCursor = 1
          if type(self.selected) == "number" then self.selected = 0 end
          self.scroll = 0
          if self.ensureVisible then self:ensureVisible() end
          playMenuSound(g, "select")
          return true
        end
        if self.close then
          self:close()
        elseif package.loaded["src.ui.game3.rse.pokedex"] and package.loaded["src.ui.game3.rse.pokedex"].reset and (self.pokeBallRotation ~= nil or self.bgPalSet ~= nil or self.session ~= nil) then
          package.loaded["src.ui.game3.rse.pokedex"].reset()
        elseif package.loaded["src.ui.game3.pokedex"] and package.loaded["src.ui.game3.pokedex"].close and (self.screen ~= nil or self._dex ~= nil) then
          package.loaded["src.ui.game3.pokedex"].close()
        else
          local stk = (self.game and self.game.stack) or (g and g.stack)
          if stk and stk.pop then stk:pop() end
          pcall(function() require("src.ui.game3.stack").pop() end)
        end
        if self.onClose then self.onClose() end
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("select") then
        self.view = "option"
        self.optionIndex = self.modeIndex or 1
        self._filterModalOpen = true
        self._gridSection = "sort"
        self._gridIndex = 1
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("start") then
        if (self._dexSearchQuery and self._dexSearchQuery ~= "") or (self._dexFilterMode and self._dexFilterMode ~= "ALL") then
          self._dexSearchQuery = ""
          self._dexFilterMode = "ALL"
          self.filteredRows = PokedexFilter.buildRows(g, self, adapter)
          self.index = 1
          self.cursor = 1
          self.listCursor = 1
          if type(self.selected) == "number" then self.selected = 0 end
          self.scroll = 0
        else
          self.view = "search"
          self._filterModalOpen = true
          self._gridSection = "search"
          self._gridIndex = 1
        end
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("up") then
        curIdx = (curIdx > 1) and (curIdx - 1) or math.max(1, totalRowsCount)
        self.index = curIdx
        self.cursor = curIdx
        self.listCursor = curIdx
        if type(self.selected) == "number" then self.selected = curIdx - 1 end
        if self.ensureVisible then self:ensureVisible() end
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("down") then
        curIdx = (curIdx < totalRowsCount) and (curIdx + 1) or 1
        self.index = curIdx
        self.cursor = curIdx
        self.listCursor = curIdx
        if type(self.selected) == "number" then self.selected = curIdx - 1 end
        if self.ensureVisible then self:ensureVisible() end
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("left") then
        curIdx = math.max(1, curIdx - 10)
        self.index = curIdx
        self.cursor = curIdx
        self.listCursor = curIdx
        if type(self.selected) == "number" then self.selected = curIdx - 1 end
        if self.ensureVisible then self:ensureVisible() end
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("right") then
        curIdx = math.min(math.max(1, totalRowsCount), curIdx + 10)
        self.index = curIdx
        self.cursor = curIdx
        self.listCursor = curIdx
        if type(self.selected) == "number" then self.selected = curIdx - 1 end
        if self.ensureVisible then self:ensureVisible() end
        playMenuSound(g, "select")
        return true
      elseif input:wasPressed("a") then
        local isSeen = row and (row.seen == true or row.isSeen == true)
        if not isSeen and row and (row.species or row.speciesId) then
          local spId = row.species or row.speciesId
          if adapter and adapter.hasSeen then
            isSeen = adapter:hasSeen(spId)
          elseif adapter and adapter.hasCaught then
            isSeen = adapter:hasCaught(spId)
          end
        end
        if isSeen then
          local subItems = {
            { label = "DATA", action = "data" },
            { label = "CRY", action = "cry" },
            { label = "AREA", action = "area" },
          }
          local spKey = (row and (row.species or row.speciesId)) or species
          if spKey == "UNOWN" or spKey == 201 or ((self.save and self.save.unownDex) or self.unownMode or (self.data and self.data.unown)) then
            subItems[#subItems + 1] = { label = "UNOWN", action = "unown" }
          end
          if self.printEntry then
            subItems[#subItems + 1] = { label = "PRNT", action = "prnt" }
          end
          subItems[#subItems + 1] = { label = "QUIT", action = "quit" }
          self.submenu = { items = subItems, index = 1, row = row }
          playMenuSound(g, "select")
        else
          playMenuSound(g, "hazard")
        end
        return true
      end

      return false
    end

    state.handleInputOmni = handleUnifiedPokedexInput
    if not state.handleInput then
      state.handleInput = handleUnifiedPokedexInput
    end

    local baseUpdate = state.update
    state.update = function(self, dt)
      local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
      if input and self.handleInputOmni then
        if self:handleInputOmni(input) then
          return
        end
      end
      if baseUpdate then baseUpdate(self, dt) end
    end
    return
  end

  -- If this is a DexEntryMenu (single entry page view)
  if state.def and (state.species or state.pageCount) then
    local baseUpdate = state.update
    state.update = function(self, dt)
      local input = (self.game and self.game.input) or (game and game.input)
      if input then
        if input:wasPressed("a") or input:wasPressed("b") then
          -- Unified modern layout presents the complete entry on one card: return on A or B
          if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
          local st = (self.game and self.game.stack) or (game and game.stack)
          if st then
            st:pop()
          end
          return
        end
      end
      if baseUpdate then baseUpdate(self, dt) end
    end
    return
  end

  local dex = (game and game.save and game.save.pokedex) or { seen = {}, owned = {} }
  local dexOwned = dex.owned or dex.caught or {}
  local dexSeen = dex.seen or {}
  local byDex = {}
  local maxDexFound = (game and game.data and game.data.constants and game.data.constants.dexSize) or 151
  if state.items and #state.items > 0 then
    maxDexFound = math.max(maxDexFound, #state.items)
  end
  for k, def in pairs((game and game.data and game.data.pokemon) or {}) do
    if type(def) == "table" and type(def.dex) == "number" then
      byDex[def.dex] = def
      if def.dex > maxDexFound then maxDexFound = def.dex end
    elseif type(k) == "number" then
      if k > maxDexFound then maxDexFound = k end
    end
  end
  if game and game.save and game.save.pokedex then
    for k in pairs(game.save.pokedex.seen or {}) do
      if type(k) == "number" and k > maxDexFound then maxDexFound = k end
    end
    for k in pairs(game.save.pokedex.owned or game.save.pokedex.caught or {}) do
      if type(k) == "number" and k > maxDexFound then maxDexFound = k end
    end
  end

  local dexSize = maxDexFound
  local numDigits = (dexSize >= 1000) and 4 or 3
  if game and game.data and game.data.constants and game.data.constants.dexDigits then
    numDigits = game.data.constants.dexDigits
  end
  local numFmt = ("%%0%dd"):format(numDigits)

  local fullItems = {}
  for n = 1, dexSize do
    local def = byDex[n]
    local known = def and (dexOwned[def.id] or dexSeen[def.id] or dexOwned[n] or dexSeen[n])
    local name = known and (def.name or def.species) or "----------"
    fullItems[#fullItems + 1] = {
      num = numFmt:format(n),
      name = name,
      label = (numFmt .. " %s"):format(n, name),
      ball = (def and (dexOwned[def.id] or dexOwned[n])) or nil,
      value = known and def.id or nil,
      def = def,
    }
  end

  if not state.items or #state.items < dexSize then
    state.items = fullItems
  end

  -- Replace vanilla syncScroll (which was hardcoded to 7 rows) with modern visibleRows sync
  local function syncPokedexScroll(self)
    local pageSize = getPokedexVisibleRows(self)
    local activeRows = self.filteredRows or self.items or fullItems
    local totalCount = math.max(1, #activeRows)
    self.index = math.max(1, math.min(totalCount, self.index or 1))
    local curIdx = self.index
    local scroll = self.scroll or 0
    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + pageSize then
      scroll = curIdx - pageSize
    end
    scroll = math.max(0, math.min(math.max(0, totalCount - pageSize), scroll))
    self.scroll = scroll
  end
  state.syncScroll = syncPokedexScroll

  local function pageScrollPokedex(self, dir)
    local pageSize = getPokedexVisibleRows(self)
    local activeRows = self.filteredRows or self.items or fullItems
    local totalCount = math.max(1, #activeRows)
    if totalCount <= pageSize then return end
    local maxScroll = math.max(0, totalCount - pageSize)
    local curIdx = self.index or self.cursor or 1
    local scroll = self.scroll or 0
    local rowOffset = curIdx - scroll
    scroll = math.max(0, math.min(maxScroll, scroll + dir * pageSize))
    curIdx = math.max(1, math.min(totalCount, scroll + rowOffset))
    self.scroll = scroll
    self.index = curIdx
    self.cursor = curIdx
    syncPokedexScroll(self)
  end
  state.pageScroll = pageScrollPokedex
  state.rows = function(self)
    local activeRows = self.filteredRows or self.items or fullItems
    return math.min(getPokedexVisibleRows(self), #activeRows)
  end

  local okRep, MenuRepeat = pcall(require, "src.ui.MenuRepeat")
  local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")

  local baseUpdate = state.update
  state.update = function(self, dt)
    self.hollowIndex = nil
    local input = (self.game and self.game.input) or (game and game.input)
    if not input then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    -- 1. Handle Navigation inside the Search & Sort Configuration Modal (2D Spatial Grid)
    local isFilterModal = (self.view == "option") or (self.view == "search") or (self.view == "filter") or (self._filterModalOpen == true)
    if isFilterModal then
      local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")
      local gw = (love and love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 800
      local gh = (love and love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 600
      local isNarrow = (gw < 560) or (gh > gw)
      if PokedexFilter.handleGridInput(self, game, input, isNarrow) then
        syncPokedexScroll(self)
        return
      end
      return
    end

    -- 2. Handle Navigation in the Main Pokédex Archive List
    local activeRows = self.filteredRows or self.items or fullItems
    local totalCount = math.max(1, #activeRows)
    local curIdx = self.index or self.cursor or 1

    local dir = nil
    if okRep and MenuRepeat and MenuRepeat.direction and self.hold then
      dir = MenuRepeat.direction(self.hold, input)
    end

    if dir == "up" or (not dir and input:wasPressed("up")) then
      curIdx = curIdx - 1
      if curIdx < 1 then
        curIdx = totalCount
      end
      self.index = curIdx
      self.cursor = curIdx
      syncPokedexScroll(self)
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif dir == "down" or (not dir and input:wasPressed("down")) then
      curIdx = curIdx + 1
      if curIdx > totalCount then
        curIdx = 1
      end
      self.index = curIdx
      self.cursor = curIdx
      syncPokedexScroll(self)
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif dir == "left" or (not dir and input:wasPressed("left")) then
      pageScrollPokedex(self, -1)
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif dir == "right" or (not dir and input:wasPressed("right")) then
      pageScrollPokedex(self, 1)
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif input:wasPressed("select") then
      self._filterModalOpen = true
      self.view = "option"
      self._filterField = 1
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif input:wasPressed("start") then
      if (self._dexSearchQuery and self._dexSearchQuery ~= "") or (self._dexFilterMode and self._dexFilterMode ~= "ALL") then
        self._dexSearchQuery = ""
        self._dexFilterMode = "ALL"
        self.index = 1
        self.scroll = 0
        syncPokedexScroll(self)
      else
        self._filterModalOpen = true
        self.view = "search"
        self._gridSection = "search"
        self._gridIndex = 1
      end
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif input:wasPressed("backspace") or input:wasPressed("delete") then
      if self._dexSearchQuery and #self._dexSearchQuery > 0 then
        self._dexSearchQuery = self._dexSearchQuery:sub(1, #self._dexSearchQuery - 1)
        self.index = 1
        self.scroll = 0
        syncPokedexScroll(self)
        if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
        return
      end
    elseif input:wasPressed("a") then
      local row = activeRows[curIdx]
      if row then
        local sp = row.species or row.value or row.dex
        local dex = self.save and self.save.pokedex
        local function dexOn(tbl)
          return type(tbl) == "table" and tbl[sp] and tbl[sp] ~= 0 and tbl[sp] ~= false
        end
        if row.seen or (row.def and (row.def.seen or row.def.caught)) or (dex and (dexOn(dex.seen) or dexOn(dex.owned) or dexOn(dex.caught))) then
          if self.onChoose then
            self.onChoose(row, self)
          else
            self.view = "entry"
            self.page = 1
            if self.playCry then self:playCry(sp) end
          end
        end
      end
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    elseif input:wasPressed("b") then
      if (self._dexSearchQuery and self._dexSearchQuery ~= "") or (self._dexFilterMode and self._dexFilterMode ~= "ALL") then
        self._dexSearchQuery = ""
        self._dexFilterMode = "ALL"
        self.index = 1
        self.scroll = 0
        syncPokedexScroll(self)
        if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
        return
      end
      local stk = (self.game and self.game.stack) or (game and game.stack)
      if stk and stk.pop then
        local top = stk.top and stk:top()
        if top == self then stk:pop() else stk:pop() end
      end
      if self.onCancel then
        self.onCancel()
      end
      if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
      return
    end

    if baseUpdate then baseUpdate(self, dt) end
  end
end

-- Attach navigation hooks for TownMap / Pokédex Area Screen
local function attachTownMapControls(state, game)
  if not state or state.__omniUiMapAttached then return end
  state.__omniUiMapAttached = true

  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if input and self.nestSpecies and self.nests and #self.nests > 0 then
      if input:wasPressed("down") then
        self.nestScroll = (self.nestScroll or 0) + 1
      elseif input:wasPressed("up") then
        self.nestScroll = math.max(0, (self.nestScroll or 0) - 1)
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

-- Attach navigation hooks for Bill's PC (Pokémon Storage)
local function attachStorageControls(state, game)
  if not state or state.__omniUiStorageAttached then return end
  state.__omniUiStorageAttached = true

  local StorageController = require("mods.omni_ui.core.StorageController")
  if not state.__storageController then
    state.__storageController = StorageController.new(game or state.game, {
      mode = state.mode or "browse",
      subMode = state.subMode or (state.mode == "withdraw" and "withdraw") or (state.mode == "deposit" and "deposit") or "move",
    })
  end

  local thisState = state
  local baseUpdate = state.update
  state.update = function(self, dt)
    self, dt = normalizeSelf(self, dt, thisState)
    local isGen3 = (self == package.loaded["src.ui.game3.box_storage_ui"] or type(self.handleInput) == "function")
    local ctrl = self.__storageController
    local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
    if not isGen3 and input and ctrl then
      local action = ctrl:handleInput(input)
      if action == "close" then
        local stk = (self.game and self.game.stack) or (game and game.stack)
        if stk and stk.pop then
          local top = stk.top and stk:top()
          if top == self then stk:pop() else stk:pop() end
        end
        local g3Stack = package.loaded["src.ui.game3.stack"]
        if g3Stack and g3Stack.has and g3Stack.has("box_storage") then
          local okUI, BoxStorageUI = pcall(require, "src.ui.game3.box_storage_ui")
          if okUI and BoxStorageUI and BoxStorageUI.close then
            BoxStorageUI.close()
          else
            g3Stack.pop("box_storage")
          end
        end
        if self.onCancel then self.onCancel() end
        if self.opts and self.opts.onClose then self.opts.onClose() end
        if game and game.data then require("src.core.Sound").play(game.data, "Press_AB") end
        return
      elseif action == true then
        return
      end
    end
    if baseUpdate then
      if isGen3 then
        baseUpdate(dt)
      else
        baseUpdate(self, dt)
      end
    end
  end
end

-- Attach navigation hooks for Player PC (Item Storage)
local function attachPlayerPcControls(state, game)
  if not state or state.__omniUiPlayerPcAttached then return end
  state.__omniUiPlayerPcAttached = true

  local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")
  if not state.__playerPcController then
    state.__playerPcController = PlayerPcController.new(game or state.game, {
      tab = (state.kind == "pc_item_deposit" or state.mode == "deposit") and "bag" or "pc",
    })
  end

  local thisState = state
  local baseUpdate = state.update
  state.update = function(self, dt)
    self, dt = normalizeSelf(self, dt, thisState)
    local isGen3 = (self == package.loaded["src.ui.game3.item_pc"] or self == package.loaded["src.ui.game3.rse.item_storage"] or type(self.handleInput) == "function")
    local ctrl = self.__playerPcController
    local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
    if not isGen3 and input and ctrl then
      local action = ctrl:handleInput(input)
      if action == "close" then
        local stk = (self.game and self.game.stack) or (game and game.stack)
        if stk and stk.pop then
          local top = stk.top and stk:top()
          if top == self then stk:pop() else stk:pop() end
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
        if self.onCancel then self.onCancel() end
        if self.opts and self.opts.onClose then self.opts.onClose() end
        if game and game.data then require("src.core.Sound").play(game.data, "Turn_Off_PC") end
        return
      elseif action == true then
        return
      end
    end
    if baseUpdate then
      if isGen3 then
        baseUpdate(dt)
      else
        baseUpdate(self, dt)
      end
    end
  end
end

-- Attach navigation hooks for Pokémon PC Terminal / Hub (Bills PC, Players PC, Oak's Rating, Hall of Fame)
local function attachPcHubControls(state, game)
  if not state or state.__omniUiPcHubAttached then return end
  state.__omniUiPcHubAttached = true

  -- If this is Gen 3 PcMenu, it already handles input natively via game3 stack
  if state.handleInput and (state == package.loaded["src.ui.game3.pc_menu"] or (state.isMenu and state._rootEntries)) then
    return
  end

  -- Clear boot text message if active so user immediately gets crisp interactive terminal
  if state.message and state.booted == false then
    state.message = nil
    state.booted = true
  end

  local thisState = state
  local baseUpdate = state.update
  state.update = function(self, dt)
    self, dt = normalizeSelf(self, dt, thisState)
    local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
    local items = self.entries or self.items or {}
    local numItems = #items

    if input and numItems > 0 then
      if input:wasPressed("up") then
        self.index = (self.index or 1) > 1 and (self.index - 1) or numItems
        self.cursor = self.index
        local g = self.game or game
        if g and g.data then require("src.core.Sound").play(g.data, "Press_AB") end
        return
      elseif input:wasPressed("down") then
        self.index = (self.index or 1) < numItems and (self.index + 1) or 1
        self.cursor = self.index
        local g = self.game or game
        if g and g.data then require("src.core.Sound").play(g.data, "Press_AB") end
        return
      elseif input:wasPressed("b") then
        local stk = (self.game and self.game.stack) or (game and game.stack)
        if self.shutdown then
          self:shutdown()
        elseif self.close then
          self:close()
        elseif self.onCancel then
          self.onCancel()
        end
        if stk and stk:top() == self then stk:pop() end
        local g = self.game or game
        if g and g.data then require("src.core.Sound").play(g.data, "Turn_Off_PC") end
        return
      elseif input:wasPressed("a") then
        local cur = items[self.index or 1]
        if cur then
          local cid = tostring(cur.id or cur.label or cur.name or ""):lower()
          local Screens = require("src.ui.Screens")
          local Sound = require("src.core.Sound")
          local g = self.game or game
          if g and g.data then Sound.play(g.data, "Enter_PC") end

          local isGen2 = hostIsGen2(g)
          if cid:find("bill") or cid:find("storage") or cid:find("someone") or cid:find("lanette") then
            local sub = Screens.push(g, isGen2 and "Gen2BoxMenu" or "BoxMenu")
            if sub then
              local baseExit = sub.exit
              sub.exit = function(...)
                if type(baseExit) == "function" then baseExit(...) end
                self.index = 1
                self.cursor = 1
              end
            end
            return
          elseif cid:find("player") or cid:find("item") or cid:find("my") then
            local sub = Screens.push(g, isGen2 and "Gen2ItemPcMenu" or "PlayerPC")
            if sub then
              local baseExit = sub.exit
              sub.exit = function(...)
                if type(baseExit) == "function" then baseExit(...) end
                self.index = 1
                self.cursor = 1
              end
            end
            return
          elseif cid:find("turnoff") or cid:find("logoff") or cid:find("turn") or cid:find("off") or cid:find("exit") then
            local stk = (self.game and self.game.stack) or (game and game.stack)
            if cur.onSelect then
              cur.onSelect()
            elseif self.shutdown then
              self:shutdown()
            elseif self.close then
              self:close()
            elseif self.onCancel then
              self.onCancel()
            end
            if stk and stk:top() == self then stk:pop() end
            if g and g.data then Sound.play(g.data, "Turn_Off_PC") end
            return
          elseif cur.onSelect then
            cur.onSelect()
            return
          elseif self.choose then
            self:choose()
            return
          end
        end
      end
    end

    if baseUpdate then baseUpdate(self, dt) end
  end
end

local function attachPokenavControls(state, game)
  if not state or state.__omniUiPokenavAttached then return end
  state.__omniUiPokenavAttached = true

  local okPR, PokenavRenderer = pcall(require, "mods.omni_ui.renderers.PokenavRenderer")

  local function sfx(self, soundName)
    local g = (self and self.game) or game or currentGame
    if g and g.data then
      pcall(function() require("src.core.Sound").play(g.data, soundName or "Press_AB") end)
    end
  end

  local function handlePokenavInput(self, input)
    if not input then return false end
    local g = self.game or game or currentGame
    local cards = (okPR and PokenavRenderer and PokenavRenderer.getAvailableCards and PokenavRenderer.getAvailableCards(g, self)) or {
      { id = "map", label = "HOENN MAP" },
    }
    local n = #cards
    self.cardIndex = math.max(1, math.min(n, self.cardIndex or 1))
    local curCard = cards[self.cardIndex] or cards[1]
    local curId = curCard and curCard.id or "map"

    -- Tier 1: Device Chassis / Tab Bar Focus
    if self.mode ~= "card" then
      if input:wasPressed("left") or input:wasPressed("lshoulder") or input:wasPressed("l") then
        self.cardIndex = (self.cardIndex > 1) and (self.cardIndex - 1) or n
        sfx(self)
        return true
      elseif input:wasPressed("right") or input:wasPressed("rshoulder") or input:wasPressed("r") then
        self.cardIndex = (self.cardIndex < n) and (self.cardIndex + 1) or 1
        sfx(self)
        return true
      elseif input:wasPressed("a") then
        self.mode = "card"
        sfx(self)
        return true
      elseif input:wasPressed("b") then
        sfx(self)
        if self.onClose then
          self.onClose()
        elseif self.shutdown then
          self:shutdown()
        elseif self.close then
          self:close()
        else
          local stk = (self.game and self.game.stack) or (game and game.stack) or (g and g.stack)
          if stk and stk.pop then stk:pop() end
          pcall(function() require("src.ui.game3.stack").pop("rse_pokenav") end)
          pcall(function() require("src.ui.game3.stack").pop("rs_pokenav") end)
        end
        return true
      end
      return true
    end

    -- Tier 2: Inside Active Card Focus
    if input:wasPressed("b") then
      if self.callActive then
        self.callActive = false
        sfx(self)
        return true
      end
      self.mode = "strip"
      sfx(self)
      return true
    end

    -- Card 1: Map
    if curId == "map" then
      local cx = self.cursorX or 0
      local cy = self.cursorY or 0
      if input:wasPressed("up") then
        self.cursorY = math.max(0, cy - 1)
        sfx(self)
        return true
      elseif input:wasPressed("down") then
        self.cursorY = math.min(14, cy + 1)
        sfx(self)
        return true
      elseif input:wasPressed("left") then
        self.cursorX = math.max(0, cx - 1)
        sfx(self)
        return true
      elseif input:wasPressed("right") then
        self.cursorX = math.min(27, cx + 1)
        sfx(self)
        return true
      elseif input:wasPressed("a") then
        sfx(self)
        return true
      end
      return true
    end

    -- Card 2: Match Call / Trainer's Eyes
    if curId == "call" or curId == "eyes" then
      local contacts = self._matchCallList or {}
      local total = #contacts
      if self.callActive then
        if input:wasPressed("a") or input:wasPressed("b") then
          self.callActive = false
          sfx(self)
          return true
        end
        return true
      end

      if input:wasPressed("up") then
        if total > 0 then
          self.contactSel = (self.contactSel or 1) > 1 and (self.contactSel - 1) or total
          sfx(self)
        end
        return true
      elseif input:wasPressed("down") then
        if total > 0 then
          self.contactSel = (self.contactSel or 1) < total and (self.contactSel + 1) or 1
          sfx(self)
        end
        return true
      elseif input:wasPressed("a") then
        if total > 0 and self.contactSel then
          local c = contacts[self.contactSel]
          if c then
            self.callActive = true
            local okMC, MatchCall = pcall(require, "src.core.game3.rse.match_call")
            local session = self.session or (g and g.session) or (package.loaded["src.core.game3.runtime"] and package.loaded["src.core.game3.runtime"]._session)
            if okMC and MatchCall and MatchCall.callTrainer and session and c.headerId then
              local okMsg, msg = pcall(MatchCall.callTrainer, session, c.headerId)
              if okMsg and msg and msg ~= "" then
                self.callMessage = msg
              else
                self.callMessage = "Trainer signal reached. Standing by for rematch call."
              end
            else
              self.callMessage = "Trainer signal reached. Standing by for rematch call."
            end
            sfx(self)
          end
        end
        return true
      end
      return true
    end

    -- Card 3: Contest Condition Radar
    if curId == "condition" then
      local party = (self.session and self.session.party) or (g and g.save and g.save.party) or (g and g.session and g.session.party) or {}
      local total = #party
      if input:wasPressed("up") or input:wasPressed("left") then
        if total > 0 then
          self.condMonSel = (self.condMonSel or 1) > 1 and (self.condMonSel - 1) or total
          sfx(self)
        end
        return true
      elseif input:wasPressed("down") or input:wasPressed("right") then
        if total > 0 then
          self.condMonSel = (self.condMonSel or 1) < total and (self.condMonSel + 1) or 1
          sfx(self)
        end
        return true
      end
      return true
    end

    -- Card 4: Ribbons Showcase
    if curId == "ribbons" then
      local holders = self._ribbonHolders or {}
      local total = #holders
      if input:wasPressed("up") or input:wasPressed("left") then
        if total > 0 then
          self.ribbonMonSel = (self.ribbonMonSel or 1) > 1 and (self.ribbonMonSel - 1) or total
          sfx(self)
        end
        return true
      elseif input:wasPressed("down") or input:wasPressed("right") then
        if total > 0 then
          self.ribbonMonSel = (self.ribbonMonSel or 1) < total and (self.ribbonMonSel + 1) or 1
          sfx(self)
        end
        return true
      end
      return true
    end

    return false
  end

  state.handleInputOmni = handlePokenavInput
  if not state.handleInput then
    state.handleInput = handlePokenavInput
  end

  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input) or (currentGame and currentGame.input)
    if input and self.handleInputOmni then
      if self:handleInputOmni(input) then
        return
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

local origModernOverlayAttachMainMenu = ModernOverlay.attachMainMenuControls
local origModernOverlayAttachStartMenu = ModernOverlay.attachStartMenuControls
local origModernOverlayAttachSave = ModernOverlay.attachSaveControls

-- Attach navigation hooks for ChoiceBox (Left/Right to switch Yes/No)
local function attachChoiceBoxControls(state)
  if not state or state.__omniUiChoiceAttached then return end
  state.__omniUiChoiceAttached = true
  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input)
    if input and self.pending == nil then
      if input:wasPressed("left") or input:wasPressed("right") then
        if self.index ~= nil then
          self.index = (self.index == 1) and 2 or 1
        elseif self.cursor ~= nil then
          self.cursor = (self.cursor == 1) and 2 or 1
        elseif self.choice ~= nil then
          self.choice = (self.choice == 1) and 2 or 1
        end
        if self.game and self.game.data then
          pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
        end
        return
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

-- Attach navigation hooks for Save Menu (Left/Right to switch Yes/No)
local function attachSaveControls(state, game)
  if not state or state.__omniUiSaveAttached then return end
  state.__omniUiSaveAttached = true
  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if input then
      if input:wasPressed("left") or input:wasPressed("right") then
        if self.choice ~= nil then
          self.choice = (self.choice == 1) and 2 or 1
          if self.playSfxNamed then
            self:playSfxNamed("Sfx_ReadText2")
          elseif self.game and self.game.data then
            pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
          end
          return
        elseif self.cursor ~= nil then
          self.cursor = (self.cursor == 1) and 2 or 1
          if self.playSfxNamed then
            self:playSfxNamed("Sfx_ReadText2")
          elseif self.game and self.game.data then
            pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
          end
          return
        elseif self.index ~= nil then
          self.index = (self.index == 1) and 2 or 1
          if self.game and self.game.data then
            pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
          end
          return
        end
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

local function attachPokegearControls(state, game)
  if not state or state.__omniUiPokegearAttached then return end
  state.__omniUiPokegearAttached = true
  local baseUpdate = state.update
  local INTERACTIVE = { map = true, phone = true, radio = true, dexnav = true }
  local function sfx(self)
    if self.game and self.game.data then pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end) end
  end
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if not input or self.fly or self.townMap then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    -- Refresh cards so custom cards from pokegear_cards / Kanto-Reforged DexNav are included
    local vCards = (self.visibleCards and self:visibleCards()) or self.cards or {}
    local hasDex = false
    for _, c in ipairs(vCards) do
      if c.id == "dexnav" then hasDex = true break end
    end
    if not hasDex then
      local okKR, DexNav = pcall(require, "mods.Kanto-Reforged.ui.dexnav")
      if okKR and DexNav and DexNav.hasPokedex then
        local g = (self.game and self.game.save and self.game) or game
        if DexNav.hasPokedex(g) and (not DexNav.mode or DexNav.mode() ~= DexNav.MODE_OFF) then
          vCards[#vCards + 1] = {
            id = "dexnav",
            label = (DexNav.menuLabel and DexNav.menuLabel()) or "DEXNAV",
            icon = 0x40,
          }
        end
      end
    end
    self.cards = vCards

    local n = #self.cards
    if n == 0 then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end
    if not self.cardIndex or self.cardIndex > n then
      self.cardIndex = math.max(1, math.min(self.cardIndex or 1, n))
    end

    local card = (self.card and self:card()) or self.cards[self.cardIndex]
    local id = card and card.id

    if self.mode ~= "card" then
      self.iconTimer = ((self.iconTimer or 0) + 1) % 32
      if id == "dexnav" then
        local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
        if PokegearRenderer.ensureDexNavData then
          PokegearRenderer.ensureDexNavData(self, self.game or game)
        end
        if card and card.onHighlight then
          pcall(card.onHighlight, self)
        end
      end

      if input:wasPressed("left") or input:wasPressed("lshoulder") or input:wasPressed("l") then
        self.cardIndex = self.cardIndex > 1 and self.cardIndex - 1 or n
        sfx(self)
        local curCard = self.cards[self.cardIndex]
        if curCard and curCard.id == "dexnav" then
          local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
          if PokegearRenderer.ensureDexNavData then
            PokegearRenderer.ensureDexNavData(self, self.game or game)
          end
          if curCard.onHighlight then pcall(curCard.onHighlight, self) end
        end
      elseif input:wasPressed("right") or input:wasPressed("rshoulder") or input:wasPressed("r") then
        self.cardIndex = self.cardIndex < n and self.cardIndex + 1 or 1
        sfx(self)
        local curCard = self.cards[self.cardIndex]
        if curCard and curCard.id == "dexnav" then
          local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
          if PokegearRenderer.ensureDexNavData then
            PokegearRenderer.ensureDexNavData(self, self.game or game)
          end
          if curCard.onHighlight then pcall(curCard.onHighlight, self) end
        end
      elseif input:wasPressed("a") then
        if INTERACTIVE[id] or (card and (card.hasDraw or card.draw or card.update)) then
          self.mode = "card"
          sfx(self)
          if card and card.onEnter then pcall(card.onEnter, self) end
          if id == "dexnav" then
            local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
            if PokegearRenderer.ensureDexNavData then
              PokegearRenderer.ensureDexNavData(self, self.game or game)
            end
          end
        end
      elseif input:wasPressed("b") then
        if self.onClose then self.onClose() end
      end
      return
    end

    local busy = id == "phone" and (self.call ~= nil or self.phoneSubmenu ~= nil)
    if busy then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    if input:wasPressed("b") then
      self.iconTimer = ((self.iconTimer or 0) + 1) % 32
      if self.stopRadio then self:stopRadio() end
      if card and card.onLeave then pcall(card.onLeave, self) end
      self.mode = "strip"
      self.viewRegion = nil
      self.mapCursor = nil
      sfx(self)
      return
    end

    if id == "dexnav" then
      self.iconTimer = ((self.iconTimer or 0) + 1) % 32
      input:wasPressed("left")
      input:wasPressed("right")
      local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
      if PokegearRenderer.ensureDexNavData then
        PokegearRenderer.ensureDexNavData(self, self.game or game)
      end
      local items = self._krDexNavItems or {}
      local total = #items
      if total > 0 then
        local cur = self._krDexNavCursor or 0
        if input:wasPressed("up") then
          cur = (cur - 1) % total
          self._krDexNavCursor = cur
          sfx(self)
        elseif input:wasPressed("down") then
          cur = (cur + 1) % total
          self._krDexNavCursor = cur
          sfx(self)
        end
      end
      return
    end

    if id == "map" then
      self.iconTimer = ((self.iconTimer or 0) + 1) % 32
      if input:wasPressed("up") then self:stepMapCursor(1)
      elseif input:wasPressed("down") then self:stepMapCursor(-1)
      elseif input:wasPressed("left") or input:wasPressed("right") then
        if self:toggleViewRegion() then sfx(self) end
      end
      return
    end

    if id == "phone" then
      self.iconTimer = ((self.iconTimer or 0) + 1) % 32
      input:wasPressed("left")
      input:wasPressed("right")

      local list = (self.phoneList and self:phoneList()) or {}
      local activeList = {}
      for _, cid in ipairs(list) do
        if cid and cid ~= 0 then activeList[#activeList + 1] = cid end
      end
      local total = #activeList

      if input:wasPressed("a") then
        if self.phoneSelection and self:phoneSelection() ~= 0 then
          if self.openPhoneSubmenu then self:openPhoneSubmenu() end
          sfx(self)
        end
        return
      end

      if total <= 1 then
        self.phoneScroll = 0
        self.phoneCursor = 0
        return
      end

      if (self.phoneScroll or 0) + (self.phoneCursor or 0) + 1 > total then
        if total <= 4 then
          self.phoneScroll = 0
          self.phoneCursor = total - 1
        else
          self.phoneScroll = total - 4
          self.phoneCursor = 3
        end
      end

      if input:wasPressed("up") then
        if (self.phoneCursor or 0) > 0 then
          self.phoneCursor = self.phoneCursor - 1
          sfx(self)
        elseif (self.phoneScroll or 0) > 0 then
          self.phoneScroll = self.phoneScroll - 1
          sfx(self)
        end
        return
      elseif input:wasPressed("down") then
        local curIdx = (self.phoneScroll or 0) + (self.phoneCursor or 0) + 1
        if curIdx < total then
          if (self.phoneCursor or 0) < 3 then
            self.phoneCursor = (self.phoneCursor or 0) + 1
            sfx(self)
          elseif (self.phoneScroll or 0) + 4 < total then
            self.phoneScroll = (self.phoneScroll or 0) + 1
            sfx(self)
          end
        end
        return
      end
      return
    end

    local isVanilla = (id == "clock" or id == "map" or id == "phone" or id == "radio" or id == "dexnav")
    if not isVanilla and card and card.update then
      pcall(card.update, self, input, dt)
      return
    end

    input:wasPressed("left")
    input:wasPressed("right")
    if baseUpdate then baseUpdate(self, dt) end
  end
end

local function attachStartMenuControls(state, game)
  if not state or state.__omniUiStartAttached then return end
  local isGen3Start = (state == (package and package.loaded and (package.loaded["src.ui.game3.start_menu"] or package.loaded["src.ui.game3.start_menu_frlg"])) or state.ENTRIES ~= nil)
  state.__omniUiStartAttached = true
  if isGen3Start then
    -- Yes and No are drawn side by side. The cart menu only listens to up/down.
    local baseUpdate = state.update
    state.update = function(self, dt)
      if type(self) ~= "table" then
        dt = self
        self = state
      end
      local menu = (type(self) == "table" and self) or state
      local input = (menu._game and menu._game.input)
        or (menu.game and menu.game.input)
        or (game and game.input)
        or (currentGame and currentGame.input)
      local typing = menu.promptTyping and menu.promptTyping()
      if input and menu._confirmExit and not typing then
        if input:wasPressed("left") or input:wasPressed("right") then
          if menu.move then menu.move(1) end
        end
      end
      if baseUpdate then baseUpdate(self, dt) end
    end
    return
  end
  local baseUpdate = state.update
  local firstFrame = true
  state.update = function(self, dt)
    if type(self) ~= "table" then
      dt = self
      self = state
    end
    self = (type(self) == "table" and self) or state
    local input = (self.game and self.game.input) or (game and game.input)
    if firstFrame then
      firstFrame = false
      if input and input.pressed and input.pressed["start"] then
        input.pressed["start"] = nil
      end
    end
    if input and (self.phase == "confirm" or self.phase == "confirmContest" or self.phase == "confirmQuit") then
      if input:wasPressed("left") or input:wasPressed("right") then
        self.confirmChoice = (self.confirmChoice == 1) and 2 or 1
        if self.playSfxNamed then
          self:playSfxNamed("Sfx_ReadText2")
        elseif self.game and self.game.data then
          pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
        end
        return
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

local function attachContinueControls(state, game)
  if not state or state.__omniUiContinueAttached then return end
  state.__omniUiContinueAttached = true
  state.confirmChoice = 1 -- 1 = YES, 2 = NO
  state.index = 1
  state.isChoiceBox = true
  state.labels = { "YES", "NO" }
  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if not input then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    if input:wasPressed("left") or input:wasPressed("right") or input:wasPressed("up") or input:wasPressed("down") then
      self.confirmChoice = (self.confirmChoice == 1) and 2 or 1
      self.index = self.confirmChoice
      local g = self.game or game
      if g and g.data then
        pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end)
      end
      return
    elseif input:wasPressed("a") then
      local g = self.game or game
      if g and g.data then
        pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end)
      end
      if (self.confirmChoice or self.index or 1) == 1 then
        local title = self.title
        local stk = g and g.stack
        if not (title and title.onContinue) and stk and stk.states then
          for _, st in ipairs(stk.states) do
            if st and st.onContinue then
              title = st
              break
            end
          end
        end
        if stk and stk:top() == self then stk:pop() end
        local okTrans, Transition = pcall(require, "src.render.Transition")
        if okTrans and Transition and Transition.whiteFlash and stk then
          stk:push(Transition.whiteFlash(g, 33, function()
            if title and title.onContinue then
              title.onContinue()
            elseif g and g.restoreSave then
              local okS, loaded = pcall(require("src.core.SaveData").load)
              if okS and loaded then
                g:restoreSave(loaded, nil, { freshBoot = true, continued = true })
              end
            end
          end))
        else
          if title and title.onContinue then
            title.onContinue()
          elseif g and g.restoreSave then
            local okS, loaded = pcall(require("src.core.SaveData").load)
            if okS and loaded then
              g:restoreSave(loaded, nil, { freshBoot = true, continued = true })
            end
          end
        end
      else
        local stk = g and g.stack
        if stk and stk:top() == self then stk:pop() end
      end
      return
    elseif input:wasPressed("b") then
      local g = self.game or game
      if g and g.data then
        pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end)
      end
      local stk = g and g.stack
      if stk and stk:top() == self then stk:pop() end
      return
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

local function attachMainMenuControls(state, game)
  if not state then return end
  if state.titleUiBox and state.save and state.title then
    return attachContinueControls(state, game)
  end
  if origModernOverlayAttachMainMenu then
    return origModernOverlayAttachMainMenu(state, game)
  end
end

local function attachLeaguePcControls(state)
  if not state or state.__omniUiLeaguePcAttached then return end
  state.__omniUiLeaguePcAttached = true
  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input)
    if input then
      local teams = self.teams or {}
      local teamCount = #teams
      local curTeam = teams[self.teamIndex or 1] or {}
      local monCount = #curTeam

      if input:wasPressed("up") then
        self.monIndex = math.max(1, (self.monIndex or 1) - 1)
        self:loadMon()
        return
      elseif input:wasPressed("down") then
        self.monIndex = math.min(monCount > 0 and monCount or 1, (self.monIndex or 1) + 1)
        self:loadMon()
        return
      elseif input:wasPressed("left") then
        if teamCount > 0 then
          self.teamIndex = math.max(1, (self.teamIndex or 1) - 1)
          self.monIndex = 1
          self:loadMon()
        end
        return
      elseif input:wasPressed("right") then
        if teamCount > 0 then
          self.teamIndex = math.min(teamCount, (self.teamIndex or 1) + 1)
          self.monIndex = 1
          self:loadMon()
        end
        return
      elseif input:wasPressed("pageup") or input:wasPressed("l") then
        if teamCount > 0 then
          self.teamIndex = math.max(1, (self.teamIndex or 1) - 10)
          self.monIndex = 1
          self:loadMon()
        end
        return
      elseif input:wasPressed("pagedown") or input:wasPressed("r") then
        if teamCount > 0 then
          self.teamIndex = math.min(teamCount, (self.teamIndex or 1) + 10)
          self.monIndex = 1
          self:loadMon()
        end
        return
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

local function attachLoadReportControls(state, game)
  if not state or state.__omniLoadReportAttached then return end
  state.__omniLoadReportAttached = true
  state.offset = state.offset or 0

  local LoadReportRenderer = require("mods.omni_ui.renderers.LoadReportRenderer")
  local report = state.report or {}
  local meta = (game and game.save and game.save.meta) or (state.save and state.save.meta) or {}
  local flatList = LoadReportRenderer.buildFlatList(report, meta, state.lines)
  local totalItems = #flatList
  local visibleCount = 8

  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if not input then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    local maxOff = math.max(0, totalItems - visibleCount)

    if input:wasPressed("up") then
      if (self.offset or 0) > 0 then
        self.offset = math.max(0, (self.offset or 0) - 1)
        local Sound = require("src.core.Sound")
        if Sound and Sound.play and self.game and self.game.data then
          pcall(Sound.play, self.game.data, "Press_AB")
        end
      end
      return
    elseif input:wasPressed("down") then
      if (self.offset or 0) < maxOff then
        self.offset = math.min(maxOff, (self.offset or 0) + 1)
        local Sound = require("src.core.Sound")
        if Sound and Sound.play and self.game and self.game.data then
          pcall(Sound.play, self.game.data, "Press_AB")
        end
      end
      return
    elseif input:wasPressed("a") or input:wasPressed("b") or input:wasPressed("start") then
      local Sound = require("src.core.Sound")
      if Sound and Sound.play and self.game and self.game.data then
        pcall(Sound.play, self.game.data, "Press_AB")
      end
      local s = self.game and self.game.stack or game and game.stack
      if s then s:pop() end
      return
    end
  end
end

local function attachDialogueControls(state, game)
  if not state or state.__omniDialogueAttached then return end
  if not (state.isTextBox or (state.pages and state.shown)) then return end
  -- Native Gen 1 / Gen 2 TextBox manages its own typewriter, prompts, and stack lifecycle!
  if state.isTextBox then
    if not state.__omniContHooked then
      state.__omniContHooked = true
      local origUpdate = state.update
      state.update = function(self, dt)
        if self.waiting and self.contAdvance then
          self.waiting = false
          self.contAdvance = false
          self.preWait = 0
          self.lineIndex = self.lineIndex + 1
          self:beginLine()
          self.holdFrames = 0
        end
        return origUpdate(self, dt)
      end
    end
    return
  end
  state.__omniDialogueAttached = true

  local Font = require("src.render.Font")
  local NAME_DELAYS = { FAST = 1, MID = 3, SLOW = 5 }

  local maxCols = 36
  local modernPages = {}

  local firstLine = (state.pages and state.pages[1] and state.pages[1][1]) or ""
  local spk, rest = firstLine:match("^([%w%._'%s%-]+):%s*(.*)$")
  if spk and #spk <= 16 and not state.speaker then
    state.speaker = spk
    if state.pages and state.pages[1] then
      state.pages[1][1] = rest
    end
  end

  for _, oldPage in ipairs(state.pages or {}) do
    local words = {}
    for _, line in ipairs(oldPage) do
      local s = tostring(line or ""):gsub("[\n\v\f]", " ")
      for word in s:gmatch("%S+") do
        words[#words + 1] = word
      end
    end

    local lines = {}
    local curLine = ""
    for _, w in ipairs(words) do
      local candidate = (curLine == "") and w or (curLine .. " " .. w)
      if #candidate > maxCols and curLine ~= "" then
        lines[#lines + 1] = curLine
        curLine = w
      else
        curLine = candidate
      end
    end
    if curLine ~= "" then
      lines[#lines + 1] = curLine
    end

    for i = 1, #lines, 2 do
      local p = { lines[i] }
      if lines[i + 1] then p[2] = lines[i + 1] end
      modernPages[#modernPages + 1] = p
    end
  end

  if #modernPages == 0 then modernPages = { { "" } } end

  state.pages = modernPages
  state.pageIndex = 1
  state.lineIndex = 1
  state.contAdvance = false
  state.scrollPx = 0
  state.waiting = false
  state.done = false
  state.charIndex = 0
  state.charTimer = 0
  state.shown = { {} }
  state.codes = Font.encode(state.pages[1][1] or "")

  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if not input then
      if baseUpdate then baseUpdate(self, dt) end
      return
    end

    if self.done then
      if self.stay then
        if not self.stayShown then
          if self.stay.prompt and not (input:wasPressed("a") or input:wasPressed("b")) then return end
          if self.stay.prompt and self.game and self.game.data then
            pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
          end
          self.stayShown = true
          if self.stay.onShown then self.stay.onShown() end
        end
        return
      end
      if self.choice then
        if baseUpdate then baseUpdate(self, dt) end
        return
      end
      if input:wasPressed("a") or input:wasPressed("b") then
        if self.autoSrc and self.autoSrc.stop then pcall(self.autoSrc.stop, self.autoSrc) end
        self.auto = nil
        if not self.waitButton and self.game and self.game.data then
          pcall(function() require("src.core.Sound").playPress(self.game.data) end)
        end
        self.game.stack:pop()
        if self.onDone then self.onDone() end
        return
      end
      if self.auto then
        if baseUpdate then baseUpdate(self, dt) end
        return
      end
      return
    end

    if self.waiting then
      if input:wasPressed("a") or input:wasPressed("b") then
        if self.autoSrc and self.autoSrc.stop then pcall(self.autoSrc.stop, self.autoSrc) end
        if self.game and self.game.data then
          pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
        end
        self.waiting = false
        self.pageIndex = self.pageIndex + 1
        self.lineIndex = 1
        self.shown = { {} }
        self.codes = Font.encode(self.pages[self.pageIndex][1] or "")
        self.charIndex = 0
        self.charTimer = 0
        return
      end
      if self.sfxHeld and self:sfxHeld() then return end
      return
    end

    if input:wasPressed("a") or input:wasPressed("b") then
      local page = self.pages[self.pageIndex] or {}
      self.shown[1] = Font.encode(page[1] or "")
      if page[2] then
        self.shown[2] = Font.encode(page[2] or "")
        self.lineIndex = 2
      else
        self.lineIndex = 1
      end
      if self.pageIndex < #self.pages then
        self.waiting = true
      else
        self.done = true
      end
      return
    end

    local rawSpeed = self.game and self.game.save and self.game.save.options and self.game.save.options.textSpeed
    local delay = NAME_DELAYS[rawSpeed] or rawSpeed or 3
    if delay ~= 1 and delay ~= 3 and delay ~= 5 then delay = 3 end
    local speedMult = (self.game and self.game.logicSpeed and self.game:logicSpeed()) or 1
    if speedMult > 1 or input:isDown("a") or input:isDown("b") then
      delay = 1
    end

    self.charTimer = (self.charTimer or 0) + 1
    while self.charTimer >= delay do
      self.charTimer = self.charTimer - delay
      if self.charIndex < #self.codes then
        self.charIndex = self.charIndex + 1
        local line = self.shown[self.lineIndex]
        if line then
          line[#line + 1] = self.codes[self.charIndex]
        end
      else
        local page = self.pages[self.pageIndex] or {}
        if self.lineIndex == 1 and page[2] then
          self.lineIndex = 2
          self.shown[2] = {}
          self.codes = Font.encode(page[2] or "")
          self.charIndex = 0
        elseif self.pageIndex < #self.pages then
          self.waiting = true
          break
        else
          self.done = true
          break
        end
      end
    end
  end
end

local function attachNamingControls(state, game)
  local okNR, NamingRenderer = pcall(require, "mods.omni_ui.renderers.NamingRenderer")
  if okNR and NamingRenderer and NamingRenderer.attachControls then
    NamingRenderer.attachControls(state, game)
  end
end

ModernOverlay.attachPokedexControls = attachPokedexControls
ModernOverlay.attachBagControls = attachBagControls
ModernOverlay.attachPokenavControls = attachPokenavControls
ModernOverlay.attachChoiceBoxControls = attachChoiceBoxControls
ModernOverlay.attachSaveControls = attachSaveControls
ModernOverlay.attachPokegearControls = attachPokegearControls
ModernOverlay.attachStartMenuControls = attachStartMenuControls
ModernOverlay.attachMainMenuControls = attachMainMenuControls
ModernOverlay.attachLeaguePcControls = attachLeaguePcControls
ModernOverlay.attachContinueControls = attachContinueControls
ModernOverlay.attachLoadReportControls = attachLoadReportControls
ModernOverlay.attachDialogueControls = attachDialogueControls
ModernOverlay.attachNamingControls = attachNamingControls

ModernOverlay.attachControls = function(state, game)
  if not state then return end
  local g = game or state.game or ModernOverlay.currentGame or currentGame
  local kind = ModernOverlay.isSupported(state)
  if kind == "summary" then
    attachSummaryControls(state, g)
  elseif kind == "bag" then
    attachBagControls(state, g)
  elseif kind == "pokedex" then
    attachPokedexControls(state, g)
  elseif kind == "shop" then
    attachShopControls(state, g)
  elseif kind == "dialogue" then
    attachDialogueControls(state, g)
  elseif kind == "load_report" then
    attachLoadReportControls(state, g)
  elseif kind == "town_map" then
    attachTownMapControls(state, g)
  elseif kind == "pokegear" then
    attachPokegearControls(state, g)
  elseif kind == "pokenav" then
    attachPokenavControls(state, g)
  elseif kind == "storage" then
    attachStorageControls(state, g)
  elseif kind == "player_pc" then
    attachPlayerPcControls(state, g)
  elseif kind == "pc_hub" then
    attachPcHubControls(state, g)
  elseif kind == "league_pc" then
    attachLeaguePcControls(state)
  elseif kind == "save" then
    attachSaveControls(state, g)
  elseif kind == "start_menu" then
    attachStartMenuControls(state, g)
  elseif kind == "main_menu" then
    attachMainMenuControls(state, g)
  elseif kind == "naming" then
    attachNamingControls(state, g)
  elseif kind == "quantity" or (state.qty and state.max) then
    attachQuantityControls(state, g)
  elseif kind == "choice" or state.onChoose or state.labels then
    attachChoiceBoxControls(state)
  end
end

return function(mod)
  -- 1. Register mod options dynamically from discovered themes in themes/
  local function buildThemeChoices()
    local choices = {}
    for _, t in ipairs(Theme.list()) do
      choices[#choices + 1] = { (t.label or t.id):upper(), t.id }
    end
    if #choices == 0 then
      choices = { { "DARK MODERN", "dark" } }
    end
    return choices
  end

  mod.options:define({
    {
      key = "theme",
      label = "UI THEME",
      type = "choice",
      default = "dark",
      choices = buildThemeChoices(),
    },
    {
      key = "overlay",
      label = "MODERN HIGH-RES UI",
      type = "toggle",
      default = true,
    },
    {
      key = "menu_animations",
      label = "MENU ANIMATIONS",
      type = "toggle",
      default = true,
    },
  })

  -- Synchronize theme from persisted mod options at startup
  local initTheme = mod.options:get("theme")
  if initTheme and Theme.REGISTRY[initTheme] then
    Theme.setTheme(initTheme)
  end

  -- 2. Capture live game reference from render.zones
  mod.hooks:wrap("render.zones", function(next, game, zones)
    currentGame = game
    ModernOverlay.currentGame = game
    return next(game, zones)
  end, 100)

  local okG3Shop, G3ShopMenu = pcall(require, "src.ui.game3.shop_menu")
  if okG3Shop and G3ShopMenu then
    attachShopControls(G3ShopMenu)
  end

  local okG3Start, G3StartMenu = pcall(require, "src.ui.game3.start_menu")
  if okG3Start and G3StartMenu then
    attachStartMenuControls(G3StartMenu)
  end

  local isGen3 = (type(mod.game_version) == "string" and (mod.game_version:lower() == "emerald" or mod.game_version:lower() == "ruby" or mod.game_version:lower() == "sapphire" or mod.game_version:lower() == "firered" or mod.game_version:lower() == "leafgreen"))
    or (package.loaded["src.core.game3.profile"] ~= nil)
    or (package.loaded["src.core.game3.rom_text"] ~= nil)
    or (package.loaded["src.core.Game3"] ~= nil)

  -- Wrap constructors so all instances (even if instantiated outside of Screens.push) get omni controls attached
  if not isGen3 then
    local okCB, ChoiceBox = pcall(require, "src.ui.ChoiceBox")
    if okCB and ChoiceBox and ChoiceBox.new then
      local origCBNew = ChoiceBox.new
      ChoiceBox.new = function(...)
        local inst = origCBNew(...)
        if inst then attachChoiceBoxControls(inst) end
        return inst
      end
    end

    local okG2SaveMenu, G2SaveMenu = pcall(require, "src.ui.gen2.SaveMenu")
    if okG2SaveMenu and G2SaveMenu and G2SaveMenu.new then
      local origG2SaveNew = G2SaveMenu.new
      G2SaveMenu.new = function(...)
        local inst = origG2SaveNew(...)
        if inst then attachSaveControls(inst) end
        return inst
      end
    end

    local okG2SM, G2StartMenu = pcall(require, "src.ui.gen2.StartMenu")
    if okG2SM and G2StartMenu and G2StartMenu.new then
      local origG2SMNew = G2StartMenu.new
      G2StartMenu.new = function(...)
        local inst = origG2SMNew(...)
        if inst then
          inst.isStartMenu = true
          inst.screenId = "StartMenu"
          attachStartMenuControls(inst)
        end
        return inst
      end
    end

    local okG2MM, G2MainMenu = pcall(require, "src.ui.gen2.MainMenu")
    if okG2MM and G2MainMenu and G2MainMenu.new then
      local origG2MMNew = G2MainMenu.new
      G2MainMenu.new = function(...)
        local inst = origG2MMNew(...)
        if inst then
          if inst.confirmChoice == nil then inst.confirmChoice = 1 end
          attachMainMenuControls(inst)
        end
        return inst
      end
      local origMMChoose = G2MainMenu.choose
      if origMMChoose then
        G2MainMenu.choose = function(self, value, index)
          origMMChoose(self, value, index)
          if value == "continue" then
            self.confirmChoice = 1
          end
        end
      end
    end
  end

  -- 3. Hook start menu items so closing Save (via Yes/No or completion) returns to the Pause list
  -- and inject any custom items registered by external mods via PublicApi.registerStartMenuItem
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local list = next(game, items) or items
    if mod.options:get("overlay") ~= false and type(list) == "table" then
      -- Inject items registered via PublicApi.registerStartMenuItem
      local PublicApi = require("mods.omni_ui.api.PublicApi")
      if PublicApi and PublicApi.startMenuItems then
        for id, def in pairs(PublicApi.startMenuItems) do
          local exists = false
          for _, it in ipairs(list) do
            if (type(it) == "table" and (it.id == id or it.label == def.label)) or it == id or it == def.label then
              exists = true
              break
            end
          end
          if not exists then
            local insertIdx = #list -- default before QUIT
            if def.insertBefore then
              for idx, it in ipairs(list) do
                local itId = type(it) == "table" and (it.id or it.label) or tostring(it)
                if itId == def.insertBefore or itId:upper() == def.insertBefore:upper() then
                  insertIdx = idx
                  break
                end
              end
            elseif def.insertAfter then
              for idx, it in ipairs(list) do
                local itId = type(it) == "table" and (it.id or it.label) or tostring(it)
                if itId == def.insertAfter or itId:upper() == def.insertAfter:upper() then
                  insertIdx = idx + 1
                  break
                end
              end
            end
            table.insert(list, math.max(1, math.min(#list + 1, insertIdx)), def)
          end
        end
      end

      local function keepsNativeGen3Save(game)
        if type(game) ~= "table" then return false end
        if game.generation == 3 then return true end
        local ver = game.gameVersion or game.version
        if type(game.session) == "table" then
          ver = ver or game.session.version
        end
        ver = tostring(ver or ""):lower()
        if ver == "firered" or ver == "leafgreen" or ver == "ruby"
            or ver == "sapphire" or ver == "emerald" then
          return true
        end
        -- Game3 persists through saveGame and has no Gen 1 state stack.
        return game.stack == nil and type(game.saveGame) == "function"
      end

      for _, item in ipairs(list) do
        local rawLabel = tostring(item.label or item.id or "")
        -- Gen 3 SAVE already opens SaveMenu. The Gen 1 panel reads
        -- game.save.playTime as seconds and pushes game.stack, both of
        -- which throw on a Game3 session, so the row looks dead.
        if (item.id == "save" or rawLabel:upper():find("SAVE")) and item.onSelect
            and not keepsNativeGen3Save(game) then
          item.onSelect = function()
            local TextBox = require("src.render.TextBox")
            local Strings = require("src.core.Strings")
            local Theme = require("src.ui.Theme")
            local Font = require("src.render.Font")
            local badges = require("src.inventory.Badges").count(game.data, game.save)
            local owned = 0
            for _ in pairs(game.save.pokedex and game.save.pokedex.owned or {}) do
              owned = owned + 1
            end
            local t = math.floor(game.save.playTime or 0)
            local panel
            panel = {
              holdsUIAnchors = true,
              delay = 0,
              update = function()
                panel.delay = panel.delay + 1
                if panel.delay == 30 then panel.openPrompt() end
              end,
              draw = function()
                Font.drawBox(4, 0, 16, 10)
                love.graphics.setColor(0, 0, 0, 1)
                Font.draw(Strings("PLAYER"), 5 * 8, 2 * 8)
                Font.draw(game.save.player.name or "RED", 12 * 8, 2 * 8)
                Font.draw(Strings("BADGES"), 5 * 8, 4 * 8)
                Font.draw(("%2d"):format(badges), 17 * 8, 4 * 8)
                Font.draw(Strings("POKéDEX"), 5 * 8, 6 * 8)
                Font.draw(("%3d"):format(owned), 16 * 8, 6 * 8)
                Font.draw(Strings("TIME"), 5 * 8, 8 * 8)
                Font.draw(("%3d:%02d"):format(math.floor(t / 3600),
                                              math.floor(t / 60) % 60), 13 * 8, 8 * 8)
                love.graphics.setColor(1, 1, 1, 1)
              end,
            }
            local function closePanel()
              while game.stack and game.stack:top() do
                local top = game.stack:pop()
                if top == panel then break end
              end
              -- StartMenu remains open as the active top of the stack!
            end
            panel.openPrompt = function()
              game.stack:push(TextBox.new(game,
                Strings("Would you like to\nSAVE the game?"), nil, {
                choiceBox = Theme.saveBox,
                choice = function(yes)
                  if not yes then closePanel() return end
                  game.stack:push(TextBox.new(game, Strings("Now saving..."), function()
                    game:writeSave()
                    game.stack:push(TextBox.new(game,
                      Strings("%s saved\nthe game!", game.save.player.name or "RED"),
                      closePanel, { auto = {
                        sound = function()
                          return require("src.core.Sound").play(game.data, "Save")
                        end,
                        delay = 30,
                      } }))
                  end, { auto = { delay = 120 } }))
                end,
              }))
            end
            game.stack:push(panel)
          end
        end
      end
    end
    return list
  end, 50)

  -- 3b. Hook Options rows so external mods registered via PublicApi.registerOptionRow appear cleanly
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local list = next(game, rows) or rows
    if mod.options:get("overlay") ~= false and type(list) == "table" then
      local PublicApi = require("mods.omni_ui.api.PublicApi")
      if PublicApi and PublicApi.optionRows then
        for id, def in pairs(PublicApi.optionRows) do
          local exists = false
          for _, r in ipairs(list) do
            if (type(r) == "table" and (r.id == id or r.label == def.label)) or r == id or r == def.label then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(list, def)
          end
        end
      end
    end
    return list
  end, 50)

  -- 3c. Hook Party submenus so external mods registered via PublicApi.registerPartyAction appear cleanly
  mod.hooks:wrap("ui.party.submenu", function(next, game, mon, index, items)
    local list = next(game, mon, index, items) or items
    if mod.options:get("overlay") ~= false and type(list) == "table" then
      local PublicApi = require("mods.omni_ui.api.PublicApi")
      if PublicApi and PublicApi.partyActions then
        for id, def in pairs(PublicApi.partyActions) do
          local exists = false
          for _, it in ipairs(list) do
            if (type(it) == "table" and (it.id == id or it.label == def.label)) or it == id or it == def.label then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(list, math.max(1, #list), def)
          end
        end
      end
    end
    return list
  end, 50)

  -- 3d. Hook PC Terminal items to streamline direct entry into storage systems without redundant dialog blurbs
  mod.hooks:wrap("ui.pc.items", function(next, game, items)
    local list = next(game, items) or items
    if mod.options:get("overlay") ~= false and type(list) == "table" then
      local Screens = require("src.ui.Screens")
      local Sound = require("src.core.Sound")
      for _, it in ipairs(list) do
        local raw = tostring(it.label or it.name or ""):upper()
        if raw:find("BILL") or raw:find("SOMEONE") or raw:find("LANETTE") or raw:find("STORAGE") then
          it.onSelect = function()
            if game and game.data then Sound.play(game.data, "Enter_PC") end
            local top = game.stack:top()
            if top and (top.isPcMenu or top.screenId == "PcMenu" or top.items == list) then
              game.stack:pop()
            end
            local sub = Screens.push(game, "BoxMenu")
            local baseExit = sub.exit
            sub.exit = function(...)
              if type(baseExit) == "function" then baseExit(...) end
              if top then
                top.index = 1
                game.stack:push(top)
              end
            end
          end
        elseif raw:find("PC") and not raw:find("OAK") and not raw:find("PROF") and not raw:find("LOG") and not raw:find("TURN") and not raw:find("OFF") then
          it.onSelect = function()
            if game and game.data then Sound.play(game.data, "Enter_PC") end
            local top = game.stack:top()
            if top and (top.isPcMenu or top.screenId == "PcMenu" or top.items == list) then
              game.stack:pop()
            end
            local sub = Screens.push(game, "PlayerPC")
            local baseExit = sub.exit
            sub.exit = function(...)
              if type(baseExit) == "function" then baseExit(...) end
              if top then
                top.index = 1
                game.stack:push(top)
              end
            end
          end
        elseif raw:find("LEAGUE") or raw:find("HALL") or raw:find("FAME") then
          it.onSelect = function()
            if game and game.data then Sound.play(game.data, "Enter_PC") end
            local top = game.stack:top()
            if top and (top.isPcMenu or top.screenId == "PcMenu" or top.items == list) then
              game.stack:pop()
            end
            local sub = Screens.push(game, "LeaguePC")
            local baseExit = sub.exit
            sub.exit = function(...)
              if type(baseExit) == "function" then baseExit(...) end
              if top then
                top.index = 1
                game.stack:push(top)
              end
            end
          end
        end
      end
    end
    return list
  end, 50)

  -- Eagerly pre-load THIS version's save when the title menu opens, so the
  -- continue card shows that cart's party instead of whichever file loads first.
  mod.hooks:wrap("ui.title_menu.items", function(next, game, items)
    local result = next(game, items)
    local ver = game and (game.gameVersion or (game.cart and game.cart.gameVersion))
    if not ver then
      local okGV, GV = pcall(require, "src.core.GameVersion")
      if okGV and GV and GV.get then ver = GV.get() end
    end
    ver = tostring(ver or ""):lower()
    local loaded
    if ver == "gold" or ver == "silver" or ver == "crystal" then
      local ok2, loaded2 = pcall(function() return require("src.core.gen2.Save").load() end)
      if ok2 and type(loaded2) == "table" then loaded = loaded2 end
    elseif ver == "firered" or ver == "leafgreen" or ver == "ruby" or ver == "sapphire" or ver == "emerald" then
      local ok3, loaded3 = pcall(function() return require("src.ui.game3.rse.scene_kit").loadRawSave() end)
      if ok3 and type(loaded3) == "table" then loaded = loaded3 end
    else
      local ok1, loaded1 = pcall(require("src.core.SaveData").load, ver ~= "" and ver or nil)
      if ok1 and type(loaded1) == "table" and loaded1.engine ~= "game3" then loaded = loaded1 end
    end
    if loaded then
      if game then game.__omniTitleSave = loaded end
      if type(result) == "table" then result.__omniSave = loaded end
    end
    return result
  end, 50)

  -- 4. Watch screen pushed to attach modern input navigation controllers
  mod.events:on("screen.pushed", function(ev)
    local state = ev and ev.state
    if not state then return end
    local game = currentGame or state.game
    local kind = ModernOverlay.isSupported(state)
    if kind == "summary" then
      attachSummaryControls(state, game)
    elseif kind == "bag" then
      attachBagControls(state, game)
    elseif kind == "shop" then
      attachShopControls(state, game)
    elseif kind == "dialogue" then
      attachDialogueControls(state, game)
    elseif kind == "load_report" then
      attachLoadReportControls(state, game)
    elseif kind == "town_map" then
      attachTownMapControls(state, game)
    elseif kind == "pokegear" then
      attachPokegearControls(state, game)
    elseif kind == "pokenav" then
      attachPokenavControls(state, game)
    elseif kind == "pokedex" then
      attachPokedexControls(state, game)
    elseif kind == "naming" then
      attachNamingControls(state, game)
    elseif kind == "storage" then
      attachStorageControls(state, game)
    elseif kind == "player_pc" then
      attachPlayerPcControls(state, game)
    elseif kind == "pc_hub" then
      attachPcHubControls(state, game)
    elseif kind == "league_pc" then
      attachLeaguePcControls(state)
    elseif kind == "save" then
      attachSaveControls(state, game)
    elseif kind == "start_menu" then
      attachStartMenuControls(state, game)
    elseif kind == "main_menu" then
      attachMainMenuControls(state, game)
    elseif kind == "choice" or state.onChoose or state.labels then
      attachChoiceBoxControls(state)
    elseif state.qty and state.max then
      attachQuantityControls(state, game)
    elseif state.titleUiBox and state.save and state.title then
      attachContinueControls(state, game)
    end
  end)

  -- 5. QWERTY grid override for native naming hooks
  mod.hooks:wrap("ui.naming.grid", function(nextFn, base, opts)
    local NamingRenderer = require("mods.omni_ui.renderers.NamingRenderer")
    local isLower = opts and opts.lower
    local page = isLower and NamingRenderer.PAGES.lower or NamingRenderer.PAGES.upper
    local res = {}
    for _, r in ipairs(page.rows) do
      res[#res + 1] = r
    end
    res[#res + 1] = { isLower and "UPPER CASE" or "lower case", "123", " ", "DEL", "ED" }
    return res
  end, 100)

  -- 5b. Suppress native Gen 3 naming screen rendering & handle input via modern QWERTY controller
  local okNaming, Naming = pcall(require, "src.ui.game3.naming")
  if okNaming and Naming then
    local origNamingDraw = Naming.draw
    Naming.draw = function(...)
      if mod.options:get("overlay") ~= false then
        return
      end
      if origNamingDraw then
        return origNamingDraw(...)
      end
    end

    local origNamingHandleInput = Naming.handleInput
    Naming.handleInput = function(input)
      if mod.options:get("overlay") ~= false and Naming.openFlag and Naming._state then
        local st = Naming._state
        local NamingRenderer = require("mods.omni_ui.renderers.NamingRenderer")
        NamingRenderer.attachControls(st, currentGame)
        if NamingRenderer.handleInput(st, input, currentGame) then
          return
        end
      end
      if origNamingHandleInput then
        return origNamingHandleInput(input)
      end
    end

    local origNamingUpdate = Naming.update
    Naming.update = function(dt)
      if mod.options:get("overlay") ~= false and Naming.openFlag and Naming._state then
        local st = Naming._state
        st.anim = (st.anim or 0) + 1
      end
      if origNamingUpdate then
        return origNamingUpdate(dt)
      end
    end
  end

  -- 5d. Handle Gen 3 BoxStorageUI input via StorageController and suppress native drawing
  local okStorageUI, BoxStorageUI = pcall(require, "src.ui.game3.box_storage_ui")
  if okStorageUI and BoxStorageUI then
    local origStorageDraw = BoxStorageUI.draw
    BoxStorageUI.draw = function(...)
      if mod.options:get("overlay") ~= false then
        return
      end
      if origStorageDraw then
        return origStorageDraw(...)
      end
    end

    local origStorageHandleInput = BoxStorageUI.handleInput
    if not BoxStorageUI.__omniHookedInput then
      BoxStorageUI.__omniHookedInput = true
      BoxStorageUI.handleInput = function(input)
        if mod.options:get("overlay") ~= false and BoxStorageUI.open then
          local StorageController = require("mods.omni_ui.core.StorageController")
          if not BoxStorageUI.__storageController then
            BoxStorageUI.__storageController = StorageController.new(currentGame or ModernOverlay.currentGame, {
              mode = BoxStorageUI.mode or "browse",
              subMode = BoxStorageUI.subMode or "move",
            })
          end
          local ctrl = BoxStorageUI.__storageController
          if ctrl and input then
            local action = ctrl:handleInput(input)
            if action == "close" then
              BoxStorageUI.__storageController = nil
              BoxStorageUI.close()
              return
            elseif action == true then
              return
            end
          end
        end
        if origStorageHandleInput then
          return origStorageHandleInput(input)
        end
      end
    end
  end

  -- 5e. Handle Gen 3 ItemPc input via PlayerPcController and suppress native drawing
  local okItemPc, ItemPc = pcall(require, "src.ui.game3.item_pc")
  if okItemPc and ItemPc then
    local origItemPcDraw = ItemPc.draw
    ItemPc.draw = function(...)
      if mod.options:get("overlay") ~= false then
        if ItemPc._fx then
          if ItemPc._fx.cb then
            local cb = ItemPc._fx.cb
            ItemPc._fx = nil
            cb()
            return
          end
          ItemPc._fx = nil
        end
        return
      end
      if origItemPcDraw then
        return origItemPcDraw(...)
      end
    end

    local function closeItemPc()
      if ItemPc._fx and ItemPc._fx.cb then
        local cb = ItemPc._fx.cb
        ItemPc._fx = nil
        cb()
        return
      end
      ItemPc.__playerPcController = nil
      ItemPc.open = false
      ItemPc._fx = nil
      local g3Stack = package.loaded["src.ui.game3.stack"] or require("src.ui.game3.stack")
      if g3Stack and g3Stack.has and g3Stack.has("item_pc") then
        g3Stack.pop("item_pc")
      end
      if ItemPc._onClose then
        local cb = ItemPc._onClose
        ItemPc._onClose = nil
        cb()
      end
      local g = currentGame or ModernOverlay.currentGame
      if g and g.data then
        pcall(function() require("src.core.Sound").play(g.data, "Turn_Off_PC") end)
      end
    end

    local origItemPcHandleInput = ItemPc.handleInput
    if not ItemPc.__omniHookedInput then
      ItemPc.__omniHookedInput = true
      ItemPc.handleInput = function(input)
        if mod.options:get("overlay") ~= false and ItemPc.open then
          if ItemPc._fx then
            if ItemPc._fx.cb then
              local cb = ItemPc._fx.cb
              ItemPc._fx = nil
              cb()
              return
            end
            ItemPc._fx = nil
          end
          local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")
          if not ItemPc.__playerPcController then
            ItemPc.__playerPcController = PlayerPcController.new(currentGame or ModernOverlay.currentGame, {
              tab = (ItemPc.kind == "pc_item_deposit" or ItemPc.mode == "deposit") and "bag" or "pc",
            })
          end
          local ctrl = ItemPc.__playerPcController
          if ctrl and input then
            local action = ctrl:handleInput(input)
            if action == "close" then
              closeItemPc()
              return
            elseif action == true then
              return
            end
          end
        end
        if origItemPcHandleInput then
          local okInput, errInput = pcall(origItemPcHandleInput, input)
          if ItemPc._fx and ItemPc._fx.cb then
            local cb = ItemPc._fx.cb
            ItemPc._fx = nil
            cb()
            return
          end
          if not okInput and errInput and errInput:find("attempt to index a nil value") then
            ItemPc.mode = "list"
            return
          end
          return
        end
      end
    end
  end

  local okRseItemStorage, RseItemStorage = pcall(require, "src.ui.game3.rse.item_storage")
  if okRseItemStorage and RseItemStorage then
    local origRseItemStorageDraw = RseItemStorage.draw
    RseItemStorage.draw = function(...)
      if mod.options:get("overlay") ~= false then
        return
      end
      if origRseItemStorageDraw then return origRseItemStorageDraw(...) end
    end
  end

  -- 5c. Suppress native Gen 3 pause sub-menu rendering when modern overlay is active
  ModernOverlay.options = mod.options
  ModernOverlay.ensureGen3Hooks(mod.options)

  -- 4. Suppress native screens and retro blank/fade overlays when modern overlay is active
  mod.hooks:wrap("screen.render_visible", function(next, state)
    if mod.options:get("overlay") ~= false and currentGame and currentGame.stack then
      local id = state and state.screenId
      if id == "Gen2OakSpeech" or id == "OakSpeech" or (state and (state.isOakSpeech or state.marillPic ~= nil or state.shrink ~= nil)) then
        return false
      end

      local isTransitionBlank = (id == "MenuFade" or id == "Gen2MenuFade" or id == "BlankScreen" or id == "Gen2BlankScreen" or id == "IntroFade"
        or (state and state.white ~= nil and state.kind ~= nil)
        or (state and state.menuFade ~= nil)
        or (state and state.left ~= nil and state.onDone ~= nil and not state.items and not state.dialogue and not state.cards and not state.glyphs))
      if isTransitionBlank then
        -- Suppress retro hardware-emulated white sheets and delay blanks so overworld stays pristine
        return false
      end

      local kind = ModernOverlay.isSupported(state)
      if kind and kind ~= "battle" then
        -- Suppress the native 160x144 rendering of modern menu states (party, summary, bag, pokedex, etc.)
        -- NOTE: battle is an overlay HUD so the native battle stage, sprites, and animations must continue rendering!
        -- NOTE: overworld and non-menu background states continue rendering so they are visible behind the translucent darkening layer!
        return false
      end
    end
    return next(state)
  end, 100)

  -- Instant transition acceleration for modern overlay (eliminates retro white frame stalls)
  mod.events:on("screen.pushed", function(ev)
    local state = ev and ev.state
    if state and mod.options:get("overlay") ~= false then
      local id = state.screenId
      if id == "MenuFade" or id == "Gen2MenuFade" or (state.white ~= nil and state.kind ~= nil) then
        if state.left and state.left > 1 then
          state.left = 1
        end
      elseif id == "BlankScreen" or id == "Gen2BlankScreen" then
        if state.left and state.left > 1 then
          state.left = 1
        end
      end
    end
  end)

  -- 5. Suppress classic low-res battle HUD and text box so modern OmniUI overlay renders cleanly over sprites
  mod.hooks:wrap("battle.status_hud_visible", function(next, battle)
    if mod.options:get("overlay") ~= false then
      return false
    end
    return next(battle)
  end, 50)

  mod.hooks:wrap("battle.bottom_ui_visible", function(next, battle)
    if mod.options:get("overlay") ~= false then
      return false
    end
    return next(battle)
  end, 50)

  -- Enable 4-way 2x2 D-Pad grid navigation for battle move selection (Up/Down/Left/Right)
  mod.hooks:wrap("battle.move_grid_navigation", function(next, battle)
    if mod.options:get("overlay") ~= false then
      return true
    end
    return next(battle)
  end, 50)

  -- Suppress classic solid paper background fill so modern dark arena & battle pedestals show through cleanly
  if not isGen3 then
    local okBS, BattleState = pcall(require, "src.battle.BattleState")
    if okBS and BattleState and BattleState.drawZonePass then
      local origDrawZonePass = BattleState.drawZonePass
      BattleState.drawZonePass = function(self, src, sx, sy)
        if mod.options:get("overlay") ~= false then
          return
        end
        return origDrawZonePass(self, src, sx, sy)
      end
    end

    local okG2BS, Gen2BattleState = pcall(require, "src.ui.gen2.BattleState")
    if okG2BS and Gen2BattleState then
      if Gen2BattleState.drawEnemyHud then
        local origG2DrawEnemyHud = Gen2BattleState.drawEnemyHud
        Gen2BattleState.drawEnemyHud = function(self)
          if mod.options:get("overlay") ~= false then
            return
          end
          return origG2DrawEnemyHud(self)
        end
      end
      if Gen2BattleState.drawPlayerHud then
        local origG2DrawPlayerHud = Gen2BattleState.drawPlayerHud
        Gen2BattleState.drawPlayerHud = function(self)
          if mod.options:get("overlay") ~= false then
            return
          end
          return origG2DrawPlayerHud(self)
        end
      end
      if Gen2BattleState.drawBottom then
        local origG2DrawBottom = Gen2BattleState.drawBottom
        Gen2BattleState.drawBottom = function(self, ox)
          if mod.options:get("overlay") ~= false then
            return
          end
          return origG2DrawBottom(self, ox)
        end
      end
      if Gen2BattleState.drawPanel then
        local origG2DrawPanel = Gen2BattleState.drawPanel
        Gen2BattleState.drawPanel = function(self)
          if mod.options:get("overlay") ~= false then
            if not Gen2BattleState.hasBattleSides(self) then return end
            self:drawHud()
            return
          end
          return origG2DrawPanel(self)
        end
      end
      if Gen2BattleState.drawWidescreen then
        local origG2DrawWidescreen = Gen2BattleState.drawWidescreen
        local Chrome = require("src.ui.gen2.Chrome")
        Gen2BattleState.drawWidescreen = function(self, winW, winH)
          if mod.options:get("overlay") ~= false then
            if love and love.graphics and love.graphics.clear then
              love.graphics.clear(0, 0, 0, 0)
            end
            local scale = self:battlePanelScale(winW, winH) or Chrome.fitScale(winW, winH)
            local ox, oy = Chrome.fitOrigin(winW, winH, scale)
            local G = love.graphics
            G.push("all")
            Chrome.clipTo(ox, oy, Chrome.SCREEN_W * 8 * scale, Chrome.SCREEN_H * 8 * scale)
            G.translate(ox, oy)
            G.scale(scale, scale)
            self:drawScene()
            G.pop()
            return
          end
          return origG2DrawWidescreen(self, winW, winH)
        end
      end
    end

    local okBAV, BattleAnimView = pcall(require, "src.ui.gen2.BattleAnimView")
    if okBAV and BattleAnimView and BattleAnimView.fillBackground then
      local origFillBg = BattleAnimView.fillBackground
      BattleAnimView.fillBackground = function(self, palByte)
        if mod.options:get("overlay") ~= false then
          return
        end
        return origFillBg(self, palByte)
      end
    end

    local okR, Renderer = pcall(require, "src.render.Renderer")
    if okR and Renderer and Renderer.beginFrame then
      local origBeginFrame = Renderer.beginFrame
      Renderer.beginFrame = function(self, transparent)
        if mod.options:get("overlay") ~= false and currentGame and currentGame.stack then
          local states = currentGame.stack.states or {}
          local theme = Theme.get()
          local isDark = not (theme.isLight or (theme.bg and (theme.bg[1] + theme.bg[2] + theme.bg[3]) / 3 > 0.7))
          for _, s in ipairs(states) do
            if ModernOverlay.isSupported(s) == "battle" or (isDark and (s.isOakSpeech or s.steps or s.picSlide ~= nil or (s.speech and s.speech.steps))) then
              transparent = true
              break
            end
          end
        end
        return origBeginFrame(self, transparent)
      end
    end

    local okOak, OakSpeech = pcall(require, "src.ui.OakSpeech")
    if okOak and OakSpeech and OakSpeech.draw then
      local origOakDraw = OakSpeech.draw
      OakSpeech.draw = function(self)
        if mod.options:get("overlay") ~= false then
          local theme = Theme.get()
          local isDark = not (theme.isLight or (theme.bg and (theme.bg[1] + theme.bg[2] + theme.bg[3]) / 3 > 0.7))
          if isDark then
            love.graphics.setColor(0, 0, 0, 0)
            love.graphics.rectangle("fill", 0, 0, 160, 144)
            love.graphics.setColor(1, 1, 1, 1)
            local revealBgp = OakSpeech.revealBgp(self.picReveal)
            if revealBgp then
              require("src.render.PaletteFX").setShadeMap(
                require("src.render.Transition").shadeMapFor(revealBgp))
            end
            if self.fadeLevel then
              local PF = require("src.render.PaletteFX")
              local Transition = require("src.render.Transition")
              PF.setShadeMap(Transition.shadeMapForLevel(self.fadeLevel))
              local shrinkBgp = (OakSpeech and OakSpeech.SHRINK_FADE_BGP) or { 0x90, 0x40, 0x00 }
              local shrinkObp = (OakSpeech and OakSpeech.SHRINK_FADE_OBP0) or { 0x80, 0x40, 0x00 }
              local i = math.min(#shrinkBgp, self.fadeLevel)
              PF.setShadeMap(Transition.shadeMapFor(shrinkBgp[i]))
              PF.setFadeObp(Transition.shadeMapFor(shrinkObp[i]))
            end
            if self.pic then
              local w, h = self.pic:getDimensions()
              local x = 48 + math.floor((8 - w / 8) / 2) * 8 + (self.picSlide or 0)
              local y = 32 + (7 - h / 8) * 8
              local reveal = self.picReveal
              local off = 0
              if reveal and reveal.kind == "wipe" then
                off = math.floor((160 - x) * (1 - math.min(1, reveal.t / reveal.dur)))
              end
              if self.picFlip then
                love.graphics.draw(self.pic, x + off + w, y, 0, -1, 1)
              else
                love.graphics.draw(self.pic, x + off, y)
              end
              if self.picTrueColor and not revealBgp and not self.bgpFade then
                require("src.render.PaletteFX").markTrueColor(x + off, y, w, h)
              end
              love.graphics.setColor(1, 1, 1, 1)
            end
            if self.walkVisible and self.walkSheet then
              self.walkQuad = self.walkQuad
                or love.graphics.newQuad(0, 0, 16, 16, self.walkSheet:getDimensions())
              local img, redraw = self:walkImage()
              love.graphics.draw(img, self.walkQuad, 64, 60)
              if redraw then
                require("src.render.PaletteFX").markUiSpriteRedraw(img, self.walkQuad, 64, 60)
              end
            end
            if self.shrinkText then
              local r = self.game and self.game.renderer
              if r and r.setUIAnchor then
                r:setUIAnchor(0, 12 * 8, 20 * 8, 6 * 8, "bottom")
              end
            end
            return
          end
        end
        return origOakDraw(self)
      end
    end

    local okG3UiPass, G3UiPass = pcall(require, "src.ui.game3.ui_pass")
    if okG3UiPass and G3UiPass and G3UiPass.drawUi then
      local origG3DrawUi = G3UiPass.drawUi
      G3UiPass.drawUi = function(...)
        if mod.options:get("overlay") ~= false then
          local activeKind = ModernOverlay.getActiveScreen(currentGame)
          if activeKind then
            local okRen, Renderer = pcall(require, "src.render.Renderer")
            if okRen and Renderer then Renderer.screenVeil = nil end
            local MapNamePopup = package.loaded["src.ui.game3.map_name_popup"]
            if MapNamePopup and MapNamePopup.isActive and MapNamePopup.isActive() and MapNamePopup.draw then
              pcall(MapNamePopup.draw)
            end
            local Fade = package.loaded["src.ui.game3.fade"]
            if Fade and Fade.active and (Fade.mode == 2 or Fade.mode == 3) then
              Fade.clear()
            elseif Fade and Fade.draw then
              pcall(Fade.draw)
            end
            local BattleTransition = package.loaded["src.core.game3.battle_transition"]
            if BattleTransition and BattleTransition.draw then pcall(BattleTransition.draw) end
            return
          end
        end
        return origG3DrawUi(...)
      end
    end

    local okG3Boot, G3Boot = pcall(require, "src.ui.game3.boot")
    if okG3Boot and G3Boot and G3Boot.draw then
      local origBootDraw = G3Boot.draw
      G3Boot.draw = function(state, ...)
        if mod.options:get("overlay") ~= false and state and (state.phase == G3Boot.PHASE.MENU or state.phase == "menu") then
          love.graphics.clear(0.05, 0.05, 0.12, 1)
          return
        end
        return origBootDraw(state, ...)
      end
    end

    local okG3BM, G3BM = pcall(require, "src.ui.game3.boot_modules")
    if okG3BM and G3BM and G3BM.draw then
      local origBMDraw = G3BM.draw
      G3BM.draw = function(Boot, state, ...)
        if mod.options:get("overlay") ~= false and state and (state.phase == Boot.PHASE.MENU or state.phase == "menu") then
          love.graphics.clear(0.05, 0.05, 0.12, 1)
          return
        end
        return origBMDraw(Boot, state, ...)
      end
    end

    local wrapBirchDraw = function(origDraw)
      return function(self, ...)
        if mod.options:get("overlay") ~= false then
          local oldShow = self.showDialogue
          local oldGender = self.genderMenu
          local oldYesNo = self.yesNo
          local oldName = self.nameMenu
          self.showDialogue = false
          self.genderMenu = nil
          self.yesNo = nil
          self.nameMenu = nil
          local ok, err = pcall(origDraw, self, ...)
          self.showDialogue = oldShow
          self.genderMenu = oldGender
          self.yesNo = oldYesNo
          self.nameMenu = oldName
          if not ok then error(err, 2) end
          return
        end
        return origDraw(self, ...)
      end
    end

    local okBirchRse, BirchRse = pcall(require, "src.ui.game3.rse.birch_speech")
    if okBirchRse and BirchRse and BirchRse.draw then
      BirchRse.draw = wrapBirchDraw(BirchRse.draw)
    end

    local okBirchRs, BirchRs = pcall(require, "src.ui.game3.rs.birch_speech")
    if okBirchRs and BirchRs and BirchRs.draw then
      BirchRs.draw = wrapBirchDraw(BirchRs.draw)
    end

    local okNewGame, NewGameScene = pcall(require, "src.ui.game3.new_game_scene")
    if okNewGame and NewGameScene and NewGameScene.drawBg0Text then
      local origDrawBg0 = NewGameScene.drawBg0Text
      NewGameScene.drawBg0Text = function(self, ...)
        if mod.options:get("overlay") ~= false then
          local oldDialog = self.win and self.win.dialog
          local oldMenu = self.win and self.win.menu
          if self.win then
            self.win.dialog = false
            self.win.menu = nil
          end
          local ok, err = pcall(origDrawBg0, self, ...)
          if self.win then
            self.win.dialog = oldDialog
            self.win.menu = oldMenu
          end
          if not ok then error(err, 2) end
          return
        end
        return origDrawBg0(self, ...)
      end
    end
  end

  local getOakSpeechState = function(game)
    if not (game and game.stack and game.stack.states) then return nil end
    for _, s in ipairs(game.stack.states) do
      if s and (s.isOakSpeech or s.steps or s.picSlide ~= nil or (s.speech and s.speech.steps) or s.screenId == "Gen2OakSpeech" or s.screenId == "OakSpeech" or s.marillPic ~= nil or s.shrink ~= nil or s.picReveal ~= nil or s.runStep ~= nil) then
        return s.speech or s
      end
    end
    return nil
  end

  -- 6. Clear 160x144 UI canvas on render.compose to prevent ghosting on full-page menus
  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    if mod.options:get("overlay") ~= false and currentGame and currentGame.stack then
      local states = currentGame.stack.states or {}
      local hasFullScreenModern = false
      local hasOverlayModal = false
      local isBattleActive = false
      for _, s in ipairs(states) do
        local k = ModernOverlay.isSupported(s)
        if k == "battle" then
          isBattleActive = true
        elseif k == "start_menu" or k == "save" or k == "dialogue" or k == "menu" or k == "dexnav" then
          hasOverlayModal = true
        elseif k then
          hasFullScreenModern = true
        end
      end

      -- Gen 1/2: themed arena and pedestals. Gen 3 keeps its own background and stage.
      if isBattleActive then
        local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
        if BattleRenderer.usesThemedStage(currentGame) then
          local theme = Theme.get()
          return BattleRenderer.composeBattleScene(renderer, ctx, theme, currentGame)
        end
      end

      -- If Oak speech / intro is active, composite themed intro backdrop & pedestal
      local oakState = getOakSpeechState(currentGame)
      if oakState then
        local theme = Theme.get()
        local IntroRenderer = require("mods.omni_ui.renderers.IntroRenderer")
        return IntroRenderer.composeIntroScene(renderer, ctx, theme, oakState, currentGame)
      end
    end
    return handled
  end, 100)

  -- 6. Hook into render.hud to paint high-resolution modern UI in window/safe space
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    currentGame = game
    if ModernOverlay.ensureGen3Hooks then
      ModernOverlay.ensureGen3Hooks(mod.options)
    end
    -- Also ensure active screen has controls attached if pushed before hook (Gen 1-3)
    local activeKind, activeState = ModernOverlay.getActiveScreen(game)
    if activeState then
      ModernOverlay.attachControls(activeState, game)
    elseif game and game.stack then
      local topState = game.stack:top()
      if topState then
        ModernOverlay.attachControls(topState, game)
      end
    end

    local initDepth = love and love.graphics and love.graphics.getStackDepth and love.graphics.getStackDepth() or 0
    next(game, viewport)
    if mod.options:get("overlay") ~= false then
      ModernOverlay.draw(game, viewport)
    end
    if love and love.graphics and love.graphics.getStackDepth then
      while love.graphics.getStackDepth() > initDepth do
        love.graphics.pop()
      end
    end
  end, 100)

  -- 7. Export public API (v1 + v2)
  for k, v in pairs(PublicApi) do
    mod.exports[k] = v
  end

  -- Backwards-compatibility alias: enable legacy mods searching for gen1_modern_ui
  if mod.loader and mod.loader.exports then
    mod.loader.exports["gen1_modern_ui"] = mod.exports
  end
  package.loaded["gen1_modern_ui"] = mod.exports

  -- 8. Option change listener for instant live theme hot-swaps
  mod.events:on("mod.options_changed", function(ev)
    if ev and (not ev.mod or ev.mod == "omni_ui") and ev.key == "theme" then
      if ev.value and Theme.REGISTRY[ev.value] and ev.value ~= Theme.currentThemeId then
        Theme.setTheme(ev.value)
      end
    end
  end)

  mod.events:on("options.changed", function(key, val)
    local targetKey = (type(key) == "table" and key.key) or key
    local targetVal = (type(key) == "table" and key.value) or val
    if targetKey == "theme" and targetVal and Theme.REGISTRY[targetVal] and targetVal ~= Theme.currentThemeId then
      Theme.setTheme(targetVal)
    end
  end)

  -- 9. Hotkey for on-the-fly live theme swapping (F6 = Prev Theme, F7 = Next Theme)
  mod.hooks:wrap("input.key", function(nextFn, game, ev)
    if ev and ev.phase == "pressed" and mod.options:get("overlay") ~= false then
      local key = ev.key
      if key == "f7" then
        local nextId = Theme.cycleTheme(1)
        if nextId then
          pcall(function()
            if mod.options and mod.options.set then
              mod.options:set("theme", nextId)
            end
          end)
          if game and game.data then
            pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end)
          end
        end
        return true
      elseif key == "f6" then
        local prevId = Theme.cycleTheme(-1)
        if prevId then
          pcall(function()
            if mod.options and mod.options.set then
              mod.options:set("theme", prevId)
            end
          end)
          if game and game.data then
            pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end)
          end
        end
        return true
      end
    end
    return nextFn(game, ev)
  end, 50)

  return mod
end
