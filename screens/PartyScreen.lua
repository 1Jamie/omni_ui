-- OmniUI Modern Party Screen
-- Full 1:1 functional parity with native Gen 1-3 party menus + Gen 3 modern presentation.

local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
local Font = require("src.render.Font")
local Screens = require("src.ui.Screens")
local Strings = require("src.core.Strings")
local Theme = require("src.ui.Theme")
local LevelDisplay = require("src.ui.LevelDisplay")
local Status = require("src.battle.Status")
local HudTiles = require("src.render.HudTiles")
local PaletteFX = require("src.render.PaletteFX")
local Runtime = require("src.mods.Runtime")

local PartyScreen = { isMenu = true, isOpaque = true }
PartyScreen.__index = PartyScreen

function PartyScreen.new(game, opts)
  opts = opts or {}
  local self = setmetatable({}, PartyScreen)
  self.game = game
  self.opts = opts
  self.battle = opts.battle
  self.onSwitch = opts.onSwitch
  self.onCancel = opts.onCancel
  self.forceSwitch = opts.forceSwitch
  self.pickOnly = opts.pickOnly
  self.tmhm = opts.tmhm
  self.evoStone = opts.evoStone
  self.keepOpen = opts.keepOpen

  self.party = opts.party or (game.save and game.save.party) or {}
  self.index = opts.initialIndex or 1
  self.subIndex = 1
  self.submenu = nil
  self.swapFrom = nil
  self.blink = 0

  self.adapter = AdapterResolver.resolve(game)
  return self
end

