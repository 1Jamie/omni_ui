-- OmniUI Stat Resolver
-- Automatically detects and adapts to Special Attack / Special Defense stat splits
-- across vanilla Gen 1/2/3, Kanto-Reforged, and custom mod configurations.

local StatResolver = {}

--- Calculates a Pokémon stat using the classic formula.
--- @param base number Base stat value
--- @param dv number Divergence Value / IV (0-15 in Gen 1/2, 0-31 in Gen 3)
--- @param statExp number Stat Experience / EV (0-65535 in Gen 1/2, 0-255 in Gen 3)
--- @param level number Pokémon level (1-100)
--- @return number
local function calcStatOne(base, dv, statExp, level)
  local ev = math.floor(math.min(255, math.ceil(math.sqrt(statExp or 0))) / 4)
  return math.floor(((base + dv) * 2 + ev) * level / 100) + 5
end

--- Calculates a Pokémon's max HP using the classic formula.
--- @param base number Base HP value
--- @param dv number HP DV / IV (0-15 in Gen 1/2, 0-31 in Gen 3)
--- @param statExp number HP Stat Experience / EV
--- @param level number Pokémon level (1-100)
--- @return number
local function calcHp(base, dv, statExp, level)
  local ev = math.floor(math.min(255, math.ceil(math.sqrt(statExp or 0))) / 4)
  return math.floor(((base + dv) * 2 + ev) * level / 100) + level + 10
end

--- Checks if a special attack/defense split is active for the given Pokémon, definition, or environment.
--- @param mon table Pokémon data object
--- @param def table|nil Species definition table
--- @param game table|nil Game instance
--- @return boolean
function StatResolver.hasSpecialSplit(mon, def, game)
  if not mon then return false end
  local stats = mon.stats or {}

  -- 1. Explicit split stat fields stored on Pokémon object
  if (stats.specialAttack and stats.specialAttack > 0) or (stats.spAttack and stats.spAttack > 0)
     or (stats.specialDefense and stats.specialDefense > 0) or (stats.spDefense and stats.spDefense > 0) then
    return true
  end

  -- 2. Mod Constants / Options Flag
  local data = (game and game.data) or (package.loaded["src.core.Data"])
  if data and data.constants and (data.constants.splitSpecial or data.constants.split_special) then
    return true
  end

  -- 3. Kanto-Reforged / SplitSpecial Engine
  local krSplit = package.loaded["mods.Kanto-Reforged.battle.split_special"]
  if krSplit and krSplit.enabled then
    local modReforged = (game and game.mods and game.mods.reforged) or (package.loaded["mods.Kanto-Reforged"] and package.loaded["mods.Kanto-Reforged"].mod)
    if krSplit.enabled(modReforged) then
      return true
    end
  end

  -- 4. Check if species definition has explicit distinct SpA/SpD bases
  def = def or (data and data.pokemon and mon.species and data.pokemon[mon.species])
  if def then
    local baseStats = def.baseStats or def.stats or def
    local baseSpA = def.sp_attack or def.spAttack or def.specialAttack or (baseStats and (baseStats.sp_attack or baseStats.spAttack or baseStats.specialAttack))
    local baseSpD = def.sp_defense or def.spDefense or def.specialDefense or (baseStats and (baseStats.sp_defense or baseStats.spDefense or baseStats.specialDefense))
    if baseSpA and baseSpD and (baseSpA ~= baseSpD or def.sp_attack or def.sp_defense) then
      return true
    end
  end

  -- 5. Engine Game Version (Gen 2 / Gen 3 games always use split stats)
  local okGv, GameVersion = pcall(require, "src.core.GameVersion")
  if okGv and GameVersion and GameVersion.generation and GameVersion.generation() >= 2 then
    return true
  end

  return false
end

