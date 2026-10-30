-- OmniUI Move Learning & Forget Selection Screen Renderer
-- Dual pane move replacement manager with live power, accuracy, type, PP comparison,
-- and newly acquired move spotlight.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Sprites = require("src.pokemon.Sprites")
local PaletteFX = require("src.render.PaletteFX")

local MoveLearnRenderer = {}

local EFFECT_DESCRIPTIONS = {
  NO_ADDITIONAL_EFFECT = "Inflicts standard damage with no additional effects.",
  POISON_SIDE_EFFECT1 = "Has a 33% chance to poison the target.",
  POISON_SIDE_EFFECT2 = "Has a 20% chance to poison the target.",
  POISON_EFFECT = "Inflicts the poison status condition on the target.",
  POISON_POWDER_EFFECT = "Scatters poisonous dust to poison the target.",
  BURN_SIDE_EFFECT1 = "Has a 10% chance to inflict a burn on the target.",
  BURN_SIDE_EFFECT2 = "Has a 33% chance to inflict a burn on the target.",
  FREEZE_SIDE_EFFECT = "Has a 10% chance to freeze the target solid.",
  PARALYZE_SIDE_EFFECT1 = "Has a 10% chance to paralyze the target.",
  PARALYZE_SIDE_EFFECT2 = "Has a 30% chance to paralyze the target.",
  PARALYZE_EFFECT = "Paralyzes the target, drastically reducing its Speed.",
  SLEEP_EFFECT = "Puts the target into a deep sleep.",
  CONFUSION_EFFECT = "Confuses the target, causing it to occasionally hurt itself.",
  CONFUSION_SIDE_EFFECT = "Has a chance to confuse the target.",
  ATTACK_UP1_EFFECT = "Raises the user's Attack stat by 1 stage.",
  ATTACK_UP2_EFFECT = "Sharply raises the user's Attack stat by 2 stages.",
  DEFENSE_UP1_EFFECT = "Raises the user's Defense stat by 1 stage.",
  DEFENSE_UP2_EFFECT = "Sharply raises the user's Defense stat by 2 stages.",
  SPEED_UP1_EFFECT = "Raises the user's Speed stat by 1 stage.",
  SPEED_UP2_EFFECT = "Sharply raises the user's Speed stat by 2 stages.",
  SPECIAL_UP1_EFFECT = "Raises the user's Special stat by 1 stage.",
  SPECIAL_UP2_EFFECT = "Sharply raises the user's Special stat by 2 stages.",
  ACCURACY_UP1_EFFECT = "Raises the user's Accuracy by 1 stage.",
  ACCURACY_UP2_EFFECT = "Sharply raises the user's Accuracy by 2 stages.",
  EVASION_UP1_EFFECT = "Raises the user's Evasion by 1 stage.",
  EVASION_UP2_EFFECT = "Sharply raises the user's Evasion by 2 stages.",
  ATTACK_DOWN1_EFFECT = "Lowers the target's Attack stat by 1 stage.",
  ATTACK_DOWN2_EFFECT = "Sharply lowers the target's Attack stat by 2 stages.",
  DEFENSE_DOWN1_EFFECT = "Lowers the target's Defense stat by 1 stage.",
  DEFENSE_DOWN2_EFFECT = "Sharply lowers the target's Defense stat by 2 stages.",
  SPEED_DOWN1_EFFECT = "Lowers the target's Speed stat by 1 stage.",
  SPEED_DOWN2_EFFECT = "Sharply lowers the target's Speed stat by 2 stages.",
  SPECIAL_DOWN1_EFFECT = "Lowers the target's Special stat by 1 stage.",
  SPECIAL_DOWN2_EFFECT = "Sharply lowers the target's Special stat by 2 stages.",
  ACCURACY_DOWN1_EFFECT = "Lowers the target's Accuracy by 1 stage.",
  ACCURACY_DOWN2_EFFECT = "Sharply lowers the target's Accuracy by 2 stages.",
  EVASION_DOWN1_EFFECT = "Lowers the target's Evasion by 1 stage.",
  EVASION_DOWN2_EFFECT = "Sharply lowers the target's Evasion by 2 stages.",
  DRAIN_HP_EFFECT = "Restores the user's HP by 50% of the damage dealt.",
  LEECH_SEED_EFFECT = "Plants a seed on the target that drains HP every turn.",
  BIDE_EFFECT = "Endures damage for 2-3 turns, then strikes back with 2x damage.",
  THRASH_PETAL_DANCE_EFFECT = "Rampages for 2-3 turns before becoming confused.",
  SWITCH_AND_TELEPORT_EFFECT = "Flees from wild battles or teleports out.",
  TWO_TO_FIVE_ATTACKS_EFFECT = "Hits the target 2 to 5 times in a single turn.",
  ATTACK_TWICE_EFFECT = "Strikes the target twice in rapid succession.",
  FLINCH_SIDE_EFFECT1 = "Has a 10% chance to make the target flinch.",
  FLINCH_SIDE_EFFECT2 = "Has a 30% chance to make the target flinch.",
  ONE_HIT_KO_EFFECT = "Instantly faints the target if the attack lands.",
  CHARGE_EFFECT = "Gathers energy on turn 1, then attacks on turn 2.",
  SUPER_FANG_EFFECT = "Bites down hard to cut the target's current HP by half.",
  SPECIAL_DAMAGE_EFFECT = "Deals a fixed or level-based amount of damage.",
  TRAPPING_EFFECT = "Traps the target in place for 2 to 5 turns.",
  HEAL_EFFECT = "Restores up to 50% of the user's maximum HP.",
  REST_EFFECT = "Sleeps for 2 turns to fully restore HP and heal all status.",
  EXPLODE_EFFECT = "User faints to trigger a catastrophic explosion.",
  RECOIL_EFFECT = "Deals heavy damage but user takes 25% recoil damage.",
  SUBSTITUTE_EFFECT = "Uses 25% HP to create a decoy substitute puppet.",
  MIMIC_EFFECT = "Temporarily copies one of the target's known moves.",
  METRONOME_EFFECT = "Wags a finger to randomly trigger almost any attack.",
  DISABLE_EFFECT = "Randomly disables one of the target's moves.",
  HAZE_EFFECT = "Eliminates all stat changes and status effects on the field.",
  REFLECT_EFFECT = "Creates a barrier that halves incoming physical damage.",
  LIGHT_SCREEN_EFFECT = "Creates a wall that halves incoming special damage.",
  FOCUS_ENERGY_EFFECT = "Focuses concentration to increase critical hit rate.",
  CONVERSION_EFFECT = "Changes the user's type to match one of its moves.",
  PAY_DAY_EFFECT = "Scatters coins across the battlefield for extra money.",
  HYPER_BEAM_EFFECT = "Deals massive damage; user must recharge on next turn.",
  SWIFT_EFFECT = "Fires star-shaped rays that never miss the target.",
  FLY_EFFECT = "Soars into the sky on turn 1, strikes on turn 2.",
  MIRROR_MOVE_EFFECT = "Counters by mimicking the target's last used move.",
  TRANSFORM_EFFECT = "Transforms into an exact copy of the target Pokémon.",
}