function PartyScreen:sgbPalettes(game)
  local P = require("src.render.PaletteFX")
  local base = P.pal(game.data, "GREENBAR")
  if not base then return nil end
  local zones = { P.whole(base) }
  local mew = P.pal(game.data, "MEWMON")
  if mew then zones[#zones + 1] = P.zone(mew, 1, 0, 2, 11) end
  if not self.tmhm then
    local party = self.party or (game.save and game.save.party) or {}
    for i, mon in ipairs(party) do
      local hp = mon.hp
      local bar = P.pal(game.data, P.barPalName(hp, (mon.stats and mon.stats.hp) or mon.hp or 1))
      if bar then
        zones[#zones + 1] = P.zone(bar, 6, i * 2 - 1, 12, i * 2 - 1)
      end
    end
  end
  return zones
end

function PartyScreen:bottomMessage()
  local text
  if self.message then
    text = self.message
  elseif self.swapFrom then
    text = (self.game.data and self.game.data.text and self.game.data.text._PartyMenuSwapMonText)
      or Strings("Move POKéMON\nwhere?")
  elseif self.tmhm then
    text = (self.game.data and self.game.data.text and self.game.data.text._PartyMenuUseTMText)
      or Strings("Use TM on which\nPOKéMON?")
  elseif self.evoStone then
    text = Strings("Use item on which\nPOKéMON?")
  elseif self.forceSwitch then
    text = (self.game.data and self.game.data.text and self.game.data.text._PartyMenuBattleText)
      or Strings("Bring out which\nPOKéMON?")
  else
    text = (self.game.data and self.game.data.text and self.game.data.text._PartyMenuNormalText)
      or Strings("Choose a POKéMON.")
  end
  return require("src.render.TextBox").strip(text)
end

function PartyScreen:update(dt)
  self.party = self.opts.party or (self.game.save and self.game.save.party) or {}
  self.maxSlots = #self.party
  self.blink = (self.blink or 0) + 1

  local input = self.game.input
  if not input then return end

  if self.game.data and (input:wasPressed("a") or input:wasPressed("b")) then
    local Sound = package.loaded["src.core.Sound"] or require("src.core.Sound")
    if Sound and Sound.play then
      Sound.play(self.game.data, "Press_AB")
    end
  end

  if self.submenu then
    local n = #self.subItems
    if input:wasPressed("up") then
      self.subIndex = self.subIndex > 1 and self.subIndex - 1 or n
    elseif input:wasPressed("down") then
      self.subIndex = self.subIndex < n and self.subIndex + 1 or 1
    elseif input:wasPressed("b") then
      self.submenu = nil
    elseif input:wasPressed("a") then
      self:onSubmenuSelect()
    end
    return
  end

  local total = self.maxSlots + 1 -- 1..N mons + Cancel button
  if input:wasPressed("up") then
    self.index = (self.index > 1) and (self.index - 1) or total
  elseif input:wasPressed("down") then
    self.index = (self.index < total) and (self.index + 1) or 1
  elseif input:wasPressed("b") then
    self:onCancelPress()
  elseif input:wasPressed("a") then
    self:onConfirmPress()
  end
end

function PartyScreen:onCancelPress()
  if self.swapFrom then
    self.swapFrom = nil
    return
  end
  self:close()
  if self.onCancel then
    self.onCancel()
  end
end

function PartyScreen:onConfirmPress()
  if self.index > self.maxSlots then
    self:onCancelPress()
    return
  end

  local mon = self.party[self.index]
  if not mon then return end

  -- Swap mode active
  if self.swapFrom then
    if self.swapFrom ~= self.index then
      local rawParty = self.game.save and self.game.save.party
      if rawParty and rawParty[self.swapFrom] and rawParty[self.index] then
        local tmp = rawParty[self.swapFrom]
        rawParty[self.swapFrom] = rawParty[self.index]
        rawParty[self.index] = tmp
      end
      if self.game.data then
        require("src.core.Sound").play(self.game.data, "Swap")
      end
    end
    self.swapFrom = nil
    return
  end

  -- Battle switch / item target pick
  if self.onSwitch then
    if self.battle and not self.forceSwitch and not self.pickOnly then
      self:openSubmenu(mon)
      return
    end
    if self.keepOpen then
      self.onSwitch(mon, self)
    else
      self.onSwitch(mon)
      self:close()
    end
    return
  end

  -- Default: open action submenu
  self:openSubmenu(mon)
end

function PartyScreen:openSubmenu(mon)
  self.submenu = true
  self.subIndex = 1
  local items = {}
  local ow = self.game.overworld

  if self.battle and self.onSwitch then
    items = {
      { label = Strings("SWITCH"), action = "battle_switch" },
      { label = Strings("STATS"), action = "stats" },
      { label = Strings("CANCEL"), action = "cancel" },
    }
  else
    -- Field moves first
    if not self.battle and ow then
      for _, mv in ipairs(mon.moves or {}) do
        local id = (type(mv) == "table" and mv.id) or mv
        if id == "FLY" then
          items[#items + 1] = { label = Strings("FLY"), action = "fly" }
        elseif id == "FLASH" then
          items[#items + 1] = { label = Strings("FLASH"), action = "flash" }
        elseif id == "CUT" then
          items[#items + 1] = { label = Strings("CUT"), action = "cut" }
        elseif id == "SURF" then
          items[#items + 1] = { label = Strings("SURF"), action = "surf" }
        elseif id == "STRENGTH" then
          items[#items + 1] = { label = Strings("STRENGTH"), action = "strength" }
        elseif id == "SOFTBOILED" then
          items[#items + 1] = { label = Strings("SOFTBOILED"), action = "softboiled" }
        elseif id == "DIG" or id == "TELEPORT" then
          items[#items + 1] = { label = Strings(id), action = "escape", move = id }
        end
      end
    end

    items[#items + 1] = { label = Strings("STATS"), action = "stats" }
    items[#items + 1] = { label = Strings("SWITCH"), action = "switch" }
    items[#items + 1] = { label = Strings("CANCEL"), action = "cancel" }
  end

  -- Mod hook wrapping
  local function sameItems(_, itms) return itms end
  local ctx = { battle = self.battle, overworld = ow }
  local hooked = Runtime.call("ui.party.submenu", sameItems, self.game, items, mon, ctx)
  if type(hooked) == "table" then items = hooked end
  self.subItems = items
end

function PartyScreen:onSubmenuSelect()
  local mon = self.party[self.index]
  local entry = self.subItems and self.subItems[self.subIndex]
  if not entry then self.submenu = nil return end

  local action = entry.action
  if not action and entry.onSelect then
    entry.onSelect(mon, self.game)
  elseif action == "stats" then
    self.submenu = nil
    Screens.push(self.game, "SummaryMenu", mon)
    return
  elseif action == "switch" then
    self.swapFrom = self.index
    self.submenu = nil
  elseif action == "battle_switch" then
    if self.keepOpen then
      self.onSwitch(mon, self)
    else
      self.onSwitch(mon)
      self:close()
    end
    return
  elseif action == "cancel" then
    self.submenu = nil
  elseif action == "cut" then
    local ow = self.game.overworld
    if ow and ow.useCutFieldMove then
      local reason = ow:useCutFieldMove()
      if reason == "ok" then
        self:close()
        local fx, fy = ow.player:facingCell()
        ow:tryCut(fx, fy)
        return
      end
    end
    self.submenu = nil
  elseif action == "fly" then
    local ow = self.game.overworld
    self:close()
    Screens.push(self.game, "TownMap", { fly = true, onFly = function(mapId)
      if ow then ow:flyTo(mapId) end
    end })
    return
  elseif action == "surf" or action == "flash" or action == "strength" then
    local ow = self.game.overworld
    if ow and ow.useFieldMove then
      ow:useFieldMove(action:upper(), mon)
      self:close()
      return
    end
    self.submenu = nil
  else
    self.submenu = nil
  end
end

function PartyScreen:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  local party = self.party or (self.game.save and self.game.save.party) or {}
  local PartyMenu = require("src.ui.PartyMenu")
  local barZoned = PaletteFX.shader() ~= nil and PaletteFX.pal(self.game.data, "GREENBAR") ~= nil

  for i, mon in ipairs(party) do
    local def = (self.game.data and self.game.data.pokemon and self.game.data.pokemon[mon.species]) or {}
    local y = (i - 1) * 16

    -- Party Icon
    love.graphics.setColor(1, 1, 1, 1)
    if PartyMenu.drawIcon then
      PartyMenu.drawIcon(self.game, mon, 8, y, i == self.index, self.blink or 0)
    end

    -- Nickname & Level
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(mon.nickname or def.name or mon.species or "POKéMON", 24, y)

    if not LevelDisplay.visible(mon, "party", self.game) then
    elseif (mon.level or 1) < 100 then
      HudTiles.tile(0x6E, 104, y)
      Font.draw(tostring(mon.level or 1), 112, y)
    else
      Font.draw(tostring(mon.level or 1), 104, y)
    end

    -- Learnability or HP bar
    if self.tmhm then
      local can = false
      for _, m in ipairs(def.tmhm or {}) do
        if m == self.tmhm.move then can = true break end
      end
      Font.draw(can and Strings("ABLE") or Strings("NOT ABLE"), can and 120 or 88, y + 8)
    elseif self.evoStone then
      local can = false
      for _, evo in ipairs(def.evolutions or {}) do
        if evo.method == "ITEM" and evo.item == self.evoStone then can = true break end
      end
      Font.draw(can and Strings("ABLE") or Strings("NOT ABLE"), can and 120 or 88, y + 8)
    else
      if (mon.hp or 0) <= 0 then
        Font.draw(Strings("FNT"), 136, y)
      elseif mon.status then
        Font.draw(Status.hudLabelFor(self.game.data and self.game.data.statuses, mon.status), 136, y)
      end

      local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
      love.graphics.setColor(1, 1, 1, 1)
      HudTiles.drawHPBar(self.game.data, 5, (y + 8) / 8, mon, nil, barZoned)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(("%3d/%3d"):format(mon.hp or 0, maxHp), 104, y + 8)
    end

    -- Cursor
    local cursorY = y + 8
    if i == self.index then
      Font.drawCode((self.submenu and Theme.cursorHollow) or Theme.cursor, 0, cursorY)
    elseif i == self.swapFrom then
      Font.drawCode(Theme.cursorHollow, 0, cursorY)
    end
  end

  -- Bottom Message Box
  Font.drawBox(0, 12, 20, 6)
  love.graphics.setColor(0, 0, 0, 1)
  local ly = 112
  for line in (self:bottomMessage() .. "\n"):gmatch("([^\n]*)\n") do
    Font.draw(line, 8, ly)
    ly = ly + 16
  end

  -- Action Submenu Box
  if self.submenu and self.subItems then
    local n = #self.subItems
    local lx = 12
    local top = n > 3 and math.max(0, 16 - n * 2) or 11
    Font.drawBox(lx - 1, top, 21 - lx, 18 - top)
    local y0 = (18 - n * 2) * 8
    for si, entry in ipairs(self.subItems) do
      Font.draw(entry.label, (lx + 1) * 8, y0 + (si - 1) * 16)
    end
    Font.drawCode(Theme.cursor, lx * 8, y0 + (self.subIndex - 1) * 16)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function PartyScreen:close()
  if self.game and self.game.stack then
    if self.game.stack:top() == self then
      self.game.stack:pop()
    else
      self.game.stack:pop()
    end
  end
end

return PartyScreen