--- Resolves full stats for a Pokémon, returning normalized values and split state.
--- @param mon table Pokémon data object
--- @param def table|nil Species definition table
--- @param game table|nil Game instance
--- @return table { isSplit=boolean, hp=number, maxHp=number, attack=number, defense=number, special=number|nil, spAttack=number|nil, spDefense=number|nil, speed=number, total=number }
function StatResolver.getStats(mon, def, game)
  if not mon then return {} end
  local stats = mon.stats or {}
  local data = (game and game.data) or (package.loaded["src.core.Data"])
  def = def or (data and data.pokemon and mon.species and data.pokemon[mon.species]) or {}

  local isSplit = StatResolver.hasSpecialSplit(mon, def, game)
  local hp = tonumber(mon.hp or (stats and stats.hp) or mon.maxHp or 1)
  local maxHp = tonumber(mon.maxHp or (stats and stats.hp) or mon.hp or 1)
  local atk = tonumber(stats.attack or stats.atk or 0)
  local defVal = tonumber(stats.defense or stats.def or 0)
  local spd = tonumber(stats.speed or stats.spd or 0)

  if isSplit then
    local spA = stats.spAttack or stats.specialAttack or stats.spAtk or stats.spa
    local spD = stats.spDefense or stats.specialDefense or stats.spDef or stats.spd

    if not spA or not spD then
      local krSplit = package.loaded["mods.Kanto-Reforged.battle.split_special"]
      if krSplit and krSplit.calcSpStats then
        local sp = krSplit.calcSpStats(def, mon)
        if sp then
          spA = spA or sp.sp_attack
          spD = spD or sp.sp_defense
        end
      end
    end

    if (not spA or not spD) and def then
      local baseStats = def.baseStats or def.stats or def
      local baseSpA = def.sp_attack or def.spAttack or def.specialAttack or (baseStats and (baseStats.sp_attack or baseStats.spAttack or baseStats.specialAttack)) or (baseStats and baseStats.special)
      local baseSpD = def.sp_defense or def.spDefense or def.specialDefense or (baseStats and (baseStats.sp_defense or baseStats.spDefense or baseStats.specialDefense)) or (baseStats and baseStats.special)
      if baseSpA or baseSpD then
        local dvs = mon.dvs or {}
        local statExp = mon.statExp or {}
        local level = tonumber(mon.level or 1)
        local dv = dvs.special or dvs.specialAttack or dvs.spAttack or 0
        local ev = statExp.special or statExp.specialAttack or statExp.spAttack or 0
        spA = spA or (baseSpA and calcStatOne(baseSpA, dv, ev, level)) or stats.special or 0
        spD = spD or (baseSpD and calcStatOne(baseSpD, dv, ev, level)) or stats.special or 0
      end
    end

    spA = tonumber(spA or stats.special or 0)
    spD = tonumber(spD or stats.special or 0)

    return {
      isSplit = true,
      hp = hp,
      maxHp = maxHp,
      attack = atk,
      defense = defVal,
      spAttack = spA,
      spDefense = spD,
      speed = spd,
      total = maxHp + atk + defVal + spA + spD + spd,
    }
  else
    local spec = tonumber(stats.special or 0)
    return {
      isSplit = false,
      hp = hp,
      maxHp = maxHp,
      attack = atk,
      defense = defVal,
      special = spec,
      speed = spd,
      total = maxHp + atk + defVal + spec + spd,
    }
  end
end

