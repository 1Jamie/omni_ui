-- OmniUI Gen 1 Adapter (Red / Blue / Yellow)
-- Bridges Gen 1 memory layouts, DVs, field move dispatch, and item usage to normalized models.

local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")
local FieldDefaults = require("src.world.FieldDefaults")

local Gen1Adapter = setmetatable({}, { __index = BaseAdapter })
Gen1Adapter.__index = Gen1Adapter

function Gen1Adapter.new(game)
  local self = BaseAdapter.new(game)
  self.generation = 1
  self.region = "KANTO"
  setmetatable(self, Gen1Adapter)
  return self
end

local GEN1_FIELD_MOVES = {
  CUT = true, FLY = true, SURF = true, STRENGTH = true,
  FLASH = true, DIG = true, TELEPORT = true, SOFTBOILED = true,
}

function Gen1Adapter:normalizeMon(mon, index)
  if not mon then return nil end
  local data = (self.game and self.game.data) or {}
  local speciesId = mon.species or "UNKNOWN"
  local def = data.pokemon and data.pokemon[speciesId]
  local Stats = require("src.pokemon.Stats")
  if def and (not mon.stats or not mon.stats.attack or mon.stats.attack == 0) then
    pcall(Stats.ensure, def, mon)
  end

  local norm = BaseAdapter.normalizeMon(self, mon, index)
  if not norm then return nil end

  if mon.stats then
    norm.stats = mon.stats
    norm.maxHp = mon.stats.hp or mon.maxHp or mon.hp or 1
  end

  -- Field moves detection in Gen 1
  norm.fieldMoves = {}
  for _, move in ipairs(mon.moves or {}) do
    local moveId = (type(move) == "table" and move.id) or move
    if moveId and (GEN1_FIELD_MOVES[moveId:upper()] or (FieldDefaults.isFieldMove and FieldDefaults.isFieldMove(moveId))) then
      norm.fieldMoves[#norm.fieldMoves + 1] = moveId:upper()
    end
  end

  -- Shiny calculation from DVs (Gen 2 backwards compatibility rule)
  local ivs = mon.ivs or mon.dvs or {}
  local atk = ivs.attack or 0
  local def = ivs.defense or 0
  local spd = ivs.speed or 0
  local spc = ivs.special or 0
  if (atk == 2 or atk == 3 or atk == 6 or atk == 7 or atk == 10 or atk == 11 or atk == 14 or atk == 15)
      and def == 10 and spd == 10 and spc == 10 then
    norm.isShiny = true
  end

  return norm
end

function Gen1Adapter:getPlayerInfo()
  local info = BaseAdapter.getPlayerInfo(self)
  local save = self.game and self.game.save
  info.badges = BaseAdapter.resolveBadgeCount(save, self.game)
  info.maxBadges = 8
  info.region = "KANTO"
  info.badgeNames = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }
  return info
end

function Gen1Adapter:getSafariInfo()
  local ow = self.game and self.game.overworld
  local safari = self.game and self.game.save and self.game.save.safari
  if safari and ow and ow.inSafariStepZone and ow:inSafariStepZone() then
    return {
      active = true,
      steps = math.floor(safari.steps or 0),
      maxSteps = 500,
      balls = math.floor(safari.balls or 0),
    }
  end
  return nil
end

local FIXED_DAMAGE_MOVES = {
  SONICBOOM = true, DRAGON_RAGE = true, NIGHT_SHADE = true,
  SUPER_FANG = true, SEISMIC_TOSS = true, PSYWAVE = true,
}