local MOVE_SPECIFIC_DESCRIPTIONS = {
  BIDE = "Endures attacks for 2-3 turns, then strikes back with double the damage taken.",
  GROWL = "Growls cutely to lower the opposing Pokémon's Attack stat.",
  TACKLE = "Charges and slams into the target with full body weight.",
  LEECH_SEED = "Plants a draining seed that saps the foe's HP each turn.",
  VINE_WHIP = "Strikes the target with slender, whip-like vines.",
  THUNDERBOLT = "Unleashes a strong electric blast with a 10% chance to paralyze.",
  THUNDER = "Strikes with a wicked lightning bolt. 10% chance to paralyze.",
  SURF = "Creates a huge wave that crashes down on the opponent.",
  PSYCHIC = "A powerful telekinetic blast. May lower the target's Special.",
  BLIZZARD = "A howling blizzard that may freeze the target solid.",
  ICE_BEAM = "Blasts the target with an icy beam. 10% chance to freeze.",
  FLAMETHROWER = "Scorches the target with intense fire. 10% chance to burn.",
  FIRE_BLAST = "An all-consuming fireball in the shape of a star. May burn.",
  EARTHQUAKE = "A powerful tremor that strikes all grounded Pokémon.",
  SOLAR_BEAM = "Absorbs light on turn 1, then fires a solar blast on turn 2.",
  HYPER_BEAM = "A devastating energy blast. Requires a recharge turn.",
  REST = "Sleeps for 2 turns to completely restore HP and cure status.",
  RECOVER = "Restores up to half of the user's maximum HP.",
  SOFTBOILED = "Heals up to half of the user's max HP in or out of battle.",
  TOXIC = "Badly poisons the target, causing increasing damage each turn.",
  THUNDER_WAVE = "A weak jolt of electricity that paralyzes the foe 100%.",
  CONFUSE_RAY = "A sinister ray that causes immediate confusion.",
  DOUBLE_EDGE = "A reckless full-body charge that causes recoil damage.",
}