--- Calculates full stats at a specific level for growth/delta comparisons.
--- @param mon table Pokémon data object
--- @param def table|nil Species definition table
--- @param game table|nil Game instance
--- @param targetLevel number Specific level to calculate stats for
--- @return table
function StatResolver.getStatsAtLevel(mon, def, game, targetLevel)
  if not mon then return {} end
  targetLevel = math.max(1, math.min(100, tonumber(targetLevel or mon.level or 1)))
  local data = (game and game.data) or (package.loaded["src.core.Data"])
  def = def or (data and data.pokemon and mon.species and data.pokemon[mon.species]) or {}
  local base = def.baseStats or def.stats or def
  local dvs = mon.dvs or mon.ivs or {}
  local statExp = mon.statExp or mon.evs or {}

  local isSplit = StatResolver.hasSpecialSplit(mon, def, game)

  local baseHp = tonumber(def.hp or (base and base.hp) or 50)
  local baseAtk = tonumber(def.attack or (base and base.attack) or 50)
  local baseDef = tonumber(def.defense or (base and base.defense) or 50)
  local baseSpd = tonumber(def.speed or (base and base.speed) or 50)

  local dvHp = tonumber(dvs.hp or dvs[1] or 8)
  local dvAtk = tonumber(dvs.attack or dvs.atk or dvs[2] or 8)
  local dvDef = tonumber(dvs.defense or dvs.def or dvs[3] or 8)
  local dvSpd = tonumber(dvs.speed or dvs.spd or dvs[6] or 8)

  local evHp = tonumber(statExp.hp or 0)
  local evAtk = tonumber(statExp.attack or statExp.atk or 0)
  local evDef = tonumber(statExp.defense or statExp.def or 0)
  local evSpd = tonumber(statExp.speed or statExp.spd or 0)

  local hp = calcHp(baseHp, dvHp, evHp, targetLevel)
  local atk = calcStatOne(baseAtk, dvAtk, evAtk, targetLevel)
  local defVal = calcStatOne(baseDef, dvDef, evDef, targetLevel)
  local spd = calcStatOne(baseSpd, dvSpd, evSpd, targetLevel)

  if isSplit then
    local baseSpA = tonumber(def.sp_attack or def.spAttack or def.specialAttack or (base and (base.sp_attack or base.spAttack or base.specialAttack)) or (base and base.special) or 50)
    local baseSpD = tonumber(def.sp_defense or def.spDefense or def.specialDefense or (base and (base.sp_defense or base.spDefense or base.specialDefense)) or (base and base.special) or 50)
    local dvSpA = tonumber(dvs.special or dvs.specialAttack or dvs.spAttack or dvs.spa or 8)
    local dvSpD = tonumber(dvs.special or dvs.specialDefense or dvs.spDefense or dvs.spd or 8)
    local evSpA = tonumber(statExp.special or statExp.specialAttack or statExp.spAttack or 0)
    local evSpD = tonumber(statExp.special or statExp.specialDefense or statExp.spDefense or 0)

    local spA = calcStatOne(baseSpA, dvSpA, evSpA, targetLevel)
    local spD = calcStatOne(baseSpD, dvSpD, evSpD, targetLevel)

    return {
      isSplit = true,
      hp = hp,
      maxHp = hp,
      attack = atk,
      defense = defVal,
      spAttack = spA,
      spDefense = spD,
      speed = spd,
      total = hp + atk + defVal + spA + spD + spd,
    }
  else
    local baseSpecial = tonumber(def.special or (base and base.special) or (base and base.sp_attack) or 50)
    local dvSpecial = tonumber(dvs.special or dvs.spAttack or dvs.spa or 8)
    local evSpecial = tonumber(statExp.special or 0)
    local spec = calcStatOne(baseSpecial, dvSpecial, evSpecial, targetLevel)

    return {
      isSplit = false,
      hp = hp,
      maxHp = hp,
      attack = atk,
      defense = defVal,
      special = spec,
      speed = spd,
      total = hp + atk + defVal + spec + spd,
    }
  end
end

--- Resolves both current stats and previous level stats to determine stat gains/deltas.
--- @param mon table Pokémon data object
--- @param def table|nil Species definition table
--- @param game table|nil Game instance
--- @return table curStats, table deltas, table prevStats
function StatResolver.getStatDeltas(mon, def, game)
  if not mon then return {}, {}, {} end
  local curStats = StatResolver.getStats(mon, def, game)
  local level = tonumber(mon.level or 2)
  local prevLevel = math.max(1, level - 1)

  local prevStats = (mon._prevStats or mon.prevStats)
  if not prevStats then
    prevStats = StatResolver.getStatsAtLevel(mon, def, game, prevLevel)
  end

  local deltas = {}
  local function calcDelta(curVal, prevVal, fallbackVal)
    if curVal and prevVal and curVal > prevVal then
      return math.max(1, curVal - prevVal)
    end
    return math.max(1, fallbackVal or 2)
  end

  deltas.hp = calcDelta(curStats.maxHp or curStats.hp, prevStats.maxHp or prevStats.hp, math.max(1, math.floor((curStats.maxHp or 20) / (level > 0 and level or 1))))
  deltas.attack = calcDelta(curStats.attack, prevStats.attack, math.max(1, math.floor((curStats.attack or 15) / (level > 0 and level or 1))))
  deltas.defense = calcDelta(curStats.defense, prevStats.defense, math.max(1, math.floor((curStats.defense or 15) / (level > 0 and level or 1))))
  deltas.speed = calcDelta(curStats.speed, prevStats.speed, math.max(1, math.floor((curStats.speed or 15) / (level > 0 and level or 1))))

  if curStats.isSplit then
    deltas.spAttack = calcDelta(curStats.spAttack, prevStats.spAttack, math.max(1, math.floor((curStats.spAttack or 15) / (level > 0 and level or 1))))
    deltas.spDefense = calcDelta(curStats.spDefense, prevStats.spDefense, math.max(1, math.floor((curStats.spDefense or 15) / (level > 0 and level or 1))))
  else
    deltas.special = calcDelta(curStats.special, prevStats.special, math.max(1, math.floor((curStats.special or 15) / (level > 0 and level or 1))))
  end

  return curStats, deltas, prevStats
end

return StatResolver