function Gen1Adapter:updateBattleInfo(outCache)
  local cache = outCache or self:getBattleCache()
  local battle, topState = self:getActiveBattle()
  if not battle then
    cache.isActive = false
    return cache
  end

  cache.isActive = true
  local data = self.game and self.game.data
  local TypeChart = nil
  local okType, tc = pcall(require, "src.battle.TypeChart")
  if okType and tc then TypeChart = tc end

  -- 1. Sync Player Battler
  local pBattler = battle.player
  local pMon = pBattler and pBattler.mon
  if pMon then
    local pDef = data and data.pokemon and data.pokemon[pMon.species]
    cache.player.active = true
    cache.player.species = pMon.species or "UNKNOWN"
    cache.player.name = pBattler.name or pMon.nickname or (pDef and pDef.name) or pMon.species
    cache.player.level = pMon.level or 1
    cache.player.maxHp = (pMon.stats and pMon.stats.hp) or pMon.maxHp or pMon.hp or 1
    cache.player.shownHp = math.max(0, math.floor(pBattler.shownHP or pMon.hp or 0))
    cache.player.hp = pMon.hp or 0
    cache.player.shownPx = pBattler.shownPx or 0
    cache.player.hpRatio = cache.player.maxHp > 0 and math.max(0, math.min(1, cache.player.shownHp / cache.player.maxHp)) or 0
    cache.player.status = pBattler.shownStatus or pMon.status
    cache.player.shownStatus = pBattler.shownStatus
    cache.player.types = pBattler.curTypes or (pDef and pDef.types) or { "NORMAL" }
    cache.player.exp = pMon.exp or 0
    cache.player.gender = nil

    -- Party Ball indicators
    local party = (self.game and self.game.save and self.game.save.party) or {}
    for i = 1, 6 do
      local pm = party[i]
      if pm then
        if (pm.hp or 0) <= 0 then
          cache.player.partyBalls[i] = "fainted"
        elseif pm.status then
          cache.player.partyBalls[i] = "status"
        else
          cache.player.partyBalls[i] = "ok"
        end
      else
        cache.player.partyBalls[i] = "empty"
      end
    end
  else
    cache.player.active = false
  end

  -- 2. Sync Enemy Battler
  local eBattler = battle.enemy
  local eMon = eBattler and eBattler.mon
  if eMon then
    local eDef = data and data.pokemon and data.pokemon[eMon.species]
    cache.enemy.active = true
    cache.enemy.species = eMon.species or "UNKNOWN"
    cache.enemy.name = eBattler.name or (eDef and eDef.name) or eMon.species
    cache.enemy.level = eMon.level or 1
    cache.enemy.maxHp = (eMon.stats and eMon.stats.hp) or eMon.maxHp or eMon.hp or 1
    cache.enemy.shownHp = math.max(0, math.floor(eBattler.shownHP or eMon.hp or 0))
    cache.enemy.hp = eMon.hp or 0
    cache.enemy.shownPx = eBattler.shownPx or 0
    cache.enemy.hpRatio = cache.enemy.maxHp > 0 and math.max(0, math.min(1, cache.enemy.shownHp / cache.enemy.maxHp)) or 0
    cache.enemy.status = eBattler.shownStatus or eMon.status
    cache.enemy.shownStatus = eBattler.shownStatus
    cache.enemy.types = eBattler.curTypes or (eDef and eDef.types) or { "NORMAL" }
    
    local save = self.game and self.game.save
    cache.enemy.isCaught = (save and save.pokedex and save.pokedex.owned and save.pokedex.owned[eMon.species] == true) or false
  else
    cache.enemy.active = false
  end

  -- 3. Sync Moves & Authentic Gen 1 Type Effectiveness
  local moves = (pBattler and pBattler.curMoves) or (pMon and pMon.moves) or {}
  local enemyTypes = cache.enemy.types or { "NORMAL" }
  for i = 1, 4 do
    local slot = cache.moves[i]
    local mv = moves[i]
    if mv then
      local mId = (type(mv) == "table" and (mv.id or mv.move or mv[1])) or (type(mv) == "string" and mv) or nil
      local mDef = data and data.moves and data.moves[mId]
      slot.id = mId
      slot.name = (mDef and mDef.name) or mId:gsub("_", " ")
      slot.type = (mDef and mDef.type) or "NORMAL"
      slot.pp = (type(mv) == "table" and mv.pp) or (mDef and mDef.pp) or 0
      slot.maxPP = (mDef and mDef.pp) or slot.pp or 1
      slot.power = (mDef and mDef.power) or 0
      slot.accuracy = (mDef and mDef.accuracy) or 100
      slot.isFixedDamage = FIXED_DAMAGE_MOVES[mId:upper()] == true

      -- Calculate authentic Gen 1 Effectiveness
      if slot.isFixedDamage or slot.power == 0 then
        slot.effectiveness = 1.0
        slot.note = slot.isFixedDamage and "Fixed Damage" or "Status Effect"
      elseif TypeChart and TypeChart.effectiveness then
        if data and data.type_chart and TypeChart.load then
          pcall(TypeChart.load, data)
        end
        local okRaw, raw = pcall(TypeChart.effectiveness, slot.type, enemyTypes)
        if okRaw and raw then
          slot.effectiveness = raw / 10
          if slot.effectiveness >= 2.0 then
            slot.note = "Super Effective!"
          elseif slot.effectiveness == 0 then
            slot.note = "No Effect"
          elseif slot.effectiveness < 1.0 then
            slot.note = "Not Very Effective"
          else
            slot.note = "Standard Effective"
          end
        else
          slot.effectiveness = 1.0
          slot.note = ""
        end
      else
        slot.effectiveness = 1.0
        slot.note = ""
      end
    else
      slot.id = ""
      slot.name = "--"
      slot.type = "NORMAL"
      slot.pp = 0
      slot.maxPP = 0
      slot.power = 0
      slot.accuracy = 0
      slot.effectiveness = 1.0
      slot.isFixedDamage = false
      slot.note = ""
    end
  end

  -- 4. Sync Phase & Selected Indices
  cache.selectedMove = battle.moveIndex or 1
  cache.selectedAction = battle.menuIndex or 1

  if battle.safari then
    cache.actions = {
      { id = "BALL", label = "BALL" },
      { id = "BAIT", label = "BAIT" },
      { id = "ROCK", label = "ROCK" },
      { id = "RUN", label = "RUN" },
    }
  else
    cache.actions = {
      { id = "FIGHT", label = "FIGHT" },
      { id = "POKEMON", label = "POKÉMON" },
      { id = "BAG", label = "BAG" },
      { id = "RUN", label = "RUN" },
    }
  end

  local bPhase = battle.phase
  local isTopStatBox = topState and (topState.isStatBox or (topState.mon and topState.mon.stats and (topState.keepOpen ~= nil or topState.onDone)))
  if bPhase == "moveSelect" or bPhase == "mimicSelect" or bPhase == "moves" or (topState and topState.isBattleMoveMenu) then
    cache.phase = "move_select"
  elseif bPhase == "menu" or (topState and topState.isChoiceBox) then
    cache.phase = "action_select"
  elseif bPhase == "stats_box" or bPhase == "stats-box" or isTopStatBox then
    cache.phase = "stats_box"
  else
    cache.phase = "messages"
  end

  cache.statsBoxMon = (topState and (topState.mon or topState.statsBoxMon)) or battle.statsBoxMon or (bPhase == "stats_box" and battle.player and (battle.player.mon or battle.player))

  -- 5. Extract Visible Combat Dialogue
  local lines = nil
  if topState and topState.visibleText then
    lines = topState:visibleText()
  elseif battle.visibleText then
    lines = battle:visibleText()
  elseif battle.textLines then
    lines = battle.textLines
  end
  if lines and #lines > 0 then
    cache.message = table.concat(lines, "\n")
  elseif cache.phase == "action_select" or cache.phase == "move_select" then
    cache.message = ("What will %s do?"):format(cache.player.name or "POKÉMON")
  else
    cache.message = ""
  end
  cache.waitingForA = (battle.msgWaiting == true or battle.msgPrompt == true or battle.promptWaiting == true or battle.waitingUI == true)
  cache.showPlayerBack = (battle.showPlayerBack == true)
  cache.showEnemyTrainer = (battle.showEnemyTrainer == true)
  cache.playerMonOut = (not battle.showPlayerBack) and (not battle.sendingOut) and (battle.player and battle.player.sprite ~= nil)
  cache.enemyMonOut = (not battle.showEnemyTrainer) and (not battle.enemySendingOut) and (battle.enemy and battle.enemy.sprite ~= nil)

  return cache