local function getMoveDescription(moveId, moveDef)
  if not moveId then return "A versatile combat technique." end
  if MOVE_SPECIFIC_DESCRIPTIONS[moveId] then
    return MOVE_SPECIFIC_DESCRIPTIONS[moveId]
  end
  if moveDef then
    if moveDef.description then
      local d = moveDef.description
      return type(d) == "table" and table.concat(d, " ") or tostring(d)
    end
    if moveDef.effect and EFFECT_DESCRIPTIONS[moveDef.effect] then
      return EFFECT_DESCRIPTIONS[moveDef.effect]
    end
  end
  local cleanId = tostring(moveId):gsub("_", " "):lower()
  return ("A %s technique used in battle."):format(cleanId)
end

local function moveTitle(moveId)
  local num = tonumber(moveId) or moveId
  local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
  if ok and Pokemon and Pokemon.moveName then
    local okN, n = pcall(Pokemon.moveName, num)
    if okN and type(n) == "string" and n ~= "" and not n:find("^MOVE ") and n ~= "-------" then
      return n:gsub("_", " ")
    end
  end
  return tostring(moveId)
end

local function drawRelearner(game, state, w, h, theme)
  theme = theme or require("mods.omni_ui.core.Theme").get()
  local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
  local mon = state._mon or {}
  local monName = "POKÉMON"
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon and Pokemon.displayName then
    local okN, n = pcall(Pokemon.displayName, mon)
    if okN and type(n) == "string" and n ~= "" then monName = n end
  end
  if monName == "POKÉMON" and type(mon.nickname) == "string" and mon.nickname ~= "" then
    monName = mon.nickname
  end

  local moves = state._moves or {}
  local total = #moves + 1
  local cursor = math.max(1, math.min(total, state.cursor or 1))
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 540) or ctx.isPortrait
  local footY = h - 52

  Layout.drawCard(0, 0, w, h, { color = theme.bg, borderColor = theme.border, radius = 12 })
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(("TEACH %s"):format(tostring(monName):upper()), 18, 12, { font = "headline", color = theme.heading, bold = true, width = w - 36 })

  local listX = 16
  local listW = isNarrow and (w - 32) or math.floor(w * 0.42)
  local rowH = 36
  local listTop = 56
  local listH = math.max(rowH, footY - listTop - 8)
  local visible = math.max(1, math.floor(listH / (rowH + 4)))
  local scroll = state.scroll or 0
  if cursor <= scroll then scroll = cursor - 1 end
  if cursor > scroll + visible then scroll = cursor - visible end
  if scroll < 0 then scroll = 0 end

  for i = 1, visible do
    local idx = scroll + i
    if idx > total then break end
    local y = listTop + (i - 1) * (rowH + 4)
    local selected = idx == cursor and state.state ~= "yesno"
    local label = idx <= #moves and moveTitle(moves[idx]) or "CANCEL"
    Layout.drawCard(listX, y, listW, rowH, {
      color = selected and theme.accent or theme.surface,
      borderColor = selected and theme.accent or theme.border,
      radius = 8,
    })
    Layout.drawText(tostring(label):upper(), listX + 14, y + 8, {
      font = "button",
      color = selected and theme.textInverse or theme.heading,
      bold = selected,
      width = listW - 28,
    })
  end

  if not isNarrow then
    local dx = listX + listW + 12
    local dw = w - dx - 16
    Layout.drawCard(dx, listTop, dw, listH, { color = theme.surface, borderColor = theme.border, radius = 10 })
    if cursor > #moves then
      Layout.drawText("CANCEL", dx + 16, listTop + 16, { font = "title", color = theme.heading, bold = true })
      Layout.drawText("Stop teaching moves.", dx + 16, listTop + 52, { font = "body", color = theme.text, width = dw - 32 })
    else
      local id = moves[cursor]
      local title = moveTitle(id)
      local def = MoveDatabase.getMoveDef(id, { id = id, source = "gen3", name = title }, game)
      local desc = MoveDatabase.getDescription(id, def, game)
      Layout.drawText(title:upper(), dx + 16, listTop + 16, { font = "title", color = theme.heading, bold = true, width = dw - 32 })
      local meta = {}
      local power = def and tonumber(def.power)
      local accuracy = def and tonumber(def.accuracy)
      local pp = def and tonumber(def.pp)
      if def and def.type then meta[#meta + 1] = tostring(def.type) end
      if power and power > 0 then meta[#meta + 1] = ("PWR %d"):format(power) end
      if accuracy and accuracy > 0 then meta[#meta + 1] = ("ACC %d%%"):format(accuracy) end
      if pp and pp > 0 then meta[#meta + 1] = ("PP %d"):format(pp) end
      Layout.drawText(table.concat(meta, "   "), dx + 16, listTop + 52, { font = "caption", color = theme.textDim, width = dw - 32 })
      if type(desc) == "string" and desc ~= "" then
        Layout.drawText(desc, dx + 16, listTop + 80, { font = "body", color = theme.text, width = dw - 32 })
      end
    end
  end

  local prompt = state.prompt
  if type(prompt) == "string" and prompt ~= "" then
    Layout.drawText(prompt:gsub("\n", " "), 18, footY + 12, { font = "body", color = theme.text, width = w - 36 })
  end

  if state.state == "yesno" then
    local bw, bh = 160, 92
    local bx, by = w - bw - 24, math.max(56, footY - bh - 12)
    Layout.drawCard(bx, by, bw, bh, { color = theme.surface, borderColor = theme.border, radius = 10 })
    local yesSel = (state.yesNoCursor or 1) == 1
    Layout.drawCard(bx + 12, by + 12, bw - 24, 30, { color = yesSel and theme.accent or theme.raised, radius = 6 })
    Layout.drawText("YES", bx + 28, by + 16, { font = "button", color = yesSel and theme.textInverse or theme.heading, bold = yesSel })
    Layout.drawCard(bx + 12, by + 50, bw - 24, 30, { color = (not yesSel) and theme.accent or theme.raised, radius = 6 })
    Layout.drawText("NO", bx + 28, by + 54, { font = "button", color = (not yesSel) and theme.textInverse or theme.heading, bold = not yesSel })
  end
end

function MoveLearnRenderer.draw(game, state, w, h, theme, subState)
  if type(state._moves) == "table" and state._mon ~= nil then
    drawRelearner(game, state, w, h, theme)
    return
  end
  local mon = state.mon or {}
  local species = mon.species or mon.id
  local monDef = game.data and game.data.pokemon and (game.data.pokemon[species] or game.data.pokemon[mon.id])
  local monName = mon.nickname or (monDef and monDef.name) or species or "POKÉMON"

  local isMoveSelect = (state.newMoveId == nil)
  local newMoveDef = (state.newMoveId and game.data and game.data.moves and game.data.moves[state.newMoveId]) or nil
  local newMoveName = newMoveDef and newMoveDef.name or state.newMoveId or "NEW MOVE"

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 540) or ctx.isPortrait
  local footY = h - 38

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  if isMoveSelect then
    local prompt = state.prompt or state.rawPrompt or "SELECT MOVE"
    if type(prompt) == "string" then prompt = prompt:gsub("\n", " ") end
    Layout.drawText(("%s: %s"):format(monName:upper(), prompt:upper()), 18, 12, { font = "headline", color = theme.heading, bold = true, width = w - 140 })
    if w >= 360 then
      Layout.drawBadge(w - 130, 10, "CHOOSE", { kind = "accent", font = "caption", height = 24 })
    end
  else
    Layout.drawText(("REPLACE: %s"):format(monName:upper()), 18, 12, { font = "headline", color = theme.heading, bold = true, width = w - 140 })
    if w >= 360 then
      Layout.drawBadge(w - 130, 10, "FORGET", { kind = "warn", font = "caption", height = 24 })
    end
  end

  local moves = mon.moves or {}
  local curIdx = state.index or 1
  local curMv = moves[curIdx]
  local curMdef = curMv and game.data and game.data.moves and game.data.moves[curMv.id]

  if not isNarrow then
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANE LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.floor(w * 0.46)
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Current 4 Moves Card
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("CURRENT KNOWN MOVES", 18, 66, { font = "caption", color = theme.colors.accent, bold = true })

    local rowH = 74
    local itemGap = 6

    for i = 1, 4 do
      local mv = moves[i]
      local mdef = mv and game.data and game.data.moves and game.data.moves[mv.id]
      local isSel = (curIdx == i)
      local iy = 90 + (i - 1) * (rowH + itemGap)

      if isSel then
        Layout.drawCard(10, iy, leftW - 20, rowH, {
          color = theme.accentDark,
          borderColor = isMoveSelect and theme.colors.accent or theme.colors.hpRed,
          borderWidth = 2,
          radius = 8,
        })
      else
        Layout.drawSlot(10, iy, leftW - 20, rowH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 8,
        })
      end

      if mdef then
        Layout.drawText(mdef.name or mv.id, 20, iy + 10, { font = "headline", color = isSel and theme.heading or theme.text, bold = true })

        if mdef.type then
          Widgets.drawTypeBadge(mdef.type, 20, iy + 38)
        end

        local maxPp = mdef.pp or 0
        local curPp = mv.pp or maxPp
        local ppStr = ("PP %d/%d"):format(curPp, maxPp)
        Layout.drawBadge(leftW - 104, iy + 10, ppStr, { kind = isSel and "good" or "ghost", font = "tiny" })

        local pwr = mdef.power and mdef.power > 0 and tostring(mdef.power) or "---"
        local acc = mdef.accuracy and mdef.accuracy > 0 and (tostring(mdef.accuracy) .. "%") or "---"
        Layout.drawText(("PWR: %s   ACC: %s"):format(pwr, acc), leftW - 160, iy + 42, { font = "tiny", color = theme.textDim, bold = true })
      else
        Layout.drawText("- EMPTY MOVE SLOT -", 20, iy + 26, { font = "body", color = theme.textMuted })
      end
    end

    -- Right Panel: Specs / Comparison
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if isMoveSelect then
      Layout.drawText("TECHNIQUE SPECIFICATIONS", rightX + 18, 66, { font = "caption", color = theme.colors.accent, bold = true })

      local selBoxY = 90
      local selBoxH = 140
      Layout.drawSlot(rightX + 14, selBoxY, rightW - 28, selBoxH, {
        color = theme.surfaceHigh,
        borderColor = theme.colors.accent,
        borderWidth = 2,
        radius = 8,
      })

      local selName = curMdef and curMdef.name or (curMv and curMv.id) or "NONE"
      Layout.drawText(selName, rightX + 26, selBoxY + 14, { font = "title", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 120, selBoxY + 14, "SELECTED", { kind = "accent" })

      if curMdef then
        if curMdef.type then
          Widgets.drawTypeBadge(curMdef.type, rightX + 26, selBoxY + 48)
        end

        local maxPp = curMdef.pp or 0
        local curPp = (curMv and curMv.pp) or maxPp
        local ppStr = ("PP %d/%d"):format(curPp, maxPp)
        Layout.drawBadge(rightX + 120, selBoxY + 48, ppStr, { kind = "good", font = "tiny" })

        local pwr = curMdef.power and curMdef.power > 0 and tostring(curMdef.power) or "---"
        local acc = curMdef.accuracy and curMdef.accuracy > 0 and (tostring(curMdef.accuracy) .. "%") or "---"
        Layout.drawText(("POWER: %s    ACCURACY: %s"):format(pwr, acc), rightX + 26, selBoxY + 84, { font = "button", color = theme.heading, bold = true })
      end

      local descY = selBoxY + selBoxH + 14
      local descH = bodyH + 52 - descY - 14
      Layout.drawSlot(rightX + 14, descY, rightW - 28, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("TECHNIQUE DETAILS", rightX + 26, descY + 12, { font = "caption", color = theme.colors.accent, bold = true })
      local moveDesc = getMoveDescription(curMv and curMv.id, curMdef)
      Layout.drawTextWrapped(moveDesc, rightX + 26, descY + 36, rightW - 52, { font = "body", color = theme.textDim })
    else
      Layout.drawText("MOVE COMPARISON", rightX + 18, 66, { font = "caption", color = theme.colors.accent, bold = true })
      local cardH2 = math.floor((bodyH - 58) / 2)

      local oldY = 90
      Layout.drawCard(rightX + 12, oldY, rightW - 24, cardH2, {
        color = theme.surfaceHigh,
        borderColor = theme.colors.hpRed,
        borderWidth = 1.5,
        radius = 8,
      })

      local oldName = curMdef and curMdef.name or (curMv and curMv.id) or "NONE"
      Layout.drawText(oldName, rightX + 24, oldY + 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 128, oldY + 10, "TO FORGET", { kind = "warn" })

      if curMdef then
        if curMdef.type then
          Widgets.drawTypeBadge(curMdef.type, rightX + 24, oldY + 40)
        end

        local maxPp = curMdef.pp or 0
        local curPp = (curMv and curMv.pp) or maxPp
        local ppStr = ("PP %d/%d"):format(curPp, maxPp)
        Layout.drawBadge(rightX + 116, oldY + 40, ppStr, { kind = "ghost", font = "tiny" })

        local pwr = curMdef.power and curMdef.power > 0 and tostring(curMdef.power) or "---"
        local acc = curMdef.accuracy and curMdef.accuracy > 0 and (tostring(curMdef.accuracy) .. "%") or "---"
        Layout.drawText(("PWR: %s   ACC: %s"):format(pwr, acc), rightX + 196, oldY + 42, { font = "tiny", color = theme.textDim, bold = true })

        local oldDesc = getMoveDescription(curMv and curMv.id, curMdef)
        Layout.drawTextWrapped(oldDesc, rightX + 24, oldY + 70, rightW - 48, { font = "tiny", color = theme.textDim })
      end

      local newY = oldY + cardH2 + 10
      Layout.drawCard(rightX + 12, newY, rightW - 24, cardH2, {
        color = theme.surfaceHigh,
        borderColor = theme.colors.hpGreen,
        borderWidth = 2,
        radius = 8,
      })

      Layout.drawText(newMoveName, rightX + 24, newY + 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 128, newY + 10, "NEW MOVE", { kind = "good" })

      if newMoveDef then
        if newMoveDef.type then
          Widgets.drawTypeBadge(newMoveDef.type, rightX + 24, newY + 40)
        end

        local newMaxPp = newMoveDef.pp or 0
        local newPpStr = ("PP %d/%d"):format(newMaxPp, newMaxPp)
        Layout.drawBadge(rightX + 116, newY + 40, newPpStr, { kind = "good", font = "tiny" })

        local pwr = newMoveDef.power and newMoveDef.power > 0 and tostring(newMoveDef.power) or "---"
        local acc = newMoveDef.accuracy and newMoveDef.accuracy > 0 and (tostring(newMoveDef.accuracy) .. "%") or "---"
        Layout.drawText(("PWR: %s   ACC: %s"):format(pwr, acc), rightX + 196, newY + 42, { font = "tiny", color = theme.textDim, bold = true })

        local newDesc = getMoveDescription(state.newMoveId, newMoveDef)
        Layout.drawTextWrapped(newDesc, rightX + 24, newY + 70, rightW - 48, { font = "tiny", color = theme.textDim })
      end
    end

  else
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED LAYOUT
    -- =========================================================================
    local detailH = 124
    local listH = footY - 48 - detailH - 8
    Layout.drawCard(0, 48, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 34
    local itemGap = 3
    for i = 1, 4 do
      local mv = moves[i]
      local mdef = mv and game.data and game.data.moves and game.data.moves[mv.id]
      local isSel = (curIdx == i)
      local iy = 54 + (i - 1) * (rowH + itemGap)

      if isSel then
        Layout.drawCard(8, iy, w - 16, rowH, {
          color = theme.accentDark,
          borderColor = isMoveSelect and theme.colors.accent or theme.colors.hpRed,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(8, iy, w - 16, rowH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
      end

      if mdef then
        if mdef.type then
          Widgets.drawTypeBadge(mdef.type, 14, iy + 6)
        end
        Layout.drawText(mdef.name or mv.id, 94, iy + 8, { font = "caption", color = isSel and theme.heading or theme.text, bold = isSel, width = w - 180 })
        local maxPp = mdef.pp or 0
        local curPp = mv.pp or maxPp
        Layout.drawText(("PP %d/%d"):format(curPp, maxPp), w - 74, iy + 9, { font = "tiny", color = theme.textDim, bold = true })
      else
        Layout.drawText("- EMPTY -", 16, iy + 8, { font = "caption", color = theme.textMuted })
      end
    end

    -- Bottom Detail / Comparison Drawer
    local detailY = 48 + listH + 6
    Layout.drawCard(0, detailY, w, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if isMoveSelect then
      local selName = curMdef and curMdef.name or (curMv and curMv.id) or "NONE"
      Layout.drawText(selName, 14, detailY + 8, { font = "headline", color = theme.heading, bold = true })
      if curMdef then
        local pwr = curMdef.power and curMdef.power > 0 and tostring(curMdef.power) or "---"
        local acc = curMdef.accuracy and curMdef.accuracy > 0 and (tostring(curMdef.accuracy) .. "%") or "---"
        Layout.drawBadge(w - 110, detailY + 8, ("PWR %s  ACC %s"):format(pwr, acc), { kind = "accent", font = "tiny" })
        local moveDesc = getMoveDescription(curMv and curMv.id, curMdef)
        Layout.drawTextWrapped(moveDesc, 14, detailY + 34, w - 28, { font = "caption", color = theme.textDim })
      end
    else
      -- Show New Move Spotlight
      Layout.drawText("LEARN: " .. tostring(newMoveName), 14, detailY + 8, { font = "headline", color = theme.hpGreen, bold = true, width = w - 110 })
      if newMoveDef then
        local pwr = newMoveDef.power and newMoveDef.power > 0 and tostring(newMoveDef.power) or "---"
        local acc = newMoveDef.accuracy and newMoveDef.accuracy > 0 and (tostring(newMoveDef.accuracy) .. "%") or "---"
        Layout.drawBadge(w - 100, detailY + 8, ("PWR %s ACC %s"):format(pwr, acc), { kind = "good", font = "tiny" })
        local newDesc = getMoveDescription(state.newMoveId, newMoveDef)
        Layout.drawTextWrapped(newDesc, 14, detailY + 34, w - 28, { font = "caption", color = theme.textDim })
      end
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints
  if isMoveSelect then
    hints = {
      { key = "▲ ▼", label = "Move", primary = true },
      { key = "A", label = "Confirm" },
      { key = "B", label = "Cancel" },
    }
  else
    hints = {
      { key = "▲ ▼", label = "Forget", primary = true },
      { key = "A", label = "Replace" },
      { key = "B", label = "Cancel" },
    }
  end
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return MoveLearnRenderer