end

-- =========================================================================
-- Atomic Storage Layer (Bill's PC & Player PC)
-- =========================================================================

local Boxes = require("src.pokemon.Boxes")

function Gen1Adapter:getBoxCount()
  return Boxes.COUNT or 12
end

function Gen1Adapter:getBoxCapacity()
  return Boxes.CAPACITY or 20
end

function Gen1Adapter:getCurrentBox()
  local save = self.game and self.game.save
  if not save then return 1 end
  Boxes.ensure(save)
  return save.currentBox or 1
end

function Gen1Adapter:setCurrentBox(boxId)
  local save = self.game and self.game.save
  if not save then return false end
  Boxes.ensure(save)
  save.currentBox = math.max(1, math.min(self:getBoxCount(), boxId or 1))
  return true
end

function Gen1Adapter:getBoxName(boxId)
  return ("BOX %d"):format(boxId or self:getCurrentBox())
end

function Gen1Adapter:getBoxData(boxId)
  local save = self.game and self.game.save
  if not save then return {} end
  local boxes = Boxes.ensure(save)
  local bId = boxId or save.currentBox or 1
  local box = boxes[bId] or {}
  local list = {}
  for slot = 1, self:getBoxCapacity() do
    local mon = box[slot]
    list[slot] = mon and self:normalizeMon(mon, slot) or nil
  end
  return list
end

function Gen1Adapter:canDeposit(partySlot, targetBoxId)
  local save = self.game and self.game.save
  if not save then return false, "No active save." end
  local party = save.party or {}
  local mon = party[partySlot]
  if not mon then return false, "No Pokémon in that slot." end

  local boxes = Boxes.ensure(save)
  local bId = targetBoxId or save.currentBox or 1
  local targetBox = boxes[bId] or {}
  local count = 0
  for slot = 1, self:getBoxCapacity() do
    if targetBox[slot] then count = count + 1 end
  end
  if count >= self:getBoxCapacity() then
    return false, ("BOX %d is full."):format(bId)
  end

  local healthy = 0
  for _, m in ipairs(party) do
    if (m.hp or 0) > 0 then healthy = healthy + 1 end
  end
  if (mon.hp or 0) > 0 and healthy <= 1 then
    return false, "You can't deposit your last battle-ready Pokémon!"
  end

  return true
end

function Gen1Adapter:canWithdraw(boxId, boxSlot)
  local save = self.game and self.game.save
  if not save then return false, "No active save." end
  local party = save.party or {}
  if #party >= 6 then
    return false, "Your party is full (6/6)."
  end

  local boxes = Boxes.ensure(save)
  local bId = boxId or save.currentBox or 1
  local box = boxes[bId] or {}
  if not box[boxSlot] then
    return false, "No Pokémon in that storage slot."
  end

  return true
end

function Gen1Adapter:depositMon(partySlot, targetBoxId, targetSlot)
  local ok, reason = self:canDeposit(partySlot, targetBoxId)
  if not ok then return false, reason end

  local save = self.game.save
  local boxes = Boxes.ensure(save)
  local bId = targetBoxId or save.currentBox or 1
  local targetBox = boxes[bId]

  local mon = table.remove(save.party, partySlot)
  if targetSlot and targetSlot >= 1 and targetSlot <= self:getBoxCapacity() and not targetBox[targetSlot] then
    targetBox[targetSlot] = mon
  else
    for s = 1, self:getBoxCapacity() do
      if not targetBox[s] then
        targetBox[s] = mon
        break
      end
    end
  end
  return true, mon
end

function Gen1Adapter:withdrawMon(boxId, boxSlot, targetPartySlot)
  local ok, reason = self:canWithdraw(boxId, boxSlot)
  if not ok then return false, reason end

  local save = self.game.save
  local boxes = Boxes.ensure(save)
  local bId = boxId or save.currentBox or 1
  local box = boxes[bId]

  local mon = box[boxSlot]
  box[boxSlot] = nil
  if targetPartySlot and targetPartySlot <= #save.party + 1 then
    table.insert(save.party, targetPartySlot, mon)
  else
    table.insert(save.party, mon)
  end
  return true, mon
end

function Gen1Adapter:swapSlots(sourceLoc, sourceSlot, targetLoc, targetSlot, sourceBoxId, targetBoxId)
  local save = self.game and self.game.save
  if not save then return false, "No save." end
  local boxes = Boxes.ensure(save)

  if sourceLoc == "party" and targetLoc == "party" then
    if sourceSlot == targetSlot then return true end
    if save.party[sourceSlot] and save.party[targetSlot] then
      save.party[sourceSlot], save.party[targetSlot] = save.party[targetSlot], save.party[sourceSlot]
      return true
    elseif save.party[sourceSlot] and not save.party[targetSlot] then
      local mon = table.remove(save.party, sourceSlot)
      local insertPos = math.min(#save.party + 1, math.max(1, targetSlot))
      table.insert(save.party, insertPos, mon)
      return true
    end
    return false, "Invalid party slots."
  elseif sourceLoc == "box" and targetLoc == "box" then
    local sB = boxes[sourceBoxId or save.currentBox or 1]
    local tB = boxes[targetBoxId or save.currentBox or 1]
    if not sB or not tB then return false, "Invalid box." end

    if sourceSlot == targetSlot and sB == tB then return true end
    sB[sourceSlot], tB[targetSlot] = tB[targetSlot], sB[sourceSlot]
    return true
  elseif sourceLoc == "party" and targetLoc == "box" then
    local tB = boxes[targetBoxId or save.currentBox or 1]
    if not tB then return false, "Invalid box." end
    if tB[targetSlot] then
      -- Swap party mon with existing box mon
      local partyMon = save.party[sourceSlot]
      local boxMon = tB[targetSlot]
      if not partyMon or not boxMon then return false, "Invalid slot." end
      save.party[sourceSlot] = boxMon
      tB[targetSlot] = partyMon
      return true
    else
      return self:depositMon(sourceSlot, targetBoxId, targetSlot)
    end
  elseif sourceLoc == "box" and targetLoc == "party" then
    local sB = boxes[sourceBoxId or save.currentBox or 1]
    if not sB then return false, "Invalid box." end
    if save.party[targetSlot] then
      -- Swap box mon with existing party mon
      local boxMon = sB[sourceSlot]
      local partyMon = save.party[targetSlot]
      if not boxMon or not partyMon then return false, "Invalid slot." end
      sB[sourceSlot] = partyMon
      save.party[targetSlot] = boxMon
      return true
    else
      return self:withdrawMon(sourceBoxId, sourceSlot, targetSlot)
    end
  end

  return false, "Unsupported swap operation."
end

function Gen1Adapter:releaseMon(loc, slot, boxId)
  local save = self.game and self.game.save
  if not save then return false, "No save." end

  if loc == "party" then
    local party = save.party or {}
    local mon = party[slot]
    if not mon then return false, "No Pokémon in that slot." end
    local healthy = 0
    for _, m in ipairs(party) do
      if (m.hp or 0) > 0 then healthy = healthy + 1 end
    end
    if (mon.hp or 0) > 0 and healthy <= 1 then
      return false, "Cannot release your last healthy Pokémon!"
    end
    return true, table.remove(party, slot)
  else
    local boxes = Boxes.ensure(save)
    local bId = boxId or save.currentBox or 1
    local box = boxes[bId] or {}
    local mon = box[slot]
    if not mon then return false, "No Pokémon in that storage slot." end
    box[slot] = nil
    return true, mon
  end
end

function Gen1Adapter:getItemStorage()
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  local Bag = require("src.inventory.Bag")
  local rows = (save and Bag.pcRows(save, data)) or {}
  local items = {}
  for _, row in ipairs(rows) do
    local id = row.id
    local count = row.count
    local def = data and data.items and data.items[id]
    items[#items + 1] = {
      id = id,
      value = id,
      name = (def and def.name) or id,
      label = (def and def.name) or id,
      count = count,
      stack = count,
      slot = row.slot,
      def = def,
    }
  end
  return items
end

function Gen1Adapter:getBagItems()
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  local Bag = require("src.inventory.Bag")
  local rows = (save and Bag.rows(save, data)) or {}
  local items = {}
  for _, row in ipairs(rows) do
    local id = row.id
    local count = row.count
    local def = data and data.items and data.items[id]
    items[#items + 1] = {
      id = id,
      value = id,
      name = (def and def.name) or id,
      label = (def and def.name) or id,
      count = count,
      stack = count,
      slot = row.slot,
      def = def,
    }
  end
  return items
end

function Gen1Adapter:withdrawItem(itemId, qty, slot)
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  if not save or not itemId then return false, "No save data available." end
  local Bag = require("src.inventory.Bag")
  local amount = qty or 1
  if not Bag.add(save, itemId, amount, data) then
    return false, "You can't carry any more items in your Bag."
  end
  Bag.pcRemove(save, itemId, amount, data, slot)
  return true
end

function Gen1Adapter:depositItem(itemId, qty, slot)
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  if not save or not itemId then return false, "No save data available." end
  local Bag = require("src.inventory.Bag")
  local amount = qty or 1
  local cap = (data and data.field and data.field.pcItemCap) or 50
  if not Bag.pcAdd(save, itemId, amount, data, cap) then
    return false, ("No room left to store items in PC (max %d)."):format(cap)
  end
  Bag.remove(save, itemId, amount, data, slot)
  return true
end

function Gen1Adapter:getBagCapacity()
  local data = self.game and self.game.data
  local Bag = require("src.inventory.Bag")
  if Bag and Bag.capacity then
    local cap = Bag.capacity(data)
    if type(cap) == "number" and cap > 0 then return cap end
  end
  if data and data.constants and data.constants.bagSize then
    return math.floor(data.constants.bagSize)
  end
  if Bag and Bag.CAPACITY then
    return Bag.CAPACITY
  end
  return 20
end

function Gen1Adapter:getPcCapacity()
  local data = self.game and self.game.data
  if data and data.field and data.field.pcItemCap then
    return data.field.pcItemCap
  end
  return 50
end

function Gen1Adapter:tossItem(itemId, qty, slot)
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  if not save or not itemId then return false, "No save data available." end
  local Bag = require("src.inventory.Bag")
  Bag.pcRemove(save, itemId, qty or 1, data, slot)
  return true
end

--- Attaches dialogue controls for Gen 1: native TextBox is fully self-contained.
function Gen1Adapter:attachDialogueControls(state)
  if not state or state.isTextBox then return end
  return BaseAdapter.attachDialogueControls(self, state)
end

return Gen1Adapter


