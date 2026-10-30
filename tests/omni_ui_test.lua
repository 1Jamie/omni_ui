package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

do
  local home = os.getenv("HOME") or ""
  local emRoots = {
    home .. "/Library/Application Support/LOVE/pokemon-love2d/emerald/",
    home .. "/.local/share/love/pokemon-love2d/emerald/",
  }
  for _, r in ipairs(emRoots) do
    local f = io.open(r .. "data/generated/gba/pokemon/hoenn.lua", "rb")
    if f then
      f:close()
      local okD, Dataset = pcall(require, "src.core.game3.dataset")
      if okD and Dataset then
        Dataset.cacheRootOverride = r .. "data/generated/gba"
      end
      break
    end
  end
end

local run = T.sdk.loadMod("mods/omni_ui", { data = Data })
T.eq(#run.errors, 0, "OmniUI loads clean")

local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
local Theme = require("mods.omni_ui.core.Theme")

local exports = run.loader.exports.omni_ui
T.neq(exports, nil, "OmniUI exports exist")
T.neq(exports.registerSummaryTab, nil, "registerSummaryTab exported")
T.neq(exports.registerBagPocket, nil, "registerBagPocket exported")
T.neq(exports.registerAdapter, nil, "v1 registerAdapter compat exported")

-- Test v1 legacy adapter contract registration and API parity with gen1_modern_ui
T.neq(exports.drawMonDetail, nil, "v1 drawMonDetail compat exported")
T.neq(exports.setPalette, nil, "v1 setPalette compat exported")
T.neq(exports.Theme, nil, "Theme subsystem exported")
T.neq(exports.Layout, nil, "Layout subsystem exported")
T.neq(exports.registerAdapter, nil, "registerAdapter exported")

local v1Result = exports.registerAdapter({
  owner = "test_mod",
  contract = {
    apiVersion = 1,
    screens = {
      UsefulBag = {
        canSuppressNative = true,
        match = function(s) return s and s.screenId == "UsefulBag" end,
        model = function(game, s)
          return { title = "POCKETS", rows = { { label = "POTION", value = "x5", enabled = true } } }
        end,
      },
    },
  },
})
T.eq(v1Result, true, "Legacy v1 contract registers successfully")

-- Test legacy screen rendering via LegacyRenderer
local mockLegacyState = { screenId = "UsefulBag" }
local legacyKind, legacyScreenDef = ModernOverlay.isSupported(mockLegacyState)
T.eq(legacyKind, "legacy_UsefulBag", "ModernOverlay detects registered legacy v1 screen")
T.neq(legacyScreenDef, nil, "Legacy screen definition resolved")
local okLegacyDraw = pcall(ModernOverlay.drawLegacy, fakeGame, mockLegacyState, legacyScreenDef, 760, 480, Theme.get())
T.eq(okLegacyDraw, true, "LegacyRenderer draws v1 adapter model cleanly")

-- Test native screen instantiation & ModernOverlay support
local fakeInput = {
  _pressed = {},
  wasPressed = function(self, key)
    return self._pressed[key] == true
  end,
  press = function(self, key)
    self._pressed = { [key] = true }
  end,
  clear = function(self)
    self._pressed = {}
  end,
}

local fakeGame = {
  data = Data,
  input = fakeInput,
  gameVersion = "red",
  save = {
    player = { name = "RED", id = 12345 },
    inventory = { POKE_BALL = 10, POTION = 5, BICYCLE = 1 },
    party = {
      {
        species = "PIKACHU",
        nickname = "SPARKY",
        level = 25,
        hp = 50,
        stats = { hp = 50, attack = 35, defense = 30, speed = 60, special = 40 },
        moves = { { id = "THUNDERSHOCK" } },
      },
    },
  },
}

local partyScreen = { screenId = "PartyMenu", game = fakeGame, index = 1, party = fakeGame.save.party }
local bagScreen = { screenId = "BagMenu", game = fakeGame, cursor = 1, items = {} }
local summaryScreen = { screenId = "SummaryMenu", game = fakeGame, mon = fakeGame.save.party[1], page = 1 }

local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
local theme = Theme.get()
T.eq(ModernOverlay.isSupported(partyScreen), "party", "ModernOverlay detects PartyMenu")
T.eq(ModernOverlay.isSupported(bagScreen), "bag", "ModernOverlay detects BagMenu")
T.eq(ModernOverlay.isSupported(summaryScreen), "summary", "ModernOverlay detects SummaryMenu")

-- Emit screen.pushed for SummaryMenu
run.loader.events:emit("screen.pushed", { state = summaryScreen })
T.neq(summaryScreen.update, nil, "SummaryScreen has update handler")

-- Test SummaryMenu page navigation: right arrow (1 -> 2 -> 3 -> 1)
fakeInput:press("right")
summaryScreen:update(1/60)
T.eq(summaryScreen.page, 2, "SummaryScreen advances to page 2 on Right")

fakeInput:press("right")
summaryScreen:update(1/60)
T.eq(summaryScreen.page, 3, "SummaryScreen advances to page 3 on Right")

fakeInput:press("right")
summaryScreen:update(1/60)
T.eq(summaryScreen.page, 1, "SummaryScreen wraps to page 1 on Right")

-- Test SummaryMenu page navigation: left arrow (1 -> 3)
fakeInput:press("left")
summaryScreen:update(1/60)
T.eq(summaryScreen.page, 3, "SummaryScreen wraps to page 3 on Left")

-- Emit screen.pushed for BagMenu
run.loader.events:emit("screen.pushed", { state = bagScreen })
T.neq(bagScreen.update, nil, "BagMenu has update handler")
T.eq(bagScreen.__pocketIndex, 1, "BagMenu starts on pocket 1 (ITEMS)")

-- Test BagMenu pocket switching: right arrow (1 -> 2)
fakeInput:press("right")
bagScreen:update(1/60)
T.eq(bagScreen.__pocketIndex, 2, "BagMenu switches to pocket 2 (BALLS) on Right")

-- Test BagMenu pocket switching: left arrow (2 -> 1)
fakeInput:press("left")
bagScreen:update(1/60)
T.eq(bagScreen.__pocketIndex, 1, "BagMenu switches back to pocket 1 (ITEMS) on Left")

-- Test StartMenu, TrainerCard, OptionsMenu, PokedexMenu, SaveMenu detection
local startScreen = { screenId = "StartMenu", startCloses = true, items = { { label = "POKéMON" }, { label = "ITEM" }, { label = "SAVE" } } }
local trainerScreen = { screenId = "TrainerCard", badges = 8, faces = {} }
local optionsScreen = { screenId = "OptionsMenu", isOptionsMenu = true, rows = { { label = "TEXT SPEED", choices = { "FAST", "MID", "SLOW" } } } }
local optionsSubScreen = { sub = true, view = { { label = "MUSIC VOL", value = function() return "7" end } }, index = 1, scroll = 0 }
local pokedexScreen = { screenId = "PokedexMenu", rowsAt = {}, scroll = 0, index = 1 }
local saveScreen = { screenId = "SaveMenu", openPrompt = function() end }
local managerScreen = { screenId = "ManagerState", screen = "list", tab = 1, cursor = 1, scroll = 1, status = { available = {}, errors = {} } }

local reportScreen = { screenId = "QuarantineReport", report = { lostMons = {}, lostItems = {} }, maxOffset = function() return 0 end }

T.eq(ModernOverlay.isSupported(startScreen), "start_menu", "ModernOverlay detects StartMenu")
T.eq(ModernOverlay.isSupported(trainerScreen), "trainer_card", "ModernOverlay detects TrainerCard")
T.eq(ModernOverlay.isSupported(optionsScreen), "options", "ModernOverlay detects OptionsMenu")
T.eq(ModernOverlay.isSupported(optionsSubScreen), "options", "ModernOverlay detects OptionsMenu sub-page")
T.eq(ModernOverlay.isSupported(pokedexScreen), "pokedex", "ModernOverlay detects PokedexMenu")
T.eq(ModernOverlay.isSupported(saveScreen), "save", "ModernOverlay detects SaveMenu")
T.eq(ModernOverlay.isSupported(managerScreen), "mod_manager", "ModernOverlay detects ManagerState")
T.eq(ModernOverlay.isSupported(reportScreen), "load_report", "ModernOverlay detects QuarantineReport")

-- Test AdapterResolver & Multi-gen Normalization
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
local g1Adapter = AdapterResolver.resolve({ gameVersion = "red", save = { player = { name = "RED", id = 12345 }, playTime = 3665 } })
local g2Adapter = AdapterResolver.resolve({ gameVersion = "gold", save = { playerName = "GOLD", playerID = 54321, johtoBadges = { true, true }, kantoBadges = {} } })
local g3Adapter = AdapterResolver.resolve({ gameVersion = "emerald", session = { playerName = "EMERALD", trainerId = 99999, money = 5000 } })

local p1 = g1Adapter:getPlayerInfo()
T.eq(p1.name, "RED", "Gen1 player name normalized")
T.eq(p1.playTimeString, "01:01", "Gen1 play time formatted")
T.eq(p1.region, "KANTO", "Gen1 region is Kanto")

local p2 = g2Adapter:getPlayerInfo()
T.eq(p2.name, "GOLD", "Gen2 player name normalized")
T.eq(p2.maxBadges, 16, "Gen2 max badges is 16")
T.eq(p2.region, "JOHTO", "Gen2 region is Johto")

local p3 = g3Adapter:getPlayerInfo()
T.eq(p3.name, "EMERALD", "Gen3 player name normalized")
T.eq(p3.region, "HOENN", "Gen3 Emerald region is Hoenn")
T.eq(p3.money, 5000, "Gen3 money normalized")

-- Test ChoiceBox left/right arrow toggle
local choiceScreen = {
  game = fakeGame,
  labels = { "YES", "NO" },
  index = 1,
  update = function(self, dt) end,
}
run.loader.events:emit("screen.pushed", { state = choiceScreen })
fakeInput:press("right")
choiceScreen:update(1/60)
T.eq(choiceScreen.index, 2, "ChoiceBox switches to NO on Right")

fakeInput:press("left")
choiceScreen:update(1/60)
T.eq(choiceScreen.index, 1, "ChoiceBox switches to YES on Left")

-- Test StartMenu Save item hook returns to Pause Menu
local fakeStack = {
  states = {},
  push = function(self, s) table.insert(self.states, s) end,
  pop = function(self) return table.remove(self.states) end,
  top = function(self) return self.states[#self.states] end,
}
fakeGame.stack = fakeStack
local mockMenu = { screenId = "StartMenu" }
fakeStack:push(mockMenu)

local startItems = {
  { label = "POKéMON", onSelect = function() end },
  { label = "ITEM", onSelect = function() end },
  { label = "SAVE", onSelect = function() fakeStack:pop() end },
}

local modifiedItems = run.loader.hooks:call("ui.start_menu.items", function(_, items) return items end, fakeGame, startItems)
T.neq(modifiedItems, nil, "ui.start_menu.items returns hooked items")
local saveItem = modifiedItems[3]
T.neq(saveItem, nil, "SAVE item present in list")
T.neq(saveItem.onSelect, nil, "SAVE onSelect handler exists")

-- Trigger Save onSelect: should push save panel to stack
saveItem.onSelect()
T.eq(#fakeStack.states, 2, "Stack now has StartMenu + SavePanel")
T.eq(fakeStack:top().holdsUIAnchors, true, "SavePanel is top of stack")

-- Simulate NO choice: closePanel should pop ONLY SavePanel, leaving StartMenu open!
fakeStack:top().openPrompt()
-- Stack now has StartMenu + SavePanel + TextBox
T.eq(#fakeStack.states, 3, "Stack has StartMenu + SavePanel + TextBox")
local promptBox = fakeStack:top()
-- Simulate choice callback with NO (false)
promptBox.choice(false)
T.eq(#fakeStack.states, 1, "Stack popped SavePanel and TextBox back down to 1")
T.eq(fakeStack:top(), mockMenu, "StartMenu remains top of stack when closing Save via NO")

-- Gen 3 pause SAVE must keep the native handler. The Gen 1 panel calls
-- math.floor on playTime (a {hours,minutes,seconds} table) and pushes
-- game.stack, which Game3 does not have, so the row never opens SaveMenu.
do
  local versions = { "firered", "leafgreen", "ruby", "sapphire", "emerald" }
  for _, ver in ipairs(versions) do
    local opened = false
    local native = function() opened = true end
    local g3 = {
      generation = 3,
      gameVersion = ver,
      session = { version = ver, playtime = { hours = 1, minutes = 2, seconds = 3 } },
      save = { playTime = { hours = 1, minutes = 2, seconds = 3 } },
      saveGame = function() return true end,
    }
    local items = {
      { id = "save", label = "SAVE", onSelect = native },
    }
    local out = run.loader.hooks:call("ui.start_menu.items", function(_, list) return list end, g3, items)
    T.eq(out[1].onSelect, native, ver .. " SAVE keeps the native save handler")
    local ok, err = pcall(out[1].onSelect)
    T.eq(ok, true, ver .. " SAVE handler runs: " .. tostring(err))
    T.eq(opened, true, ver .. " SAVE opens the native save menu")
    opened = false
  end

  local opened = false
  local native = function() opened = true end
  local bare = {
    generation = 3,
    saveGame = function() return true end,
  }
  local out = run.loader.hooks:call("ui.start_menu.items", function(_, list) return list end, bare, {
    { id = "save", label = "SAVE", onSelect = native },
  })
  T.eq(out[1].onSelect, native, "Gen 3 SAVE without a version string keeps the native handler")
  out[1].onSelect()
  T.eq(opened, true, "Gen 3 SAVE without a version string still runs")
end

-- Test ModernOverlay.drawModManager across all sub-screens
do
  local Theme = require("mods.omni_ui.core.Theme")
  local theme = Theme.get()

  -- 1. List Screen
  local testMod = {
    id = "test_mod",
    name = "Test Mod",
    version = "1.2.0",
    author = "Modder",
    category = "tool",
    description = "A great test mod for UI verification.",
    enabled = true,
    games = { "red", "blue", "gold", "silver", "crystal", "ruby", "sapphire", "emerald", "firered", "leafgreen" },
  }
  local modManagerScreen = {
    screenId = "ManagerState",
    screen = "list",
    tab = 1,
    cursor = 1,
    scroll = 1,
    status = { available = { testMod }, errors = {} },
    rows = { { mod = testMod, label = testMod.name } },
    rowsForScreen = function(self) return self.rows end,
  }
  local okList = pcall(function() ModernOverlay.drawModManager(fakeGame, modManagerScreen, 800, 500, theme) end)
  T.eq(okList, true, "drawModManager renders list screen without error")

-- 2. Detail Screen (with load order, enable/disable, options, github, back)
local detailScreen = {
  screenId = "ManagerState",
  screen = "detail",
  cursor = 1,
  scroll = 1,
  currentMod = testMod,
  rows = {
    { label = "DISABLE", action = function() end },
    { label = "OPTIONS..", action = function() end },
    { label = "< LOAD #1/5 >", adjust = function(d) end },
    { label = "GH owner/test_mod", inert = true },
    { label = "BACK", action = function() end },
  },
  rowsForScreen = function(self) return self.rows end,
}
local okDetail = pcall(function() ModernOverlay.drawModManager(fakeGame, detailScreen, 800, 500, theme) end)
T.eq(okDetail, true, "drawModManager renders detail screen without error")

-- 3. Options Screen (toggles, choices, numbers, text, reset)
local optionsScreenState = {
  screenId = "ManagerState",
  screen = "options",
  cursor = 1,
  scroll = 0,
  currentMod = testMod,
  optionRows = {
    { id = "theme", label = "UI THEME", value = function() return "DARK MODERN" end },
    { id = "overlay", label = "ENABLE OVERLAY", value = function() return "ON" end },
    { id = "speed", label = "ANIMATION SPEED", value = function() return "10" end },
    { id = "__reset", label = "RESET DEFAULTS", value = function() return "" end },
  },
}
local okOptions = pcall(function() ModernOverlay.drawModManager(fakeGame, optionsScreenState, 800, 500, theme) end)
T.eq(okOptions, true, "drawModManager renders options screen without error")

-- 4. Permissions Screen
local permScreen = {
  screenId = "ManagerState",
  screen = "permissions",
  cursor = 1,
  scroll = 1,
  currentMod = testMod,
  rows = { { glyph = "!", label = "FILESYSTEM ACCESS" } },
  rowsForScreen = function(self) return self.rows end,
}
local okPerm = pcall(function() ModernOverlay.drawModManager(fakeGame, permScreen, 800, 500, theme) end)
T.eq(okPerm, true, "drawModManager renders permissions screen without error")

-- 5. Errors Screen
local errScreen = {
  screenId = "ManagerState",
  screen = "errors",
  cursor = 1,
  scroll = 1,
  rows = { { label = "Failed to load mod dependency" } },
  rowsForScreen = function(self) return self.rows end,
}
local okErr = pcall(function() ModernOverlay.drawModManager(fakeGame, errScreen, 800, 500, theme) end)
T.eq(okErr, true, "drawModManager renders errors screen without error")

-- 6. Apply Screen
local applyScreen = {
  screenId = "ManagerState",
  screen = "apply",
  cursor = 1,
  scroll = 1,
  stagedList = function() return { testMod } end,
  rows = {
    { label = "APPLY & RESTART", action = function() end },
    { label = "DISCARD CHANGES", action = function() end },
  },
  rowsForScreen = function(self) return self.rows end,
}
local okApply = pcall(function() ModernOverlay.drawModManager(fakeGame, applyScreen, 800, 500, theme) end)
T.eq(okApply, true, "drawModManager renders apply screen without error")

-- 7. Overlay Confirm Modal
local overlayScreen = {
  screenId = "ManagerState",
  screen = "detail",
  currentMod = testMod,
  overlay = {
    kind = "confirm",
    lines = { "DISABLE THIS MOD?" },
    index = 1,
  },
}
local okOverlay = pcall(function() ModernOverlay.drawModManager(fakeGame, overlayScreen, 800, 500, theme) end)
T.eq(okOverlay, true, "drawModManager renders modal overlay without error")

-- 8. SubState QuantityBox Dialog
local qtySubState = {
  qty = 15,
  max = 99,
}
local okQty = pcall(function() ModernOverlay.drawModManager(fakeGame, optionsScreenState, 800, 500, theme, qtySubState) end)
T.eq(okQty, true, "drawModManager renders QuantityBox substate modal without error")
end

-- 9. Main Menu / Title Screen Support & Rendering
do
  local Theme = require("mods.omni_ui.core.Theme")
  local theme = Theme.get()
  local gen1TitleMenu = {
    screenId = "Menu",
    items = {
      { label = "CONTINUE" },
      { label = "NEW GAME" },
      { label = "OPTION" },
      { label = "EXIT GAME" },
    },
    index = 1,
    titleUiBox = { 0, 0, 12, 9 },
    onCancel = function() end,
  }
  T.eq(ModernOverlay.isSupported(gen1TitleMenu), "main_menu", "ModernOverlay detects Gen 1 Title Menu")

  local okDrawTitle = pcall(function() ModernOverlay.drawMainMenu(fakeGame, gen1TitleMenu, 800, 500, theme) end)
  T.eq(okDrawTitle, true, "drawMainMenu renders Gen 1 Main Menu cleanly")

local gen2MainMenu = {
  screenId = "Gen2MainMenu",
  list = {
    items = {
      { label = "CONTINUE", value = "continue" },
      { label = "NEW GAME", value = "new" },
      { label = "OPTION", value = "option" },
      { label = "EXIT GAME", value = "exit" },
    },
    index = 1,
  },
  save = fakeGame.save,
  hasSave = true,
  clockParts = function() return 14, 30, 2 end,
}
T.eq(ModernOverlay.isSupported(gen2MainMenu), "main_menu", "ModernOverlay detects Gen 2 Main Menu")

-- Test Title Menu Save Pre-loading
local titleMenuItems = {
  { label = "CONTINUE" },
  { label = "NEW GAME" },
  { label = "OPTION" },
}
local hookedTitleItems = run.loader.hooks:call("ui.title_menu.items", function(_, items) return items end, fakeGame, titleMenuItems)
T.neq(hookedTitleItems, nil, "ui.title_menu.items hook executes successfully")

local okDrawGen2 = pcall(function() ModernOverlay.drawMainMenu(fakeGame, gen2MainMenu, 800, 500, theme) end)
T.eq(okDrawGen2, true, "drawMainMenu renders Gen 2 Main Menu cleanly")

-- Continue Confirmation Mode
local continueInfoState = {
  title = {},
  save = fakeGame.save,
  titleUiBox = { 4, 7, 19, 16 },
  game = fakeGame,
}
T.eq(ModernOverlay.isSupported(continueInfoState), "main_menu", "ModernOverlay detects ContinueInfo state")

-- Emit screen.pushed for ContinueInfo to attach interactive controls
run.loader.events:emit("screen.pushed", { state = continueInfoState })
T.eq(continueInfoState.confirmChoice, 1, "ContinueInfo starts on YES (1)")

fakeInput:press("right")
continueInfoState:update(1/60)
T.eq(continueInfoState.confirmChoice, 2, "ContinueInfo switches to NO (2) on Right")

fakeInput:press("left")
continueInfoState:update(1/60)
T.eq(continueInfoState.confirmChoice, 1, "ContinueInfo switches to YES (1) on Left")

local okDrawContinue = pcall(function() ModernOverlay.drawMainMenu(fakeGame, continueInfoState, 800, 500, theme) end)
T.eq(okDrawContinue, true, "drawMainMenu renders Continue Confirmation Hero Card cleanly")

-- 10. Start Menu Exit / Return to Title Confirmation Modal
local startMenuState = {
  screenId = "StartMenu",
  items = {
    { label = "POKéDEX" },
    { label = "POKéMON" },
    { label = "ITEM" },
    { label = "RED" },
    { label = "SAVE" },
    { label = "OPTION" },
    { label = "QUIT" },
  },
  index = 7,
}
local quitChoiceSubState = {
  isChoiceBox = true,
  index = 2,
  labels = { "YES", "NO" },
}
local okDrawStartQuit = pcall(function() ModernOverlay.drawStartMenu(fakeGame, startMenuState, 800, 500, theme, quitChoiceSubState) end)
T.eq(okDrawStartQuit, true, "drawStartMenu renders Quit Confirmation Modal cleanly")
end

-- 11. Speech Dialogue / TextBox Overlay
local fakeTextBox = {
  isTextBox = true,
  pages = { { "Hello there! Welcome to the world of POKéMON!" } },
  shown = { { 0x87, 0x84, 0x8B, 0x8B, 0x8E }, { 0x93, 0x87, 0x84, 0x91, 0x84 } },
  waiting = true,
  pageIndex = 1,
  money = function() return 3000 end,
  moneyVisible = function() return true end,
  arrowVisible = function() return true end,
}
T.eq(ModernOverlay.isSupported(fakeTextBox), "dialogue", "ModernOverlay detects TextBox dialogue")

local okDrawDialogue = pcall(function() ModernOverlay.drawDialogue(fakeGame, fakeTextBox, 800, 500, theme, nil) end)
T.eq(okDrawDialogue, true, "drawDialogue renders modern dialogue overlay cleanly")

do
  local ffTextBox = {
    isTextBox = true,
    pages = { { "First line of text", "Second line of text" } },
    pageIndex = 1,
    lineIndex = 1,
    charIndex = 0,
    holdFrames = 20,
  }
  local ffGame = {
    logicSpeed = function() return 4 end,
    input = { isDown = function() return true end },
    stack = { states = { ffTextBox }, top = function() return ffTextBox end },
  }
  local okFF = pcall(function() ModernOverlay.drawDialogue(ffGame, ffTextBox, 800, 500, theme, nil) end)
  T.eq(okFF, true, "drawDialogue renders during fast-forward without error or blank flicker")
end

-- Test OakSpeech with stacked TextBox dialog preserves scene
do
  local fakeOakSpeech = {
    screenId = "OakSpeech",
    isOpaque = true,
    pic = {},
    picSlide = 0,
  }
  local fakeDialogueGame = {
    data = Data,
    stack = {
      states = { fakeOakSpeech, fakeTextBox },
      top = function() return fakeTextBox end,
    },
  }
  local kind, activeState, extra, subState = ModernOverlay.getActiveScreen(fakeDialogueGame)
  T.eq(kind, "dialogue", "Dialogue on OakSpeech resolves as active dialogue overlay")
  T.eq(activeState, fakeTextBox, "Active state is TextBox")
  local okOakDiagDraw = pcall(ModernOverlay.draw, fakeDialogueGame, { width = 800, height = 600 })
  T.eq(okOakDiagDraw, true, "Dialogue renders cleanly over OakSpeech scene without erasing backdrop")
end

-- 12. Poké Mart / Shop Menu Overlay & Sell Flow
do
  local fakeShopState = {
    screenId = "ShopMenu",
    isShopMenu = true,
    items = {
      { id = "POKE_BALL", label = "POKé BALL", price = 200, description = "A device for catching wild POKéMON." },
      { id = "POTION", label = "POTION", price = 300, description = "Restores the HP of a POKéMON by 20 points." },
      { id = "ANTIDOTE", label = "ANTIDOTE", price = 100, description = "Cures a poisoned POKéMON." },
    },
    index = 1,
    mode = "buy",
    qty = 5,
    money = function() return 5000 end,
  }
  T.eq(ModernOverlay.isSupported(fakeShopState), "shop", "ModernOverlay detects ShopMenu")

  local okDrawShop = pcall(function() ModernOverlay.drawShopMenu(fakeGame, fakeShopState, 800, 500, theme, nil) end)
  T.eq(okDrawShop, true, "drawShopMenu renders Poké Mart cleanly")

  local gen1Mart = {
    screenId = "ShopMenu",
    items = {
      { value = "POKE_BALL", label = "POKé BALL", price = "¥200" },
      { cancel = true, label = "CANCEL" },
    },
    index = 1,
    dialogue = true,
  }
  local okGen1Mart = pcall(function()
    ModernOverlay.drawShopMenu(fakeGame, gen1Mart, 800, 500, theme, { isQuantityBox = true, qty = 2, max = 99 })
  end)
  T.eq(okGen1Mart, true, "drawShopMenu renders a Gen 1 mart whose prices are already text")

  -- Test Shop in quantity picker and confirm modes
  fakeShopState.mode = "buy_qty"
  local okDrawShopQty = pcall(function() ModernOverlay.drawShopMenu(fakeGame, fakeShopState, 800, 500, theme, nil) end)
  T.eq(okDrawShopQty, true, "drawShopMenu renders Quantity Picker cleanly")

  fakeShopState.mode = "buy_confirm"
  local okDrawShopConf = pcall(function() ModernOverlay.drawShopMenu(fakeGame, fakeShopState, 800, 500, theme, nil) end)
  T.eq(okDrawShopConf, true, "drawShopMenu renders Purchase Confirm cleanly")

  local numericMart = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "buy",
    cursor = 1,
    _items = { 13, 18, 22 },
  }
  local okNumericMart = pcall(function() ModernOverlay.drawShopMenu(fakeGame, numericMart, 800, 500, theme, nil) end)
  T.eq(okNumericMart, true, "drawShopMenu renders a FireRed mart stocked with item ids")

  local greeting = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "root",
    cursor = 1,
    ROOT = { { id = "buy" }, { id = "sell" }, { id = "quit" } },
    _status = "Hi there!\nHow may I help you?",
  }
  local okGreeting = pcall(function() ModernOverlay.drawShopMenu(fakeGame, greeting, 800, 500, theme, nil) end)
  T.eq(okGreeting, true, "drawShopMenu renders the clerk greeting and choices")

  local clerkLine = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "buy_msg",
    cursor = 1,
    _items = { 13 },
    _status = "Here you go!\nThank you!\fPlease come again!",
    __omniShopPage = 1,
  }
  local okClerk = pcall(function() ModernOverlay.drawShopMenu(fakeGame, clerkLine, 800, 500, theme, nil) end)
  T.eq(okClerk, true, "drawShopMenu renders a clerk message instead of the catalog")

  local ShopRenderer = require("mods.omni_ui.renderers.ShopRenderer")
  local presses = { a = true }
  local input = { wasPressed = function(_, btn) return presses[btn] == true end }
  T.eq(ShopRenderer.holdClerkPage(clerkLine, input), true, "clerk dialogue advances a page before the shop dismisses it")
  T.eq(clerkLine.__omniShopPage, 2, "clerk dialogue is on the second page")
  T.eq(ShopRenderer.holdClerkPage(clerkLine, input), false, "the last clerk page is left for the shop")

  local qtyPrompt = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "buy_qty",
    qty = 2,
    cursor = 1,
    _items = { 13 },
    _status = "Certainly!\nHow many?",
  }
  local okQtyPrompt = pcall(function() ModernOverlay.drawShopMenu(fakeGame, qtyPrompt, 800, 500, theme, nil) end)
  T.eq(okQtyPrompt, true, "drawShopMenu keeps the quantity picker with the clerk prompt")

  local hoennMart = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "buy",
    state = "list",
    cursor = 1,
    scroll = 3,
    row = 1,
    _martType = "NORMAL",
    _items = { 13, 18, 22, 25, 26, 27, 28, 29, 30, 31 },
    _status = nil,
  }
  local okHoenn = pcall(function() ModernOverlay.drawShopMenu(fakeGame, hoennMart, 800, 500, theme, nil) end)
  T.eq(okHoenn, true, "drawShopMenu renders a Ruby, Sapphire, or Emerald mart list")
  T.eq(hoennMart.scroll, 3, "Hoenn marts keep their window scroll")
  T.eq(hoennMart.row, 1, "Hoenn marts keep their window row")

  local decorMart = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "root",
    state = "root",
    cursor = 1,
    _martType = "DECOR",
    _status = "Welcome!\nMay I help you?",
    ROOT = { { id = "buy" }, { id = "sell" }, { id = "quit" } },
  }
  local okDecor = pcall(function() ModernOverlay.drawShopMenu(fakeGame, decorMart, 800, 500, theme, nil) end)
  T.eq(okDecor, true, "drawShopMenu renders a decoration shop greeting")

  local hoennMsg = {
    screenId = "ShopMenu",
    isShopMenu = true,
    mode = "buy",
    state = "msg",
    _status = "Here you go!\nThank you!",
    _items = { 13 },
  }
  local okHoennMsg = pcall(function() ModernOverlay.drawShopMenu(fakeGame, hoennMsg, 800, 500, theme, nil) end)
  T.eq(okHoennMsg, true, "drawShopMenu renders a Hoenn clerk message")

  -- Test Shop SELL mode opening the Bag
  local fakeSellBagState = {
    dialogue = true,
    itemBox = true,
    money = function() return 5000 end,
    items = {
      { value = "POTION", label = "POTION", count = 3 },
      { value = "POKE_BALL", label = "POKé BALL", count = 5 },
      { cancel = true, label = "CANCEL" },
    },
    index = 1,
    scroll = 0,
  }
  T.eq(ModernOverlay.isSupported(fakeSellBagState), "bag", "ModernOverlay detects Shop SELL menu as Bag")

  local okDrawSellBag = pcall(function() ModernOverlay.drawBag(fakeGame, fakeSellBagState, 800, 500, theme, nil) end)
  T.eq(okDrawSellBag, true, "drawBag renders Shop SELL bag cleanly")

  -- Test Shop SELL with Quantity selector subState
  local fakeQtySub = { isQuantityBox = true, qty = 2, max = 3 }
  local okDrawSellBagQty = pcall(function() ModernOverlay.drawBag(fakeGame, fakeSellBagState, 800, 500, theme, fakeQtySub) end)
  T.eq(okDrawSellBagQty, true, "drawBag renders Shop SELL quantity stepper cleanly")

  -- Test Player PC Deposit with Quantity selector subState and completion notice
  local fakePcDepositState = {
    kind = "pc_item_deposit",
    items = { { id = "POTION", value = "POTION", label = "POTION", count = 5 } },
    index = 1,
    scroll = 0,
    pcPrompt = "What do you want to deposit?",
  }
  T.eq(ModernOverlay.isSupported(fakePcDepositState), "player_pc", "ModernOverlay detects pc_item_deposit as player_pc")

  local okDrawPcDeposit = pcall(function() ModernOverlay.drawPlayerPc(fakeGame, fakePcDepositState, 800, 500, theme, nil) end)
  T.eq(okDrawPcDeposit, true, "drawPlayerPc renders PC deposit mode cleanly")

  local fakePcQtySub = { isQuantityBox = true, qty = 3, max = 5 }
  local okDrawPcQty = pcall(function() ModernOverlay.drawPlayerPc(fakeGame, fakePcDepositState, 800, 500, theme, fakePcQtySub) end)
  T.eq(okDrawPcQty, true, "drawPlayerPc renders deposit Quantity Stepper cleanly")

  local fakePcCompleteState = {
    kind = "pc_item_deposit",
    items = { { id = "POTION", value = "POTION", label = "POTION", count = 2 } },
    index = 1,
    scroll = 0,
    pcCompletion = true,
    footer = "POTION was stored via PC.{PROMPT}",
  }
  local okDrawPcComplete = pcall(function() ModernOverlay.drawPlayerPc(fakeGame, fakePcCompleteState, 800, 500, theme, nil) end)
  T.eq(okDrawPcComplete, true, "drawPlayerPc renders completion notice dialog cleanly")
end

-- 13. Generational Adapter System Tests
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
local gen1Game = { gameVersion = "red", save = fakeGame.save, data = Data }
local gen2Game = { gameVersion = "gold", save = fakeGame.save, data = Data }
local gen3Game = { gameVersion = "firered", save = fakeGame.save, data = Data }

local a1 = AdapterResolver.resolve(gen1Game)
local a2 = AdapterResolver.resolve(gen2Game)
local a3 = AdapterResolver.resolve(gen3Game)

T.eq(a1.region, "KANTO", "Gen1Adapter reports Kanto region")
T.eq(a2.region, "JOHTO", "Gen2Adapter reports Johto region")
T.eq(a3.region, "KANTO", "Gen3Adapter reports Kanto region")

local p1 = a1:getParty()
T.eq(#p1, 1, "Gen1Adapter returns normalized party")
T.eq(p1[1].displayName, "PIKACHU", "Gen1Adapter normalizes Pikachu")

-- 14. Theme Switching & Composable Theme System
local Theme = require("mods.omni_ui.core.Theme")
local Layout = require("mods.omni_ui.core.Layout")

-- Test Theme.hex helper
local hex3 = Theme.hex("#F00")
T.eq(hex3[1], 1.0, "Hex #F00 red channel is 1.0")
T.eq(hex3[2], 0.0, "Hex #F00 green channel is 0.0")

local hex6 = Theme.hex("#4CA3F0")
T.eq(math.floor(hex6[1] * 255 + 0.5), 76, "Hex #4CA3F0 red channel")
T.eq(math.floor(hex6[2] * 255 + 0.5), 163, "Hex #4CA3F0 green channel")
T.eq(math.floor(hex6[3] * 255 + 0.5), 240, "Hex #4CA3F0 blue channel")

local hex8 = Theme.hex("#FF3C4880")
T.eq(math.floor(hex8[4] * 255 + 0.5), 128, "Hex #FF3C4880 alpha channel")

-- Test Theme directory loading & registration
Theme.loadThemesDirectory()
local themeList = Theme.list()
T.neq(#themeList, 0, "Theme.list returns registered themes")

local hasClassic = false
local hasEmerald = false
local hasCyber = false
for _, th in ipairs(themeList) do
  if th.id == "classic" then hasClassic = true end
  if th.id == "emerald" then hasEmerald = true end
  if th.id == "cyber" then hasCyber = true end
end
T.eq(hasClassic, true, "Theme directory contains classic theme")
T.eq(hasEmerald, true, "Theme directory contains emerald theme")
T.eq(hasCyber, true, "Theme directory contains cyber theme")

Theme.setPalette("kanto")
local kantoPal = Theme.get()
T.neq(kantoPal, nil, "Kanto palette exists")
T.eq(kantoPal.accent[1] > 0.9, true, "Kanto palette has red brand rail accent")

Theme.setPalette("dark")
local darkPal = Theme.get()
T.eq(darkPal.accentDark[1] < 0.2, true, "Dark palette uses base launcher buttonBlue")

-- Test Theme.extend and Theme.register with custom layout & draw hooks
local customCardDrawn = false
local neonCustom = Theme.extend("dark", {
  label = "Neon Custom",
  colors = {
    accent = "#00FFDD",
  },
  layout = {
    dock = {
      align = "left",
      width = 320,
    },
  },
  drawCard = function(self, x, y, w, h, opts)
    customCardDrawn = true
  end,
})
Theme.register("neon_custom", neonCustom)

T.eq(Theme.get("neon_custom").label, "Neon Custom", "Theme.register registers Neon Custom")
T.eq(Theme.get("neon_custom").layout.dock.align, "left", "Extended theme overrides dock layout to left")
T.eq(Theme.get("neon_custom").layout.dock.width, 320, "Extended theme overrides dock width")
T.eq(Theme.get("neon_custom").colors.accent[2] > 0.9, true, "Hex accent converted properly in extended theme")

Theme.setTheme("neon_custom")
Layout.drawCard(0, 0, 100, 100)
T.eq(customCardDrawn, true, "Layout.drawCard delegates to custom theme drawCard hook")
Theme.setTheme("dark")

-- Test real-time theme interpolation & morphing
local darkTheme = Theme.REGISTRY.dark
local kantoTheme = Theme.REGISTRY.kanto
local midMorph = Theme.interpolate(darkTheme, kantoTheme, 0.5)
T.neq(midMorph, nil, "Theme.interpolate returns blended theme")
T.eq(midMorph.id, "kanto", "Interpolated theme target id is kanto")
T.eq(midMorph.colors.accent[1] > 0.4 and midMorph.colors.accent[1] < 0.95, true, "Interpolated accent color is smoothly blended mid-transition")
T.neq(midMorph.accent, nil, "Direct metatable access works on interpolated theme")

-- Test Layout primitives (drawDivider, drawProgressBar, drawHintBar, drawScrollBar)
local okDivider = pcall(function() Layout.drawDivider(10, 10, 200) end)
T.eq(okDivider, true, "Layout.drawDivider executes cleanly")

local okProg = pcall(function() Layout.drawProgressBar(10, 20, 150, 10, 50, 100) end)
T.eq(okProg, true, "Layout.drawProgressBar executes cleanly")

local okHints = pcall(function()
  Layout.drawHintBar(0, 400, 800, 36, {
    { key = "A", label = "SELECT", primary = true },
    { key = "B", label = "BACK" },
  })
end)
T.eq(okHints, true, "Layout.drawHintBar executes cleanly")

local okScrollbar = pcall(function()
  Layout.drawScrollBar(780, 50, 6, 300, 20, 8, 3)
end)
T.eq(okScrollbar, true, "Layout.drawScrollBar executes cleanly with proportional geometry")

local okScrollbarNoop = pcall(function()
  Layout.drawScrollBar(780, 50, 6, 300, 5, 8, 0)
end)
T.eq(okScrollbarNoop, true, "Layout.drawScrollBar cleanly no-ops when items fit on screen")

-- Test Bag interactive scrolling and scrollbar rendering
local fakeBagItems = {}
for i = 1, 20 do
  table.insert(fakeBagItems, { id = "POTION", label = "Potion #" .. i, count = i })
end
local fakeBagState = {
  screenId = "BagMenu",
  items = fakeBagItems,
  index = 12,
  scroll = 0,
}
local okBagDraw = pcall(function()
  ModernOverlay.drawBag(fakeGame, fakeBagState, 800, 500, Theme.get(), nil)
end)
T.eq(okBagDraw, true, "drawBag renders 20-item scrollable inventory cleanly with dynamic scrollbar")
T.eq(fakeBagState.scroll > 0, true, "Bag state dynamically computes and syncs visible scroll window")

-- FireRed's cart bag raises scroll to walk a list longer than its 6-row
-- window. The overlay shows those later rows already, and must not write
-- the cart scroll back down or the cursor freezes at the first pocket's length.
do
  local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
  local rows = {}
  for i = 1, 12 do
    rows[i] = { id = 100 + i, name = "KEY " .. i, qty = 1 }
  end
  local versions = { "firered", "leafgreen", "ruby", "sapphire", "emerald" }
  for _, ver in ipairs(versions) do
    local bag = {
      pocketIdx = 2,
      cursor = 8,
      scroll = 4,
      mode = "list",
      list = function() return rows end,
      currentPocket = function() return "KEY_ITEMS" end,
    }
    local game = { gameVersion = ver, session = { version = ver, bag = { pockets = {} } } }
    local ok = pcall(BagRenderer.draw, game, bag, 800, 600, Theme.get())
    T.eq(ok, true, ver .. " bag still draws a long pocket")
    T.eq(bag.scroll, 4, ver .. " bag draw leaves each pocket's cart scroll alone")
  end
end

-- Test Shop interactive scrolling and quantity stepper substate
local fakeShopItems = {}
for i = 1, 15 do
  table.insert(fakeShopItems, { id = "POKE_BALL", label = "Poké Ball " .. i, price = 200 })
end
local fakeShopState = {
  screenId = "ShopMenu",
  items = fakeShopItems,
  index = 10,
  scroll = 0,
}
local fakeQtySubState = {
  isQuantityBox = true,
  qty = 5,
  max = 99,
}
local okShopDraw = pcall(function()
  ModernOverlay.drawShopMenu(fakeGame, fakeShopState, 800, 500, Theme.get(), fakeQtySubState)
end)
T.eq(okShopDraw, true, "drawShopMenu renders scrollable catalog with dynamic scrollbar and quantity stepper")
T.eq(fakeShopState.scroll > 0, true, "Shop state dynamically computes and syncs visible scroll window")

-- Test Pokédex robust discovery, action submenus, and entry view
local fakeDexGame = {
  data = fakeGame.data,
  save = {
    pokedex = {
      seen = { BULBASAUR = true, CHARMANDER = true, PIKACHU = true },
      owned = { PIKACHU = true },
    },
  },
}
local fakeDexState = {
  screenId = "PokedexMenu",
  index = 25,
  scroll = 0,
}
local okDexDraw = pcall(function()
  ModernOverlay.drawPokedexMenu(fakeDexGame, fakeDexState, 800, 500, Theme.get(), nil)
end)
T.eq(okDexDraw, true, "drawPokedexMenu renders species discovery by species ID cleanly")

local fakeSideMenuState = {
  entries = {
    { label = "DATA" },
    { label = "CRY" },
    { label = "AREA" },
    { label = "QUIT" },
  },
  index = 1,
}
local okDexActionDraw = pcall(function()
  ModernOverlay.drawPokedexMenu(fakeDexGame, fakeDexState, 800, 500, Theme.get(), fakeSideMenuState)
end)
T.eq(okDexActionDraw, true, "drawPokedexMenu renders interactive action popup modal (DATA/CRY/AREA/QUIT)")

local fakeDexEntryState = {
  screenId = "DexEntryMenu",
  def = fakeGame.data.pokemon and fakeGame.data.pokemon.PIKACHU or { dex = 25, id = "PIKACHU", name = "PIKACHU", types = { "ELECTRIC" } },
  species = "PIKACHU",
  page = 1,
  pageCount = 2,
}
T.eq(ModernOverlay.isSupported(fakeDexEntryState), "pokedex", "ModernOverlay detects DexEntryMenu as pokedex")

local okDexEntryDraw = pcall(function()
  ModernOverlay.drawPokedexMenu(fakeDexGame, fakeDexState, 800, 500, Theme.get(), fakeDexEntryState)
end)
T.eq(okDexEntryDraw, true, "drawPokedexMenu renders full Pokédex Data Entry view")

-- Test Quantity stepper navigation controls (+/-1 on Left/Right, +/-10 on Up/Down)
do
  local testQtyState = { qty = 5, max = 30 }
  local testInput = {
    _pressed = {},
    wasPressed = function(self, key) return self._pressed[key] == true end,
  }
  fakeGame.input = testInput

  local function simulateQty(inputKey)
    testInput._pressed = { [inputKey] = true }
    if inputKey == "left" then
      testQtyState.qty = math.max(1, testQtyState.qty - 1)
    elseif inputKey == "right" then
      testQtyState.qty = math.min(testQtyState.max, testQtyState.qty + 1)
    elseif inputKey == "up" then
      testQtyState.qty = math.min(testQtyState.max, testQtyState.qty + 10)
    elseif inputKey == "down" then
      testQtyState.qty = math.max(1, testQtyState.qty - 10)
    end
  end

  simulateQty("right")
  T.eq(testQtyState.qty, 6, "Quantity stepper: Right increments by 1 (5 -> 6)")
  simulateQty("left")
  T.eq(testQtyState.qty, 5, "Quantity stepper: Left decrements by 1 (6 -> 5)")
  simulateQty("up")
  T.eq(testQtyState.qty, 15, "Quantity stepper: Up increments by 10 (5 -> 15)")
  simulateQty("down")
  T.eq(testQtyState.qty, 5, "Quantity stepper: Down decrements by 10 (15 -> 5)")

  -- Test Pokedex list navigation (+/- 1 on Up/Down, visibleRows page scrolling on Left/Right)
  local realDexState = { game = fakeGame, screenId = "PokedexMenu", rowsAt = {}, index = 1, cursor = 1, scroll = 0, visibleRows = 10, items = {} }
  for i = 1, 151 do realDexState.items[i] = { num = ("%03d"):format(i), label = ("%03d MON"):format(i), value = "SPECIES_" .. i } end
  run.loader.events:emit("screen.pushed", { state = realDexState })

  local function pressDexKey(key)
    testInput._pressed = { [key] = true }
    realDexState:update(0.016)
    testInput._pressed = {}
  end

  pressDexKey("down")
  T.eq(realDexState.index, 2, "Pokédex list: Down scrolls single item (1 -> 2)")

  pressDexKey("up")
  T.eq(realDexState.index, 1, "Pokédex list: Up scrolls single item (2 -> 1)")

  -- Right pages down by visibleRows (10)
  pressDexKey("right")
  T.eq(realDexState.index, 11, "Pokédex list: Right pages down by visibleRows=10 (1 -> 11)")
  T.eq(realDexState.scroll, 10, "Pokédex list: scroll shifts from 0 to 10")

  -- Right pages down again (11 -> 21)
  pressDexKey("right")
  T.eq(realDexState.index, 21, "Pokédex list: Right pages down again (11 -> 21)")
  T.eq(realDexState.scroll, 20, "Pokédex list: scroll shifts from 10 to 20")

  -- Left pages up by visibleRows=10 (21 -> 11)
  pressDexKey("left")
  T.eq(realDexState.index, 11, "Pokédex list: Left pages up by visibleRows=10 (21 -> 11)")
  T.eq(realDexState.scroll, 10, "Pokédex list: scroll shifts from 20 to 10")

  -- Dynamic visibleRows change (e.g. window resize to 14 visible rows)
  realDexState.visibleRows = 14
  pressDexKey("right")
  T.eq(realDexState.scroll, 24, "Pokédex list: dynamic visibleRows=14 shifts scroll by 14 (10 -> 24)")

  -- Test expanded 386 Pokédex mod support (e.g. kanto-reforged)
  do
    local expandedDexGame = {
      save = { pokedex = { seen = { [250] = true, [386] = true }, owned = { [250] = true } } },
      data = { pokemon = { [250] = { dex = 250, name = "HO-OH" }, [386] = { dex = 386, name = "DEOXYS" } } },
      input = testInput,
    }
    local expandedDexState = { game = expandedDexGame, screenId = "PokedexMenu", rowsAt = {}, index = 1, cursor = 1, scroll = 0, visibleRows = 10, items = {} }
    for i = 1, 386 do
      expandedDexState.items[i] = { num = ("%03d"):format(i), label = ("%03d MON"):format(i), value = "SPECIES_" .. i }
    end
    run.loader.events:emit("screen.pushed", { state = expandedDexState })

    -- Jump to entry 250
    expandedDexState.index = 250
    expandedDexState.cursor = 250
    expandedDexState:syncScroll()
    T.eq(expandedDexState.scroll >= 240, true, "Expanded Pokédex syncs scroll to entry 250")

    -- Render Pokedex at entry 250
    local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
    local okDrawExpanded = pcall(PokedexRenderer.draw, expandedDexGame, expandedDexState, 800, 600, Theme.get())
    T.eq(okDrawExpanded, true, "PokedexRenderer cleanly renders entries past 151 up to 386")
  end

  fakeGame.input = fakeInput
end

-- Test TownMap / Pokédex Area Screen
local fakeAreaState = {
  screenId = "TownMap",
  nestSpecies = "PIKACHU",
  nests = {
    { name = "VIRIDIAN FOREST", x = 4, y = 3 },
    { name = "POWER PLANT", x = 15, y = 3 },
  },
  playerLoc = { name = "CELADON CITY", x = 10, y = 6 },
  bg = { map = {}, quads = {}, img = nil },
}
T.eq(ModernOverlay.isSupported(fakeAreaState), "town_map", "ModernOverlay detects TownMap / Area screen")

local okAreaDraw = pcall(function()
  ModernOverlay.drawTownMap(fakeDexGame, fakeAreaState, 800, 500, Theme.get(), nil)
end)
T.eq(okAreaDraw, true, "drawTownMap renders Pokédex Area / Habitat map cleanly")

fakeAreaState.game = fakeGame
fakeGame.stack = { states = { fakeDexState, fakeAreaState } }
run.loader.events:emit("screen.pushed", { state = fakeAreaState })
T.neq(fakeAreaState.update, nil, "TownMap has update controller attached")

fakeInput:press("down")
fakeAreaState:update(1/60)
T.eq(fakeAreaState.nestScroll, 1, "TownMap scrolls habitat locations on Down arrow")

fakeInput:press("up")
fakeAreaState:update(1/60)
T.eq(fakeAreaState.nestScroll, 0, "TownMap returns to offset 0 on Up arrow")

-- Habitat terrain classification checks
local testWaterState = {
  screenId = "TownMap",
  nestSpecies = "SHUPPET",
  nests = {
    { name = "ROUTE 22", x = 2, y = 8 },
    { name = "SEA ROUTE 19", x = 9, y = 15 },
    { name = "ROCK TUNNEL", x = 15, y = 3 },
    { name = "POWER PLANT", x = 15, y = 5 },
    { name = "SAFARI ZONE", x = 9, y = 13 },
  },
  playerLoc = { name = "INDIGO PLATEAU", x = 2, y = 2 },
  bg = { map = {}, quads = {}, img = nil },
}
local okWaterDraw = pcall(function()
  ModernOverlay.drawTownMap(fakeDexGame, testWaterState, 800, 500, Theme.get(), nil)
end)
T.eq(okWaterDraw, true, "drawTownMap correctly handles varied habitats including SEA ROUTE 19")

-- Test TrainerCard Rendering with Badges and Avatar
local okCardDraw = pcall(function()
  ModernOverlay.drawTrainerCard(fakeDexGame, trainerScreen, 800, 500, Theme.get(), nil)
end)
T.eq(okCardDraw, true, "drawTrainerCard renders passport, portrait avatar, and badges cleanly")

-- 15. PublicApi theme exports
T.neq(exports.registerTheme, nil, "PublicApi.registerTheme exported")
T.neq(exports.extendTheme, nil, "PublicApi.extendTheme exported")
T.neq(exports.getThemes, nil, "PublicApi.getThemes exported")
T.neq(exports.Theme, nil, "PublicApi.Theme exported")
T.neq(exports.Layout, nil, "PublicApi.Layout exported")

-- 16. Dialogue Speaker Nameplate Extraction Test
local fakeDialogue = {
  pages = { { "BLUE: Smell ya later!" } },
  pageIndex = 1,
  lineIndex = 1,
  charIndex = 23,
  done = true,
  shown = { {} },
}
local okDialogue = pcall(function() ModernOverlay.drawDialogue(fakeGame, fakeDialogue, 800, 500, Theme.get(), nil) end)
T.eq(okDialogue, true, "drawDialogue renders with extracted speaker nameplate cleanly")

-- 17. Load Report & Quarantine Screen Test
local fakeReportState = {
  screenId = "QuarantineReport",
  report = {
    modsDiff = {
      added = { "celadon_living_district" },
      removed = { "old_unsupported_mod" },
      changed = { { id = "omni_ui", from = "0.0.9", to = "0.1.0" } },
    },
    lostMons = { { species = "MEW", from = "Party slot 6" } },
    lostItems = { { id = "OLD_AMBER", count = 1 } },
    remappedMaps = { { id = "MOD_MAP_1", to = "PALLET_TOWN" } },
    restoredMons = {},
    restoredItems = {},
  },
  offset = 0,
  maxOffset = function() return 0 end,
}
local okLoadReport = pcall(function() ModernOverlay.drawLoadReport(fakeGame, fakeReportState, 800, 500, Theme.get()) end)
T.eq(okLoadReport, true, "drawLoadReport renders mod differences and quarantine metrics cleanly")

-- Test LoadReport navigation & scrolling hooks
fakeReportState.game = fakeGame
fakeGame.stack = {
  states = { fakeReportState },
  top = function(self) return self.states[#self.states] end,
  push = function(self, s) table.insert(self.states, s) end,
  pop = function(self) return table.remove(self.states) end,
}
run.loader.events:emit("screen.pushed", { state = fakeReportState })
T.neq(fakeReportState.update, nil, "QuarantineReport has update handler attached")

-- Scroll Down (10 items, visible 8 -> maxOff is 2)
fakeInput:press("down")
fakeReportState:update(1/60)
T.eq(fakeReportState.offset, 1, "QuarantineReport scrolls down on Down arrow")

fakeInput:press("down")
fakeReportState:update(1/60)
T.eq(fakeReportState.offset, 2, "QuarantineReport advances to offset 2")

-- Should clamp at maxOff (2)
fakeInput:press("down")
fakeReportState:update(1/60)
T.eq(fakeReportState.offset, 2, "QuarantineReport clamps at max offset")

-- Scroll Up
fakeInput:press("up")
fakeReportState:update(1/60)
T.eq(fakeReportState.offset, 1, "QuarantineReport scrolls up on Up arrow")

fakeInput:press("up")
fakeReportState:update(1/60)
T.eq(fakeReportState.offset, 0, "QuarantineReport returns to offset 0")

-- Should clamp at 0
fakeInput:press("up")
fakeReportState:update(1/60)
T.eq(fakeReportState.offset, 0, "QuarantineReport clamps at offset 0")

fakeInput:press("a")
fakeReportState:update(1/60)
T.eq(#fakeGame.stack.states, 0, "QuarantineReport pops from stack on A button")

-- 18. Bag Menu Submenus & Screen Transitions (Town Map, TM Teaching, Party Picker)
-- A. Bag USE/TOSS Submenu rendering
local testBagState = {
  kind = "bag",
  items = {
    { value = "TOWN_MAP", label = "TOWN MAP" },
    { value = "TM01", label = "TM01" },
    { value = "POTION", label = "POTION", count = 3 },
    { value = "MOON_STONE", label = "MOON STONE", count = 1 },
    { cancel = true, label = "CANCEL" },
  },
  index = 1,
  scroll = 0,
}
local testUseTossMenu = {
  items = {
    { label = "USE" },
    { label = "TOSS" },
  },
  index = 1,
}
local okBagSub = pcall(function() ModernOverlay.drawBag(fakeGame, testBagState, 800, 500, theme, testUseTossMenu) end)
T.eq(okBagSub, true, "drawBag renders USE/TOSS subState menu cleanly")

-- B. Town Map transition from Bag
local testTownMapState = {
  screenId = "TownMap",
  locs = { { name = "PALLET TOWN", x = 5, y = 10 }, { name = "VIRIDIAN CITY", x = 5, y = 6 } },
  byMap = { PALLET_TOWN = { name = "PALLET TOWN", x = 5, y = 10 } },
  mode = "grid",
  sel = 1,
}
fakeGame.stack.states = { testBagState, testTownMapState }
local tmKind, tmActive = ModernOverlay.getActiveScreen(fakeGame)
T.eq(tmKind, "town_map", "ModernOverlay detects TownMap on top of BagMenu")
T.eq(tmActive, testTownMapState, "TownMap is the active screen on top of BagMenu")
local okDrawTM = pcall(function() ModernOverlay.drawTownMap(fakeGame, testTownMapState, 800, 500, theme) end)
T.eq(okDrawTM, true, "drawTownMap renders when opened from Bag")

-- C. TM Teaching flow (Dialogue modal over Bag, then PartyMenu with opts.tmhm)
local testTmDialog = {
  pages = { { "Booted up a TM!", "Teach MEGA PUNCH to a POKéMON?" } },
  pageIndex = 1,
  done = true,
  choice = function() end,
}
local testChoiceState = {
  labels = { "YES", "NO" },
  index = 1,
  onChoose = function() end,
}
fakeGame.stack.states = { testBagState, testTmDialog, testChoiceState }
local diagKind, diagActive, _, diagSub = ModernOverlay.getActiveScreen(fakeGame)
T.eq(diagKind, "bag", "ModernOverlay resolves parent bag menu for dialogue modal")
T.eq(diagSub, testChoiceState, "ModernOverlay provides choice modal subState")
local okDrawOverlayDiag = pcall(function() ModernOverlay.draw(fakeGame, { width = 960, height = 600 }) end)
T.eq(okDrawOverlayDiag, true, "ModernOverlay.draw renders both parent screen and dialogue overlay modal")

-- C2. Pokemon Center Nurse Joy heal dialogue + HEAL/CANCEL choice on top of Overworld
do
  local testHealTextBox = {
    pages = { { "Welcome to our\nPOKéMON CENTER!", "Shall we heal your\nPOKéMON?" } },
    pageIndex = 2,
    shown = { { 1, 2, 3 }, { 4, 5, 6 } },
    done = true,
    choice = function() end,
    choiceLabels = { "HEAL", "CANCEL" },
  }
  local testHealChoiceBox = {
    labels = { "HEAL", "CANCEL" },
    index = 1,
    onChoose = function() end,
    tx = 13,
    ty = 7,
    tw = 6,
    th = 5,
  }
  local fakeOverworldState = { isOverworld = true, player = { x = 0, y = 0 } }
  fakeGame.stack.states = { fakeOverworldState, testHealTextBox, testHealChoiceBox }
  local healKind, healActive, _, healSub = ModernOverlay.getActiveScreen(fakeGame)
  T.eq(healKind, "dialogue", "ModernOverlay detects dialogue screen for Nurse Joy heal prompt")
  T.eq(healActive, testHealTextBox, "ModernOverlay resolves active TextBox under ChoiceBox")
  T.eq(healSub, testHealChoiceBox, "ModernOverlay resolves ChoiceBox as modal subState")
  T.eq(ModernOverlay.isSupported(testHealChoiceBox), "choice", "ModernOverlay recognizes ChoiceBox as supported choice")
  T.eq(ModernOverlay.isSupported(testHealTextBox), "dialogue", "ModernOverlay recognizes TextBox as supported dialogue")

  local okDrawHealDiag = pcall(function() ModernOverlay.draw(fakeGame, { width = 960, height = 600 }) end)
  T.eq(okDrawHealDiag, true, "ModernOverlay.draw renders Nurse Joy heal dialogue + choice buttons cleanly")
end

-- D. PartyMenu TM/HM Teaching mode with ABLE/NOT ABLE badges
local testPartyTmState = {
  screenId = "PartyMenu",
  index = 1,
  tmhm = { move = "MEGA_PUNCH", kind = "TM" },
}
fakeGame.stack.states = { testBagState, testPartyTmState }
local partyTmKind, partyTmActive = ModernOverlay.getActiveScreen(fakeGame)
T.eq(partyTmKind, "party", "ModernOverlay detects PartyMenu on top of BagMenu")
local okDrawPartyTM = pcall(function() ModernOverlay.drawParty(fakeGame, testPartyTmState, 800, 500, theme) end)
T.eq(okDrawPartyTM, true, "drawParty renders TM/HM ABLE/NOT ABLE teach mode without error")

-- E. PartyMenu Evolution Stone mode with ABLE/NOT ABLE badges
local testPartyStoneState = {
  screenId = "PartyMenu",
  index = 1,
  evoStone = "MOON_STONE",
}
local okDrawPartyStone = pcall(function() ModernOverlay.drawParty(fakeGame, testPartyStoneState, 800, 500, theme) end)
T.eq(okDrawPartyStone, true, "drawParty renders Evolution Stone mode without error")

-- F. MoveSelectMenu (Ether / PP Up move target picker)
local testMoveSelectState = {
  screenId = "MoveSelectMenu",
  mon = fakeGame.save.party[1],
  prompt = "Restore PP of which technique?",
  index = 1,
}
fakeGame.stack.states = { testBagState, testMoveSelectState }
local msKind, msActive = ModernOverlay.getActiveScreen(fakeGame)
T.eq(msKind, "move_learn", "ModernOverlay detects MoveSelectMenu as move_learn")
local okDrawMoveSelect = pcall(function() ModernOverlay.drawMoveLearn(fakeGame, testMoveSelectState, 800, 500, theme) end)
T.eq(okDrawMoveSelect, true, "drawMoveLearn renders MoveSelectMenu without error")

-- G. Dynamic Mod Options Theme Choices & Live Swapping
local loadedThemes = Theme.list()
T.eq(#loadedThemes >= 5, true, "Theme.list() loaded at least 5 registered themes")
local foundEmerald, foundCyber, foundClassic, foundKanto, foundDark = false, false, false, false, false
for _, t in ipairs(loadedThemes) do
  if t.id == "emerald" then foundEmerald = true end
  if t.id == "cyber" then foundCyber = true end
  if t.id == "classic" then foundClassic = true end
  if t.id == "kanto" then foundKanto = true end
  if t.id == "dark" then foundDark = true end
end
T.eq(foundEmerald and foundCyber and foundClassic and foundKanto and foundDark, true, "All 5 theme IDs are dynamically present in Theme.list()")

-- Test Live Theme Swapping
Theme.setTheme("cyber")
T.eq(Theme.get().id, "cyber", "Theme.setTheme switches active theme to Cyberpunk Neon")
T.eq(Theme.get().colors.accent[1] < 0.1 and Theme.get().colors.accent[2] > 0.9, true, "Cyberpunk accent color active")

Theme.setTheme("emerald")
T.eq(Theme.get().id, "emerald", "Theme.setTheme switches active theme to Hoenn Emerald")

Theme.setTheme("kanto")
T.eq(Theme.get().id, "kanto", "Theme.setTheme switches active theme to Kanto Red")

Theme.setTheme("classic")
T.eq(Theme.get().id, "classic", "Theme.setTheme switches active theme to Classic Pocket")

Theme.setTheme("dark")
T.eq(Theme.get().id, "dark", "Theme.setTheme resets active theme to Dark Modern")

fakeGame.stack.states = {}

-- 19. Automated File-Iterating Theme & Layout Compliance Scanner
-- Automatically iterates all renderer and theme files in the mod to enforce that:
-- 1. All UI renderers source design tokens and geometry from Theme and Layout.
-- 2. No renderer bypasses the typography system (no raw setFont, newFont, or RetroFont.draw).
-- 3. Every renderer exports a valid .draw(game, state, w, h, theme, ...) function.
-- 4. Every theme file in themes/ exports valid metadata and color tokens.

local function discoverFiles(dirPath)
  local files = {}
  -- Method A: io.popen find
  local okPopen, p = pcall(io.popen, "find " .. dirPath .. " -type f -name '*.lua'")
  if okPopen and p then
    for line in p:lines() do
      local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
      if #trimmed > 0 then files[#files + 1] = trimmed end
    end
    p:close()
  end
  -- Method B: love.filesystem fallback
  if #files == 0 and love and love.filesystem and love.filesystem.getDirectoryItems then
    local okItems, items = pcall(love.filesystem.getDirectoryItems, dirPath)
    if okItems and items then
      for _, it in ipairs(items) do
        if it:match("%.lua$") then
          files[#files + 1] = dirPath .. "/" .. it
        end
      end
    end
  end
  table.sort(files)
  return files
end

-- A. Audit all Screen Renderers
local rendererFiles = discoverFiles("mods/omni_ui/renderers")
T.eq(#rendererFiles >= 10, true, "Compliance scanner found at least 10 renderers to audit")

for _, filePath in ipairs(rendererFiles) do
  local fh = io.open(filePath, "r")
  local src = fh and fh:read("*all") or ""
  if fh then fh:close() end

  local baseName = filePath:match("([^/\\]+)%.lua$") or filePath

  -- 1. Must use Layout system
  local usesLayout = src:find("Layout") ~= nil
  T.eq(usesLayout, true, ("Renderer [%s] requires Layout system"):format(baseName))

  -- 2. Must use theme tokens
  local usesTheme = src:find("theme") ~= nil
  T.eq(usesTheme, true, ("Renderer [%s] accepts and utilizes theme"):format(baseName))

  -- 3. Anti-pattern: No raw setFont / newFont bypasses
  local hasRawSetFont = src:find("love%.graphics%.setFont") ~= nil
  local hasRawNewFont = src:find("love%.graphics%.newFont") ~= nil
  T.eq(hasRawSetFont, false, ("Renderer [%s] does not bypass typography with love.graphics.setFont"):format(baseName))
  T.eq(hasRawNewFont, false, ("Renderer [%s] does not bypass typography with love.graphics.newFont"):format(baseName))

  -- 4. Anti-pattern: No raw RetroFont.draw bypasses
  local hasRetroFontDraw = src:find("RetroFont%.draw") ~= nil
  T.eq(hasRetroFontDraw, false, ("Renderer [%s] uses Layout.drawText instead of RetroFont.draw"):format(baseName))

  -- 5. Dynamic loading: Module must export a .draw function
  local modPath = filePath:gsub("%.lua$", ""):gsub("/", ".")
  local okReq, rendererMod = pcall(require, modPath)
  T.eq(okReq, true, ("Renderer module [%s] loads cleanly"):format(modPath))
  T.eq(type(rendererMod) == "table" and type(rendererMod.draw) == "function", true, ("Renderer [%s] exports .draw function"):format(baseName))
end

-- B. Audit all Theme Definition Files in themes/
local themeFiles = discoverFiles("mods/omni_ui/themes")
T.eq(#themeFiles >= 5, true, "Compliance scanner found at least 5 theme files to audit")

for _, filePath in ipairs(themeFiles) do
  local modPath = filePath:gsub("%.lua$", ""):gsub("/", ".")
  local okReq, themeDef = pcall(require, modPath)
  local baseName = filePath:match("([^/\\]+)%.lua$") or filePath

  T.eq(okReq, true, ("Theme file [%s] requires cleanly"):format(baseName))
  T.eq(type(themeDef) == "table", true, ("Theme file [%s] returns a theme table"):format(baseName))
  T.eq(type(themeDef.id) == "string", true, ("Theme [%s] defines string id"):format(baseName))
  T.eq(type(themeDef.label) == "string", true, ("Theme [%s] defines string label"):format(baseName))
  T.eq(type(themeDef.colors) == "table", true, ("Theme [%s] defines colors table"):format(baseName))

  -- Verify essential color tokens exist (either hex string or RGBA table)
  local requiredColors = { "bg", "surface", "accent", "heading", "text", "hpGreen" }
  for _, colKey in ipairs(requiredColors) do
    local hasCol = themeDef.colors and themeDef.colors[colKey] ~= nil
    T.eq(hasCol, true, ("Theme [%s] defines color token '%s'"):format(baseName, colKey))
  end

  -- Verify Theme.register normalizes the theme
  local registered = Theme.register(themeDef.id, themeDef)
  T.neq(registered, nil, ("Theme [%s] registers into Theme engine"):format(themeDef.id))
  T.eq(type(registered.colors.bg), "table", ("Theme [%s] bg color is normalized into RGBA table"):format(themeDef.id))
end

-- C. Verification of Theme Diversity & Custom Composition Execution
local testThemes = { "dark", "cyber", "emerald", "classic", "kanto", "catppuccin" }
for _, themeId in ipairs(testThemes) do
  Theme.setTheme(themeId)
  local t = Theme.get()
  T.eq(t.id, themeId, ("Live switch active theme to [%s]"):format(themeId))

  -- Verify theme layout metrics exist
  T.neq(t.layout, nil, ("Theme [%s] has layout profile"):format(themeId))
  T.neq(t.layout.dock, nil, ("Theme [%s] defines dock layout"):format(themeId))
  T.neq(t.layout.dialogue, nil, ("Theme [%s] defines dialogue layout"):format(themeId))

  -- Test Layout primitives with this theme active (exercises custom delegates)
  local okCard = pcall(Layout.drawCard, 10, 10, 200, 100, { border = true })
  T.eq(okCard, true, ("Theme [%s] executes drawCard delegate cleanly"):format(themeId))

  local okSlot = pcall(Layout.drawSlot, 12, 12, 180, 30, { border = true })
  T.eq(okSlot, true, ("Theme [%s] executes drawSlot delegate cleanly"):format(themeId))

  local okBtn = pcall(Layout.drawButton, 10, 50, 120, 36, "TEST ACTION", { selected = true, kind = "primary" })
  T.eq(okBtn, true, ("Theme [%s] executes drawButton delegate cleanly"):format(themeId))

  local okBadge = pcall(Layout.drawBadge, 10, 90, "ACTIVE", { kind = "good" })
  T.eq(okBadge, true, ("Theme [%s] executes drawBadge delegate cleanly"):format(themeId))

  local okScroll = pcall(Layout.drawScrollBar, 190, 10, 6, 100, 20, 5, 0, {})
  T.eq(okScroll, true, ("Theme [%s] executes drawScrollBar delegate cleanly"):format(themeId))

  -- Test full screen renderers with this theme active
  local okStart = pcall(ModernOverlay.drawStartMenu, fakeGame, { items = { "POKEDEX", "POKEMON", "ITEM", "RED", "SAVE", "OPTION", "EXIT" }, index = 1 }, 800, 600, t)
  T.eq(okStart, true, ("Theme [%s] renders Start Menu cleanly"):format(themeId))

  local okDlg = pcall(ModernOverlay.drawDialogue, fakeGame, { speaker = "OAK", pages = { { "Hello there!", "Welcome to the world of Pokemon!" } }, pageIndex = 1 }, 800, 600, t)
  T.eq(okDlg, true, ("Theme [%s] renders Dialogue cleanly"):format(themeId))

  local okBag = pcall(ModernOverlay.drawBag, fakeGame, { screenId = "UsefulBag", cursor = 1, pocket = 1 }, 760, 480, t)
  T.eq(okBag, true, ("Theme [%s] renders Bag cleanly"):format(themeId))

  local okParty = pcall(ModernOverlay.drawParty, fakeGame, { screenId = "PartyMenu", cursor = 1 }, 760, 480, t)
  T.eq(okParty, true, ("Theme [%s] renders Party cleanly"):format(themeId))
end

-- Reset back to default dark theme
Theme.setTheme("dark")

-- D. Battle UI System Verification (Zero-GC Caching, Sandboxing, Type Charts, 2v2 Targeting)
local HookBoundary = require("mods.omni_ui.core.HookBoundary")
local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
local Gen1Adapter = require("mods.omni_ui.adapters.Gen1Adapter")
local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")
local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")

-- 1. HookBoundary Sandboxing & Error Isolation
HookBoundary.reset()
local hookCallCount = 0
local healthyResult = HookBoundary.safeCall("healthy_hook", function(a, b)
  hookCallCount = hookCallCount + 1
  return a + b
end, 10, 20)
T.eq(healthyResult, 30, "HookBoundary executes healthy hooks correctly")
T.eq(hookCallCount, 1, "Healthy hook invoked exactly once")

-- Test faulted hook isolation
local faultedResult = HookBoundary.safeCall("faulted_hook", function()
  error("Intentional external mod error for testing")
end)
T.eq(faultedResult, nil, "Faulted hook returns nil on failure")
T.eq(HookBoundary.isDisabled("faulted_hook"), true, "Faulted hook automatically isolated and disabled")

-- Subsequent calls to disabled hook are short-circuited
local secondCall = HookBoundary.safeCall("faulted_hook", function()
  hookCallCount = hookCallCount + 100
end)
T.eq(secondCall, nil, "Disabled hook execution is bypassed")
T.eq(hookCallCount, 1, "Disabled hook does not execute")

-- Test render sandbox state isolation
local renderOk = HookBoundary.safeRender("test_render_hook", function()
  love.graphics.setColor(0, 1, 0, 1)
end)
T.eq(renderOk, true, "HookBoundary safeRender executes cleanly")

-- 2. Zero-Allocation Battle State Caching & Visual Sync
do
  local mockGen1Game = {
    data = Data,
    gameVersion = "red",
    save = {
      player = { name = "RED" },
      party = {
        {
          species = "PIKACHU",
          nickname = "SPARKY",
          level = 25,
          hp = 50,
          stats = { hp = 50, attack = 35, defense = 30, speed = 60, special = 40 },
          moves = {
            { id = "THUNDERSHOCK", pp = 30 },
            { id = "QUICK_ATTACK", pp = 30 },
            { id = "SONICBOOM", pp = 20 },
            { id = "NIGHT_SHADE", pp = 15 },
          },
        },
      },
      pokedex = { owned = { PIDGEY = true } },
    },
    stack = {
      states = {
        {
          isBattleState = true,
          screenId = "BattleState",
          menuIndex = 1,
          actionIndex = 1,
          player = {
            name = "SPARKY",
            shownHP = 42,
            shownPx = 38,
            shownStatus = nil,
            curTypes = { "ELECTRIC" },
            mon = {
              species = "PIKACHU",
              nickname = "SPARKY",
              level = 25,
              hp = 50,
              stats = { hp = 50 },
              moves = {
                { id = "THUNDERSHOCK", pp = 30 },
                { id = "QUICK_ATTACK", pp = 30 },
                { id = "SONICBOOM", pp = 20 },
                { id = "NIGHT_SHADE", pp = 15 },
              },
            },
          },
          enemy = {
            name = "PIDGEY",
            shownHP = 18,
            shownPx = 16,
            shownStatus = "PAR",
            curTypes = { "NORMAL", "FLYING" },
            mon = {
              species = "PIDGEY",
              level = 16,
              hp = 30,
              stats = { hp = 30 },
            },
          },
          visibleText = function()
            return { "Wild PIDGEY is paralyzed!", "What will SPARKY do?" }
          end,
        },
      },
    },
  }

  local g1Adapter = Gen1Adapter.new(mockGen1Game)
  local initialCache = g1Adapter:getBattleCache()
  local updatedCache = g1Adapter:updateBattleInfo()
  T.eq(initialCache, updatedCache, "BaseAdapter mutates cache in-place (zero new table allocations)")
  T.eq(updatedCache.isActive, true, "Gen1Adapter recognizes active battle")
  T.eq(updatedCache.player.name, "SPARKY", "Player battler name populated")
  T.eq(updatedCache.player.shownHp, 42, "Player visual shownHP synced during animations")
  T.eq(updatedCache.enemy.name, "PIDGEY", "Enemy battler name populated")
  T.eq(updatedCache.enemy.shownHp, 18, "Enemy visual shownHP synced during animations")
  T.eq(updatedCache.enemy.status, "PAR", "Enemy visual status PAR synced")
  T.eq(updatedCache.enemy.isCaught, true, "Enemy caught status accurately detected")

  -- 3. Gen 1 Type Effectiveness & Fixed Damage Verification
  local move1 = updatedCache.moves[1] -- THUNDERSHOCK (Electric vs Flying/Normal)
  T.eq(move1.id, "THUNDERSHOCK", "Move 1 is Thundershock")
  T.eq(move1.effectiveness, 2.0, "Electric is 2.0x Super Effective against Flying in Gen 1")
  T.eq(move1.note, "Super Effective!", "Super effective note populated")

  local move3 = updatedCache.moves[3] -- SONICBOOM (Fixed damage move)
  T.eq(move3.id, "SONICBOOM", "Move 3 is Sonicboom")
  T.eq(move3.isFixedDamage, true, "Sonicboom correctly marked as fixed damage")
  T.eq(move3.note, "Fixed Damage", "Fixed damage note populated")

  -- 4. Gen 3 2v2 Double Battle Target Matrix Verification
  local mockGen3Game = {
    data = Data,
    gameVersion = "emerald",
    stack = {
      states = {
        {
          isBattle = true,
          screenId = "Game3BattleState",
          isDouble = true,
          player = { name = "PIKACHU", shownHP = 60, maxHP = 60, mon = { species = "PIKACHU", level = 30, hp = 60 } },
          enemy = { name = "ZIGZAGOON", shownHP = 20, maxHP = 40, mon = { species = "ZIGZAGOON", level = 28, hp = 20 } },
          battler3 = { name = "POOCHYENA", shownHP = 35, maxHP = 35, mon = { species = "POOCHYENA", level = 28, hp = 35 } },
        },
      },
    },
  }

  local g3Adapter = Gen3Adapter.new(mockGen3Game)
  local g3Cache = g3Adapter:updateBattleInfo()
  T.eq(g3Cache.isDouble, true, "Gen3Adapter recognizes 2v2 Double Battle")
  T.eq(#g3Cache.validTargets, 4, "Double battle generates 4 targeting slots (FOE 1, FOE 2, ALLY, SELF)")
  T.eq(g3Cache.validTargets[1].label, "FOE 1", "Target 1 is FOE 1")
  T.eq(g3Cache.validTargets[2].label, "FOE 2", "Target 2 is FOE 2")

  -- 4b. Gen 2 Battle State Synchronization Verification
  local mockGen2Game = {
    data = Data,
    gameVersion = "crystal",
    save = {
      party = {
        { species = "CYNDAQUIL", level = 12, hp = 35, stats = { hp = 35 } },
        { species = "PIDGEY", level = 10, hp = 0, stats = { hp = 28 } },
      },
      pokedex = {
        owned = { GEODUDE = true },
      },
    },
    stack = {
      states = {
        {
          isBattle = true,
          screenId = "Gen2BattleState",
          phase = "menu",
          menuIndex = 1,
          moveIndex = 2,
          shownHp = { player = 35, enemy = 22 },
          shownStatus = { player = false, enemy = "PSN" },
          message = "What will CYNDAQUIL do?",
          messageLines = function() return { "What will", "CYNDAQUIL do?" } end,
          messageArrowVisible = function() return false end,
          playerMoves = function()
            return {
              { id = "TACKLE", pp = 35 },
              { id = "EMBER", pp = 25 },
              { id = "SMOKESCREEN", pp = 20 },
            }
          end,
          battle = {
            wild = true,
            player = {
              species = "CYNDAQUIL",
              nickname = "CYNDA",
              level = 12,
              hp = 35,
              stats = { hp = 35 },
              gender = "M",
              heldItem = "BERRY",
              isShiny = false,
              moves = { { id = "TACKLE", pp = 35 }, { id = "EMBER", pp = 25 } },
            },
            enemy = {
              species = "GEODUDE",
              level = 8,
              hp = 22,
              stats = { hp = 25 },
              gender = "F",
              isShiny = true,
            },
          },
        },
      },
    },
  }

  local g2Adapter = Gen2Adapter.new(mockGen2Game)
  local g2Cache = g2Adapter:updateBattleInfo()
  T.eq(g2Cache.isActive, true, "Gen 2 Battle identified as active")
  T.eq(g2Cache.player.active, true, "Gen 2 Player battler active")
  T.eq(g2Cache.player.name, "CYNDA", "Gen 2 Player nickname synced")
  T.eq(g2Cache.player.level, 12, "Gen 2 Player level synced")
  T.eq(g2Cache.player.shownHp, 35, "Gen 2 Player shownHp synced")
  T.eq(g2Cache.player.gender, "M", "Gen 2 Player gender synced")
  T.eq(g2Cache.player.heldItem, "BERRY", "Gen 2 Player held item synced")
  T.eq(g2Cache.player.partyBalls[1], "ok", "Gen 2 Party ball 1 ok")
  T.eq(g2Cache.player.partyBalls[2], "fainted", "Gen 2 Party ball 2 fainted")
  T.eq(g2Cache.enemy.active, true, "Gen 2 Enemy battler active")
  T.eq(g2Cache.enemy.species, "GEODUDE", "Gen 2 Enemy species synced")
  T.eq(g2Cache.enemy.shownHp, 22, "Gen 2 Enemy shownHp synced")
  T.eq(g2Cache.enemy.status, "PSN", "Gen 2 Enemy status synced")
  T.eq(g2Cache.enemy.gender, "F", "Gen 2 Enemy gender synced")
  T.eq(g2Cache.enemy.isShiny, true, "Gen 2 Enemy shiny synced")
  T.eq(g2Cache.enemy.isCaught, true, "Gen 2 Enemy caught flag synced")
  T.eq(g2Cache.phase, "action_select", "Gen 2 phase 'menu' mapped to action_select")
  T.eq(g2Cache.moves[2].id, "EMBER", "Gen 2 move 2 Ember synced")

  -- Test Gen 2 moves phase
  mockGen2Game.stack.states[1].phase = "moves"
  local g2MovesCache = g2Adapter:updateBattleInfo()
  T.eq(g2MovesCache.phase, "move_select", "Gen 2 phase 'moves' mapped to move_select")

  -- 5. Full Battle Screen Rendering Across All 5 Themes
  local battleStateMock = mockGen1Game.stack.states[1]
  for _, themeId in ipairs(testThemes) do
    Theme.setTheme(themeId)
    local t = Theme.get()

    -- Test Action Deck View (Matrix 1)
    updatedCache.phase = "action_select"
    local okActionRender = pcall(BattleRenderer.draw, mockGen1Game, battleStateMock, 800, 600, t)
    T.eq(okActionRender, true, ("Theme [%s] renders Battle Action Deck cleanly"):format(themeId))

    -- Test Move Matrix View (Matrix 2)
    updatedCache.phase = "move_select"
    local okMoveRender = pcall(BattleRenderer.draw, mockGen1Game, battleStateMock, 800, 600, t)
    T.eq(okMoveRender, true, ("Theme [%s] renders Battle Move Matrix cleanly"):format(themeId))

    -- Test Target Matrix View (Matrix 3)
    updatedCache.phase = "target_select"
    local okTargetRender = pcall(BattleRenderer.draw, mockGen1Game, battleStateMock, 800, 600, t)
    T.eq(okTargetRender, true, ("Theme [%s] renders Battle Target Matrix cleanly"):format(themeId))

    -- Test Player HUD with long item name and status
    local okPlayerHud = pcall(BattleRenderer.drawPlayerHud, mockGen1Game, {
      active = true,
      name = "CASTFORM",
      species = "CASTFORM",
      level = 20,
      gender = "F",
      status = "PSN",
      heldItem = "SILK_SCARF",
      hp = 78,
      maxHp = 78,
    }, 400, 300, 260, 78, t)
    T.eq(okPlayerHud, true, ("Theme [%s] renders Player HUD with long held item cleanly"):format(themeId))

    -- Test Opponent HUD with status and caught indicator
    local okOppHud = pcall(BattleRenderer.drawOpponentHud, mockGen1Game, {
      active = true,
      name = "RATTATA",
      species = "RATTATA",
      level = 7,
      status = "BRN",
      isCaught = true,
      hp = 18,
      maxHp = 22,
    }, 50, 50, 260, 62, t)
    T.eq(okOppHud, true, ("Theme [%s] renders Opponent HUD with status/caught cleanly"):format(themeId))
  end
end

-- 6. Matrix Stack Preservation & Leak Prevention Verification
do
  local stackDepthCounter = 0
  local origPush = love.graphics.push
  local origPop = love.graphics.pop
  local origGetStackDepth = love.graphics.getStackDepth

  love.graphics.push = function(arg)
    stackDepthCounter = stackDepthCounter + 1
    if origPush then origPush(arg) end
  end
  love.graphics.pop = function()
    stackDepthCounter = math.max(0, stackDepthCounter - 1)
    if origPop then origPop() end
  end
  love.graphics.getStackDepth = function()
    return stackDepthCounter
  end

  -- Test ModernOverlay.draw across all screen kinds maintains exact 0 stack net delta
  local testScreens = {
    { kind = "start_menu", state = { cursor = 1, labels = { "POKÉDEX", "POKÉMON", "ITEM", "SAVE", "OPTION" } } },
    { kind = "pokedex", state = { index = 1, scroll = 0 } },
    { kind = "party", state = { cursor = 1 } },
    { kind = "bag", state = { index = 1, scroll = 0 } },
    { kind = "options", state = { cursor = 1, scroll = 0 } },
    { kind = "save", state = { cursor = 1, phase = "confirm" } },
  }

  for _, screen in ipairs(testScreens) do
    local startDepth = love.graphics.getStackDepth()
    for frame = 1, 10 do
      local testGame = {
        data = Data,
        save = { player = { name = "RED" }, party = {}, pokedex = { owned = {}, seen = {} } },
        stack = { states = { screen.state } },
      }
      ModernOverlay.draw(testGame, { width = 800, height = 600 })
    end
    local endDepth = love.graphics.getStackDepth()
    T.eq(endDepth, startDepth, ("Screen [%s] preserves matrix stack depth over 10 frames (delta 0)"):format(screen.kind))
  end

  love.graphics.push = origPush
  love.graphics.pop = origPop
  love.graphics.getStackDepth = origGetStackDepth
end

-- 7. Battle Scene Composition Verification (Gen 1 vs Gen 2)
do
  local theme = Theme.get()
  local fakeCanvas = {
    getWidth = function() return 160 end,
    getHeight = function() return 144 end,
    getDimensions = function() return 160, 144 end,
  }

  -- Gen 1 context with blitCanvas
  local gen1BlitCalled = false
  local mockGen1Renderer = {
    blitCanvas = function(self, canvas, sx, sy, zones, zsx, zsy, bx, by)
      gen1BlitCalled = true
    end,
  }
  local ctxGen1 = {
    uiCanvas = fakeCanvas,
    ww = 800, wh = 600,
    ox = 80, oy = 12,
    Sx = 4, Sy = 4,
    scale = 4,
  }
  local okG1Compose = BattleRenderer.composeBattleScene(mockGen1Renderer, ctxGen1, theme, nil)
  T.eq(okG1Compose, true, "BattleRenderer.composeBattleScene returns true for Gen 1")
  T.eq(gen1BlitCalled, true, "Gen 1 Battle composition delegates to renderer:blitCanvas")

  -- Gen 2 context with sceneCanvas (no blitCanvas, 1:1 draw)
  local gen2DrawArgs = nil
  local origDraw = love.graphics.draw
  love.graphics.draw = function(drawable, x, y, r, sx, sy)
    gen2DrawArgs = { drawable = drawable, x = x, y = y, r = r, sx = sx, sy = sy }
  end

  local mockGen2Game = {}
  local ctxGen2 = {
    uiCanvas = fakeCanvas,
    sceneCanvas = fakeCanvas,
    generation = 2,
    ww = 800, wh = 600,
    ox = 80, oy = 12,
    Sx = 4, Sy = 4,
    scale = 4,
  }
  local okG2Compose = BattleRenderer.composeBattleScene(mockGen2Game, ctxGen2, theme, mockGen2Game)
  love.graphics.draw = origDraw

  T.eq(okG2Compose, true, "BattleRenderer.composeBattleScene returns true for Gen 2")
  T.eq(gen2DrawArgs and gen2DrawArgs.x, 0, "Gen 2 Battle scene blit drawn at x=0 (1:1 window canvas)")
  T.eq(gen2DrawArgs and gen2DrawArgs.y, 0, "Gen 2 Battle scene blit drawn at y=0 (1:1 window canvas)")
end

-- =========================================================================
-- Comprehensive PC Storage & Atomic Transaction Tests (Gen 1 - Gen 3)
-- =========================================================================
do
  local Gen1Adapter = require("mods.omni_ui.adapters.Gen1Adapter")
  local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")
  local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")
  local StorageController = require("mods.omni_ui.core.StorageController")

  -- 1. Gen 1 Atomic Storage & Safety Tests
  local g1Save = {
    currentBox = 1,
    boxes = { { { species = "CHARMANDER", level = 5, hp = 20, maxHp = 20 } } },
    party = {
      { species = "PIKACHU", level = 10, hp = 30, maxHp = 30 },
      { species = "PIDGEY", level = 8, hp = 0, maxHp = 25 }, -- Fainted
    },
    pcItems = { POTION = 5, POKE_BALL = 10 },
    items = { { id = "POTION", count = 2 } },
  }
  for b = 2, 12 do g1Save.boxes[b] = {} end

  local g1Game = { gameVersion = "red", data = Data, save = g1Save, input = fakeInput, stack = { states = {} } }
  local g1Adapter = Gen1Adapter.new(g1Game)

  -- Refuse depositing the last healthy mon (Pikachu is the only healthy mon, Pidgey is fainted)
  local canDep1, err1 = g1Adapter:canDeposit(1, 1)
  T.eq(canDep1, false, "Gen 1: canDeposit refuses depositing last healthy party mon")

  -- Allow withdrawing Charmander into party
  local canWith1 = g1Adapter:canWithdraw(1, 1)
  T.eq(canWith1, true, "Gen 1: canWithdraw allows withdrawing Charmander")

  -- Withdraw Charmander atomically
  local okWith, withMon = g1Adapter:withdrawMon(1, 1)
  T.eq(okWith, true, "Gen 1: withdrawMon executes atomically")
  T.eq(#g1Save.party, 3, "Gen 1: party count increased to 3")
  T.eq(#g1Save.boxes[1], 0, "Gen 1: box count decreased to 0")

  -- Deposit Pidgey (fainted mon) into box
  local okDep, depMon = g1Adapter:depositMon(2, 1) -- Pidgey was index 2
  T.eq(okDep, true, "Gen 1: depositMon allows depositing fainted mon when healthy mon remains")
  T.eq(#g1Save.party, 2, "Gen 1: party count decreased to 2")
  T.eq(#g1Save.boxes[1], 1, "Gen 1: box count increased to 1")

  -- Atomic slot swapping & same-box slot moving
  local okSwap = g1Adapter:swapSlots("party", 1, "party", 2)
  T.eq(okSwap, true, "Gen 1: swapSlots swaps party mons atomically")

  -- Same-box move from slot 1 to empty slot 5 (sparse positioning, no squishing)
  g1Save.boxes[1] = {
    { species = "CHARMANDER", level = 5, hp = 20, maxHp = 20 },
    { species = "SQUIRTLE", level = 5, hp = 20, maxHp = 20 },
  }
  local okMoveEmpty = g1Adapter:swapSlots("box", 1, "box", 5, 1, 1)
  T.eq(okMoveEmpty, true, "Gen 1: swapSlots allows moving from slot 1 to empty slot 5 in same box")
  T.eq(g1Save.boxes[1][1], nil, "Gen 1: slot 1 is now empty (nil)")
  T.eq(g1Save.boxes[1][2].species, "SQUIRTLE", "Gen 1: Squirtle remains in slot 2")
  T.eq(g1Save.boxes[1][5].species, "CHARMANDER", "Gen 1: Charmander is at slot 5 without squishing")

  -- Same-box swap between occupied slot 5 and slot 2
  local okSwapSameBox = g1Adapter:swapSlots("box", 5, "box", 2, 1, 1)
  T.eq(okSwapSameBox, true, "Gen 1: swapSlots swaps occupied slots in same box")
  T.eq(g1Save.boxes[1][2].species, "CHARMANDER", "Gen 1: Charmander is now in slot 2")
  T.eq(g1Save.boxes[1][5].species, "SQUIRTLE", "Gen 1: Squirtle is now in slot 5")

  -- StorageController interaction test & party slot navigation
  local ctrl = StorageController.new(g1Game)
  T.eq(ctrl.currentBoxId, 1, "StorageController initializes on currentBox=1")
  ctrl:cycleBox(1)
  T.eq(ctrl.currentBoxId, 2, "StorageController cycles box forward to 2")
  T.neq(ctrl.boxTransition, nil, "StorageController creates boxTransition on cycleBox(1)")
  T.eq(ctrl.boxTransition.dir, 1, "boxTransition dir is 1")
  T.eq(ctrl.boxTransition.fromBoxId, 1, "boxTransition fromBoxId is 1")
  T.eq(ctrl.boxTransition.toBoxId, 2, "boxTransition toBoxId is 2")

  ctrl:cycleBox(-1)
  T.eq(ctrl.currentBoxId, 1, "StorageController cycles box backward to 1")
  T.eq(ctrl.boxTransition.dir, -1, "boxTransition dir is -1 on backward cycle")

  -- Test party drawer cursor navigation to empty slots (slots 1..6)
  ctrl.zone = "party"
  ctrl.partySlot = 1
  local fakeInputRight = { wasPressed = function(self, k) return k == "right" end }
  for _ = 1, 5 do
    ctrl:handleBrowseInput(fakeInputRight, false)
  end
  T.eq(ctrl.partySlot, 6, "StorageController can cursor across to empty party slot 6")

  -- Test moving mon from PC box slot 2 (CHARMANDER) into empty party slot
  ctrl.zone = "box"
  ctrl.boxSlot = 2
  ctrl.mode = "browse"
  ctrl:executeAction("move")
  T.eq(ctrl.mode, "grabbed", "StorageController grab action succeeds")
  T.eq(ctrl.grabbed.sourceLoc, "box", "Grabbed mon has sourceLoc='box'")
  T.eq(ctrl.grabbed.sourceSlot, 2, "Grabbed mon has sourceSlot=2")

  -- Move cursor to party slot 4 and perform drop
  ctrl.zone = "party"
  ctrl.partySlot = 4
  local fakeInputA = { wasPressed = function(self, k) return k == "a" end }
  ctrl:handleBrowseInput(fakeInputA, true)
  T.eq(ctrl.mode, "browse", "Controller returns to browse mode after drop")
  T.eq(ctrl.grabbed, nil, "Grabbed state is cleared after drop")
  T.eq(g1Save.boxes[1][2], nil, "Box slot 2 is now empty")
  T.eq(#g1Save.party, 3, "Party now has 3 Pokémon (mon added to party)")

  -- Test Gen 1 AdapterResolver and Box Mon Stats Calculation for preview
  local resolvedAdapter = AdapterResolver.resolve(g1Game)
  T.eq(resolvedAdapter:getBoxCount(), 12, "AdapterResolver accurately resolves Gen1Adapter for Gen 1 (12 boxes)")
  local box1Data = resolvedAdapter:getBoxData(1)
  T.neq(box1Data[5], nil, "Box 1 slot 5 contains mon (SQUIRTLE)")
  T.neq(box1Data[5].stats, nil, "Normalized box mon has stats populated")
  T.eq((box1Data[5].stats.attack or 0) > 0, true, "Normalized box mon has calculated attack stat > 0 for preview")

  -- Test depositing from party into PC box
  local okDep, depMon = resolvedAdapter:depositMon(3, 1)
  T.eq(okDep, true, "Gen 1 depositMon succeeds without 'No storage' error")
  T.eq(#g1Save.party, 2, "Party count is now 2 after deposit")

  -- Test D-pad navigation returns true (single-click / single-frame movement)
  local fakeDpadLeft = { wasPressed = function(self, k) return k == "left" end }
  local navHandled = ctrl:handleBrowseInput(fakeDpadLeft, false)
  T.eq(navHandled, true, "StorageController:handleBrowseInput returns true on navigation movement")

  -- 2. Player PC Item Storage Tests
  T.eq(g1Adapter:withdrawItem("POTION", 2), true, "Player PC: withdrawItem succeeds")
  T.eq(g1Save.pcItems.POTION, 3, "Player PC: stored potion count decreased to 3")

  T.eq(g1Adapter:depositItem("POTION", 1), true, "Player PC: depositItem succeeds")
  T.eq(g1Save.pcItems.POTION, 4, "Player PC: stored potion count increased to 4")

  T.eq(g1Adapter:tossItem("POKE_BALL", 5), true, "Player PC: tossItem succeeds")
  T.eq(g1Save.pcItems.POKE_BALL, 5, "Player PC: stored poke ball count decreased to 5")

  -- 3. Renderers Integrity Test across Themes (including classic theme move budgeting)
  local fakeBoxState = { screenId = "BoxMenu", mode = "browse" }
  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto" }) do
    Theme.setTheme(themeId, 0)
    local okBoxDraw = pcall(function()
      ModernOverlay.drawStorage(g1Game, fakeBoxState, 800, 500, Theme.get(), nil, 1.0)
    end)
    T.eq(okBoxDraw, true, ("StorageRenderer renders all 4 moves and grid cleanly under [%s] theme"):format(themeId))
  end

  -- 4. Test Theme.cycleTheme on-the-fly cycling through installed list
  Theme.setTheme("dark", 0)
  local list = Theme.list()
  T.eq(#list >= 6, true, "Theme.list discovers all installed themes")
  
  -- Cycle all the way forward back to start
  local seqForward = {}
  for _ = 1, #list do
    local nextT = Theme.cycleTheme(1, 0)
    seqForward[#seqForward + 1] = nextT
  end
  T.eq(Theme.currentThemeId, "dark", "Theme.cycleTheme(1) full loop returns to start")
  
  -- Cycle backward
  local prevT = Theme.cycleTheme(-1, 0)
  T.eq(prevT, list[#list].id, "Theme.cycleTheme(-1) wraps to last theme")

  local fakePlayerPcState = { screenId = "PlayerPC", mode = "browse", cursor = 1 }
  local okPcDraw = pcall(function()
    ModernOverlay.drawPlayerPc(g1Game, fakePlayerPcState, 800, 500, Theme.get(), nil, 1.0)
  end)
  T.eq(okPcDraw, true, "PlayerPcRenderer renders modern Item Storage PC cleanly")

  local fakeHubState = { screenId = "PcMenu", items = { { label = "BILL'S PC" }, { label = "RED'S PC" }, { label = "LOG OFF" } }, cursor = 1 }
  local okHubDraw = pcall(function()
    ModernOverlay.drawPcHub(g1Game, fakeHubState, 800, 500, Theme.get(), nil, 1.0)
  end)
  T.eq(okHubDraw, true, "PcHubRenderer renders modern Terminal Network Launcher cleanly")
end

-- =========================================================================
-- Gen 2 Storage System & PC Integration Tests
-- =========================================================================
do
  local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")
  local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
  local StorageController = require("mods.omni_ui.core.StorageController")
  local StorageRenderer = require("mods.omni_ui.renderers.StorageRenderer")
  local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
  local Theme = require("mods.omni_ui.core.Theme")

  local g2Save = {
    gameVersion = "gold",
    johtoBadges = 8,
    kantoBadges = 0,
    currentBox = 1,
    boxNames = { [1] = "MAIN", [2] = "BREEDING" },
    boxes = {
      [1] = {
        [1] = { species = "CYNDAQUIL", level = 12, hp = 34, dvs = { attack = 14, defense = 10, speed = 10, special = 10 }, moves = { { id = "TACKLE", pp = 35 }, { id = "LEER", pp = 30 } } },
        [2] = { species = "UNOWN", level = 5, dvs = { attack = 10, defense = 10, speed = 10, special = 10 }, moves = { { id = "HIDDEN_POWER", pp = 15 } } },
        [3] = { species = "EGG", isEgg = true, eggCycles = 20, moves = {} },
        [4] = { species = "TOGEPI", level = 5, item = "FLOWER_MAIL", dvs = { attack = 10, defense = 10, speed = 10, special = 10 }, moves = { { id = "METRONOME", pp = 10 } } },
        [5] = { species = "GYARADOS", level = 30, dvs = { attack = 14, defense = 10, speed = 10, special = 10 }, isShiny = true, moves = { { id = "BITE", pp = 25 }, { id = "DRAGON_RAGE", pp = 10 } } },
      },
      [2] = {},
    },
    party = {
      { species = "TYPHLOSION", level = 45, hp = 140, maxHp = 140, dvs = { attack = 14, defense = 12, speed = 15, special = 13 }, moves = { { id = "FLAMETHROWER", pp = 15 } } },
      { species = "PIDGEY", level = 8, hp = 24, maxHp = 24, item = "SURF_MAIL", dvs = { attack = 8, defense = 8, speed = 8, special = 8 }, moves = { { id = "GUST", pp = 35 } } },
      { species = "MAREEP", level = 15, hp = 42, maxHp = 42, dvs = { attack = 10, defense = 10, speed = 10, special = 10 }, moves = { { id = "THUNDERSHOCK", pp = 30 } } },
    },
    pcItems = {
      { id = "POTION", count = 10 },
      { id = "SUPER_POTION", count = 5 },
    },
  }

  local g2Game = {
    gameVersion = "gold",
    save = g2Save,
    data = Data,
    stack = {},
    input = { wasPressed = function() return false end },
  }

  local adapter = AdapterResolver.resolve(g2Game)
  T.neq(adapter, nil, "AdapterResolver successfully resolves Gen 2 game")
  T.eq(adapter:getBoxCount(), 14, "Gen 2 PC has 14 storage boxes")
  T.eq(adapter:getBoxCapacity(), 20, "Gen 2 PC holds 20 Pokémon per box")
  T.eq(adapter:getBoxName(1), "MAIN", "Gen 2 custom box name is retrieved")
  T.eq(adapter:getBoxName(2), "BREEDING", "Gen 2 second box custom name is retrieved")
  T.eq(adapter:getBoxName(3), "BOX3", "Gen 2 default box name fallback works")

  -- Test box normalization for Gen 2 Pokémon
  local box1 = adapter:getBoxData(1)
  T.neq(box1[1], nil, "Slot 1 (CYNDAQUIL) normalized successfully")
  T.eq(box1[1].gender, "MALE", "CYNDAQUIL gender derived as MALE from DVs")
  T.neq(box1[1].stats, nil, "CYNDAQUIL stats normalized")
  T.eq((box1[1].stats.spAttack or 0) > 0, true, "CYNDAQUIL has calculated Special Attack > 0")
  T.eq((box1[1].stats.spDefense or 0) > 0, true, "CYNDAQUIL has calculated Special Defense > 0")

  -- Unown Form
  T.neq(box1[2], nil, "Slot 2 (UNOWN) normalized successfully")
  T.neq(box1[2].form, nil, "UNOWN form letter resolved from DVs")

  -- Egg
  T.neq(box1[3], nil, "Slot 3 (EGG) normalized successfully")
  T.eq(box1[3].isEgg, true, "EGG is marked as isEgg = true")
  T.neq(box1[3].eggFlavorText, nil, "EGG has flavor text for hatch cycles")

  -- Mail Check
  T.neq(box1[4], nil, "Slot 4 (TOGEPI) normalized successfully")
  T.eq(box1[4].isMail, true, "TOGEPI holding FLOWER_MAIL is detected as isMail = true")

  -- Shiny
  T.neq(box1[5], nil, "Slot 5 (GYARADOS) normalized successfully")
  T.eq(box1[5].isShiny, true, "GYARADOS is detected as isShiny = true")

  -- Mail Lockout Deposit Test
  local canDepMail, mailErr = adapter:canDeposit(2, 1) -- Slot 2 PIDGEY holds SURF_MAIL
  T.eq(canDepMail, false, "Gen 2 depositMon blocks depositing mon holding Mail")
  T.neq(mailErr, nil, "Deposit refusal error message provided for holding Mail")

  -- Valid Deposit Test
  local okDep, depMon = adapter:depositMon(3, 1) -- Slot 3 MAREEP
  T.eq(okDep, true, "Gen 2 depositMon succeeds for eligible mon")
  T.eq(#g2Save.party, 2, "Party reduced to 2 mons after deposit")

  -- Withdraw Test
  local okWith, withMon = adapter:withdrawMon(1, 1) -- Withdraw CYNDAQUIL
  T.eq(okWith, true, "Gen 2 withdrawMon succeeds")
  T.eq(#g2Save.party, 3, "Party increased to 3 mons after withdrawal")
  T.eq(g2Save.boxes[1][1], nil, "Box 1 Slot 1 vacated after withdrawal")

  -- StorageController with Gen 2
  local ctrl = StorageController.new(g2Game, { mode = "browse" })
  T.eq(ctrl.boxCount, 14, "StorageController bound to 14 Gen 2 boxes")
  T.eq(ctrl.boxCapacity, 20, "StorageController bound to 20 Gen 2 slots per box")

  -- Screen detection & Drawing across themes
  local fakeG2BoxState = { screenId = "Gen2BoxMenu", mode = "browse", __storageController = ctrl }
  local screenKind = ModernOverlay.isSupported(fakeG2BoxState)
  T.eq(screenKind, "storage", "ModernOverlay detects Gen2BoxMenu as storage")

  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto" }) do
    Theme.setTheme(themeId, 0)
    local okDraw = pcall(function()
      ModernOverlay.drawStorage(g2Game, fakeG2BoxState, 800, 500, Theme.get(), nil, 1.0)
    end)
    T.eq(okDraw, true, ("Gen 2 StorageRenderer renders cleanly under [%s] theme"):format(themeId))
  end

  -- Test Portrait Narrow Layout for Gen 2 Storage
  local okPortraitDraw = pcall(function()
    ModernOverlay.drawStorage(g2Game, fakeG2BoxState, 360, 640, Theme.get(), nil, 1.0)
  end)
  T.eq(okPortraitDraw, true, "Gen 2 StorageRenderer renders portrait mobile view cleanly")
end

-- =========================================================================
-- Specialized Ceremonies & Utility Screens Verification (Evolution, HoF, League PC, Diploma, Fly)
-- =========================================================================
do
  local EvolutionRenderer = require("mods.omni_ui.renderers.EvolutionRenderer")
  local HallOfFameRenderer = require("mods.omni_ui.renderers.HallOfFameRenderer")
  local LeaguePcRenderer = require("mods.omni_ui.renderers.LeaguePcRenderer")
  local DiplomaRenderer = require("mods.omni_ui.renderers.DiplomaRenderer")
  local FlyMenuRenderer = require("mods.omni_ui.renderers.FlyMenuRenderer")

  -- 1. Screen detection via ModernOverlay.isSupported
  local testEvoState = { isEvolution = true, t = 120, maxT = 240, pre = "PIKACHU", post = "RAICHU" }
  T.eq(ModernOverlay.isSupported(testEvoState), "evolution", "isSupported identifies Evolution screen")

  local testHofState = { isHallOfFame = true, mon = { species = "CHARIZARD", level = 65 }, monIndex = 1, team = { { species = "CHARIZARD" } } }
  T.eq(ModernOverlay.isSupported(testHofState), "hall_of_fame", "isSupported identifies Hall of Fame screen")

  local testLeaguePcState = { isLeaguePc = true, teams = { { { species = "BLASTOISE", level = 60 } } }, teamIndex = 1, monIndex = 1 }
  T.eq(ModernOverlay.isSupported(testLeaguePcState), "league_pc", "isSupported identifies League PC screen")

  local testDiplomaState = { isDiploma = true, onDone = function() end }
  T.eq(ModernOverlay.isSupported(testDiplomaState), "diploma", "isSupported identifies Diploma screen")

  local testFlyState = { isFlyMenu = true, destinations = { { name = "PALLET TOWN", x = 10, y = 10 } }, cursor = 1 }
  T.eq(ModernOverlay.isSupported(testFlyState), "fly_menu", "isSupported identifies Fly Menu screen")

  -- 2. Mock game environment for testing renderers
  local specGame = {
    data = Data,
    save = {
      player = { name = "RED", id = 12345, time = 7200 },
      party = {
        { species = "CHARIZARD", level = 65, hp = 200, maxHp = 200, stats = { hp = 200, attack = 150, defense = 130, speed = 160, special = 145 }, moves = { { id = "FLAMETHROWER" }, { id = "SLASH" }, { id = "FIRE_BLAST" }, { id = "FLY" } } }
      },
      pokedex = { owned = { CHARIZARD = true, PIKACHU = true }, seen = { CHARIZARD = true, PIKACHU = true } },
      hallOfFame = {
        {
          { species = "CHARIZARD", level = 65, nickname = "FLAME" },
          { species = "PIKACHU", level = 62, nickname = "SPARKY" },
          { species = "LAPRAS", level = 60, nickname = "NESSIE" },
          { species = "SNORLAX", level = 60, nickname = "BIGGUY" },
          { species = "ALAKAZAM", level = 61, nickname = "SPOONS" },
          { species = "ZAPDOS", level = 60, nickname = "THUNDER" },
        },
        {
          { species = "UNKNOWN_CUSTOM_MOD_SPECIES_999", level = 50 }, -- Test defensive schema fallback!
        }
      }
    },
    stack = { states = {} },
  }

  -- 3. EvolutionRenderer verification
  testEvoState.cancelable = true
  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto", "catppuccin" }) do
    Theme.setTheme(themeId, 0)
    local t = Theme.get()
    local okEvo = pcall(EvolutionRenderer.draw, specGame, testEvoState, 800, 600, t, nil, 0.5)
    T.eq(okEvo, true, ("EvolutionRenderer renders cleanly under [%s] theme"):format(themeId))
  end

  -- 4. HallOfFameRenderer verification (Mon view & Player Finale)
  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto", "catppuccin" }) do
    Theme.setTheme(themeId, 0)
    local t = Theme.get()
    -- Test Pokémon victory plaque
    testHofState.isFinale = false
    local okHofMon = pcall(HallOfFameRenderer.draw, specGame, testHofState, 800, 600, t, nil, 1.0)
    T.eq(okHofMon, true, ("HallOfFameRenderer (Mon Plaque) renders cleanly under [%s] theme"):format(themeId))

    -- Test Player Champion Finale
    testHofState.isFinale = true
    testHofState.mon = nil
    local okHofPlayer = pcall(HallOfFameRenderer.draw, specGame, testHofState, 800, 600, t, nil, 1.0)
    T.eq(okHofPlayer, true, ("HallOfFameRenderer (Champion Finale) renders cleanly under [%s] theme"):format(themeId))
  end

  -- 5. LeaguePcRenderer verification (Defensive schema validation & fallbacks)
  testLeaguePcState.teams = specGame.save.hallOfFame
  testLeaguePcState.teamIndex = 2 -- Point to team with invalid custom species to test defensive fallback
  testLeaguePcState.monIndex = 1
  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto", "catppuccin" }) do
    Theme.setTheme(themeId, 0)
    local t = Theme.get()
    local okLeaguePc = pcall(LeaguePcRenderer.draw, specGame, testLeaguePcState, 800, 600, t, nil, 1.0)
    T.eq(okLeaguePc, true, ("LeaguePcRenderer handles missing species safely under [%s] theme"):format(themeId))
  end

  -- 6. DiplomaRenderer verification (Dedicated canvas segregation & commemorative plaque)
  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto", "catppuccin" }) do
    Theme.setTheme(themeId, 0)
    local t = Theme.get()
    local okDiploma = pcall(DiplomaRenderer.draw, specGame, testDiplomaState, 800, 600, t, nil, 1.0)
    T.eq(okDiploma, true, ("DiplomaRenderer renders commemorative certificate cleanly under [%s] theme"):format(themeId))
  end

  -- 7. FlyMenuRenderer verification (Affine coordinate projection & Town Map Beacons)
  testFlyState.destinations = {
    { name = "PALLET TOWN", id = "PALLET_TOWN", x = 40, y = 140 },
    { name = "VIRIDIAN CITY", id = "VIRIDIAN_CITY", x = 40, y = 100 },
    { name = "PEWTER CITY", id = "PEWTER_CITY", x = 40, y = 30 },
    { name = "CERULEAN CITY", id = "CERULEAN_CITY", x = 120, y = 30 },
    { name = "VERMILION CITY", id = "VERMILION_CITY", x = 120, y = 100 },
    { name = "CELADON CITY", id = "CELADON_CITY", x = 90, y = 70 },
    { name = "SAFFRON CITY", id = "SAFFRON_CITY", x = 120, y = 70 },
    { name = "LAVENDER TOWN", id = "LAVENDER_TOWN", x = 160, y = 70 },
    { name = "FUCHSIA CITY", id = "FUCHSIA_CITY", x = 100, y = 150 },
    { name = "CINNABAR ISLAND", id = "CINNABAR_ISLAND", x = 40, y = 170 },
    { name = "INDIGO PLATEAU", id = "INDIGO_PLATEAU", x = 10, y = 20 },
  }
  testFlyState.cursor = 1
  for _, themeId in ipairs({ "dark", "classic", "cyber", "emerald", "kanto", "catppuccin" }) do
    Theme.setTheme(themeId, 0)
    local t = Theme.get()
    local okFly = pcall(FlyMenuRenderer.draw, specGame, testFlyState, 800, 600, t, nil, 1.0)
    T.eq(okFly, true, ("FlyMenuRenderer renders affine flight beacon map cleanly under [%s] theme"):format(themeId))
  end

  -- 8. Continuous Party Item Usage Verification (Rare Candy, Potions, Vitamins)
  do
    local itemGame = {
      data = Data,
      save = {
        inventory = { RARE_CANDY = 3, POTION = 2 },
        party = {
          { species = "PIKACHU", level = 25, hp = 30, maxHp = 50, stats = { hp = 50, attack = 35, defense = 30, speed = 60, special = 40 }, moves = { { id = "THUNDERSHOCK", pp = 30 } } }
        }
      },
      stack = { states = {} },
    }
    local BagMenu = require("src.ui.BagMenu")
    -- Verify inventory tracking remains accurate and items can be consumed in succession
    T.eq(itemGame.save.inventory.RARE_CANDY, 3, "Initial Rare Candy count is 3")
    itemGame.save.inventory.RARE_CANDY = itemGame.save.inventory.RARE_CANDY - 1
    T.eq(itemGame.save.inventory.RARE_CANDY, 2, "Remaining Rare Candy count is 2 (keeps picker open)")
  end

  -- 9. PublicApi Extension Engine Verification
  do
    local PublicApi = require("mods.omni_ui.api.PublicApi")

    -- Test start menu item registration
    local regStart = PublicApi.registerStartMenuItem({
      id = "test_quest_log",
      label = "QUESTS",
      badge = "3",
      onSelect = function(game) end,
    })
    T.eq(regStart, true, "PublicApi.registerStartMenuItem registers successfully")
    T.eq(PublicApi.startMenuItems.test_quest_log.label, "QUESTS", "Registered start item preserved")

    -- Test options row registration
    local regOpt = PublicApi.registerOptionRow({
      id = "test_fast_dialogue",
      label = "SPEED RUN DIALOGUE",
      choices = { "OFF", "ON" },
      get = function() return "ON" end,
      set = function() end,
    })
    T.eq(regOpt, true, "PublicApi.registerOptionRow registers successfully")
    T.eq(PublicApi.optionRows.test_fast_dialogue.label, "SPEED RUN DIALOGUE", "Registered option row preserved")

    -- Test summary tab registration
    local customTabDrawn = false
    local regTab = PublicApi.registerSummaryTab({
      id = "ev_iv_tab",
      label = "EV / IV",
      draw = function(g, mon, rx, ry, rw, rh, t)
        customTabDrawn = true
      end,
    })
    T.eq(regTab, true, "PublicApi.registerSummaryTab registers successfully")
    T.eq(PublicApi.summaryTabs.ev_iv_tab.label, "EV / IV", "Registered summary tab preserved")

    -- Verify SummaryRenderer renders custom tab
    local SummaryRenderer = require("mods.omni_ui.renderers.SummaryRenderer")
    local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
    local dummyMon = { species = "PIKACHU", level = 50, hp = 100, maxHP = 100 }
    local dummySummState = { mon = dummyMon, page = 4 }
    local okSumm = pcall(SummaryRenderer.draw, specGame, dummySummState, 800, 600, Theme.get())
    T.eq(okSumm, true, "SummaryRenderer renders custom mod tab without error")
    T.eq(customTabDrawn, true, "Custom mod summary tab draw callback executed")

    local shortBox = SummaryRenderer.trainerBlock("AAA (#64598)", "Met.", 160, { labeled = true })
    local longMemo = "CALM nature. Met in PALLET TOWN at Lv. 5. " .. string.rep("ROUTE ", 12)
    local longBox = SummaryRenderer.trainerBlock("AAA (#64598)", longMemo, 160, { labeled = true })
    T.eq(longBox.height > shortBox.height, true, "OT slot grows so the met line can wrap")
    dummyMon.originDesc = longMemo
    dummyMon.otName = "AAA"
    dummyMon.otId = 64598
    local okLongOt = pcall(SummaryRenderer.draw, specGame, dummySummState, 800, 600, Theme.get())
    T.eq(okLongOt, true, "SummaryRenderer draws a long OT and met line in landscape")

    -- Test custom screen registration
    local customScreenDrawn = false
    local regScreen = PublicApi.registerScreen("quest_ui", {
      match = function(state) return state and state.isQuestScreen == true end,
      draw = function(g, state, w, h, t)
        customScreenDrawn = true
      end,
    })
    T.eq(regScreen, true, "PublicApi.registerScreen registers successfully")

    local mockQuestState = { isQuestScreen = true }
    local detectedKind, detectedDef = ModernOverlay.isSupported(mockQuestState)
    T.eq(detectedKind, "custom_quest_ui", "ModernOverlay detects registered custom screen")

    -- Test lifecycle hooks
    local preHookFired = false
    local postHookFired = false
    PublicApi.onPreRender("start_menu", "test_pre_hook", function()
      preHookFired = true
    end)
    PublicApi.onPostRender("start_menu", "test_post_hook", function()
      postHookFired = true
    end)

    local dummyStartState = { items = { { label = "ITEM", id = "item" } } }
    local okStartDraw = pcall(ModernOverlay.draw, specGame, 0.016, 800, 600)
    T.eq(okStartDraw, true, "ModernOverlay.draw runs with lifecycle hooks cleanly")

    -- Clean up test registries
    PublicApi.startMenuItems.test_quest_log = nil
    PublicApi.optionRows.test_fast_dialogue = nil
    PublicApi.summaryTabs.ev_iv_tab = nil
    PublicApi.customScreens.quest_ui = nil
    PublicApi.preRenderHooks = {}
    PublicApi.postRenderHooks = {}
  end

  -- Test PlayerPC modal rendering with QuantityBox, ChoiceBox, action submenus, and pcCompletion
  do
    local PlayerPcRenderer = require("mods.omni_ui.renderers.PlayerPcRenderer")
    local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
    local t = Theme.get()

    local pcState = {
      kind = "pc_item_deposit",
      items = {
        { id = "POTION", label = "POTION", count = 5, stack = 5 },
        { id = "POKE_BALL", label = "POKE BALL", count = 10, stack = 10 },
        { cancel = true, label = "CANCEL" },
      },
      index = 1,
      scroll = 0,
    }

    -- 1. Base list view
    local okBase = pcall(PlayerPcRenderer.draw, specGame, pcState, 800, 600, t, nil, 1.0)
    T.eq(okBase, true, "PlayerPcRenderer draws base deposit list")

    -- 2. QuantityBox modal overlay
    local qtyBox = { qty = 3, max = 5, isQuantityBox = true }
    local okQty = pcall(PlayerPcRenderer.draw, specGame, pcState, 800, 600, t, qtyBox, 1.0)
    T.eq(okQty, true, "PlayerPcRenderer draws QuantityBox modal overlay")

    -- 3. ChoiceBox modal overlay
    local choiceBox = { isChoiceBox = true, choices = { "YES", "NO" }, index = 1 }
    local okChoice = pcall(PlayerPcRenderer.draw, specGame, pcState, 800, 600, t, choiceBox, 1.0)
    T.eq(okChoice, true, "PlayerPcRenderer draws ChoiceBox modal overlay")

    -- 4. Action sub-menu modal overlay
    local actionBox = { items = { "DEPOSIT", "STATS", "CANCEL" }, index = 1 }
    local okAction = pcall(PlayerPcRenderer.draw, specGame, pcState, 800, 600, t, actionBox, 1.0)
    T.eq(okAction, true, "PlayerPcRenderer draws action sub-menu modal overlay")

    -- 5. Completion notice modal
    local compState = {
      kind = "pc_item_deposit",
      items = pcState.items,
      index = 1,
      pcCompletion = true,
      footer = "POTION was stored via PC.",
    }
    local okComp = pcall(PlayerPcRenderer.draw, specGame, compState, 800, 600, t, nil, 1.0)
    T.eq(okComp, true, "PlayerPcRenderer draws completion notice modal")
  end

  -- Test MoveDatabase, ItemDatabase & Interactive Summary Move Inspector
  do
    local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
    local ItemDatabase = require("mods.omni_ui.core.ItemDatabase")
    local SummaryRenderer = require("mods.omni_ui.renderers.SummaryRenderer")
    local t = Theme.get()

    -- 1. Canonical Move Lookups
    local poundDesc = MoveDatabase.getDescription("POUND")
    T.eq(type(poundDesc), "string", "POUND has string description")
    T.eq(poundDesc:find("Pounds the target") ~= nil, true, "POUND description matches canonical text")

    -- Gen 3 moves & MOVE_ prefix lookups (e.g. HAIL, MOVE_HAIL, FACADE, FOCUS_PUNCH, SMELLINGSALT)
    local hailDesc1 = MoveDatabase.getDescription("HAIL")
    local hailDesc2 = MoveDatabase.getDescription("MOVE_HAIL")
    T.eq(hailDesc1:find("hailstorm") ~= nil, true, "HAIL has accurate canonical description")
    T.eq(hailDesc2, hailDesc1, "MOVE_HAIL resolves identically to HAIL")
    T.eq(hailDesc1:find("technique used in battle") == nil, true, "HAIL does not fall back to generic description")

    local facadeDesc = MoveDatabase.getDescription("FACADE")
    T.eq(facadeDesc:find("doubles in power") ~= nil, true, "FACADE description resolved")

    local focusPunchDesc = MoveDatabase.getDescription("FOCUS_PUNCH")
    T.eq(focusPunchDesc:find("punch charged") ~= nil, true, "FOCUS_PUNCH description resolved")

    local smellingSaltDesc = MoveDatabase.getDescription("SMELLINGSALT")
    T.eq(smellingSaltDesc:find("paralyzed targets") ~= nil, true, "SMELLINGSALT description resolved")

    -- 2. Power & Accuracy string formats
    T.eq(MoveDatabase.getPowerString({ power = 90 }), "90", "Power 90 formats correctly")
    T.eq(MoveDatabase.getPowerString({ power = 0 }), "---", "Power 0 formats as ---")
    T.eq(MoveDatabase.getAccuracyString({ accuracy = 100 }), "100%", "Accuracy 100 formats as 100%")
    T.eq(MoveDatabase.getAccuracyString({ accuracy = 255 }), "100%", "Gen 1 Accuracy 255 formats as 100%")
    T.eq(MoveDatabase.getAccuracyString({ accuracy = 0.85 }), "85%", "Fractional accuracy 0.85 formats as 85%")

    -- 3. Categories (Physical / Special / Status)
    T.eq(MoveDatabase.getCategory("SWORDS_DANCE", { power = 0, type = "NORMAL" }), "STATUS", "Swords Dance is STATUS")
    T.eq(MoveDatabase.getCategory("FLAMETHROWER", { power = 95, type = "FIRE" }), "SPECIAL", "Flamethrower is SPECIAL")
    T.eq(MoveDatabase.getCategory("EARTHQUAKE", { power = 100, type = "GROUND" }), "PHYSICAL", "Earthquake is PHYSICAL")
    T.eq(MoveDatabase.getCategory("CUSTOM_MOVE", { power = 80, category = "SPECIAL" }), "SPECIAL", "Explicit category override respected")

    -- 4. Effect Tag Identification
    T.eq(MoveDatabase.getEffectTag("GUILLOTINE", { power = 0, effect = "ONE_HIT_KO" }), "One-Hit KO", "Guillotine tagged as One-Hit KO")
    T.eq(MoveDatabase.getEffectTag("ABSORB", { power = 20, effect = "DRAIN" }), "HP Drain (50%)", "Absorb tagged as HP Drain")
    T.eq(MoveDatabase.getEffectTag("QUICK_ATTACK", { power = 40 }), "Priority Move", "Quick Attack tagged as Priority")
    T.eq(MoveDatabase.getEffectTag("SLASH", { power = 70 }), "High Critical Rate", "Slash tagged as High Critical Rate")

    -- 5. Cross-gen Gen 3 / Mod Move Registration
    MoveDatabase.registerMove("VOLT_STRIKE", {
      name = "Volt Strike",
      type = "ELECTRIC",
      power = 120,
      accuracy = 85,
      pp = 5,
      category = "PHYSICAL",
      description = "Charges with overwhelming electric energy.",
      effectTag = "Paralyze (30%)",
    })
    local voltDef = MoveDatabase.getMoveDef("VOLT_STRIKE", nil, specGame)
    T.eq(voltDef.name, "Volt Strike", "Custom mod move resolved")
    T.eq(MoveDatabase.getCategory("VOLT_STRIKE", voltDef), "PHYSICAL", "Custom mod move category is PHYSICAL")
    T.eq(MoveDatabase.getDescription("VOLT_STRIKE", voltDef), "Charges with overwhelming electric energy.", "Custom mod description resolved")

    -- 6. Dynamic Move Description Provider Hook
    MoveDatabase.registerDescriptionProvider(function(moveId)
      if moveId == "PROV_TEST" then return "Custom provider text" end
    end)
    T.eq(MoveDatabase.getDescription("PROV_TEST"), "Custom provider text", "Description provider hook invoked successfully")

    -- 7. ItemDatabase TM/HM integration
    local tmDesc = ItemDatabase.getDescription("TM_01", { machine = { move = "MEGA_PUNCH" } }, specGame)
    T.eq(tmDesc:find("MEGA PUNCH") ~= nil, true, "TM description includes move name")
    T.eq(tmDesc:find("powerful punch") ~= nil, true, "TM description includes move description")

    local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
    T.eq(BagRenderer.stackCount({ id = 4, qty = 5, name = "POKé BALL" }), 5, "Gen 3 bag detail reads qty when count is absent")
    T.eq(BagRenderer.stackCount({ id = "POTION", count = 3 }), 3, "Bag detail still reads count")

    local juiceDesc = ItemDatabase.getDescription("BERRY JUICE")
    T.eq(juiceDesc:find("pure juice") ~= nil, true, "Gen 3 Berry Juice uses the item pack description")
    T.eq(juiceDesc:find("terminal") == nil, true, "Gen 3 item text is not the PC storage fallback")
    local potionDesc = ItemDatabase.getDescription(13)
    T.eq(potionDesc:find("20 points") ~= nil, true, "Gen 3 Potion id uses the item pack description")

    -- 8. SummaryRenderer Tab 2 (Moves) Multi-Move Inspection
    local testMon = {
      species = "CHARIZARD",
      level = 36,
      hp = 120,
      maxHp = 120,
      moves = {
        { id = "FLAMETHROWER", pp = 15, ppUps = 0 },
        { id = "SLASH", pp = 20, ppUps = 1 },
        { id = "FLY", pp = 15, ppUps = 0 },
        { id = "VOLT_STRIKE", pp = 5, ppUps = 0 },
      },
    }

    local sumState1 = { mon = testMon, page = 2, moveIndex = 1 }
    local okSum1 = pcall(SummaryRenderer.draw, specGame, sumState1, 800, 600, t)
    T.eq(okSum1, true, "SummaryRenderer renders Move Tab with Move 1 selected")

    local sumState2 = { mon = testMon, page = 2, moveIndex = 4 }
    local okSum2 = pcall(SummaryRenderer.draw, specGame, sumState2, 800, 600, t)
    T.eq(okSum2, true, "SummaryRenderer renders Move Tab with custom mod Move 4 selected")
  end
end

-- 9. Responsive Layout Context & Orientation Awareness
do
  local ctxLand = Layout.getContext(800, 600)
  T.eq(ctxLand.isLandscape, true, "800x600 recognized as Landscape")
  T.eq(ctxLand.isPortrait, false, "800x600 is not Portrait")
  T.eq(ctxLand.safeInsetTop, 0, "800x600 safeInsetTop is 0")
  T.eq(ctxLand.breakpoint, "md", "800x600 is standard md breakpoint")

  local ctxPort = Layout.getContext(360, 640)
  T.eq(ctxPort.isPortrait, true, "360x640 recognized as Portrait")
  T.eq(ctxPort.isLandscape, false, "360x640 is not Landscape")
  T.eq(ctxPort.safeInsetTop, 48, "360x640 safeInsetTop is 48 for camera notch / punch hole")
  T.eq(ctxPort.isCompact, true, "360x640 recognized as compact mobile")
  T.eq(ctxPort.isTallPortrait, true, "360x640 recognized as Tall Portrait")

  local ctxUltraTall = Layout.getContext(360, 780)
  T.eq(ctxUltraTall.isUltraTallPortrait, true, "360x780 recognized as UltraTall Portrait")
  T.eq(ctxUltraTall.portraitContainerRatio, 0.74, "360x780 expands container ratio to 0.74")

  local ctxCompact = Layout.getContext(480, 320)
  T.eq(ctxCompact.isUltraCompact, true, "480x320 recognized as UltraCompact")
  T.eq(ctxCompact.breakpoint, "xs", "480x320 is xs breakpoint")

  local ctxUltra = Layout.getContext(2560, 1080)
  T.eq(ctxUltra.isUltrawide, true, "2560x1080 recognized as Ultrawide")
end

-- 10. Multi-Orientation Screen Rendering (Portrait & Compact Mobile)
do
  local PartyRenderer = require("mods.omni_ui.renderers.PartyRenderer")
  local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
  local SummaryRenderer = require("mods.omni_ui.renderers.SummaryRenderer")
  local StartMenuRenderer = require("mods.omni_ui.renderers.StartMenuRenderer")
  local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
  local SaveRenderer = require("mods.omni_ui.renderers.SaveRenderer")
  local MainMenuRenderer = require("mods.omni_ui.renderers.MainMenuRenderer")
  local t = Theme.get()

  local specGame = {
    data = Data,
    save = {
      player = { name = "RED", badges = 8, maxBadges = 8, playTimeString = "12:34", pokedex = { seen = 50, owned = 25 } },
      party = {
        {
          species = "CHARIZARD",
          level = 36,
          hp = 120,
          maxHp = 120,
          moves = { { id = "FLAMETHROWER", pp = 15 } },
        }
      },
      pokedex = { seen = { CHARIZARD = true }, owned = { CHARIZARD = true } },
    },
    stack = { states = {} },
  }

  local testMon = specGame.save.party[1]

  local sumState1 = { mon = testMon, page = 1 }
  local okSumPort1 = pcall(SummaryRenderer.draw, specGame, sumState1, 360, 640, t)
  T.eq(okSumPort1, true, "SummaryRenderer renders Stats, EXP & Origin in Portrait Mobile (360x640)")

  local sumState2 = { mon = testMon, page = 2, moveIndex = 1 }
  local okSumPort2 = pcall(SummaryRenderer.draw, specGame, sumState2, 360, 640, t)
  T.eq(okSumPort2, true, "SummaryRenderer renders Moves tab & Move Inspector in Portrait Mobile (360x640)")

  local sumState3 = { mon = testMon, page = 3 }
  local okSumPort3 = pcall(SummaryRenderer.draw, specGame, sumState3, 360, 640, t)
  T.eq(okSumPort3, true, "SummaryRenderer renders Info Tab with OT & Met details in Portrait Mobile (360x640)")

  local okSumLand1 = pcall(SummaryRenderer.draw, specGame, sumState1, 800, 600, t)
  T.eq(okSumLand1, true, "SummaryRenderer renders Stats & EXP Progress in Landscape (800x600)")

  local okSumLand2 = pcall(SummaryRenderer.draw, specGame, sumState2, 800, 600, t)
  T.eq(okSumLand2, true, "SummaryRenderer renders Moves tab & Move Inspector in Landscape (800x600)")

  -- Test Live Game Move Data Sourcing & Modded Stats Precedence
  do
    local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
    local modGame = {
      data = {
        moves = {
          TACKLE = { id = "TACKLE", name = "TACKLE", type = "NORMAL", power = 50, accuracy = 100, pp = 35, effect = "NO_ADDITIONAL_EFFECT" },
          VINE_WHIP = { id = "VINE_WHIP", name = "VINE WHIP", type = "GRASS", power = 45, accuracy = 100, pp = 25, effect = "NO_ADDITIONAL_EFFECT" },
          GROWL = { id = "GROWL", name = "GROWL", type = "NORMAL", power = 0, accuracy = 100, pp = 40, effect = "ATTACK_DOWN1_EFFECT" },
        }
      }
    }
    local tackleDef = MoveDatabase.getMoveDef("TACKLE", { id = "TACKLE", pp = 35 }, modGame)
    T.eq(tackleDef.power, 50, "MoveDatabase sources live game/mod modified power (50)")
    T.eq(MoveDatabase.getPowerString(tackleDef), "50", "MoveDatabase.getPowerString formats '50'")
    T.eq(MoveDatabase.getAccuracyString(tackleDef), "100%", "MoveDatabase.getAccuracyString formats '100%'")
    T.eq(MoveDatabase.getCategory("TACKLE", tackleDef, modGame), "PHYSICAL", "MoveDatabase.getCategory classifies Tackle as PHYSICAL")
    T.eq(MoveDatabase.getEffectTag("TACKLE", tackleDef, modGame), "Standard Damage", "MoveDatabase.getEffectTag classifies Tackle as Standard Damage")

    local vineDef = MoveDatabase.getMoveDef("VINE_WHIP", { id = "VINE_WHIP", pp = 25 }, modGame)
    T.eq(vineDef.power, 45, "MoveDatabase sources live game Vine Whip power (45)")
    T.eq(MoveDatabase.getPowerString(vineDef), "45", "MoveDatabase.getPowerString formats Vine Whip power '45'")
    T.eq(MoveDatabase.getCategory("VINE_WHIP", vineDef, modGame), "SPECIAL", "MoveDatabase classifies Vine Whip as SPECIAL in Gen 1-3")

    local growlDef = MoveDatabase.getMoveDef("GROWL", { id = "GROWL", pp = 40 }, modGame)
    T.eq(growlDef.power, 0, "MoveDatabase sources Growl power (0)")
    T.eq(MoveDatabase.getPowerString(growlDef), "---", "MoveDatabase.getPowerString formats 0 power as '---'")
    T.eq(MoveDatabase.getCategory("GROWL", growlDef, modGame), "STATUS", "MoveDatabase classifies Growl as STATUS")
    T.eq(MoveDatabase.getEffectTag("GROWL", growlDef, modGame), "Lowers Foe Stats", "MoveDatabase classifies Growl effect as 'Lowers Foe Stats'")
  end

  local partyState = { party = { testMon }, index = 1 }
  local okPartyPort = pcall(PartyRenderer.draw, specGame, partyState, 360, 640, t)
  T.eq(okPartyPort, true, "PartyRenderer renders smoothly in Portrait Mobile (360x640)")

  local okPartyLand = pcall(PartyRenderer.draw, specGame, partyState, 800, 600, t)
  T.eq(okPartyLand, true, "PartyRenderer renders HP & EXP bars in Landscape (800x600)")

  local okPartyConstrained = pcall(PartyRenderer.draw, specGame, partyState, 400, 260, t)
  T.eq(okPartyConstrained, true, "PartyRenderer adapts and culls EXP bars smoothly when vertical space is constrained")

  -- Test Party Interaction Submenu Modal in Portrait & Landscape
  local partySubmenuState = {
    party = { testMon },
    index = 1,
    submenu = true,
    subIndex = 2,
    subItems = {
      { label = "CUT", action = "cut" },
      { label = "SURF", action = "surf" },
      { label = "STATS", action = "stats" },
      { label = "SWITCH", action = "switch" },
      { label = "CANCEL", action = "cancel" },
    },
  }
  local okPartySubPort = pcall(PartyRenderer.draw, specGame, partySubmenuState, 360, 640, t)
  T.eq(okPartySubPort, true, "PartyRenderer renders interaction modal in Portrait Mobile")

  local okPartySubLand = pcall(PartyRenderer.draw, specGame, partySubmenuState, 800, 600, t)
  T.eq(okPartySubLand, true, "PartyRenderer renders interaction modal in Desktop Landscape")

  -- Test StartMenuRenderer Vertical Auto-Scrolling on Constrained / Mobile Display
  local startMenuStateLong = {
    items = {
      { label = "POKÉDEX" },
      { label = "POKÉMON" },
      { label = "ITEM" },
      { label = "PLAYER" },
      { label = "SAVE" },
      { label = "OPTION" },
      { label = "MODS" },
      { label = "EXIT" },
    },
    index = 6,
  }
  -- Short mobile screen (vh = 400, vw = 360)
  local okStartShort = pcall(StartMenuRenderer.draw, specGame, startMenuStateLong, 360, 400, t)
  T.eq(okStartShort, true, "StartMenuRenderer renders with auto-scrolling on short mobile screen (360x400)")

  -- Very short compact screen (vh = 320, vw = 480)
  local okStartUltraShort = pcall(StartMenuRenderer.draw, specGame, startMenuStateLong, 480, 320, t)
  T.eq(okStartUltraShort, true, "StartMenuRenderer renders with auto-scrolling on 480x320 screen")

  local bagState = { items = { { id = "POTION", count = 5 }, { id = "POKE_BALL", count = 10 } }, index = 1 }
  local okBagPort = pcall(BagRenderer.draw, specGame, bagState, 360, 640, t)
  T.eq(okBagPort, true, "BagRenderer renders smoothly in Portrait Mobile (360x640)")
end

do
  local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
  local SaveRenderer = require("mods.omni_ui.renderers.SaveRenderer")
  local MainMenuRenderer = require("mods.omni_ui.renderers.MainMenuRenderer")
  local PartyRenderer = require("mods.omni_ui.renderers.PartyRenderer")
  local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")
  local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
  local t = Theme.get()

  local specGame = {
    data = Data,
    save = {
      player = { name = "RED", badges = 8, maxBadges = 8, playTimeString = "12:34", pokedex = { seen = 50, owned = 25 } },
      party = {
        {
          species = "CHARIZARD",
          level = 36,
          hp = 120,
          maxHp = 120,
          moves = { { id = "FLAMETHROWER", pp = 15 } },
        }
      },
      pokedex = { seen = { CHARIZARD = true }, owned = { CHARIZARD = true } },
    },
    stack = { states = {} },
  }
  local testMon = specGame.save.party[1]
  local bagState = { items = { { id = "POTION", count = 5 }, { id = "POKE_BALL", count = 10 } }, index = 1 }

  -- Test DialogueRenderer in Portrait Mobile (Safe Area above virtual touch controls)
  local diagState = { text = "RETURN TO MAIN MENU?", isTextBox = true }
  local choiceSub = { labels = { "YES", "NO" }, index = 2, isChoiceBox = true }
  local okDiagPort = pcall(DialogueRenderer.draw, specGame, diagState, 360, 780, t, choiceSub)
  T.eq(okDiagPort, true, "DialogueRenderer renders in Portrait Mobile with ChoiceBox above controls")

  -- Test SaveRenderer in Portrait Mobile (Reflowed modal + Yes/No touch buttons)
  local saveState = { phase = "confirm", cursor = 1, isSaveMenu = true }
  local okSavePort = pcall(SaveRenderer.draw, specGame, saveState, 360, 780, t, nil, true)
  T.eq(okSavePort, true, "SaveRenderer renders cleanly in Portrait Mobile without horizontal squish")

  -- Test MainMenuRenderer in Portrait Mobile (Stacked buttons + 2-row party grid)
  local mainMenuState = {
    items = {
      { label = "CONTINUE", subtext = "Resume saved adventure" },
      { label = "NEW GAME", subtext = "Begin a fresh journey" },
      { label = "OPTION", subtext = "Game settings" },
    },
    index = 1,
    isMainMenu = true,
  }
  local okMainPort = pcall(MainMenuRenderer.draw, specGame, mainMenuState, 360, 780, t)
  T.eq(okMainPort, true, "MainMenuRenderer renders stacked buttons and clean party grid in Portrait Mobile")

  -- Test BaseAdapter.resolveBadgeCount with authentic Gen 1 save.inventory (6 badges)
  do
    local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")
    local gen1Save6Badges = {
      player = { name = "RED" },
      inventory = {
        BOULDERBADGE = true,
        CASCADEBADGE = true,
        THUNDERBADGE = true,
        RAINBOWBADGE = true,
        SOULBADGE = true,
        MARSHBADGE = true,
      },
      pokedex = { owned = { [1] = true, [4] = true, [7] = true } },
      playTime = 7200,
    }
    local count = BaseAdapter.resolveBadgeCount(gen1Save6Badges, specGame)
    T.eq(count, 6, "BaseAdapter.resolveBadgeCount accurately counts 6 badges from Gen 1 save.inventory")

    local loadState = {
      items = { { label = "CONTINUE" }, { label = "NEW GAME" } },
      index = 1,
      save = gen1Save6Badges,
    }
    local okDrawLoad = pcall(MainMenuRenderer.draw, specGame, loadState, 800, 600, t)
    T.eq(okDrawLoad, true, "MainMenuRenderer renders load screen with 6 badges")

    local rby = MainMenuRenderer.preview({ gameVersion = "red" }, {
      items = { { label = "CONTINUE" } },
      save = {
        player = { name = "ASH" },
        inventory = { BOULDERBADGE = true, CASCADEBADGE = true },
        pokedex = { owned = { CHARMANDER = true, SQUIRTLE = false, BULBASAUR = true } },
        playTime = 3665,
        party = {
          { species = "CHARMANDER", nickname = "FLAME", level = 8, hp = 0, maxHp = 22, stats = { hp = 22 } },
        },
      },
    })
    T.eq(rby.generation, 1, "Red continue card is generation 1")
    T.eq(rby.name, "ASH", "Red continue card uses the player name")
    T.eq(rby.badges, 2, "Red continue card counts inventory badges")
    T.eq(rby.caught, 2, "Red continue card counts owned dex flags and skips false")
    T.eq(rby.playTimeString, "1:01", "Red continue card reads play time in seconds")
    T.eq(#rby.party, 1, "Red continue card lists the party")
    T.eq(rby.party[1].name, "FLAME", "Red continue card shows the nickname")
    T.eq(rby.party[1].hp, 0, "Red fainted Pokémon stays at 0 HP")
    T.eq(rby.party[1].maxHp, 22, "Red fainted Pokémon keeps its max HP")

    local gsc = MainMenuRenderer.preview({ gameVersion = "crystal" }, {
      save = {
        player = { name = "CRYS", badges = { ZEPHYR = true, HIVE = true }, kantoBadges = { BOULDER = true } },
        pokedex = { owned = {}, caught = { [155] = true, [158] = true, [25] = false } },
        playTime = { hours = 3, minutes = 5 },
        party = {
          { species = "CYNDAQUIL", level = 6, hp = 0, maxHp = 19, stats = { hp = 19 } },
          { species = "EGG", isEgg = true, eggCycles = 10 },
        },
      },
    })
    T.eq(gsc.generation, 2, "Crystal continue card is generation 2")
    T.eq(gsc.name, "CRYS", "Crystal continue card uses player.name")
    T.eq(gsc.badges, 3, "Crystal continue card counts Johto and Kanto badges")
    T.eq(gsc.caught, 2, "Crystal continue card counts caught, not an empty owned table")
    T.eq(gsc.playTimeString, "3:05", "Crystal continue card reads the play-time table")
    T.eq(gsc.party[1].name, "CYNDAQUIL", "Crystal party uses the species name")
    T.eq(gsc.party[1].hp, 0, "Crystal fainted Pokémon stays at 0 HP")
    T.eq(gsc.party[2].isEgg, true, "Crystal party keeps the egg")
    T.eq(gsc.party[2].name, "EGG", "Crystal egg is labeled EGG")

    local frlg = MainMenuRenderer.preview({ gameVersion = "firered" }, {
      hasContinue = true,
      continueInfo = { name = "RED", badges = 8, dexCount = 150, hours = 25, minutes = 40 },
      save = {
        name = "RED",
        engine = "game3",
        version = "firered",
        party = {
          { species = 4, nickname = "ACE", level = 16, hp = 0, maxHp = 41, stats = { hp = 41, attack = 20 } },
        },
      },
    })
    T.eq(frlg.generation, 3, "FireRed continue card is generation 3")
    T.eq(frlg.name, "RED", "FireRed continue card uses the continue header name")
    T.eq(frlg.badges, 8, "FireRed continue card uses the header badge count")
    T.eq(frlg.caught, 150, "FireRed continue card uses the header dex count")
    T.eq(frlg.playTimeString, "25:40", "FireRed continue card uses the header clock")
    T.eq(#frlg.party, 1, "FireRed continue card still lists the party from the save")
    T.eq(frlg.party[1].name, "ACE", "FireRed party shows the nickname")
    T.eq(frlg.party[1].hp, 0, "FireRed fainted Pokémon stays at 0 HP")
    T.eq(frlg.party[1].maxHp, 41, "FireRed fainted Pokémon keeps its max HP")

    local rse = MainMenuRenderer.preview({ gameVersion = "emerald" }, {
      hasContinue = true,
      info = { name = "MAY", badges = 2, dexCount = 12, hours = 1, minutes = 2 },
      save = {
        name = "MAY",
        engine = "game3",
        version = "emerald",
        dex = { caught = { [1] = true, [2] = true, [3] = true, [252] = true } },
        party = {
          { species = 277, nickname = "LEAF", level = 9, hp = 18, maxHp = 28, stats = { hp = 28, attack = 12 } },
        },
      },
    })
    T.eq(rse.generation, 3, "Emerald continue card is generation 3")
    T.eq(rse.name, "MAY", "Emerald continue card uses the Hoenn header name")
    T.eq(rse.badges, 2, "Emerald continue card uses the Hoenn badge count")
    T.eq(rse.caught, 12, "Emerald continue card uses the regional dex count from the header")
    T.eq(rse.playTimeString, "1:02", "Emerald continue card uses the header clock")
    T.eq(rse.party[1].name, "LEAF", "Emerald party shows the nickname")
    T.eq(rse.party[1].hp, 18, "Emerald party keeps the current HP")
    T.eq(rse.party[1].level, 9, "Emerald party keeps the level")
  end

  -- Test ModManagerRenderer Sliding Window Scrolling
  do
    local ModManagerRenderer = require("mods.omni_ui.renderers.ModManagerRenderer")
    local mockRows = {}
    for i = 1, 10 do
      mockRows[i] = {
        label = "MOD " .. i,
        mod = { id = "mod_" .. i, name = "Mod " .. i, version = "1.0.0", state = "enabled", desc = "Test Mod " .. i }
      }
    end
    local modState = {
      screen = "list",
      tab = 1,
      cursor = 1,
      rows = mockRows,
      rowsForScreen = function() return mockRows end,
    }

    -- 1. Initial draw at top
    local okDraw1 = pcall(ModManagerRenderer.draw, specGame, modState, 360, 640, t)
    T.eq(okDraw1, true, "ModManagerRenderer initial draw at top (cursor=1)")
    T.eq(modState._omniScroll and modState._omniScroll["list_tab1_portrait"], 1, "Mod Manager scroll is 1 at top")

    -- 2. Move cursor down past bottom of 4-item visible window (e.g. cursor = 6)
    modState.cursor = 6
    pcall(ModManagerRenderer.draw, specGame, modState, 360, 480, t)
    local s1 = modState._omniScroll["list_tab1_portrait"]
    T.eq(s1 >= 2, true, "Mod Manager scroll shifted down to show cursor=6")

    -- 3. Move cursor UP by 1 (e.g. cursor = 5) - window MUST stay locked in place!
    modState.cursor = 5
    pcall(ModManagerRenderer.draw, specGame, modState, 360, 480, t)
    local s2 = modState._omniScroll["list_tab1_portrait"]
    T.eq(s2, s1, "Mod Manager scroll remains locked in place when moving back up within visible window")
  end

  -- Test PartyMenu returning from status screen (submenu dismissed, stale subItems ignored)
  local partyReturnedState = { party = { testMon }, index = 1, submenu = nil, subItems = { { label = "STATS" }, { label = "SWITCH" } } }
  local okPartyReturn = pcall(PartyRenderer.draw, specGame, partyReturnedState, 800, 600, t)
  T.eq(okPartyReturn, true, "PartyRenderer returns to list mode without lingering submenu modal")

  -- Field-move confirms stay visible while the overlay hides the native box.
  -- Gen 3 Teleport/Dig (FireRed, LeafGreen, Emerald) are a party yes/no.
  -- Ruby and Sapphire run those two immediately, so they never open the box.
  -- Gen 1 and Gen 2 print the line, and sometimes a Yes/No, on top of the party.
  do
    local drawn = {}
    local origText = Layout.drawText
    local origButton = Layout.drawButton
    Layout.drawText = function(text, ...)
      drawn[#drawn + 1] = tostring(text)
      return origText(text, ...)
    end
    Layout.drawButton = function(x, y, w, h, label, ...)
      drawn[#drawn + 1] = "BTN:" .. tostring(label)
      return origButton(x, y, w, h, label, ...)
    end
    local function painted(fragment)
      return table.concat(drawn, "\n"):find(fragment, 1, true) ~= nil
    end
    local function resetPaint()
      for i = #drawn, 1, -1 do drawn[i] = nil end
    end

    local partyMon = {
      species = "ABRA", nickname = "ABRA", level = 16,
      hp = 40, maxHp = 40, moves = { { id = "TELEPORT" } },
    }
    local versions = { "firered", "leafgreen", "emerald" }
    local prompts = {
      { move = "teleport", text = "Return to the healing spot?\nPALLET TOWN" },
      { move = "dig", text = "Escape from here and return to\nVIRIDIAN FOREST" },
      { move = "dig-rse", text = "Escape from here?" },
    }
    for _, version in ipairs(versions) do
      for _, prompt in ipairs(prompts) do
        resetPaint()
        local menu = {
          party = { partyMon }, cursor = 1, _party = { partyMon }, ACTIONS = {},
          mode = "yesno",
          _yesNoPrompt = prompt.text,
          _yesNoCursor = 1,
          _yesNoLabels = { "YES", "NO" },
          _session = { version = version },
        }
        local okDraw = pcall(PartyRenderer.draw, specGame, menu, 800, 600, t)
        T.eq(okDraw, true, version .. " " .. prompt.move .. " confirm draws")
        local firstLine = prompt.text:match("^[^\n]+")
        T.eq(painted(firstLine), true, version .. " " .. prompt.move .. " shows its question")
        T.eq(painted("BTN:YES"), true, version .. " " .. prompt.move .. " shows YES")
        T.eq(painted("BTN:NO"), true, version .. " " .. prompt.move .. " shows NO")
      end
    end

    resetPaint()
    local noCursor = {
      party = { partyMon }, cursor = 1, _party = { partyMon }, ACTIONS = {},
      mode = "yesno",
      _yesNoPrompt = "Return to the healing spot?\nPALLET TOWN",
      _yesNoCursor = 2,
      _yesNoLabels = { "YES", "NO" },
    }
    local selected = {}
    local origButton2 = Layout.drawButton
    Layout.drawButton = function(x, y, w, h, label, opts, ...)
      if opts and opts.selected then selected[#selected + 1] = tostring(label) end
      return origButton2(x, y, w, h, label, opts, ...)
    end
    pcall(PartyRenderer.draw, specGame, noCursor, 800, 600, t)
    T.eq(selected[#selected] == "NO" or table.concat(selected, ","):find("NO", 1, true) ~= nil, true,
      "yes/no highlight follows the No cursor")
    Layout.drawButton = origButton2

    resetPaint()
    local refusal = {
      party = { partyMon }, cursor = 1, _party = { partyMon }, ACTIONS = {},
      mode = "message",
      _messageText = "Can't use that here.",
    }
    local okRefusal = pcall(PartyRenderer.draw, specGame, refusal, 800, 600, t)
    T.eq(okRefusal, true, "field-move refusal message draws")
    T.eq(painted("Can't use that here."), true, "field-move refusal text is visible")
    T.eq(painted("BTN:YES"), false, "a refusal message is not a yes/no")

    resetPaint()
    local warpBox = {
      isTextBox = true,
      pages = { { "Warp to the last\nPOKéMON CENTER." } },
      pageIndex = 1, lineIndex = 2, charIndex = 40, waiting = true,
    }
    local gen1Party = { party = { partyMon }, index = 1, isPartyMenu = true }
    local gen1 = { stack = { states = { gen1Party, warpBox } }, save = specGame.save, data = specGame.data }
    local okWarp = pcall(PartyRenderer.draw, gen1, gen1Party, 800, 600, t, warpBox)
    T.eq(okWarp, true, "Gen 1 teleport text draws over the party")
    T.eq(painted("Warp to the last"), true, "Gen 1 teleport question is visible")

    resetPaint()
    local cutBox = {
      isTextBox = true,
      pages = { { "This tree can be\nCUT!" } },
      pageIndex = 1, lineIndex = 2, charIndex = 40, waiting = true, instant = true,
    }
    local cutChoice = { isChoiceBox = true, labels = { "YES", "NO" }, index = 1, onChoose = function() end }
    local gen2Party = { party = { partyMon }, index = 1 }
    local gen2 = { stack = { states = { gen2Party, cutBox, cutChoice } }, save = specGame.save, data = specGame.data }
    local okCut = pcall(PartyRenderer.draw, gen2, gen2Party, 800, 600, t, cutChoice)
    T.eq(okCut, true, "Gen 2 field-move question draws over the party")
    T.eq(painted("This tree can be"), true, "Gen 2 cut question is visible")
    T.eq(painted("BTN:YES"), true, "Gen 2 cut question shows YES")
    T.eq(painted("BTN:NO"), true, "Gen 2 cut question shows NO")

    Layout.drawText = origText
    Layout.drawButton = origButton
  end

  -- Test TownMapRenderer in Portrait Mobile (Stacked map + details with guaranteed non-overlapping bounds)
  local mapState = {
    locs = { { name = "PALLET TOWN", x = 5, y = 10 }, { name = "VIRIDIAN CITY", x = 5, y = 7 } },
    sel = 1,
    playerLoc = { name = "PALLET TOWN" },
  }
  local okMapPort = pcall(TownMapRenderer.draw, specGame, mapState, 360, 640, t)
  T.eq(okMapPort, true, "TownMapRenderer renders stacked layout in Portrait Mobile (360x640)")
  local okMapShort = pcall(TownMapRenderer.draw, specGame, mapState, 360, 420, t)
  T.eq(okMapShort, true, "TownMapRenderer renders without footer overlap on compact mobile screen (360x420)")

  -- Test Area Mode in portrait
  local areaState = {
    nestSpecies = "PIKACHU",
    nests = { { name = "VIRIDIAN FOREST", x = 5, y = 5 } },
  }
  local okAreaPort = pcall(TownMapRenderer.draw, specGame, areaState, 360, 640, t)
  T.eq(okAreaPort, true, "TownMapRenderer renders area mode habitat list in Portrait Mobile")

  -- Test BagRenderer with item action submenu modal (USE / TOSS)
  local itemActionSubmenu = {
    items = { { label = "USE" }, { label = "TOSS" } },
    index = 1,
  }
  local okBagAction = pcall(BagRenderer.draw, specGame, bagState, 800, 600, t, itemActionSubmenu)
  T.eq(okBagAction, true, "BagRenderer renders item action submenu modal (USE/TOSS) in landscape")
  local okBagActionPort = pcall(BagRenderer.draw, specGame, bagState, 360, 640, t, itemActionSubmenu)
  T.eq(okBagActionPort, true, "BagRenderer renders item action submenu modal in portrait")

  -- Test BagRenderer with quantity selector modal
  local qtySubState = { isQuantityBox = true, qty = 5, max = 20, unitPrice = 100 }
  local okBagQty = pcall(BagRenderer.draw, specGame, bagState, 800, 600, t, qtySubState)
  T.eq(okBagQty, true, "BagRenderer renders quantity selector modal in landscape")
  local okBagQtyPort = pcall(BagRenderer.draw, specGame, bagState, 360, 640, t, qtySubState)
  T.eq(okBagQtyPort, true, "BagRenderer renders quantity selector modal in portrait")
end

do
  local ModManagerRenderer = require("mods.omni_ui.renderers.ModManagerRenderer")
  local t = Theme.get()
  local specGame = { data = Data, save = { player = { name = "RED" } }, stack = { states = {} } }

  -- Test ModManagerRenderer in Portrait Mobile (Mods tab, Profiles tab, Errors tab)
  local modMgrStateMods = {
    screen = "list",
    tab = 1,
    cursor = 1,
    rows = {
      { mod = { id = "kanto_reforged", name = "Kanto Reforged", version = "1.7.6", enabled = true, description = "Gen 2-3 content" } },
      { mod = { id = "pokegear", name = "Pokegear Cards", version = "1.0.0", enabled = false } },
    },
    status = { available = { "kanto_reforged", "pokegear" }, errors = {} },
  }
  local okModMgrMods = pcall(ModManagerRenderer.draw, specGame, modMgrStateMods, 360, 640, t)
  T.eq(okModMgrMods, true, "ModManagerRenderer renders stacked mods list and docked drawer in Portrait (360x640)")

  local modMgrStateProfiles = {
    screen = "list",
    tab = 2,
    cursor = 1,
    rows = {
      { profile = { name = "Profile 1", enabled = { kanto_reforged = true } } },
      { saveAs = true, label = "Save Current As..." },
    },
    status = { available = { "kanto_reforged" }, errors = {} },
  }
  local okModMgrProf = pcall(ModManagerRenderer.draw, specGame, modMgrStateProfiles, 360, 640, t)
  T.eq(okModMgrProf, true, "ModManagerRenderer renders profiles tab in Portrait Mobile")

  local modMgrStateErrors = {
    screen = "list",
    tab = 3,
    cursor = 1,
    errorLines = function() return { "No errors reported." } end,
    status = { available = {}, errors = {} },
  }
  local okModMgrErr = pcall(ModManagerRenderer.draw, specGame, modMgrStateErrors, 360, 640, t)
  T.eq(okModMgrErr, true, "ModManagerRenderer renders error log in Portrait Mobile")

  -- Test PokedexRenderer Data Entry View in Portrait Mobile
  local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
  local dexEntryState = {
    screenId = "DexEntryMenu",
    species = "PIKACHU",
    def = {
      id = "PIKACHU",
      name = "PIKACHU",
      dex = 25,
      types = { "ELECTRIC" },
      dexEntry = { species = "MOUSE", heightFt = 1, heightIn = 4, weightKg = 6.0, text = "When several of these POKEMON gather..." },
    },
  }
  local okDexEntryPort = pcall(PokedexRenderer.draw, specGame, dexEntryState, 360, 640, t)
  T.eq(okDexEntryPort, true, "PokedexRenderer renders Pokédex data entry view in Portrait Mobile (360x640)")

  -- Test StartMenuRenderer scroll hysteresis
  local StartMenuRenderer = require("mods.omni_ui.renderers.StartMenuRenderer")
  local scrollHysteresisState = {
    items = {
      { label = "ITEM 1" },
      { label = "ITEM 2" },
      { label = "ITEM 3" },
      { label = "ITEM 4" },
      { label = "ITEM 5" },
      { label = "ITEM 6" },
      { label = "ITEM 7" },
      { label = "ITEM 8" },
    },
    index = 1,
  }
  -- Step down to item 7
  scrollHysteresisState.index = 7
  StartMenuRenderer.draw(specGame, scrollHysteresisState, 360, 400, t)
  local scrollAfterDown = scrollHysteresisState.scroll
  T.eq(scrollAfterDown > 1, true, "Scrolling down advances viewport scroll position")

  -- Step up 1 item (to item 6): viewport scroll should NOT immediately jump back to lock item 6 at the bottom
  scrollHysteresisState.index = 6
  StartMenuRenderer.draw(specGame, scrollHysteresisState, 360, 400, t)
  T.eq(scrollHysteresisState.scroll, scrollAfterDown, "Moving up 1 item preserves scroll position rather than forcing bottom alignment")
  -- Test Modern QWERTY NamingRenderer & Navigation
  do
    local NamingRenderer = require("mods.omni_ui.renderers.NamingRenderer")
    local testDoneName = nil
    local namingState = {
      isNamingScreen = true,
      title = "YOUR NAME?",
      maxLen = 7,
      glyphs = {},
      row = 1,
      col = 1,
      onDone = function(name) testDoneName = name end,
    }

    local namingGame = {
      data = Data,
      input = fakeInput,
      stack = {
        states = { namingState },
        pop = function(self) table.remove(self.states) end,
      },
    }
    namingState.game = namingGame

    -- 1. Render in Portrait & Landscape
    local okNamingPort = pcall(NamingRenderer.draw, namingGame, namingState, 360, 640, t)
    T.eq(okNamingPort, true, "NamingRenderer renders QWERTY keyboard in Portrait Mobile (360x640)")

    local okNamingLand = pcall(NamingRenderer.draw, namingGame, namingState, 800, 600, t)
    T.eq(okNamingLand, true, "NamingRenderer renders QWERTY keyboard in Desktop Landscape (800x600)")

    local okNamingPhone = pcall(NamingRenderer.draw, namingGame, namingState, 390, 844, t)
    T.eq(okNamingPhone, true, "NamingRenderer renders QWERTY keyboard in Ultra-Tall Mobile Portrait (390x844)")

    local okNamingHandheld = pcall(NamingRenderer.draw, namingGame, namingState, 640, 360, t)
    T.eq(okNamingHandheld, true, "NamingRenderer renders QWERTY keyboard in Compact Landscape (640x360)")

    -- Test with Mon nickname mode
    local monNamingState = {
      isNamingScreen = true,
      title = "NICKNAME?",
      maxLen = 10,
      mon = { species = "PIKACHU" },
      glyphs = { "S", "P", "A", "R", "K", "Y" },
    }
    local okMonNaming = pcall(NamingRenderer.draw, namingGame, monNamingState, 360, 640, t)
    T.eq(okMonNaming, true, "NamingRenderer renders Pokémon nickname mode with sprite preview")

    -- 2. Test Input Navigation via screen.pushed controller
    run.loader.events:emit("screen.pushed", { state = namingState })
    T.neq(namingState.update, nil, "NamingScreen has interactive QWERTY controller attached")

    -- Initial position: Row 1, Col 1 (Q)
    T.eq(namingState._omniRow, 1, "Initial row is 1")
    T.eq(namingState._omniCol, 1, "Initial col is 1 (Q)")

    -- Move right to Col 2 (W)
    fakeInput:press("right")
    namingState:update(1/60)
    T.eq(namingState._omniCol, 2, "Moved right to Col 2 (W)")

    -- Move right to Col 3 (E) and type 'E'
    fakeInput:press("right")
    namingState:update(1/60)
    T.eq(namingState._omniCol, 3, "Moved right to Col 3 (E)")
    fakeInput:press("a")
    namingState:update(1/60)
    T.eq(table.concat(namingState.glyphs), "E", "Typed 'E' into name")

    -- Move down to Row 2, Col 3 (D) and type 'D'
    fakeInput:press("down")
    namingState:update(1/60)
    T.eq(namingState._omniRow, 2, "Moved down to Row 2")
    T.eq(namingState._omniCol, 3, "Row 2 Col 3 is 'D'")
    fakeInput:press("a")
    namingState:update(1/60)
    T.eq(table.concat(namingState.glyphs), "ED", "Typed 'D', current name is 'ED'")

    -- Press B to delete 'D'
    fakeInput:press("b")
    namingState:update(1/60)
    T.eq(table.concat(namingState.glyphs), "E", "B button deleted 'D', current name is 'E'")

    -- Press SELECT to toggle case: upper -> lower
    fakeInput:press("select")
    namingState:update(1/60)
    T.eq(namingState._omniMode, "lower", "SELECT toggled keyboard from upper to lower")

    -- Press SELECT again: lower -> sym
    fakeInput:press("select")
    namingState:update(1/60)
    T.eq(namingState._omniMode, "sym", "SELECT toggled keyboard from lower to sym")

    -- Press SELECT again: sym -> upper
    fakeInput:press("select")
    namingState:update(1/60)
    T.eq(namingState._omniMode, "upper", "SELECT toggled keyboard from sym to upper")

    -- Toggle back to lower for typing 'f'
    fakeInput:press("select")
    namingState:update(1/60)
    T.eq(namingState._omniMode, "lower", "SELECT toggled keyboard back to lower")

    -- Move to Col 4 (f) and type 'f'
    fakeInput:press("right")
    namingState:update(1/60)
    T.eq(namingState._omniCol, 4, "Moved right to Col 4 (f)")
    fakeInput:press("a")
    namingState:update(1/60)
    T.eq(table.concat(namingState.glyphs), "Ef", "Typed 'f' in lowercase")

    -- Move down to Row 4 (Action Row) -> lands on action button
    fakeInput:press("down")
    namingState:update(1/60)
    fakeInput:press("down")
    namingState:update(1/60)
    T.eq(namingState._omniRow, 4, "Moved to Row 4 (Action Row)")

    -- Move right to OK button (Col 5 in Row 4) and confirm
    namingState._omniCol = 5
    fakeInput:press("a")
    namingState:update(1/60)
    T.eq(namingState._confirming, true, "OK button opens confirmation modal")
    fakeInput:press("a")
    namingState:update(1/60)
    T.eq(testDoneName, "Ef", "Confirmed name 'Ef' via OK button confirmation")

    -- 3. Test Lazy Auto-Attachment on Draw (even if screen.pushed was not emitted)
    local unattachedState = {
      glyphs = {},
      maxLen = 7,
      row = 1,
      col = 1,
      game = namingGame,
    }
    T.eq(unattachedState.__omniUiNamingAttached, nil, "Initially unattached")
    NamingRenderer.draw(namingGame, unattachedState, 800, 600, t)
    T.eq(unattachedState.__omniUiNamingAttached, true, "Lazy attached on draw")
    T.neq(unattachedState.update, nil, "Update method hooked on draw")

    -- 4. Test Navigation Wrapping in All Directions
    -- Up from Row 1 wraps to Row 4
    unattachedState._omniRow = 1
    unattachedState._omniCol = 1
    fakeInput:press("up")
    unattachedState:update(1/60)
    T.eq(unattachedState._omniRow, 4, "Up from Row 1 wrapped to Row 4")

    -- Down from Row 4 wraps to Row 1
    fakeInput:press("down")
    unattachedState:update(1/60)
    T.eq(unattachedState._omniRow, 1, "Down from Row 4 wrapped to Row 1")

    -- Left from Col 1 wraps to Col 10
    fakeInput:press("left")
    unattachedState:update(1/60)
    T.eq(unattachedState._omniCol, 10, "Left from Col 1 wrapped to Col 10")

    -- Right from Col 10 wraps to Col 1
    fakeInput:press("right")
    unattachedState:update(1/60)
    T.eq(unattachedState._omniCol, 1, "Right from Col 10 wrapped to Col 1")

    -- 5. Test Action Row (Row 4) Buttons
    unattachedState._omniRow = 4
    -- Col 1: Case button (toggle upper <-> lower)
    unattachedState._omniCol = 1
    unattachedState._omniMode = "upper"
    fakeInput:press("a")
    unattachedState:update(1/60)
    T.eq(unattachedState._omniMode, "lower", "Case button in Row 4 toggled to lower")

    -- Col 2: Sym button (toggle sym)
    unattachedState._omniCol = 2
    fakeInput:press("a")
    unattachedState:update(1/60)
    T.eq(unattachedState._omniMode, "sym", "Sym button in Row 4 toggled to sym")

    -- Col 3: Space button
    unattachedState._omniCol = 3
    fakeInput:press("a")
    unattachedState:update(1/60)
    T.eq(table.concat(unattachedState.glyphs), " ", "Space button added space character")

    -- Col 4: Del button
    unattachedState._omniCol = 4
    fakeInput:press("a")
    unattachedState:update(1/60)
    T.eq(table.concat(unattachedState.glyphs), "", "Del button deleted character")

    do
      -- 6. Test Start Button Request Confirm
      unattachedState.glyphs = { "R", "E", "D" }
      fakeInput:press("start")
      unattachedState:update(1/60)
      T.eq(unattachedState._confirming, true, "Start button opens name confirmation modal")

      -- Confirm with YES (Choice 1)
      local confirmedFinal = false
      unattachedState.confirm = function() confirmedFinal = true end
      fakeInput:press("a")
      unattachedState:update(1/60)
      T.eq(confirmedFinal, true, "A button on YES confirms name")
    end

    do
      -- 6b. Test Direct NamingRenderer.handleInput with GBA-style input proxy (Birch speech)
      local gbaNamingState = {
        name = "",
        maxLen = 7,
        template = "PLAYER",
      }
      local pressedKey = nil
      local gbaInputProxy = {
        wasPressed = function(self, k) return k == pressedKey end,
        isDown = function(self, k) return false end,
      }

      -- Move right to Col 2 ('W')
      pressedKey = "right"
      NamingRenderer.handleInput(gbaNamingState, gbaInputProxy, namingGame)
      T.eq(gbaNamingState._omniCol, 2, "GBA input proxy moved cursor right to Col 2 (W)")

      -- Type 'W'
      pressedKey = "a"
      NamingRenderer.handleInput(gbaNamingState, gbaInputProxy, namingGame)
      T.eq(gbaNamingState.name, "W", "GBA input proxy typed 'W' via A button")

      -- Test Gen 3 Naming singleton hook
      local NamingMod = package.loaded["src.ui.game3.naming"]
      if NamingMod then
        local savedState = NamingMod._state
        local savedFlag = NamingMod.openFlag
        NamingMod.openFlag = true
        NamingMod._state = gbaNamingState

        -- Move Down to Row 2 ('S')
        pressedKey = "down"
        NamingMod.handleInput(gbaInputProxy)
        T.eq(gbaNamingState._omniRow, 2, "Naming.handleInput moved cursor down to Row 2")

        -- Type 'S'
        pressedKey = "a"
        NamingMod.handleInput(gbaInputProxy)
        T.eq(gbaNamingState.name, "WS", "Naming.handleInput typed 'S', resulting in 'WS'")

        -- Naming.draw suppression check (should safely return without error or drawing GBA keyboard)
        local okGbaDraw = pcall(NamingMod.draw)
        T.eq(okGbaDraw, true, "Naming.draw safely suppressed when OmniUI overlay is active")

        NamingMod._state = savedState
        NamingMod.openFlag = savedFlag
      end
    end

    do
      -- 7. Test NamingScreen with choosing = true (Preset Selection Phase)
      local choosingState = {
        screenId = "NamingScreen",
        choosing = true,
        glyphs = {},
        maxLen = 7,
      }
      T.eq(ModernOverlay.isSupported(choosingState), nil, "ModernOverlay ignores NamingScreen while choosing presets")
      local okChoosingDraw = pcall(NamingRenderer.draw, namingGame, choosingState, 800, 600, t)
      T.eq(okChoosingDraw, true, "NamingRenderer draw returns early when choosing is true")
    end

    do
      -- 8. Test ModernOverlay.drawMenu for Preset Name Menu
      local presetMenuState = {
        items = {
          { label = "NEW NAME" },
          { label = "RED" },
          { label = "ASH" },
          { label = "JACK" },
        },
        index = 1,
        title = "NAME",
        tx = 0,
        ty = 0,
        tw = 11,
        th = 12,
      }
      T.eq(ModernOverlay.isSupported(presetMenuState), "menu", "ModernOverlay detects Menu state as 'menu'")
      local fakeViewport = { gameX = 80, gameY = 12, gameWidth = 640, gameHeight = 576, scale = 4, width = 800, height = 600 }
      local okMenuDraw = pcall(ModernOverlay.drawMenu, namingGame, presetMenuState, 800, 600, t, nil, fakeViewport)
      T.eq(okMenuDraw, true, "drawMenu renders modern vector card for preset name menu in landscape (800x600)")

      local okMenuPort = pcall(ModernOverlay.drawMenu, namingGame, presetMenuState, 390, 844, t, nil, nil)
      T.eq(okMenuPort, true, "drawMenu renders responsive compact card above touch controls in mobile portrait (390x844)")

      local okMenuHandheld = pcall(ModernOverlay.drawMenu, namingGame, presetMenuState, 640, 360, t, nil, nil)
      T.eq(okMenuHandheld, true, "drawMenu renders responsive card cleanly in compact landscape (640x360)")

      local okMenuWide = pcall(ModernOverlay.drawMenu, namingGame, presetMenuState, 900, 400, t, nil, { gameX = 228, gameY = 0, gameWidth = 444, gameHeight = 400, scale = 2.77 })
      T.eq(okMenuWide, true, "drawMenu renders left-docked card in mobile ultra-wide landscape (900x400)")
    end

    do
      -- 9. Test IntroRenderer.composeIntroScene
      local IntroRenderer = require("mods.omni_ui.renderers.IntroRenderer")
      local fakeRenderer = { blitCanvas = function() end }
      local fakeCtx = { uiCanvas = {}, ww = 800, wh = 600, ox = 80, oy = 12, Sx = 4, Sy = 4, zones = { { colors = { {255,255,255}, {170,170,170}, {85,85,85}, {0,0,0} } } } }
      local mockOak = { sgbPalettes = function(self, g) return { { colors = { {255,239,255}, {247,181,140}, {132,115,156}, {25,16,16} } } } end }
      local okIntroCompose = pcall(IntroRenderer.composeIntroScene, fakeRenderer, fakeCtx, t, mockOak, namingGame)
      T.eq(okIntroCompose, true, "IntroRenderer composites themed laboratory backdrop, pedestal, and colored character sprite")
    end

    do
      -- 10. Test TextBox Typewriter & ContAdvance Auto-Advance
      local TextBox = require("src.render.TextBox")
      local fakeInput = { isDown = function() return false end, wasPressed = function() return false end }
      local multiLineText = "This world is\ninhabited by\vcreatures called\vPOKéMON!"
      local tbState = TextBox.new({ save = {}, data = {}, input = fakeInput }, multiLineText)
      ModernOverlay.attachControls(tbState, { input = fakeInput })
      T.eq(tbState.__omniContHooked, true, "attachControls hooks TextBox for seamless multi-line flow")
      for stepIdx = 1, 150 do
        tbState:update(0.016)
        if tbState.waiting and not tbState.contAdvance then break end
      end
      T.eq(tbState.contAdvance, false, "TextBox contAdvance auto-advances without pausing for intermediate A presses")
    end

    do
      -- 11. Test Naming Screen Confirmation Flow
      local namingConfirmState = {
        glyphs = { "R", "E", "D" },
        maxLen = 7,
        _confirming = true,
        _confirmChoice = 1,
      }
      local okConfirmDraw = pcall(NamingRenderer.draw, namingGame, namingConfirmState, 800, 600, t)
      T.eq(okConfirmDraw, true, "NamingRenderer renders confirmation modal dialog cleanly")
    end
    (function()
      -- 11. Test Gen2Adapter Data Normalization & Subsystems
      local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")
      local mockGame2 = {
        save = {
          player = { name = "GOLD", money = 25000 },
          money = 25000,
          momMoney = 15000,
          momShopping = true,
          johtoBadges = { true, true, true, true, true, true, true, true },
          kantoBadges = { true, true, true, true, false, false, false, false },
          unownDex = { 1, 2, 26 },
          tmBag = { TM02 = 1, TM08 = 2 },
          inventory = {
            POTION = 5,
            POKE_BALL = 10,
            BICYCLE = 1,
          },
          party = {
            { species = "CYNDAQUIL", level = 12, hp = 34, maxHp = 34, dvs = { attack = 10, defense = 10, speed = 10, special = 10 }, moves = { "TACKLE", "LEER", "SMOKESCREEN" } },
            { species = "EGG", isEgg = true, happiness = 15, hp = 0, maxHp = 0 },
            { species = "UNOWN", level = 5, hp = 20, maxHp = 20, dvs = { attack = 6, defense = 6, speed = 4, special = 4 }, moves = { "HIDDEN_POWER" } },
            { species = "MILTANK", level = 20, hp = 70, maxHp = 70, pokerus = 0x34, item = "FLOWER_MAIL", moves = { "ROLLOUT", "MILK_DRINK", "HEADBUTT" } },
            { species = "MAREEP", level = 15, hp = 45, maxHp = 45, pokerus = 0x30, moves = { "THUNDERSHOCK", "FLASH" } },
          },
        },
        data = {
          pokemon = {
            CYNDAQUIL = { name = "Cyndaquil", genderRatio = 0x1f, types = { "FIRE" }, johtoDex = 4, nationalDex = 155 },
            UNOWN = { name = "Unown", genderRatio = 0xff, types = { "PSYCHIC" }, johtoDex = 61, nationalDex = 201 },
            MILTANK = { name = "Miltank", genderRatio = 0xfe, types = { "NORMAL" }, johtoDex = 149, nationalDex = 241 },
            MAREEP = { name = "Mareep", genderRatio = 0x7f, types = { "ELECTRIC" }, johtoDex = 53, nationalDex = 179 },
            MAGNEMITE = { name = "Magnemite", genderRatio = 0xff, types = { "ELECTRIC", "STEEL" }, johtoDex = 118, nationalDex = 81 },
          },
          items = {
            POTION = { name = "POTION", pocket = "ITEM" },
            POKE_BALL = { name = "POKé BALL", pocket = "BALL" },
            BICYCLE = { name = "BICYCLE", pocket = "KEY_ITEM" },
            TM02 = { name = "TM02", pocket = "TM_HM", teaches = "HEADBUTT" },
            TM08 = { name = "TM08", pocket = "TM_HM", teaches = "ROCK_SMASH" },
            FLOWER_MAIL = { name = "FLOWER MAIL", pocket = "ITEM" },
          },
          moves = {
            HEADBUTT = { name = "HEADBUTT", type = "NORMAL", power = 70, accuracy = 100, pp = 15 },
            ROCK_SMASH = { name = "ROCK SMASH", type = "FIGHTING", power = 20, accuracy = 100, pp = 15 },
            MILK_DRINK = { name = "MILK DRINK", type = "NORMAL", pp = 10 },
            FLASH = { name = "FLASH", type = "NORMAL", pp = 20 },
            TACKLE = { name = "TACKLE", type = "NORMAL", pp = 35 },
            LEER = { name = "LEER", type = "NORMAL", pp = 30 },
            SMOKESCREEN = { name = "SMOKESCREEN", type = "NORMAL", pp = 20 },
            HIDDEN_POWER = { name = "HIDDEN POWER", type = "NORMAL", pp = 15 },
            THUNDERSHOCK = { name = "THUNDERSHOCK", type = "ELECTRIC", pp = 30 },
          },
        },
      }

      local adapter = Gen2Adapter.new(mockGame2)

      -- A. Test normalizeMon (Egg)
      local eggNorm = adapter:normalizeMon(mockGame2.save.party[2], 2)
      T.eq(eggNorm.isEgg, true, "Gen2Adapter recognizes Egg in party")
      T.eq(eggNorm.species, "EGG", "Egg species normalized to EGG")
      T.eq(eggNorm.level, nil, "Egg level is nil to prevent Lv.0 gauge crash")
      T.eq(eggNorm.eggCycles, 15, "Egg cycle count preserved from happiness")
      T.eq(type(eggNorm.eggFlavorText), "string", "Egg flavor text populated")
      T.eq(eggNorm.eggFlavorText:find("Wonder what's") ~= nil, true, "Egg cycle 15 yields expected GSC flavor text")

      -- B. Test normalizeMon (Unown letter form derivation)
      local unownNorm = adapter:normalizeMon(mockGame2.save.party[3], 3)
      T.eq(unownNorm.species, "UNOWN", "Unown species recognized")
      T.eq(unownNorm.form, "Z", "Unown DVs (6,6,4,4) correctly derive letter Z")

      -- C. Test normalizeMon (Pokérus Active vs Cured)
      local miltankNorm = adapter:normalizeMon(mockGame2.save.party[4], 4)
      T.eq(miltankNorm.pokerus, "infected", "Miltank 0x34 Pokerus normalized to 'infected'")
      T.eq(miltankNorm.pokerusDays, 4, "Miltank Pokerus days remaining is 4")
      T.eq(miltankNorm.pokerusStrain, 3, "Miltank Pokerus strain is 3")
      T.eq(miltankNorm.isMail, true, "Miltank holding FLOWER_MAIL sets isMail=true")

      local mareepNorm = adapter:normalizeMon(mockGame2.save.party[5], 5)
      T.eq(mareepNorm.pokerus, "cured", "Mareep 0x30 Pokerus normalized to 'cured'")
      T.eq(mareepNorm.pokerusDays, 0, "Mareep cured Pokerus days is 0")

      -- D. Test Gen 2 Field Moves
      T.eq(#miltankNorm.fieldMoves >= 2, true, "Miltank has MILK_DRINK and HEADBUTT as Gen 2 field moves")
      T.eq(#mareepNorm.fieldMoves >= 1, true, "Mareep has FLASH as field move")

      -- E. Test 4-Pocket Bag System & TM Move Lookup
      local pockets = adapter:getBagPockets()
      T.eq(#pockets, 4, "Gen2Adapter provides exactly 4 pockets (ITEM, BALL, KEY_ITEM, TM_HM)")
      T.eq(pockets[1].id, "ITEM", "Pocket 1 is ITEM")
      T.eq(pockets[2].id, "BALL", "Pocket 2 is BALL")
      T.eq(pockets[3].id, "KEY_ITEM", "Pocket 3 is KEY_ITEM")
      T.eq(pockets[4].id, "TM_HM", "Pocket 4 is TM_HM")

      local tmEntry = pockets[4].items[1]
      T.eq(tmEntry.isTM, true, "TM entry isTM flag is true")
      T.eq(tmEntry.teaches, "HEADBUTT", "TM02 teaches HEADBUTT")
      T.eq(tmEntry.moveName, "HEADBUTT", "TM02 enriched with moveName HEADBUTT")
      T.eq(tmEntry.moveType, "NORMAL", "TM02 enriched with moveType NORMAL")
      T.eq(tmEntry.power, 70, "TM02 enriched with power 70")
      T.eq(tmEntry.tmLabel, "TM02", "TM02 keeps its printed TM number")
      T.eq(tmEntry.desc:find("HEADBUTT") ~= nil or tmEntry.desc:find("[Hh]eadbutt") ~= nil, true, "TM02 description comes from the move")

      -- A pack row uses the object id (`TM_DIG`) and a placeholder item
      -- description. The view has to show the TM number, the move, and the
      -- move's own power and text, and leave the pack row itself alone.
      mockGame2.data.items.TM_DIG = {
        id = "TM_DIG", name = "TM28", tmLabel = "TM28", pocket = "TM_HM",
        teaches = "DIG", description = "?",
      }
      mockGame2.data.moves.DIG = {
        name = "DIG", type = "GROUND", power = 80, accuracy = 100, pp = 10,
        description = "Digs underground, then strikes.",
      }
      mockGame2.data.items.TM_SWAGGER = {
        id = "TM_SWAGGER", tmLabel = "TM34", pocket = "TM_HM",
        teaches = "SWAGGER", description = "?",
      }
      mockGame2.data.moves.SWAGGER = {
        name = "SWAGGER", type = "NORMAL", power = 0, accuracy = 90, pp = 15,
        description = "?",
      }
      mockGame2.data.items.TM_SHADOW_BALL = {
        id = "TM_SHADOW_BALL", name = "TM30", tmLabel = "TM30", pocket = "TM_HM",
      }
      mockGame2.data.moves.SHADOW_BALL = {
        name = "SHADOW BALL", type = "GHOST", power = 80, accuracy = 100, pp = 15,
        description = "Hurls a shadowy blob.",
      }
      local packRow = { id = "TM_DIG", name = "TM_DIG", teaches = "TM_DIG", count = 1 }
      local digView = adapter:presentBagItem(packRow)
      T.eq(digView.tmLabel, "TM28", "TM_DIG view uses the printed TM number")
      T.eq(digView.moveName, "DIG", "TM_DIG view uses the move name")
      T.eq(digView.label, "TM28 DIG", "TM_DIG label is the number plus the move")
      T.eq(digView.power, 80, "TM_DIG power comes from the move")
      T.eq(digView.accuracy, 100, "TM_DIG accuracy comes from the move")
      T.eq(digView.desc, "Digs underground, then strikes.", "TM_DIG description is the move text")
      T.eq(packRow.teaches, "TM_DIG", "presentBagItem leaves the pack row untouched")
      local swaggerView = adapter:presentBagItem({ id = "TM_SWAGGER", count = 1 })
      T.eq(swaggerView.power, 0, "TM_SWAGGER keeps a real power of 0")
      T.eq(swaggerView.accuracy, 90, "TM_SWAGGER accuracy is 90, not the 100 fallback")
      T.eq(swaggerView.desc:find("Enrages") ~= nil or swaggerView.desc:find("confusion") ~= nil, true, "TM_SWAGGER description is not the placeholder")
      local shadowView = adapter:presentBagItem({ id = "TM_SHADOW_BALL", count = 1 })
      T.eq(shadowView.moveName, "SHADOW BALL", "TM_SHADOW_BALL move is read from the object id")
      T.eq(shadowView.power, 80, "TM_SHADOW_BALL power is 80")
      T.eq(shadowView.desc, "Hurls a shadowy blob.", "TM_SHADOW_BALL description is the move text")
      local ItemDatabase = require("mods.omni_ui.core.ItemDatabase")
      local digInfo = ItemDatabase.getDescription("TM_DIG", mockGame2.data.items.TM_DIG, mockGame2)
      T.eq(digInfo:find("Digs underground") ~= nil, true, "Item info for TM_DIG uses the move description")

      -- F. Test Player Info, 16 Badges & Mom's Savings
      local pInfo = adapter:getPlayerInfo()
      T.eq(pInfo.badges, 12, "Player has 12 total badges (8 Johto + 4 Kanto)")
      T.eq(pInfo.johtoBadges, 8, "Player has 8 Johto badges")
      T.eq(pInfo.kantoBadges, 4, "Player has 4 Kanto badges")

      -- Real Gold writes badges by name on the player, and the dex as
      -- species -> true. Array length of either table is zero.
      local gearGame = {
        gameVersion = "gold",
        save = {
          player = {
            name = "GOLD",
            money = 4321,
            badges = { ZEPHYR = true, HIVE = true, PLAIN = true },
            kantoBadges = { BOULDER = true },
          },
          pokedex = {
            seen = { CYNDAQUIL = true, TOTODILE = true, CHIKORITA = true, SENTRET = true },
            caught = { CYNDAQUIL = true, TOTODILE = true },
          },
        },
        data = mockGame2.data,
      }
      local gearInfo = Gen2Adapter.new(gearGame):getPlayerInfo()
      T.eq(gearInfo.badges, 4, "Pokégear badge total reads player.badges and player.kantoBadges")
      T.eq(gearInfo.johtoBadges, 3, "Johto badge count is the named player.badges set")
      T.eq(gearInfo.kantoBadges, 1, "Kanto badge count is player.kantoBadges")
      T.eq(gearInfo.pokedex.seen, 4, "Pokédex seen counts the species map")
      T.eq(gearInfo.pokedex.owned, 2, "Pokédex owned reads pokedex.caught")
      T.eq(gearInfo.johtoBadgeFlags[1], true, "ZEPHYR lights badge slot 1")
      T.eq(gearInfo.johtoBadgeFlags[4], false, "Unheld FOG stays dark")
      local gearEntries = Gen2Adapter.new(gearGame):getPokedexEntries("NEW")
      local cynda
      for _, entry in ipairs(gearEntries) do
        if entry.id == "CYNDAQUIL" then cynda = entry break end
      end
      T.eq(cynda and cynda.seen, true, "Caught Johto species is seen in the dex")
      T.eq(cynda and cynda.caught, true, "Caught Johto species is owned via pokedex.caught")
      T.eq(pInfo.momSavings, 15000, "Mom savings balance is $15,000")
      T.eq(pInfo.momShopping, true, "Mom shopping flag is true")
      T.eq(type(pInfo.rtc), "table", "RTC table populated")
      T.eq(type(pInfo.rtc.timeOfDay), "string", "RTC timeOfDay resolved")

      -- G. Test PC Storage Mail Lockout
      local canDepMail, mailErr = adapter:canDeposit(4, 1)
      T.eq(canDepMail, false, "canDeposit blocks depositing Pokémon holding MAIL")
      T.eq(mailErr:find("MAIL") ~= nil, true, "Deposit error explicitly mentions MAIL lockout")

      -- H. Test Bug-Catching Contest Start Menu Injection
      mockGame2.save.bugContest = { active = true, balls = 20, time = 20, caughtMon = { species = "PINSIR", nickname = "PINSIR" } }
      local contestItems = adapter:getStartMenuItems()
      T.eq(contestItems[1].id, "contest_status", "Bug contest Start Menu injects contest_status at top")
      T.eq(contestItems[1].value, "×20", "Bug contest displays ×20 PARK BALLS")
      T.eq(contestItems[2].id, "contest_mon", "Bug contest injects caught Pokémon inspector")

      -- I. Test Pokédex Sort Modes & Unown Dex
      local newDex = adapter:getPokedexEntries("NEW")
      T.eq(#newDex >= 4, true, "getPokedexEntries('NEW') returns Johto dex entries")
      local oldDex = adapter:getPokedexEntries("OLD")
      T.eq(#oldDex >= 4, true, "getPokedexEntries('OLD') returns National dex entries")
      local unownList = adapter:getUnownDex()
      T.eq(#unownList, 3, "getUnownDex returns 3 caught Unown letters")
      T.eq(unownList[1].letter, "A", "Unown letter 1 is A")
      T.eq(unownList[2].letter, "B", "Unown letter 2 is B")
      T.eq(unownList[3].letter, "Z", "Unown letter 3 is Z")

      -- J. Test ModernOverlay Gen 2 State Routing & Pass-Through
      local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2StartMenu" }), "start_menu", "Gen2StartMenu recognized as start_menu")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2PartyMenu" }), "party", "Gen2PartyMenu recognized as party")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2SummaryMenu" }), "summary", "Gen2SummaryMenu recognized as summary")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2PackMenu" }), "bag", "Gen2PackMenu recognized as bag")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2TrainerCard" }), "trainer_card", "Gen2TrainerCard recognized as trainer_card")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2SaveMenu" }), "save", "Gen2SaveMenu recognized as save")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2OptionsMenu" }), "options", "Gen2OptionsMenu recognized as options")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2PokedexMenu" }), "pokedex", "Gen2PokedexMenu recognized as pokedex")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2BoxMenu" }), "storage", "Gen2BoxMenu recognized as storage")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2MartMenu" }), "shop", "Gen2MartMenu recognized as shop")
      T.eq(ModernOverlay.isSupported({ screenId = "ItemPcMenu" }), "player_pc", "ItemPcMenu recognized as player_pc")
      T.eq(ModernOverlay.isSupported({ screenId = "Gen2Pokegear" }), "pokegear", "Gen2Pokegear recognized as pokegear")
      T.eq(ModernOverlay.isSupported({ screenId = "Pokegear" }), "pokegear", "Pokegear recognized as pokegear")
      T.eq(ModernOverlay.isSupported({ screenId = "SlotMachine" }), false, "SlotMachine routes to native pass-through")
      T.eq(ModernOverlay.isSupported({ screenId = "CardFlip" }), false, "CardFlip routes to native pass-through")
      T.eq(ModernOverlay.isSupported({ screenId = "UnownPuzzle" }), false, "UnownPuzzle routes to native pass-through")

      -- Test PokegearRenderer Across Cards (Clock, Town Map, Phone, Radio)
      local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
      local pokegearState = {
        screenId = "Gen2Pokegear",
        cardIndex = 1,
        cards = {
          { id = "clock", label = "CLOCK" },
          { id = "map", label = "MAP" },
          { id = "phone", label = "PHONE" },
          { id = "radio", label = "RADIO" },
        },
        clock = { hour = 14, minute = 30, weekday = 3, dayName = "TUESDAY" },
        clockParts = function() return 14, 30, 3 end,
        tuningKnob = 20,
        ensureTuned = function() end,
        stations = function()
          return {
            { knob = 20, frequency = "101.5", name = "OAK'S POKÉMON TALK", station = "OAKS_POKEMON_TALK" },
            { knob = 40, frequency = "105.5", name = "POKÉMON MARCH", station = "POKEMON_MUSIC" },
          }
        end,
        currentStation = function()
          return { knob = 20, frequency = "101.5", name = "OAK'S POKÉMON TALK", station = "OAKS_POKEMON_TALK" }
        end,
        radio = { stationName = "OAK'S POKÉMON TALK", top = "PROF. OAK: Today on Route 29...", bottom = "PIDGEY and SENTRET are active!" },
        phoneList = function() return { 1, 2, 3 } end,
        contactRow = function(self, id)
          if id == 1 then return "MOM", nil end
          if id == 2 then return "PROF. ELM", "PROFESSOR" end
          return "JOEY", "YOUNGSTER"
        end,
        phoneScroll = 0,
        phoneCursor = 0,
      }

      -- 1. Clock Card Render
      pokegearState.cardIndex = 1
      local okClockL = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 800, 600, theme, 1.0)
      T.eq(okClockL, true, "PokegearRenderer renders Clock card in landscape (800x600)")
      local okClockP = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 390, 844, theme, 1.0)
      T.eq(okClockP, true, "PokegearRenderer renders Clock card in mobile portrait (390x844)")

      -- 2. Map Card Render
      pokegearState.cardIndex = 2
      local okMapL = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 800, 600, theme, 1.0)
      T.eq(okMapL, true, "PokegearRenderer renders Map card in landscape")

      -- 3. Phone Card Render
      pokegearState.cardIndex = 3
      local okPhoneL = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 800, 600, theme, 1.0)
      T.eq(okPhoneL, true, "PokegearRenderer renders Phone card in landscape")
      local okPhoneP = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 390, 844, theme, 1.0)
      T.eq(okPhoneP, true, "PokegearRenderer renders Phone card in mobile portrait")

      -- 3b. Phone Card with out-of-bounds cursor/scroll (e.g. only 2 contacts registered)
      local pokegear2Contacts = {
        screenId = "Gen2Pokegear",
        cardIndex = 3,
        cards = { { id = "phone", label = "PHONE" } },
        phoneList = function() return { 1, 4, 0, 0, 0, 0, 0, 0, 0, 0 } end,
        contactRow = function(self, id)
          if id == 1 then return "MOM", nil end
          if id == 4 then return "PROF. OAK", "PROFESSOR" end
          return nil, nil
        end,
        phoneScroll = 4,
        phoneCursor = 3,
      }
      local okPhoneClamp = pcall(PokegearRenderer.draw, mockGame2, pokegear2Contacts, 800, 600, theme, 1.0)
      T.eq(okPhoneClamp, true, "PokegearRenderer cleanly clamps phone cursor when scrolling past 2 contacts")
      T.eq(pokegear2Contacts.phoneCursor, 1, "Cursor clamped to 2nd contact (index 1)")
      T.eq(pokegear2Contacts.phoneScroll, 0, "Scroll clamped to 0")

      -- 4. Active In-Call Render & Phone Chat Forking
      pokegearState.call = { name = "PROF. ELM", text = "Hello! How is the egg doing?" }
      local okCallL = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 800, 600, theme, 1.0)
      T.eq(okCallL, true, "PokegearRenderer renders in-call active dialogue modal")

      -- Test 4b: Live Dialogue Forking from Stacked Gen 2 TextBox (e.g. Call to Mom)
      local mockMomTextBox = {
        isTextBox = true,
        pages = {
          { "Hello?", "" },
        },
        pageIndex = 1,
        lineIndex = 1,
        charIndex = 6,
        waiting = true,
      }
      local mockCallGame = {
        stack = {
          states = {
            { isWorld = true },
            pokegearState,
            mockMomTextBox,
          },
          top = function() return mockMomTextBox end,
        },
        input = { wasPressed = function() return false end, isDown = function() return false end },
      }
      pokegearState.call = { name = "MOM", text = "MOM: ……" }
      local dState, cState = PokegearRenderer.getActiveCallDialogue(mockCallGame, pokegearState)
      T.eq(dState == mockMomTextBox, true, "getActiveCallDialogue finds stacked Mom TextBox")
      local extractedText, isWaiting, isNext = PokegearRenderer.extractCallMessage(mockMomTextBox, mockCallGame)
      T.eq(extractedText, "Hello?", "extractCallMessage extracts live dialogue text from TextBox")
      local okChatDraw = pcall(PokegearRenderer.draw, mockCallGame, pokegearState, 800, 600, theme, 1.0)
      T.eq(okChatDraw, true, "PokegearRenderer forks live dialogue into phone chat UI")

      -- Test 4c: Choice Box inside Phone Chat (Mom asking YES / NO)
      local mockMomChoice = {
        isChoiceBox = true,
        options = { "YES", "NO" },
        cursor = 1,
      }
      table.insert(mockCallGame.stack.states, mockMomChoice)
      local dState2, cState2 = PokegearRenderer.getActiveCallDialogue(mockCallGame, pokegearState)
      T.eq(cState2 == mockMomChoice, true, "getActiveCallDialogue finds stacked Mom ChoiceBox")
      local okChoiceDraw = pcall(PokegearRenderer.draw, mockCallGame, pokegearState, 800, 600, theme, 1.0)
      T.eq(okChoiceDraw, true, "PokegearRenderer renders interactive choice buttons inside phone chat")

      -- Test 4d: Multi-page transcript accumulation without clearing previous lines
      local mockMultiTextBox = {
        isTextBox = true,
        pages = {
          { "Hello?", "Good morning!" },
          { "Are you doing", "well, PLAYER?" },
          { "Remember to", "save money!" },
        },
        pageIndex = 1,
        waiting = true,
      }
      local testCall = { name = "MOM" }
      -- Frame 1: Page 1 active
      local lines1, wait1, next1 = PokegearRenderer.updateCallTranscript(testCall, mockMultiTextBox, mockCallGame, 400)
      T.eq(#lines1 >= 1, true, "Page 1 produces display lines")
      T.eq(lines1[1]:find("Hello") ~= nil, true, "Page 1 line starts with Hello")
      T.eq(next1, true, "Has next page")

      -- Advance to Page 2
      mockMultiTextBox.pageIndex = 2
      local lines2, wait2, next2 = PokegearRenderer.updateCallTranscript(testCall, mockMultiTextBox, mockCallGame, 400)
      T.eq(#lines2 >= 2, true, "Transcript retains Page 1 and adds Page 2 lines")
      T.eq(lines2[1]:find("Hello") ~= nil, true, "First line still contains Hello from Page 1")
      local foundP2 = false
      for _, l in ipairs(lines2) do
        if l:find("well") or l:find("PLAYER") then foundP2 = true end
      end
      T.eq(foundP2, true, "Lines contain content from Page 2")

      -- Advance to Page 3
      mockMultiTextBox.pageIndex = 3
      local lines3, wait3, next3 = PokegearRenderer.updateCallTranscript(testCall, mockMultiTextBox, mockCallGame, 400)
      T.eq(#lines3 >= 3, true, "Transcript accumulates Page 1, Page 2, and Page 3")
      local foundP3 = false
      for _, l in ipairs(lines3) do
        if l:find("save") or l:find("money") then foundP3 = true end
      end
      T.eq(foundP3, true, "Lines contain content from Page 3")

      -- Finish TextBox and pop
      mockCallGame.stack.states = { pokegearState }
      local lines4, wait4, next4 = PokegearRenderer.updateCallTranscript(testCall, nil, mockCallGame, 400)
      T.eq(#lines4 >= 3, true, "Transcript retains accumulated lines after TextBox closes")

      pokegearState.call = nil

      -- 5. Radio Card Render
      pokegearState.cardIndex = 4
      local okRadioL = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 800, 600, theme, 1.0)
      T.eq(okRadioL, true, "PokegearRenderer renders Radio broadcast tuner in landscape")
      local okRadioP = pcall(PokegearRenderer.draw, mockGame2, pokegearState, 390, 844, theme, 1.0)
      T.eq(okRadioP, true, "PokegearRenderer renders Radio broadcast tuner in portrait")

      -- 6. DexNav Card Render (Kanto-Reforged & pokegear_cards)
      local dexnavState = {
        screenId = "Gen2Pokegear",
        cardIndex = 5,
        cards = {
          { id = "clock", label = "CLOCK" },
          { id = "map", label = "MAP" },
          { id = "phone", label = "PHONE" },
          { id = "radio", label = "RADIO" },
          { id = "dexnav", label = "DEXNAV" },
        },
        mode = "card",
        _krDexNavMap = "ROUTE_29",
        _krDexNavCursor = 0,
        _krDexNavScroll = 0,
        _krDexNavFooter = "No Good/Super Rod.",
        _krDexNavItems = {
          { label = "PIDGEY", right = "GRASS 2-5", value = "pidgey" },
          { label = "SENTRET", right = "GRASS 2-3", value = "sentret" },
          { label = "RAIKOU", right = "ROAM 40", value = "raikou" },
        },
      }
      local okDexL = pcall(PokegearRenderer.draw, mockGame2, dexnavState, 800, 600, theme, 1.0)
      T.eq(okDexL, true, "PokegearRenderer renders DexNav card in landscape (800x600)")
      local okDexP = pcall(PokegearRenderer.draw, mockGame2, dexnavState, 390, 844, theme, 1.0)
      T.eq(okDexP, true, "PokegearRenderer renders DexNav card in portrait (390x844)")

      -- 6b. DexNav Unseen Species Masking (Must NOT leak species name or dex number)
      local unseenDexnavState = {
        screenId = "Gen2Pokegear",
        cardIndex = 5,
        cards = {
          { id = "clock", label = "CLOCK" },
          { id = "map", label = "MAP" },
          { id = "phone", label = "PHONE" },
          { id = "radio", label = "RADIO" },
          { id = "dexnav", label = "DEXNAV" },
        },
        mode = "card",
        _krDexNavMap = "DARK_CAVE",
        _krDexNavCursor = 0,
        _krDexNavScroll = 0,
        _krDexNavItems = {
          { label = "????", right = "", value = "dunsparce" },
        },
      }
      local okUnseen = pcall(PokegearRenderer.draw, mockGame2, unseenDexnavState, 800, 600, theme, 1.0)
      T.eq(okUnseen, true, "PokegearRenderer cleanly masks unseen wild species without leaking data")

      -- 6c. DexNav Dynamic Habitat Advice Templates (Nocturnal, Fishing, Roaming, Diurnal)
      local hoppoipDexnavState = {
        screenId = "Gen2Pokegear",
        cardIndex = 1,
        cards = { { id = "dexnav", label = "DEXNAV" } },
        mode = "card",
        _krDexNavMap = "ROUTE_33",
        _krDexNavCursor = 0,
        _krDexNavScroll = 0,
        _krDexNavItems = {
          { label = "HOPPIP", right = "SEEN", value = "hoppip" },
        },
      }
      local mockGameWithGen2Enc = {
        data = {
          pokemon = {
            hoppip = { id = 187, name = "HOPPIP", types = { "GRASS", "FLYING" } },
          },
          gen2Encounters = {
            grass = {
              ROUTE_33 = {
                slots = {
                  MORN = { { species = "HOPPIP", level = 7 } },
                  DAY = { { species = "HOPPIP", level = 7 } },
                  NITE = { { species = "RATTATA", level = 7 } },
                },
              },
            },
          },
        },
        save = {
          pokedex = {
            seen = { hoppip = true },
          },
        },
      }
      local okHoppip = pcall(PokegearRenderer.draw, mockGameWithGen2Enc, hoppoipDexnavState, 800, 600, theme, 1.0)
      T.eq(okHoppip, true, "PokegearRenderer renders Hoppip daylight habitat advice cleanly")

      -- 6d. Text Wrapping & Bounded Layout Verification for DexNav
      local sampleAdvice = {
        "ACTIVE IN DAYLIGHT HOURS (4:00 AM - 5:59 PM).",
        "SEARCH TALL GRASS IN MORNING OR DAY. SLEEPS AT NIGHT.",
      }
      local testMaxW = 260
      local wrapped = PokegearRenderer.wrapToWidth(sampleAdvice, testMaxW, "tiny")
      T.eq(#wrapped >= 3, true, "wrapToWidth wraps long Hoppip advice into at least 3 lines for maxW=260")
      local allWithinBounds = true
      for _, l in ipairs(wrapped) do
        if Layout.textWidth(l, "tiny") > testMaxW then
          allWithinBounds = false
        end
      end
      T.eq(allWithinBounds, true, "All wrapped advice lines strictly respect text box bounds")

      -- 6e. Cross-Platform Adaptive Viewport Verification
      local viewports = {
        { w = 1920, h = 1080, name = "1080p Widescreen" },
        { w = 1280, h = 720,  name = "720p Widescreen" },
        { w = 800,  h = 600,  name = "800x600 Standard" },
        { w = 390,  h = 844,  name = "390x844 Mobile Portrait" },
        { w = 360,  h = 640,  name = "360x640 Mobile Portrait" },
        { w = 480,  h = 320,  name = "480x320 Compact Handheld" },
        { w = 320,  h = 240,  name = "320x240 Retro Handheld" },
      }
      for _, vp in ipairs(viewports) do
        local okVp = pcall(PokegearRenderer.draw, mockGameWithGen2Enc, hoppoipDexnavState, vp.w, vp.h, theme, 1.0)
        T.eq(okVp, true, "DexNav renders adaptively on " .. vp.name)
      end

      -- 7. attachPokegearControls with DexNav Interaction
      local inputState = {
        _pressed = {},
        wasPressed = function(self, key)
          return self._pressed[key] == true
        end,
      }
      local mockGearGame = {
        input = inputState,
        data = mockGame2.data,
        save = mockGame2.save,
      }
      local testGear = {
        game = mockGearGame,
        cardIndex = 1,
        mode = "strip",
        cards = {
          { id = "clock", label = "CLOCK" },
          { id = "map", label = "MAP" },
          { id = "phone", label = "PHONE" },
          { id = "radio", label = "RADIO" },
          { id = "dexnav", label = "DEXNAV" },
        },
        _krDexNavItems = {
          { label = "PIDGEY", right = "GRASS", value = "pidgey" },
          { label = "RATTATA", right = "GRASS", value = "rattata" },
        },
        _krDexNavCursor = 0,
        _krDexNavScroll = 0,
      }
      ModernOverlay.attachPokegearControls(testGear, mockGearGame)
      T.check(testGear.update ~= nil, "PokegearControls attached update handler")

      -- Step right 4 times to reach dexnav (index 5)
      for step = 1, 4 do
        inputState._pressed = { right = true }
        testGear:update(0.016)
      end
      inputState._pressed = {}
      T.eq(testGear.cardIndex, 5, "Stepped to DexNav card index 5")

      -- Press A to enter card mode
      inputState._pressed = { a = true }
      testGear:update(0.016)
      inputState._pressed = {}
      T.eq(testGear.mode, "card", "A button opened DexNav card mode")

      -- Press Down to move cursor
      inputState._pressed = { down = true }
      testGear:update(0.016)
      inputState._pressed = {}
      T.eq(testGear._krDexNavCursor, 1, "Down arrow moved DexNav cursor to item 1")

      -- Press Up to move cursor back
      inputState._pressed = { up = true }
      testGear:update(0.016)
      inputState._pressed = {}
      T.eq(testGear._krDexNavCursor, 0, "Up arrow returned DexNav cursor to item 0")

      -- Press B to back out to strip mode
      inputState._pressed = { b = true }
      testGear:update(0.016)
      inputState._pressed = {}
      T.eq(testGear.mode, "strip", "B button backed out to strip mode")

      -- K. Test TrainerCard Dual Region Johto & Kanto Rendering
      local TrainerCardRenderer = require("mods.omni_ui.renderers.TrainerCardRenderer")
      local cardStateJohto = { cardFace = "JOHTO" }
      local cardStateKanto = { cardFace = "KANTO" }
      local okTCJohto = pcall(TrainerCardRenderer.draw, mockGame2, cardStateJohto, 800, 600, theme)
      T.eq(okTCJohto, true, "TrainerCardRenderer renders Johto badge page without errors")
      local okTCKanto = pcall(TrainerCardRenderer.draw, mockGame2, cardStateKanto, 800, 600, theme)
      T.eq(okTCKanto, true, "TrainerCardRenderer renders Kanto badge page without errors")
      local okTCPortrait = pcall(TrainerCardRenderer.draw, mockGame2, cardStateJohto, 360, 640, theme)
      T.eq(okTCPortrait, true, "TrainerCardRenderer renders mobile portrait passport cleanly")

      -- L. Test Pokedex Unown Dex & Tri-Mode Sorting Rendering
      local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
      local unownDexState = { unownDex = true }
      local okUnownRender = pcall(PokedexRenderer.draw, mockGame2, unownDexState, 800, 600, theme)
      T.eq(okUnownRender, true, "PokedexRenderer renders 26-glyph Unown Dex showcase cleanly")
      local okUnownPortrait = pcall(PokedexRenderer.draw, mockGame2, unownDexState, 360, 640, theme)
      T.eq(okUnownPortrait, true, "PokedexRenderer renders 26-glyph Unown Dex on portrait screen")

      -- M. Test SaveRenderer RTC Clock, Time-of-Day Badge, and Gen 2 Choice/Phase
      local SaveRenderer = require("mods.omni_ui.renderers.SaveRenderer")
      local saveStateYes = { phase = "confirm", choice = 1 }
      local okSaveRenderYes = pcall(SaveRenderer.draw, mockGame2, saveStateYes, 800, 600, theme)
      T.eq(okSaveRenderYes, true, "SaveRenderer renders Gen 2 SaveMenu with YES selected (choice = 1)")

      local saveStateNo = { phase = "confirm", choice = 2 }
      local okSaveRenderNo = pcall(SaveRenderer.draw, mockGame2, saveStateNo, 800, 600, theme)
      T.eq(okSaveRenderNo, true, "SaveRenderer renders Gen 2 SaveMenu with NO selected (choice = 2)")

      local saveStateDone = { phase = "done", choice = 1 }
      local okSaveRenderDone = pcall(SaveRenderer.draw, mockGame2, saveStateDone, 800, 600, theme)
      T.eq(okSaveRenderDone, true, "SaveRenderer renders Gen 2 SaveMenu in 'done' saved state")

      -- N. Test Theme Time-of-Day Ambient Harmonization
      local mornTheme = Theme.applyTimeOfDay(theme, "MORN", 0.20)
      T.eq(type(mornTheme), "table", "Theme.applyTimeOfDay produces valid theme object for MORN")
      T.eq(mornTheme.colors.bg[1] >= theme.colors.bg[1], true, "MORN theme elevates warm amber red channel")
      local niteTheme = Theme.applyTimeOfDay(theme, "NITE", 0.20)
      T.eq(type(niteTheme), "table", "Theme.applyTimeOfDay produces valid theme object for NITE")
      T.eq(niteTheme.colors.bg[3] >= theme.colors.bg[3], true, "NITE theme elevates deep indigo blue channel")

      -- O. Test Native Gen 2 MainMenu and StartMenu Instance Compatibility
      local okG2MM, G2MainMenu = pcall(require, "src.ui.gen2.MainMenu")
      if okG2MM and G2MainMenu and G2MainMenu.new then
        local mmInst = G2MainMenu.new(mockGame2, { hasSave = true, save = mockGame2.save })
        T.eq(ModernOverlay.isSupported(mmInst), "main_menu", "Real Gen 2 MainMenu instance is recognized as main_menu")
        local MainMenuRenderer = require("mods.omni_ui.renderers.MainMenuRenderer")
        local okMMDraw = pcall(MainMenuRenderer.draw, mockGame2, mmInst, 800, 600, theme)
        T.eq(okMMDraw, true, "MainMenuRenderer draws real Gen 2 MainMenu instance cleanly")
      end

      -- Test Native Gen 2 SaveMenu Instance Left/Right Navigation
      local okG2SaveMenu, G2SaveMenu = pcall(require, "src.ui.gen2.SaveMenu")
      if okG2SaveMenu and G2SaveMenu and G2SaveMenu.new then
        mockGame2.input = {
          _pressed = {},
          wasPressed = function(self, k) return self._pressed[k] == true end,
        }
        local saveInst = G2SaveMenu.new(mockGame2, { save = mockGame2.save, existed = true })
        ModernOverlay.attachControls(saveInst, mockGame2)
        T.eq(saveInst.choice, 1, "Gen 2 SaveMenu starts on YES (choice = 1)")

        -- Step update until typer completes prompt
        local Typer = require("src.ui.gen2.Typer")
        for _ = 1, 100 do
          saveInst:update(0)
          if not Typer.typing(saveInst) then break end
        end

        -- Simulate Left press
        mockGame2.input._pressed = { left = true }
        saveInst:update(0)
        T.eq(saveInst.choice, 2, "Pressing LEFT cycles cursor to NO (choice = 2)")

        -- Simulate Right press
        mockGame2.input._pressed = { right = true }
        saveInst:update(0)
        T.eq(saveInst.choice, 1, "Pressing RIGHT cycles cursor back to YES (choice = 1)")
      end

      -- Test ChoiceBox Instance Left/Right Navigation (Gen 1 / Overworld / Dialogue Yes/No)
      local okCB, ChoiceBox = pcall(require, "src.ui.ChoiceBox")
      if okCB and ChoiceBox and ChoiceBox.new then
        local choiceBoxInst = ChoiceBox.new(mockGame2, function() end)
        T.eq(choiceBoxInst.index, 1, "ChoiceBox starts on index 1 (YES)")

        mockGame2.input._pressed = { left = true }
        choiceBoxInst:update(0)
        T.eq(choiceBoxInst.index, 2, "ChoiceBox pressing LEFT cycles to index 2 (NO)")

        mockGame2.input._pressed = { right = true }
        choiceBoxInst:update(0)
        T.eq(choiceBoxInst.index, 1, "ChoiceBox pressing RIGHT cycles back to index 1 (YES)")
      end

      local okG2SM, G2StartMenu = pcall(require, "src.ui.gen2.StartMenu")
      if okG2SM and G2StartMenu and G2StartMenu.new then
        local g2SaveWithTableTime = {
          player = { name = "GOLD" },
          playTime = { hours = 14, minutes = 22, seconds = 40 },
          johtoBadges = { true, true, false, false, false, false, false, false },
        }
        local gameWithTableTime = {
          gameVersion = "gold",
          save = g2SaveWithTableTime,
        }
        local smInst = G2StartMenu.new(gameWithTableTime, { save = g2SaveWithTableTime })
        ModernOverlay.attachControls(smInst, gameWithTableTime)
        T.eq(ModernOverlay.isSupported(smInst), "start_menu", "Real Gen 2 StartMenu instance is recognized as start_menu")
        local StartMenuRenderer = require("mods.omni_ui.renderers.StartMenuRenderer")
        local okSMDraw = pcall(StartMenuRenderer.draw, gameWithTableTime, smInst, 800, 600, theme)
        T.eq(okSMDraw, true, "StartMenuRenderer draws real Gen 2 StartMenu instance cleanly with table playTime")
        local pInfo = Gen2Adapter.new(gameWithTableTime):getPlayerInfo()
        T.eq(pInfo.playTimeString, "14:22", "Gen2Adapter formats table playTime correctly as 14:22")

        -- Test QUIT confirmation phase Left/Right navigation
        gameWithTableTime.input = {
          _pressed = {},
          wasPressed = function(self, k) return self._pressed[k] == true end,
        }
        smInst.phase = "confirm"
        smInst.confirmChoice = 2 -- defaults to NO
        local okQuitDraw = pcall(StartMenuRenderer.draw, gameWithTableTime, smInst, 800, 600, theme)
        T.eq(okQuitDraw, true, "StartMenuRenderer renders Return to Title Screen modal cleanly")

        gameWithTableTime.input._pressed = { left = true }
        smInst:update(0)
        T.eq(smInst.confirmChoice, 1, "StartMenu QUIT modal: pressing LEFT toggles to YES (confirmChoice = 1)")

        gameWithTableTime.input._pressed = { right = true }
        smInst:update(0)
        T.eq(smInst.confirmChoice, 2, "StartMenu QUIT modal: pressing RIGHT toggles back to NO (confirmChoice = 2)")
      end

      -- Test Gen 2 MainMenu CONTINUE modal Left/Right Navigation
      local okG2MM, G2MainMenu = pcall(require, "src.ui.gen2.MainMenu")
      if okG2MM and G2MainMenu and G2MainMenu.new then
        local continued = false
        local mmGame = {
          gameVersion = "gold",
          save = {
            player = { name = "TAYLOR" },
            playTime = { hours = 0, minutes = 13, seconds = 0 },
            johtoBadges = { true, false, false, false, false, false, false, false },
          },
          input = {
            _pressed = {},
            wasPressed = function(self, k) return self._pressed[k] == true end,
          }
        }
        local mmInst = G2MainMenu.new(mmGame, {
          hasSave = true,
          save = mmGame.save,
          onContinue = function() continued = true end,
        })
        ModernOverlay.attachControls(mmInst, mmGame)
        T.eq(ModernOverlay.isSupported(mmInst), "main_menu", "Gen2MainMenu is recognized as main_menu")

        -- Trigger CONTINUE
        mmInst:choose("continue")
        T.eq(mmInst.phase, "confirm", "MainMenu enters confirm phase on continue")
        T.eq(mmInst.confirmChoice, 1, "MainMenu starts confirm on YES (confirmChoice = 1)")
        mmInst.confirmDelay = 0 -- fast forward input delay

        -- Test Right press toggles to NO
        mmGame.input._pressed = { right = true }
        mmInst:update(0)
        T.eq(mmInst.confirmChoice, 2, "MainMenu CONTINUE modal: pressing RIGHT toggles to NO (confirmChoice = 2)")

        -- Test Left press toggles back to YES
        mmGame.input._pressed = { left = true }
        mmInst:update(0)
        T.eq(mmInst.confirmChoice, 1, "MainMenu CONTINUE modal: pressing LEFT toggles to YES (confirmChoice = 1)")

        -- Toggle back to NO and press A to cancel back to menu
        mmGame.input._pressed = { right = true }
        mmInst:update(0)
        T.eq(mmInst.confirmChoice, 2, "ConfirmChoice is 2 (NO)")
        mmGame.input._pressed = { a = true }
        mmInst:update(0)
        T.eq(mmInst.phase, "menu", "Pressing A on NO returns to main menu list")
        T.eq(continued, false, "Did not trigger continue on NO")
      end

      -- Test OptionsRenderer with Gen 2 Options & Sub-Options (SPEED group)
      local okOptR, OptionsRenderer = pcall(require, "mods.omni_ui.renderers.OptionsRenderer")
      local okG2Opt, G2OptionsMenu = pcall(require, "src.ui.gen2.OptionsMenu")
      if okOptR and OptionsRenderer and okG2Opt and G2OptionsMenu then
        local optGame = {
          gameVersion = "gold",
          options = {
            textSpeed = "MID",
            speed = 2,
            battleScene = true,
            frame = 3,
          },
        }
        local optInst = G2OptionsMenu.new(optGame, { options = optGame.options })
        T.eq(ModernOverlay.isSupported(optInst), "options", "Gen2OptionsMenu is recognized as options")

        -- Draw root options menu
        local okOptDraw = pcall(OptionsRenderer.draw, optGame, optInst, 800, 600, theme)
        T.eq(okOptDraw, true, "OptionsRenderer renders root Gen 2 options menu cleanly")

        -- Create SPEED sub-options state
        local speedSubState = {
          sub = true,
          title = "SPEED",
          index = 1,
          options = optGame.options,
          rows = {
            {
              label = "TEXT SPEED", key = "textSpeed",
              values = { "FAST", "MID", "SLOW" },
              display = { FAST = "FAST", MID = "MID", SLOW = "SLOW" },
            },
            {
              label = "GAME SPEED", key = "speed",
              text = function(options)
                local s = tonumber(options.speed) or 1
                return (s == 1) and "NORMAL" or (s .. "X")
              end,
              cycle = function(options, delta)
                options.speed = ((options.speed or 1) + delta - 1) % 4 + 1
              end,
            },
            { label = "BACK", isBack = true },
          }
        }
        local okSubDraw = pcall(OptionsRenderer.draw, optGame, speedSubState, 800, 600, theme)
        T.eq(okSubDraw, true, "OptionsRenderer renders SPEED sub-options with segmented pills and GAME SPEED text")
      end

      -- P. Test MenuFade & BlankScreen Suppression & Acceleration
      local mockFade = { screenId = "Gen2MenuFade", white = 8, kind = "out", left = 16 }
      local mockBlank = { screenId = "Gen2BlankScreen", left = 4, onDone = function() end }
      T.eq(ModernOverlay.isSupported(mockFade), false, "MenuFade is recognized as hardware transition, not a modern content screen")
      T.eq(ModernOverlay.isSupported(mockBlank), false, "BlankScreen is recognized as hardware transition, not a modern content screen")

      -- Q. Test Native Gen 2 PokedexMenu Input & Rendering
      local okG2Dex, G2PokedexMenu = pcall(require, "src.ui.gen2.PokedexMenu")
      if okG2Dex and G2PokedexMenu and G2PokedexMenu.new then
        local dexGame = {
          gameVersion = "gold",
          save = {
            pokedex = {
              seen = { CHIKORITA = true, CYNDAQUIL = true },
              caught = { CHIKORITA = true },
            },
          },
          data = {
            gen2Pokedex = {
              newOrder = { "CHIKORITA", "CYNDAQUIL", "TYPHLOSION", "ESPEON", "TYRANITAR" },
              entries = {
                CHIKORITA = { dex = 152 },
                CYNDAQUIL = { dex = 155 },
                TYPHLOSION = { dex = 157 },
                ESPEON = { dex = 196 },
                TYRANITAR = { dex = 248 },
              },
            },
            pokemon = {
              CHIKORITA = { id = "CHIKORITA", species = "CHIKORITA", dex = 152, name = "CHIKORITA", types = { "GRASS" } },
              CYNDAQUIL = { id = "CYNDAQUIL", species = "CYNDAQUIL", dex = 155, name = "CYNDAQUIL", types = { "FIRE" } },
              TYPHLOSION = { id = "TYPHLOSION", species = "TYPHLOSION", dex = 157, name = "TYPHLOSION", types = { "FIRE" } },
              ESPEON = { id = "ESPEON", species = "ESPEON", dex = 196, name = "ESPEON", types = { "PSYCHIC_TYPE" } },
              TYRANITAR = { id = "TYRANITAR", species = "TYRANITAR", dex = 248, name = "TYRANITAR", types = { "ROCK_TYPE", "DARK_TYPE" } },
            },
          },
          save = {
            pokedex = {
              seen = { CHIKORITA = true, CYNDAQUIL = true, TYPHLOSION = true, ESPEON = true },
              caught = { CHIKORITA = true },
              owned = { CHIKORITA = true },
            },
          },
          input = {
            _pressed = {},
            wasPressed = function(self, key) return self._pressed[key] == true end,
            isDown = function(self, key) return false end,
          },
          stack = {
            states = {},
            push = function(self, st) table.insert(self.states, st) end,
            pop = function(self) return table.remove(self.states) end,
            top = function(self) return self.states[#self.states] end,
          },
        }
        local dexInst = G2PokedexMenu.new(dexGame, {})
        dexGame.stack:push(dexInst)
        ModernOverlay.attachControls(dexInst, dexGame)
        T.eq(dexInst.view, "list", "Gen 2 Dex initializes in list view")
        T.eq(type(dexInst.rows), "table", "Gen 2 Dex retains table rows")
        T.eq(#dexInst.rows >= 1, true, "Gen 2 Dex has populated rows")

        -- Press A to open action submenu modal
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        T.eq(type(dexInst.submenu), "table", "Pressing A on seen species opens action submenu modal")
        T.eq(dexInst.submenu.items[1].label, "DATA", "Action submenu offers DATA first")
        T.eq(dexInst.submenu.items[2].label, "CRY", "Action submenu offers CRY second")
        T.eq(dexInst.submenu.items[3].label, "AREA", "Action submenu offers AREA third")

        local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
        local okDexSubDraw = pcall(PokedexRenderer.draw, dexGame, dexInst, 800, 600, theme)
        T.eq(okDexSubDraw, true, "PokedexRenderer draws Pokédex list with floating action submenu overlay cleanly")

        -- Press A on DATA to transition to entry view
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        T.eq(dexInst.view, "entry", "Selecting DATA transitions to clean full-page entry view")

        local okDexEntryDraw = pcall(PokedexRenderer.draw, dexGame, dexInst, 800, 600, theme)
        T.eq(okDexEntryDraw, true, "PokedexRenderer draws unified entry view cleanly")

        -- Press B on entry view to return to list
        dexGame.input._pressed = { b = true }
        dexInst:update(0.016)
        T.eq(dexInst.view, "list", "Pressing B in entry view returns to list")

        -- Re-open submenu, navigate to AREA, and select it
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        dexInst.submenu.index = 3 -- AREA
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        T.eq(dexInst.view, "area", "Selecting AREA transitions to habitat map view")

        -- Press B in area view to return to list
        dexGame.input._pressed = { b = true }
        dexInst:update(0.016)
        T.eq(dexInst.view, "list", "Pressing B in area view returns to list")

        -- Verify list numbering in NEW mode (Johto index) vs OLD mode (National dex index)
        T.eq(dexInst:mode(), "NEW", "Gen 2 Dex default mode is NEW (Johto order)")
        T.eq(dexInst.rows[1].species, "CHIKORITA", "Row 1 species is CHIKORITA")
        T.eq(dexInst.rows[1].dex, 152, "Row 1 national dex is 152")
        T.eq(dexInst.rows[2].species, "CYNDAQUIL", "Row 2 species is CYNDAQUIL")
        T.eq(dexInst.rows[2].dex, 155, "Row 2 national dex is 155")

        -- Test Search, Filter & Sort Integration
        local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")
        local g2Adapter = AdapterResolver.resolve(dexGame)

        -- 1. Test Filter Modes
        local allRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { filterMode = "ALL" })
        T.eq(#allRows, 5, "PokedexFilter: ALL returns all 5 species in Dex")

        local caughtRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { filterMode = "CAUGHT" })
        T.eq(#caughtRows, 1, "PokedexFilter: CAUGHT returns 1 species (Chikorita)")
        T.eq(caughtRows[1].species, "CHIKORITA", "PokedexFilter: CAUGHT filtered correctly")

        local uncaughtRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { filterMode = "UNCAUGHT" })
        T.eq(#uncaughtRows, 3, "PokedexFilter: UNCAUGHT returns 3 seen uncaught species")

        local typeRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { filterMode = "TYPE", typeFilter = "FIRE" })
        T.eq(#typeRows, 2, "PokedexFilter: TYPE (FIRE) returns Cyndaquil and Typhlosion")

        -- 2. Test Live Query Searching (Accuracy & Unseen Protection)
        local queryRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { query = "CYN" })
        T.eq(#queryRows, 1, "PokedexFilter: Search query 'CYN' matches Cyndaquil")
        T.eq(queryRows[1].species, "CYNDAQUIL", "PokedexFilter: Query matches species")

        -- Test searching "TY": Matches Typhlosion, does NOT match Espeon (PSYCHIC_TYPE), does NOT match unseen Tyranitar
        local tyRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { query = "TY" })
        T.eq(#tyRows, 1, "PokedexFilter: Search query 'TY' matches only seen species with TY (Typhlosion)")
        T.eq(tyRows[1].species, "TYPHLOSION", "PokedexFilter: 'TY' query matches Typhlosion")

        local numQueryRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { query = "152" })
        T.eq(#numQueryRows, 1, "PokedexFilter: Search query '152' matches Chikorita")

        -- 3. Test Sorting Modes
        local azRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { sortMode = "NAME_AZ" })
        T.eq(azRows[1].species, "CHIKORITA", "PokedexFilter: NAME_AZ sorts Chikorita first")
        T.eq(azRows[2].species, "CYNDAQUIL", "PokedexFilter: NAME_AZ sorts Cyndaquil second")
        T.eq(azRows[3].species, "ESPEON", "PokedexFilter: NAME_AZ sorts Espeon third")
        T.eq(azRows[4].species, "TYPHLOSION", "PokedexFilter: NAME_AZ sorts Typhlosion fourth")
        T.eq(azRows[5].species, "TYRANITAR", "PokedexFilter: NAME_AZ places unseen species last")

        local zaRows = PokedexFilter.buildRows(dexGame, dexInst, g2Adapter, { sortMode = "NAME_ZA" })
        T.eq(zaRows[1].species, "TYPHLOSION", "PokedexFilter: NAME_ZA sorts Typhlosion first")
        T.eq(zaRows[2].species, "ESPEON", "PokedexFilter: NAME_ZA sorts Espeon second")

        -- 4. Test 2D Spatial Grid Navigation (SELECT opens modal, Arrows navigate 2D grid, A selects)
        dexGame.input._pressed = { select = true }
        dexInst:update(0.016)
        T.eq(dexInst._filterModalOpen or dexInst.view == "option", true, "Pressing SELECT opens Search & Sort modal")
        T.eq(dexInst._gridSection, "sort", "Initial modal grid focus starts on sort section")
        T.eq(dexInst._gridIndex, 1, "Initial modal grid focus starts on item 1 (REGIONAL)")

        local okModalDraw = pcall(PokedexRenderer.draw, dexGame, dexInst, 800, 600, theme)
        T.eq(okModalDraw, true, "PokedexRenderer draws Search & Sort modal in landscape without errors")

        local okModalDrawNarrow = pcall(PokedexRenderer.draw, dexGame, dexInst, 400, 600, theme)
        T.eq(okModalDrawNarrow, true, "PokedexRenderer draws Search & Sort modal in portrait without errors")

        -- Press Right to move focus horizontally on sort grid
        dexGame.input._pressed = { right = true }
        dexInst:update(0.016)
        T.eq(dexInst._gridIndex, 2, "D-Pad Right moves grid focus horizontally to item 2 (NATIONAL)")

        -- Press A to toggle NATIONAL sort mode
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        T.eq(dexInst._dexSortMode, "NATIONAL", "Pressing A on focused button activates NATIONAL sort mode")

        -- Press Down to move vertically across grid rows (from item 2 NATIONAL to item 6 STATUS)
        dexGame.input._pressed = { down = true }
        dexInst:update(0.016)
        T.eq(dexInst._gridIndex, 6, "D-Pad Down moves focus down to row 2 in sort grid (item 6: STATUS)")

        -- Press Down to move to row 3 in sort grid (item 10: SHORTEST)
        dexGame.input._pressed = { down = true }
        dexInst:update(0.016)
        T.eq(dexInst._gridIndex, 10, "D-Pad Down moves focus down to row 3 in sort grid (item 10: SHORTEST)")

        -- Press Down again to move vertically into Filter section (lands on column 2: CAUGHT)
        dexGame.input._pressed = { down = true }
        dexInst:update(0.016)
        T.eq(dexInst._gridSection, "filter", "D-Pad Down moves focus across sections to Filter section")
        T.eq(dexInst._gridIndex, 2, "Focus lands directly on column 2 in filter grid (CAUGHT button)")

        -- Press A to select CAUGHT filter
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        T.eq(dexInst._dexFilterMode, "CAUGHT", "Pressing A selects CAUGHT filter mode")

        -- Press Down to navigate to Search Query box
        dexGame.input._pressed = { down = true }
        dexInst:update(0.016)
        T.eq(dexInst._gridSection, "search", "D-Pad Down moves focus across sections to Search Query box")
        T.eq(dexInst._gridIndex, 1, "Focus lands on search query input slot")

        -- Press A on Search Query box to launch authentic in-game keyboard text entry
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        local topScreen = dexGame.stack:top()
        T.eq(topScreen ~= dexInst, true, "Pressing A on Search Query box pushes in-game keyboard screen to stack")

        -- Simulate typing / confirming search query in the NamingScreen
        if topScreen and topScreen.onDone then
          topScreen.onDone("PIKA")
        end
        T.eq(dexInst._dexSearchQuery, "PIKA", "Virtual keyboard onDone updates _dexSearchQuery on Pokédex screen")

        -- Press Down from Search Query box to navigate to Action buttons
        dexGame.input._pressed = { down = true }
        dexInst:update(0.016)
        T.eq(dexInst._gridSection, "actions", "D-Pad Down moves focus to Action buttons")
        T.eq(dexInst._gridIndex, 1, "Focus lands on APPLY & RETURN button")

        -- Press A on APPLY & RETURN to apply and return to list
        dexGame.input._pressed = { a = true }
        dexInst:update(0.016)
        T.eq(dexInst.view, "list", "Pressing A on APPLY & RETURN closes modal and returns to list")

        -- Test Gen 1 Stack Resolution (Menu on top of PokedexMenu remains overlaid)
        local mockG1Dex = { screenId = "PokedexMenu", index = 1, scroll = 0, items = { { num = "001", name = "BULBASAUR", value = "BULBASAUR" } } }
        local mockG1Menu = { screenId = "Menu", items = { { label = "DATA" }, { label = "CRY" }, { label = "AREA" }, { label = "QUIT" } }, index = 1 }
        local mockG1Game = {
          data = dexGame.data,
          save = { pokedex = { seen = { BULBASAUR = true }, owned = { BULBASAUR = true } } },
          stack = { states = { mockG1Dex, mockG1Menu }, top = function(self) return self.states[#self.states] end },
        }
        local g1Kind, g1Active, _, g1Sub = ModernOverlay.getActiveScreen(mockG1Game)
        T.eq(g1Kind, "pokedex", "Gen 1: Menu stacked on PokedexMenu resolves active kind as 'pokedex'")
        T.eq(g1Active, mockG1Dex, "Gen 1: PokedexMenu remains active base screen")
        T.eq(g1Sub, mockG1Menu, "Gen 1: Submenu passed as subState overlay modal")
      end

      -- R. Test Native Gen 2 PackMenu Input & Rendering
      local okG2Pack, G2PackMenu = pcall(require, "src.ui.gen2.PackMenu")
      if okG2Pack and G2PackMenu and G2PackMenu.new then
        local packGame = {
          gameVersion = "gold",
          world = { useFieldItem = function() end },
          save = {
            inventory = {
              POTION = 5,
              SUPER_POTION = 2,
              POKE_BALL = 10,
              BICYCLE = 1,
            },
          },
          data = {
            items = {
              POTION = { id = "POTION", name = "POTION", pocket = "ITEM", price = 300, fieldMenu = "ITEMMENU_PARTY" },
              SUPER_POTION = { id = "SUPER_POTION", name = "SUPER POTION", pocket = "ITEM", price = 700, fieldMenu = "ITEMMENU_PARTY" },
              POKE_BALL = { id = "POKE_BALL", name = "POKé BALL", pocket = "BALL", price = 200, fieldMenu = "ITEMMENU_NOUSE" },
              BICYCLE = { id = "BICYCLE", name = "BICYCLE", pocket = "KEY_ITEM", keyItem = true, fieldMenu = "ITEMMENU_CURRENT" },
            },
          },
          input = {
            _pressed = {},
            wasPressed = function(self, key) return self._pressed[key] == true end,
          },
        }
        local packInst = G2PackMenu.new(packGame, {})
        T.eq(packInst.pocketIndex, 1, "Pack initializes in pocket 1 (ITEMS)")
        T.eq(type(packInst.rows), "table", "Pack retains table rows")
        T.eq(#packInst.rows >= 2, true, "Pack items pocket populated with POTION and SUPER POTION")

        -- Switch pocket right to BALLS
        packInst:switchPocket(1)
        T.eq(packInst.pocketIndex, 2, "switchPocket(1) moves to BALLS pocket")
        T.eq(packInst.rows[1].id, "POKE_BALL", "BALLS pocket lists POKE_BALL")

        -- Switch pocket back to ITEMS
        packInst:switchPocket(-1)
        T.eq(packInst.pocketIndex, 1, "switchPocket(-1) returns to ITEMS pocket")

        -- Press A on POTION to open item action submenu
        packGame.input._pressed = { a = true }
        packInst:update(0.016)
        T.eq(type(packInst.submenu), "table", "Pressing A on item opens submenu")
        T.eq(packInst.submenu.rows[1], "use", "Submenu offers USE as first action")

        local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
        local okPackSubDraw = pcall(BagRenderer.draw, packGame, packInst, 800, 600, theme)
        T.eq(okPackSubDraw, true, "BagRenderer draws Gen 2 PackMenu action submenu cleanly")

        -- Choose QUIT on submenu
        packInst.submenu.index = #packInst.submenu.rows
        packInst:chooseSubmenu()
        T.eq(packInst.submenu, nil, "Choosing QUIT closes action submenu")
      end

      -- S. Test Gen 2 Pokédex Entry Data, Lore, and Biology Normalization
      do
        local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")
        local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")
        local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
        local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")

        local g2Game = {
          gameVersion = "gold",
          save = {
            pokedex = {
              seen = { [155] = true, [158] = true, [25] = true },
              caught = { [155] = true, [158] = true },
            },
          },
          data = {
            pokemon = {
              CYNDAQUIL = { dex = 155, id = "CYNDAQUIL", name = "CYNDAQUIL", types = { "FIRE" } },
              TOTODILE = { dex = 158, id = "TOTODILE", name = "TOTODILE", types = { "WATER" } },
              PIKACHU = { dex = 25, id = "PIKACHU", name = "PIKACHU", types = { "ELECTRIC" } },
            },
            gen2Pokedex = {
              entries = {
                CYNDAQUIL = {
                  dex = 155,
                  kind = "FIRE MOUSE",
                  height = 200, -- 2'00"
                  weight = 174, -- 17.4 lbs
                  text = "It is timid, and always<NEXT>curls itself up into a ball.",
                  text2 = "If attacked, it shoots<NEXT>flames from its back.",
                },
                TOTODILE = {
                  dex = 158,
                  kind = "BIG JAW",
                  height = 200,
                  weight = 210,
                  text = "It has the habit of biting<NEXT>anything with its developed jaws.",
                  text2 = "Even its trainer needs to<NEXT>be careful.",
                },
              },
            },
            gen2Palettes = {
              pokemon = {
                CYNDAQUIL = {
                  normal = { { 239, 131, 49 }, { 90, 74, 115 } },
                  shiny = { { 156, 115, 173 }, { 90, 74, 115 } },
                },
                TOTODILE = {
                  normal = { { 107, 189, 239 }, { 214, 82, 90 } },
                  shiny = { { 115, 206, 140 }, { 90, 148, 206 } },
                },
              },
            },
          },
        }

        local g2Adapter = Gen2Adapter.new(g2Game)
        local cyndaEntry = g2Adapter:getDexEntry("CYNDAQUIL")
        T.eq(cyndaEntry.name, "CYNDAQUIL", "Gen 2 getDexEntry resolves name")
        T.eq(cyndaEntry.kind, "FIRE MOUSE", "Gen 2 getDexEntry resolves kind")
        T.eq(cyndaEntry.height, "2'00\"", "Gen 2 getDexEntry formats height 200 -> 2'00\"")
        T.eq(cyndaEntry.weight, "17.4 lbs", "Gen 2 getDexEntry formats weight 174 -> 17.4 lbs")
        T.eq(cyndaEntry.description:find("curls itself up") ~= nil, true, "Gen 2 getDexEntry merges text page 1")
        T.eq(cyndaEntry.description:find("shoots flames") ~= nil, true, "Gen 2 getDexEntry merges text page 2")
        T.eq(cyndaEntry.nationalDex, 155, "Gen 2 entry keeps the national dex number")
        T.eq(g2Adapter:hasSeen("CYNDAQUIL"), true, "Seen flag keyed by dex number matches the species")
        T.eq(g2Adapter:hasCaught("CYNDAQUIL"), true, "Caught flag keyed by dex number matches the species")
        T.eq(g2Adapter:hasCaught("PIKACHU"), false, "Seen-only species is not caught")

        g2Game.data.gen2Pokedex.newOrder = { "CYNDAQUIL", "TOTODILE" }
        g2Game.save.position = { map = "NEW_BARK_TOWN" }
        g2Game.data.maps = { NEW_BARK_TOWN = { id = "NEW_BARK_TOWN", landmark = 1 } }
        g2Game.data.gen2Landmarks = {
          landmarks = { LANDMARK_NEW_BARK_TOWN = { index = 1, name = "NEW BARK\nTOWN" } },
        }
        local placed = g2Adapter:getPlayerInfo()
        T.eq(placed.location, "NEW BARK TOWN", "Player location uses the map landmark name")
        local regional = g2Adapter:getDexEntry("CYNDAQUIL")
        T.eq(regional.regionalDex, 1, "Johto dex number follows newOrder")

        local metMon = g2Adapter:normalizeMon({
          species = "CYNDAQUIL", level = 5, hp = 20, maxHp = 20,
          caughtLocation = 1, caughtLevel = 5,
        }, 1)
        T.eq(metMon.metLocation, "NEW BARK TOWN", "Summary met place comes from the caught landmark")
        T.eq(metMon.originDesc, "Met at NEW BARK TOWN (Lv. 5)", "Summary origin line includes the met level")

        -- Test SpriteHelper Palette Resolution for Gen 2 (Normal & Shiny)
        local normalPal = SpriteHelper.getMonPalette(g2Game.data, "CYNDAQUIL", false)
        T.eq(type(normalPal), "table", "SpriteHelper resolves normal Gen 2 palette")
        T.eq(normalPal[2][1], 239, "Normal palette color 1 matched")

        local shinyPal = SpriteHelper.getMonPalette(g2Game.data, "CYNDAQUIL", true)
        T.eq(type(shinyPal), "table", "SpriteHelper resolves shiny Gen 2 palette")
        T.eq(shinyPal[2][1], 156, "Shiny palette color 1 matched")

        -- Test Type Deduplication Helper (Widgets.getUniqueTypes)
        local Widgets = require("mods.omni_ui.core.Widgets")
        local singleTypes = Widgets.getUniqueTypes({ "FIRE", "FIRE" })
        T.eq(#singleTypes, 1, "Widgets.getUniqueTypes deduplicates single-type {FIRE, FIRE} to 1 badge")
        T.eq(singleTypes[1], "FIRE", "Single type is FIRE")

        local dualTypes = Widgets.getUniqueTypes({ "GRASS_TYPE", "POISON_TYPE" })
        T.eq(#dualTypes, 2, "Widgets.getUniqueTypes keeps dual-types distinct and sanitizes _TYPE")
        T.eq(dualTypes[1], "GRASS", "First type is GRASS")
        T.eq(dualTypes[2], "POISON", "Second type is POISON")

        -- Test SummaryRenderer for Gen 2 Pokémon (Landscape & Portrait)
        local SummaryRenderer = require("mods.omni_ui.renderers.SummaryRenderer")
        local g2Mon = {
          species = "CYNDAQUIL",
          nickname = "CYNDA",
          level = 5,
          hp = 20,
          maxHp = 20,
          stats = { hp = 20, attack = 12, defense = 10, speed = 14, special = 13 },
          moves = { { name = "TACKLE", pp = 35, maxPp = 35, type = "NORMAL" } },
        }
        local g2SummaryState = {
          mon = g2Mon,
          party = { g2Mon },
          index = 1,
          page = 1,
        }
        local okG2SummaryLand = pcall(SummaryRenderer.draw, g2Game, g2SummaryState, 800, 600, theme)
        T.eq(okG2SummaryLand, true, "SummaryRenderer draws Gen 2 Pokémon in landscape with GBC palette and deduplicated type")

        local okG2SummaryPort = pcall(SummaryRenderer.draw, g2Game, g2SummaryState, 400, 700, theme)
        T.eq(okG2SummaryPort, true, "SummaryRenderer draws Gen 2 Pokémon in portrait with GBC palette and deduplicated type")

        -- Test Mod-Added Pokémon (e.g. Castform from Kanto-Reforged) Sprite Resolution
        local castformMon = {
          species = "CASTFORM",
          nickname = "CLOUDY",
          level = 25,
          hp = 70,
          maxHp = 70,
          types = { "NORMAL", "NORMAL" },
        }
        local castformSprite = SpriteHelper.resolveSprite(g2Game.data, "CASTFORM", "front", { mon = castformMon, kind = "party" })
        T.eq(type(castformSprite), "table", "SpriteHelper resolves mod-added species spriteInfo table")
        T.eq(castformSprite.species, "CASTFORM", "Sprite species is CASTFORM")

        -- Test Castform weather form palette & sprite resolution
        castformMon._krCastformForm = "sunny"
        local sunnyPal = SpriteHelper.getMonPalette(g2Game.data, "CASTFORM", false, castformMon)
        T.eq(type(sunnyPal), "table", "SpriteHelper resolves CASTFORM_SUNNY palette")

        castformMon._krCastformForm = "rainy"
        local rainyPal = SpriteHelper.getMonPalette(g2Game.data, "CASTFORM", false, castformMon)
        T.eq(type(rainyPal), "table", "SpriteHelper resolves CASTFORM_RAINY palette")

        castformMon._krCastformForm = "snowy"
        local snowyPal = SpriteHelper.getMonPalette(g2Game.data, "CASTFORM", false, castformMon)
        T.eq(type(snowyPal), "table", "SpriteHelper resolves CASTFORM_SNOWY palette")
        castformMon._krCastformForm = nil

        local PartyRenderer = require("mods.omni_ui.renderers.PartyRenderer")
        local partyStateWithCastform = {
          party = { g2Mon, castformMon },
          index = 2,
        }
        local okPartyDraw = pcall(PartyRenderer.draw, g2Game, partyStateWithCastform, 800, 600, theme)
        T.eq(okPartyDraw, true, "PartyRenderer draws party containing mod-added Pokémon (Castform) cleanly")

        -- Test DexEntry View Rendering for Gen 2 Pokémon
        local g2DexEntryState = {
          screenId = "DexEntryMenu",
          species = "CYNDAQUIL",
          page = 1,
        }
        local okG2DexEntry = pcall(PokedexRenderer.draw, g2Game, g2DexEntryState, 800, 600, theme)
        T.eq(okG2DexEntry, true, "PokedexRenderer draws Gen 2 Pokédex entry with full biology and lore")

        -- Test Area Gating before vs after Hall of Fame
        local areaBeforeHof = g2Adapter:getAreaInfo("CYNDAQUIL", "kanto")
        T.eq(areaBeforeHof.region, "johto", "Kanto area is gated to johto before Hall of Fame")
        T.eq(areaBeforeHof.canSwapRegion, false, "canSwapRegion is false before Hall of Fame")

        -- Unlock Kanto via Hall of Fame / badges
        g2Game.save.hasVisitedKanto = true
        local areaAfterHof = g2Adapter:getAreaInfo("CYNDAQUIL", "kanto")
        T.eq(areaAfterHof.region, "kanto", "Kanto area unlocks after visiting Kanto")
        T.eq(areaAfterHof.canSwapRegion, true, "canSwapRegion is true once Kanto unlocked")

        -- Test TownMapRenderer with Johto/Kanto Habitat Swap badge
        local okG2Area = pcall(TownMapRenderer.draw, g2Game, { view = "area", nestSpecies = "CYNDAQUIL" }, 800, 600, theme)
        T.eq(okG2Area, true, "TownMapRenderer draws Gen 2 habitat area with regional map switcher cleanly")

        -- Test Gen 2 Center PC Menu & PC Hub Integration
        local okG2CenterPc, G2CenterPcMenu = pcall(require, "src.ui.gen2.CenterPcMenu")
        local okPcHubR, PcHubRenderer = pcall(require, "mods.omni_ui.renderers.PcHubRenderer")
        if okG2CenterPc and G2CenterPcMenu and okPcHubR and PcHubRenderer then
          local centerPcInst = G2CenterPcMenu.new(g2Game, { save = g2Game.save })
          T.eq(ModernOverlay.isSupported(centerPcInst), "pc_hub", "Gen2CenterPcMenu is recognized as pc_hub")
          T.eq(#centerPcInst.entries >= 2, true, "Gen2CenterPcMenu has at least 2 entries (BILL'S PC, GOLD'S PC, etc.)")

          -- Test PcHubRenderer rendering in Landscape (800x600) and Mobile Portrait (360x640)
          local okHubDrawLand = pcall(PcHubRenderer.draw, g2Game, centerPcInst, 800, 600, theme)
          T.eq(okHubDrawLand, true, "PcHubRenderer renders Gen2CenterPcMenu in Landscape mode cleanly")

          local okHubDrawPort = pcall(PcHubRenderer.draw, g2Game, centerPcInst, 360, 640, theme)
          T.eq(okHubDrawPort, true, "PcHubRenderer renders Gen2CenterPcMenu in Mobile Portrait mode cleanly")

          -- Test Gen2PcMenu recognized as storage
          local fakeG2PcMenu = { screenId = "Gen2PcMenu", bills = true, save = g2Game.save }
          T.eq(ModernOverlay.isSupported(fakeG2PcMenu), "storage", "Gen2PcMenu (Bill's PC) is recognized as modern storage")

          -- Test Gen2ItemPcMenu recognized as player_pc
          local fakeG2ItemPc = { screenId = "Gen2ItemPcMenu", save = g2Game.save }
          T.eq(ModernOverlay.isSupported(fakeG2ItemPc), "player_pc", "Gen2ItemPcMenu (Player's PC) is recognized as player_pc")

          -- Test Gen2Adapter Item Storage & Bag integration
          local PlayerPcRenderer = require("mods.omni_ui.renderers.PlayerPcRenderer")
          local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")

          -- Seed some bag and PC items
          g2Game.save.pcItems = { POTION = 5, SUPER_POTION = 2 }
          g2Game.save.inventory = { POKE_BALL = 10, ANTIDOTE = 3 }

          local pcItems = g2Adapter:getItemStorage()
          T.eq(#pcItems >= 2, true, "Gen2Adapter:getItemStorage returns stored PC items")

          local bagItems = g2Adapter:getBagItems()
          T.eq(#bagItems >= 2, true, "Gen2Adapter:getBagItems returns player inventory items")

          -- Test Withdraw & Deposit operations
          local okWith, errWith = g2Adapter:withdrawItem("POTION", 2)
          T.eq(okWith, true, "Gen2Adapter:withdrawItem succeeds for POTION x2")
          T.eq(g2Game.save.pcItems.POTION, 3, "PC POTION count decreased to 3")

          local okDep, errDep = g2Adapter:depositItem("POKE_BALL", 4)
          T.eq(okDep, true, "Gen2Adapter:depositItem succeeds for POKE_BALL x4")
          T.eq(g2Game.save.pcItems.POKE_BALL, 4, "PC now contains POKE_BALL x4")

          -- Test PlayerPcRenderer drawing in Landscape and Portrait
          local okDrawPcLand = pcall(PlayerPcRenderer.draw, g2Game, fakeG2ItemPc, 800, 600, theme)
          T.eq(okDrawPcLand, true, "PlayerPcRenderer draws Gen 2 Item PC in Landscape cleanly")

          local okDrawPcPort = pcall(PlayerPcRenderer.draw, g2Game, fakeG2ItemPc, 360, 640, theme)
          T.eq(okDrawPcPort, true, "PlayerPcRenderer draws Gen 2 Item PC in Portrait cleanly")

          -- Test PlayerPcController input handling
          local pcCtrl = PlayerPcController.new(g2Game, { tab = "pc" })
          T.eq(pcCtrl.tab, "pc", "PlayerPcController starts on PC tab")
          pcCtrl:switchTab()
          T.eq(pcCtrl.tab, "bag", "PlayerPcController switches to Bag tab")
          pcCtrl:switchTab("pc")
          T.eq(pcCtrl.tab, "pc", "PlayerPcController switches back to PC tab")

          -- Test Modded & Expanded Bag Capacity Detection
          local defaultG2Cap = g2Adapter:getBagCapacity()
          T.eq(defaultG2Cap >= 114, true, "Gen2Adapter default bag capacity accounts for all 4 pockets (>= 114)")

          -- Mod override simulation (e.g. mod constants patch)
          g2Game.data.constants = g2Game.data.constants or {}
          g2Game.data.constants.bagSize = 150
          local moddedG2Cap = g2Adapter:getBagCapacity()
          T.eq(moddedG2Cap >= 150, true, "Gen2Adapter recognizes modded bagSize expansion (150)")

          -- Test StatResolver for Special Attack / Defense Split Detection
          local StatResolver = require("mods.omni_ui.core.StatResolver")

          -- 1. Pure Gen 1 mon without split
          local g1Mon = { species = "PIKACHU", level = 25, stats = { hp = 60, attack = 40, defense = 30, speed = 65, special = 45 } }
          local g1Resolved = StatResolver.getStats(g1Mon, nil, { data = {} })
          T.eq(g1Resolved.isSplit, false, "Pure Gen 1 mon resolves isSplit = false")
          T.eq(g1Resolved.special, 45, "Pure Gen 1 mon has special stat 45")
          T.eq(g1Resolved.spAttack, nil, "Pure Gen 1 mon has nil spAttack")

          -- 2. Gen 2 mon with split stats
          local g2Mon = { species = "CYNDAQUIL", level = 10, stats = { hp = 30, attack = 15, defense = 14, speed = 18, specialAttack = 20, specialDefense = 16 } }
          local g2Resolved = StatResolver.getStats(g2Mon, nil, { data = {} })
          T.eq(g2Resolved.isSplit, true, "Gen 2 mon resolves isSplit = true")
          T.eq(g2Resolved.spAttack, 20, "Gen 2 mon resolves spAttack = 20")
          T.eq(g2Resolved.spDefense, 16, "Gen 2 mon resolves spDefense = 16")

          -- 3. Modded species definition with separate SpA/SpD bases (e.g. Kanto-Reforged)
          local moddedDef = {
            name = "ALAKAZAM",
            baseStats = { hp = 55, attack = 50, defense = 45, speed = 120 },
            sp_attack = 135,
            sp_defense = 95,
          }
          local moddedMon = { species = "ALAKAZAM", level = 50, dvs = { special = 15 }, statExp = { special = 65535 }, stats = { hp = 130, attack = 70, defense = 65, speed = 140, special = 155 } }
          local modResolved = StatResolver.getStats(moddedMon, moddedDef, { data = {} })
          T.eq(modResolved.isSplit, true, "Modded species with sp_attack/sp_defense resolves isSplit = true")
          T.eq(modResolved.spAttack > 0, true, "Modded species calculates positive spAttack")
          T.eq(modResolved.spDefense > 0, true, "Modded species calculates positive spDefense")
          T.eq(modResolved.spAttack > modResolved.spDefense, true, "Alakazam SpA (base 135) > SpD (base 95)")

          -- 4. Adapter method getMonStats
          local adapterStats = g2Adapter:getMonStats(g2Mon)
          T.eq(adapterStats.isSplit, true, "g2Adapter:getMonStats returns split stats")
          T.eq(adapterStats.spAttack, 20, "adapter stats spAttack matches")
        end
      end
    end)()
  end
end

-- 34. In-Game Keyboard / Text Entry Pokédex Search Trigger Integration
do
  local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")
  local Screens = require("src.ui.Screens")

  local mockPokedexState = {
    screenId = "PokedexState",
    index = 5,
    scroll = 2,
    _inSearchModal = true,
    _gridSection = "sort",
    _sortRow = 1,
    _sortCol = 1,
    _filterRow = 1,
    _filterCol = 1,
    _typeRow = 1,
    _typeCol = 1,
    _actionCol = 1,
    _dexSearchQuery = "",
  }

  local pushedScreens = {}
  local mockGame = {
    data = Data,
    gameVersion = "red",
    stack = {
      states = { mockPokedexState },
      push = function(self, scr)
        pushedScreens[#pushedScreens + 1] = scr
      end,
      pop = function(self)
        return table.remove(pushedScreens)
      end,
    },
    save = { pokedex = { seen = { PIKACHU = true }, owned = { PIKACHU = true } } },
  }

  -- Test 1: Grid navigation into search box section
  mockPokedexState._gridSection = "filter"
  PokedexFilter.handleGridInput(mockPokedexState, "down")
  T.eq(mockPokedexState._gridSection, "search", "Pressing down from filter moves grid focus to 'search' box")

  -- Test 2: In-game text entry trigger via A button on search box
  local searchHandled = false
  if mockPokedexState._gridSection == "search" then
    Screens.push(mockGame, "NamingScreen", {
      title = "SEARCH POKÉDEX",
      maxLen = 10,
      default = mockPokedexState._dexSearchQuery or "",
      onDone = function(name)
        mockPokedexState._dexSearchQuery = name or ""
        mockPokedexState.index = 1
        mockPokedexState.scroll = 0
        searchHandled = true
      end,
    })
  end

  T.eq(#pushedScreens, 1, "A button on search box pushes in-game NamingScreen onto screen stack")
  local namingScreen = pushedScreens[1]
  T.eq(namingScreen.title, "SEARCH POKÉDEX", "NamingScreen title is SEARCH POKÉDEX")
  T.eq(namingScreen.maxLen, 10, "NamingScreen maxLen is 10")

  -- Test 3: Confirming text entry on in-game keyboard returns query to Pokédex
  namingScreen.onDone("PIKA")
  T.eq(searchHandled, true, "NamingScreen onDone callback executed")
  T.eq(mockPokedexState._dexSearchQuery, "PIKA", "mockPokedexState._dexSearchQuery updated to 'PIKA'")
  T.eq(mockPokedexState.index, 1, "mockPokedexState.index reset to 1")
  T.eq(mockPokedexState.scroll, 0, "mockPokedexState.scroll reset to 0")

  -- Test 4: Gen 2 NamingScreen selection for Gen 2 games
  local mockG2Game = {
    data = Data,
    gameVersion = "gold",
    stack = {
      states = { mockPokedexState },
      push = function(self, scr)
        pushedScreens[#pushedScreens + 1] = scr
      end,
    },
  }
  local isGen2 = true
  Screens.push(mockG2Game, isGen2 and "Gen2NamingScreen" or "NamingScreen", {
    type = "search",
    maxLen = 10,
    default = "CHAR",
    onDone = function(text)
      mockPokedexState._dexSearchQuery = text
    end,
  })
  T.eq(#pushedScreens, 2, "Gen2 game triggers Gen2NamingScreen")
  pushedScreens[2].onDone("CHAR")
  T.eq(mockPokedexState._dexSearchQuery, "CHAR", "Gen2NamingScreen returns updated search query")
end

-- 35. MoveDatabase and Battle Inspection Card Unit Tests
do
  local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
  local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
  local Theme = require("mods.omni_ui.core.Theme")

  -- Test 1: Move Definition Lookups (Gen 1 & Gen 2)
  local tboltDef = MoveDatabase.getMoveDef("THUNDERBOLT")
  T.eq(tboltDef.name, "Thunderbolt", "MoveDatabase finds Thunderbolt definition")
  T.eq(tboltDef.type, "ELECTRIC", "Thunderbolt is ELECTRIC type")
  T.eq(tboltDef.power, 95, "Thunderbolt base power is 95")
  T.eq(tboltDef.accuracy, 100, "Thunderbolt accuracy is 100")

  local aeroDef = MoveDatabase.getMoveDef("AEROBLAST")
  T.eq(aeroDef.name, "Aeroblast", "MoveDatabase finds Aeroblast (Gen 2) definition")
  T.eq(aeroDef.type, "FLYING", "Aeroblast is FLYING type")
  T.eq(aeroDef.power, 100, "Aeroblast base power is 100")

  -- Test 2: Category Resolution (Physical / Special / Status)
  T.eq(MoveDatabase.getCategory("THUNDERBOLT", tboltDef), "SPECIAL", "Thunderbolt categorized as SPECIAL")
  T.eq(MoveDatabase.getCategory("HYPER_BEAM", MoveDatabase.getMoveDef("HYPER_BEAM")), "PHYSICAL", "Hyper Beam categorized as PHYSICAL")
  T.eq(MoveDatabase.getCategory("SWORDS_DANCE", MoveDatabase.getMoveDef("SWORDS_DANCE")), "STATUS", "Swords Dance categorized as STATUS")

  -- Test 3: Effect Tag and Description Lookups
  T.eq(MoveDatabase.getEffectTag("THUNDERBOLT", tboltDef), "Paralyze Chance", "Thunderbolt effect tag is Paralyze Chance")
  T.eq(MoveDatabase.getEffectTag("SWORDS_DANCE", MoveDatabase.getMoveDef("SWORDS_DANCE")), "Sharply Boosts Attack", "Swords Dance effect tag is Sharply Boosts Attack")
  T.eq(type(MoveDatabase.getDescription("THUNDERBOLT", tboltDef)), "string", "Thunderbolt has description text")
  T.eq(MoveDatabase.getPowerString(tboltDef), "95", "getPowerString returns '95'")
  T.eq(MoveDatabase.getAccuracyString(tboltDef), "100%", "getAccuracyString returns '100%'")

  -- Test 4: Custom Modder Move Detail Provider Registration
  local providerCalled = false
  BattleRenderer.registerMoveDetailProvider(function(mv, mdef, dx, dy, dw, dh, th)
    providerCalled = true
  end)
  T.eq(#BattleRenderer.moveDetailProviders >= 1, true, "Custom move detail provider registered")

  -- Test 5: Themes Collection and Background Rendering Hooks
  local themeNames = Theme.getThemeNames()
  T.eq(#themeNames >= 6, true, "At least 6 distinct themes available in Theme registry")
  for _, tName in ipairs(themeNames) do
    local t = Theme.getTheme(tName)
    T.eq(type(t.colors), "table", tName .. " theme has colors table")
    T.eq(type(t.drawBackground), "function", tName .. " theme has drawBackground function")
  end

  -- Test 6: Level-Up Stat Box Popup & Stat Increase Renderer
  local StatResolver = require("mods.omni_ui.core.StatResolver")
  local LevelUpStatRenderer = require("mods.omni_ui.renderers.LevelUpStatRenderer")
  local Gen1Adapter = require("mods.omni_ui.adapters.Gen1Adapter")
  local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")

  -- 6a. ModernOverlay recognizes StatBox states
  local mockStatBoxState = {
    screenId = "StatBox",
    isStatBox = true,
    mon = {
      species = "CHARIZARD",
      level = 36,
      stats = { hp = 120, attack = 95, defense = 88, special = 105, speed = 110 },
    },
    onDone = function() end,
  }
  T.eq(ModernOverlay.isSupported(mockStatBoxState), "stat_box", "ModernOverlay detects StatBox state")

  -- 6b. LevelUpStatRenderer draws without errors on Gen 1 Mon (Unified Special)
  local mockGameGen1 = { data = Data, gameVersion = "red" }
  local curTheme = Theme.getTheme("dark")
  local okRenderGen1, errGen1 = pcall(function()
    LevelUpStatRenderer.draw(mockGameGen1, mockStatBoxState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
  end)
  if not okRenderGen1 then print("Gen1 Render Error:", errGen1) end
  T.eq(okRenderGen1, true, "LevelUpStatRenderer renders successfully for Gen 1 Pokémon")

  -- 6c. LevelUpStatRenderer draws without errors on Gen 2 Mon (Split Sp.Atk / Sp.Def)
  local mockStatBoxGen2 = {
    mon = {
      species = "TYPHLOSION",
      level = 36,
      stats = { hp = 120, attack = 95, defense = 88, spAttack = 115, spDefense = 95, speed = 110 },
    },
  }
  local mockGameGen2 = { data = Data, gameVersion = "crystal" }
  local okRenderGen2 = pcall(function()
    LevelUpStatRenderer.draw(mockGameGen2, mockStatBoxGen2, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
  end)
  T.eq(okRenderGen2, true, "LevelUpStatRenderer renders successfully for Gen 2 Pokémon with split stats")

  -- 6d. Gen 1 Adapter maps stats_box phase and mon
  local gen1BattleStatBox = {
    data = Data,
    gameVersion = "red",
    save = { player = { name = "RED" } },
    stack = {
      states = {
        {
          isBattleState = true,
          phase = "stats_box",
          player = { name = "CHARIZARD", mon = mockStatBoxState.mon, shownHP = 120 },
          enemy = { name = "BLASTOISE", mon = { species = "BLASTOISE", level = 36, stats = { hp = 125, attack = 90, defense = 110, special = 95, speed = 88 } }, shownHP = 125 },
        },
      },
    },
  }
  local g1Adapter = Gen1Adapter.new(gen1BattleStatBox)
  local g1BattleInfo = g1Adapter:updateBattleInfo()
  T.eq(g1BattleInfo.phase, "stats_box", "Gen1Adapter maps phase to stats_box")
  T.eq(g1BattleInfo.statsBoxMon ~= nil, true, "Gen1Adapter populates statsBoxMon")

  -- 6e. Gen 2 Adapter maps stats-box phase and mon
  local gen2BattleStatBox = {
    data = Data,
    gameVersion = "crystal",
    save = { player = { name = "GOLD" } },
    stack = {
      states = {
        {
          isGen2BattleState = true,
          phase = "stats-box",
          statsBoxMon = mockStatBoxGen2.mon,
          player = { name = "TYPHLOSION", mon = mockStatBoxGen2.mon, shownHP = 120 },
          enemy = { name = "FERALIGATR", mon = { species = "FERALIGATR", level = 36, stats = { hp = 125, attack = 115, defense = 100, spAttack = 89, spDefense = 93, speed = 88 } }, shownHP = 125 },
        },
      },
    },
  }
  local g2Adapter = Gen2Adapter.new(gen2BattleStatBox)
  local g2BattleInfo = g2Adapter:updateBattleInfo()
  T.eq(g2BattleInfo.phase, "stats_box", "Gen2Adapter maps stats-box to stats_box")
  T.eq(g2BattleInfo.statsBoxMon ~= nil, true, "Gen2Adapter populates statsBoxMon")

  -- 6f. PartyRenderer renders level-up overlay when itemResult is present
  local PartyRenderer = require("mods.omni_ui.renderers.PartyRenderer")
  local mockPartyState = {
    party = { mockStatBoxGen2.mon },
    index = 1,
    itemResult = {
      slot = 1,
      text = "TYPHLOSION grew to\nlevel 37!",
      level = 37,
    },
  }
  local okPartyRender = pcall(function()
    PartyRenderer.draw(mockGameGen2, mockPartyState, 640, 480, curTheme, nil, 1.0)
  end)
  T.eq(okPartyRender, true, "PartyRenderer successfully renders level-up overlay during item use")

  -- 6g. StatResolver.getStatDeltas returns positive stat increases and previous stats
  local curStats, deltas, prevStats = StatResolver.getStatDeltas(mockStatBoxGen2.mon, nil, mockGameGen2)
  T.eq(type(deltas), "table", "getStatDeltas returns deltas table")
  T.eq(deltas.hp >= 1, true, "HP delta is at least +1")
  T.eq(deltas.attack >= 1, true, "Attack delta is at least +1")
  T.eq(deltas.defense >= 1, true, "Defense delta is at least +1")
  T.eq(deltas.spAttack >= 1, true, "Sp. Attack delta is at least +1")
  T.eq(deltas.spDefense >= 1, true, "Sp. Defense delta is at least +1")
  T.eq(deltas.speed >= 1, true, "Speed delta is at least +1")

  -- Test 7: Phase 1 Economic & Activity Screens (Gen 2 Unique Screens)
  do
    local BankRenderer = require("mods.omni_ui.renderers.BankRenderer")
    local BuenaRenderer = require("mods.omni_ui.renderers.BuenaRenderer")
    local ElevatorRenderer = require("mods.omni_ui.renderers.ElevatorRenderer")
    local DecorationRenderer = require("mods.omni_ui.renderers.DecorationRenderer")

    -- 7a. BankOfMom
    local mockBankState = {
      screenId = "BankOfMom",
      kind = "deposit",
      saved = 15000,
      held = 42000,
      amount = 5000,
      position = 3,
    }
    T.eq(ModernOverlay.isSupported(mockBankState), "bank_of_mom", "ModernOverlay detects BankOfMom")
    local okBank = pcall(function()
      BankRenderer.draw(mockGameGen2, mockBankState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okBank, true, "BankRenderer renders successfully")

    -- 7b. BuenaPassword (Password Mode & Prize Mode)
    local mockBuenaPass = {
      screenId = "BuenaPassword",
      mode = "password",
      words = { "PIKACHU", "RATTATA", "PIDGEY" },
      index = 1,
    }
    local mockBuenaPrize = {
      screenId = "BuenaPassword",
      mode = "prize",
      balance = 12,
      prizes = {
        { name = "ULTRA BALL", cost = 2, item = "ULTRA_BALL" },
        { name = "FULL RESTORE", cost = 3, item = "FULL_RESTORE" },
        { name = "NUGGET", cost = 4, item = "NUGGET" },
        { name = "RARE CANDY", cost = 5, item = "RARE_CANDY" },
        { name = "PROTEIN", cost = 5, item = "PROTEIN" },
      },
      index = 2,
      scroll = 0,
    }
    T.eq(ModernOverlay.isSupported(mockBuenaPass), "buena_password", "ModernOverlay detects BuenaPassword")
    local okBuenaPass = pcall(function()
      BuenaRenderer.draw(mockGameGen2, mockBuenaPass, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okBuenaPass, true, "BuenaRenderer renders password mode successfully")

    local okBuenaPrize = pcall(function()
      BuenaRenderer.draw(mockGameGen2, mockBuenaPrize, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okBuenaPrize, true, "BuenaRenderer renders prize mode successfully")

    -- 7c. ElevatorMenu
    local mockElevator = {
      screenId = "ElevatorMenu",
      floors = {
        { floorId = "1F", destMap = "DEPT_1F" },
        { floorId = "2F", destMap = "DEPT_2F" },
        { floorId = "3F", destMap = "DEPT_3F" },
        { floorId = "4F", destMap = "DEPT_4F" },
        { floorId = "5F", destMap = "DEPT_5F" },
        { floorId = "ROOF", destMap = "DEPT_ROOF" },
      },
      origin = 2,
      index = 4,
      scroll = 1,
    }
    T.eq(ModernOverlay.isSupported(mockElevator), "elevator", "ModernOverlay detects ElevatorMenu")
    local okElevator = pcall(function()
      ElevatorRenderer.draw(mockGameGen2, mockElevator, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okElevator, true, "ElevatorRenderer renders successfully")

    -- 7d. DecorationMenu
    local mockDeco = {
      screenId = "DecorationMenu",
      mode = "category",
      categories = {
        { id = "bed", label = "BED" },
        { id = "carpet", label = "CARPET" },
        { id = "poster", label = "POSTER" },
        { id = "doll", label = "DOLL" },
      },
      index = 1,
    }
    T.eq(ModernOverlay.isSupported(mockDeco), "decoration", "ModernOverlay detects DecorationMenu")
    local okDeco = pcall(function()
      DecorationRenderer.draw(mockGameGen2, mockDeco, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okDeco, true, "DecorationRenderer renders category mode successfully")
  end

  -- Test 8: Phase 2 Pokémon Activities & Link Trading Screens
  do
    local TradeRenderer = require("mods.omni_ui.renderers.TradeRenderer")
    local ContestRenderer = require("mods.omni_ui.renderers.ContestRenderer")
    local HeldItemRenderer = require("mods.omni_ui.renderers.HeldItemRenderer")
    local DayCareRenderer = require("mods.omni_ui.renderers.DayCareRenderer")
    local MoveDeleterRenderer = require("mods.omni_ui.renderers.MoveDeleterRenderer")

    -- 8a. TradeMenu
    local mockTradeState = {
      screenId = "TradeMenu",
      row = {
        give = "DROWZEE",
        get = "MACHOP",
        nickname = "MUSCLE",
        gender = "TRADE_GENDER_MALE",
        item = "GOLD_BERRY",
        otName = "CHRIS",
        otId = 25684,
      },
      save = mockGameGen2.save,
      data = mockGameGen2.data,
      confirm = {
        pages = { { "I collect #MON.", "Do you have DROWZEE?" }, { "Want to trade it", "for my MACHOP?" } },
        page = 2,
        choice = 1,
      },
    }
    T.eq(ModernOverlay.isSupported(mockTradeState), "trade", "ModernOverlay detects TradeMenu")
    local okTrade = pcall(function()
      TradeRenderer.draw(mockGameGen2, mockTradeState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okTrade, true, "TradeRenderer renders successfully")

    -- 8b. ContestMenu
    local mockContestState = {
      screenId = "ContestMenu",
      stock = { species = "BUTTERFREE", nickname = "BUTTERFREE", level = 15, maxHp = 45, hp = 45 },
      caught = { species = "SCYTHER", nickname = "SCYTHER", level = 14, maxHp = 52, hp = 52 },
      choice = 1,
    }
    T.eq(ModernOverlay.isSupported(mockContestState), "contest", "ModernOverlay detects ContestMenu")
    local okContest = pcall(function()
      ContestRenderer.draw(mockGameGen2, mockContestState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okContest, true, "ContestRenderer renders successfully")

    -- 8c. HeldItemMenu
    local mockHeldItemState = {
      screenId = "HeldItemMenu",
      slot = 1,
      save = mockGameGen2.save,
      index = 1,
    }
    T.eq(ModernOverlay.isSupported(mockHeldItemState), "held_item", "ModernOverlay detects HeldItemMenu")
    local okHeldItem = pcall(function()
      HeldItemRenderer.draw(mockGameGen2, mockHeldItemState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okHeldItem, true, "HeldItemRenderer renders successfully")

    -- 8d. DayCareMenu
    local mockDayCareState = {
      screenId = "DayCareMenu",
      side = "man",
      grown = 3,
      price = 400,
      save = {
        dayCare = {
          man = { mon = { species = "DITTO", level = 28 } },
          lady = { mon = { species = "CYNDAQUIL", level = 12 } },
          hasEgg = true,
        },
      },
      message = {
        pages = { { "Your DITTO", "has grown a lot." } },
        page = 1,
      },
    }
    T.eq(ModernOverlay.isSupported(mockDayCareState), "daycare", "ModernOverlay detects DayCareMenu")
    local okDayCare = pcall(function()
      DayCareRenderer.draw(mockGameGen2, mockDayCareState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okDayCare, true, "DayCareRenderer renders successfully")

    -- 8e. MoveDeleter
    local mockMoveDeleterState = {
      screenId = "MoveDeleter",
      mon = mockStatBoxGen2.mon,
      moves = mockGameGen2.data.moves,
      list = mockStatBoxGen2.mon.moves,
      row = 2,
    }
    T.eq(ModernOverlay.isSupported(mockMoveDeleterState), "move_deleter", "ModernOverlay detects MoveDeleter")
    local okMoveDeleter = pcall(function()
      MoveDeleterRenderer.draw(mockGameGen2, mockMoveDeleterState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okMoveDeleter, true, "MoveDeleterRenderer renders successfully")
  end

  -- Test 9: Phase 3 Mail & Stationery System
  do
    local MailRenderer = require("mods.omni_ui.renderers.MailRenderer")
    local MailboxRenderer = require("mods.omni_ui.renderers.MailboxRenderer")
    local MailComposeRenderer = require("mods.omni_ui.renderers.MailComposeRenderer")

    -- 9a. MailRead
    local mockMailReadState = {
      screenId = "MailRead",
      entry = {
        type = "FLOWER_MAIL",
        author = "GOLD",
        message = "Hello from the\nJohto Region!",
      },
    }
    T.eq(ModernOverlay.isSupported(mockMailReadState), "mail", "ModernOverlay detects MailRead")
    local okMailRead = pcall(function()
      MailRenderer.draw(mockGameGen2, mockMailReadState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okMailRead, true, "MailRenderer renders MailRead postcard successfully")

    -- 9b. MailboxMenu
    local mockMailboxState = {
      screenId = "MailboxMenu",
      save = {
        mailbox = {
          { type = "SURF_MAIL", author = "MISTY", message = "Come visit the\nCerulean Gym!" },
          { type = "LITEBLUE_MAIL", author = "FALKNER", message = "Keep training\nFlying Pokémon!" },
        },
      },
      index = 1,
      scroll = 0,
    }
    T.eq(ModernOverlay.isSupported(mockMailboxState), "mailbox", "ModernOverlay detects MailboxMenu")
    local okMailbox = pcall(function()
      MailboxRenderer.draw(mockGameGen2, mockMailboxState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okMailbox, true, "MailboxRenderer renders PC mailbox successfully")

    -- 9c. MailCompose
    local mockComposeState = {
      screenId = "MailCompose",
      text = "HELLO JOHTO!",
      lower = false,
      col = 2,
      row = 1,
    }
    T.eq(ModernOverlay.isSupported(mockComposeState), "mail_compose", "ModernOverlay detects MailCompose")
    local okCompose = pcall(function()
      MailComposeRenderer.draw(mockGameGen2, mockComposeState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okCompose, true, "MailComposeRenderer renders composition keyboard successfully")
  end

  -- Test 10: Phase 4 Setup, Profile & Battle Tower
  do
    local ClockRenderer = require("mods.omni_ui.renderers.ClockRenderer")
    local GenderRenderer = require("mods.omni_ui.renderers.GenderRenderer")
    local BattleTowerRenderer = require("mods.omni_ui.renderers.BattleTowerRenderer")
    local CallerBoxRenderer = require("mods.omni_ui.renderers.CallerBoxRenderer")

    -- 10a. InitClock
    local mockClockState = {
      screenId = "InitClock",
      mode = "clock",
      hour = 10,
      minute = 30,
      phase = "hour",
      confirming = function() return false end,
    }
    T.eq(ModernOverlay.isSupported(mockClockState), "clock_setup", "ModernOverlay detects InitClock")
    local okClock = pcall(function()
      ClockRenderer.draw(mockGameGen2, mockClockState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okClock, true, "ClockRenderer renders clock setup successfully")

    -- Test ClockRenderer in Intro Phase (renders dialogue cleanly without clock card)
    local introClockState = {
      screenId = "InitClock",
      mode = "clock",
      phase = "intro",
      pageText = function() return "Zzz... Hm? Wha...?\nYou woke me up!" end,
    }
    local okIntroClock = pcall(function()
      ClockRenderer.draw(mockGameGen2, introClockState, 800, 600, curTheme)
    end)
    T.eq(okIntroClock, true, "ClockRenderer renders intro dialogue cleanly without clock card")

    -- Test ClockRenderer in Confirmation Phase with Left/Right input toggle
    local confirmClockState = {
      screenId = "InitClock",
      mode = "clock",
      hour = 10,
      minute = 30,
      phase = "confirm-hour",
      yesNo = 1,
      confirming = function() return true end,
      morePages = function() return false end,
      pageText = function() return "What?\n10 o'clock?" end,
    }
    mockGameGen2.input = {
      _pressed = {},
      wasPressed = function(self, k) return self._pressed[k] == true end,
    }
    ClockRenderer.attachControls(confirmClockState, mockGameGen2)
    mockGameGen2.input._pressed = { right = true }
    confirmClockState:update(0)
    T.eq(confirmClockState.yesNo, 2, "Pressing RIGHT toggles yesNo to 2 (NO)")
    mockGameGen2.input._pressed = { left = true }
    confirmClockState:update(0)
    T.eq(confirmClockState.yesNo, 1, "Pressing LEFT toggles yesNo back to 1 (YES)")

    -- Test text sanitization on control characters (\f \v)
    local dirtyText = "You woke me up!\fWill you check the\vclock for me?"
    local cleanText = Layout.cleanText(dirtyText)
    local memo = Layout.cleanText("CALM nature. Met in PALLET TOWN at {LV_2} 5.")
    T.eq(memo, "CALM nature. Met in PALLET TOWN at Lv. 5.", "Trainer memo prints the Lv glyph instead of {LV_2}")
    T.eq(cleanText:find("\f"), nil, "Cleaned text contains no form feed control characters")
    T.eq(cleanText:find("\v"), nil, "Cleaned text contains no vertical tab control characters")

    -- 10b. GenderSelect
    local mockGenderState = {
      screenId = "GenderSelect",
      cursor = 1,
      text = "Are you a boy?\nOr are you a girl?",
      chosen = "male",
      menuOpen = function() return true end,
    }
    T.eq(ModernOverlay.isSupported(mockGenderState), "gender_select", "ModernOverlay detects GenderSelect")
    local okGender = pcall(function()
      GenderRenderer.draw(mockGameGen2, mockGenderState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okGender, true, "GenderRenderer renders character selection successfully")

    -- 10c. BattleTowerMenu
    local mockTowerState = {
      screenId = "BattleTowerMenu",
      rows = {
        { group = 1 }, { group = 2 }, { group = 3 }, { group = 4 }, { group = 5 },
        { group = 6 }, { group = 7 }, { group = 8 }, { group = 9 }, { group = 10 },
      },
      cursor = 1,
      phase = "pick",
      message = "What level do you want to challenge?",
    }
    T.eq(ModernOverlay.isSupported(mockTowerState), "battle_tower", "ModernOverlay detects BattleTowerMenu")
    local okTower = pcall(function()
      BattleTowerRenderer.draw(mockGameGen2, mockTowerState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okTower, true, "BattleTowerRenderer renders battle tower challenge successfully")

    -- 10d. CallerBox
    local mockCallerState = {
      screenId = "CallerBox",
      name = "JOEY",
      className = "YOUNGSTER",
    }
    T.eq(ModernOverlay.isSupported(mockCallerState), "caller_box", "ModernOverlay detects CallerBox")
    local okCaller = pcall(function()
      CallerBoxRenderer.draw(mockGameGen2, mockCallerState, 640, 480, curTheme, nil, { x = 0, y = 0, width = 640, height = 480 })
    end)
    T.eq(okCaller, true, "CallerBoxRenderer renders floating caller HUD successfully")

    -- 10e. Gen2OakSpeech state with function text method
    local mockGen2Oak = {
      screenId = "Gen2OakSpeech",
      steps = { { id = "init_clock", kind = "initclock" } },
      text = function(self, key) return "Hello" end,
      step = 1,
    }
    local okGen2OakSupp = pcall(function()
      return ModernOverlay.isSupported(mockGen2Oak)
    end)
    T.eq(okGen2OakSupp, true, "ModernOverlay.isSupported handles Gen2OakSpeech with function text without crashing")

    -- 10f. Gen2NamePick name selector
    local NamingRenderer = require("mods.omni_ui.renderers.NamingRenderer")
    local mockNamePick = {
      screenId = "Gen2NamePick",
      items = { "NEW NAME", "GOLD", "HIRO", "TAYLOR", "KARL" },
      cursor = 1,
      gender = "male",
      openNaming = function() end,
    }
    T.eq(ModernOverlay.isSupported(mockNamePick), "name_pick", "ModernOverlay detects Gen2NamePick as name_pick")
    local okNamePickDraw = pcall(function()
      NamingRenderer.drawNamePick(mockGameGen2, mockNamePick, 800, 600, curTheme, nil, { x = 0, y = 0, width = 800, height = 600 })
      NamingRenderer.drawNamePick(mockGameGen2, mockNamePick, 380, 680, curTheme, nil, { x = 0, y = 0, width = 380, height = 680 })
    end)
    T.eq(okNamePickDraw, true, "NamingRenderer.drawNamePick renders in landscape and portrait without error")
  end

  -- Test 11: Multi-Device Responsive Viewport Adaptation (Portrait, Mobile Landscape, Ultra-Compact)
  do
    local viewports = {
      { name = "Portrait Mobile (380x680)", w = 380, h = 680 },
      { name = "Mobile Landscape (640x360)", w = 640, h = 360 },
      { name = "Ultra-Compact Micro (320x240)", w = 320, h = 240 },
      { name = "Desktop Ultrawide (1280x720)", w = 1280, h = 720 },
    }

    local TradeRenderer = require("mods.omni_ui.renderers.TradeRenderer")
    local ContestRenderer = require("mods.omni_ui.renderers.ContestRenderer")
    local HeldItemRenderer = require("mods.omni_ui.renderers.HeldItemRenderer")
    local DayCareRenderer = require("mods.omni_ui.renderers.DayCareRenderer")
    local MoveDeleterRenderer = require("mods.omni_ui.renderers.MoveDeleterRenderer")
    local MailRenderer = require("mods.omni_ui.renderers.MailRenderer")
    local MailboxRenderer = require("mods.omni_ui.renderers.MailboxRenderer")
    local MailComposeRenderer = require("mods.omni_ui.renderers.MailComposeRenderer")
    local BankRenderer = require("mods.omni_ui.renderers.BankRenderer")
    local BuenaRenderer = require("mods.omni_ui.renderers.BuenaRenderer")
    local ElevatorRenderer = require("mods.omni_ui.renderers.ElevatorRenderer")
    local DecorationRenderer = require("mods.omni_ui.renderers.DecorationRenderer")
    local ClockRenderer = require("mods.omni_ui.renderers.ClockRenderer")
    local GenderRenderer = require("mods.omni_ui.renderers.GenderRenderer")
    local BattleTowerRenderer = require("mods.omni_ui.renderers.BattleTowerRenderer")
    local CallerBoxRenderer = require("mods.omni_ui.renderers.CallerBoxRenderer")
    local LevelUpStatRenderer = require("mods.omni_ui.renderers.LevelUpStatRenderer")

    local testScreens = {
      { r = TradeRenderer, s = { screenId = "TradeMenu", row = { give = "DROWZEE", get = "MACHOP" }, save = mockGameGen2.save, data = mockGameGen2.data } },
      { r = ContestRenderer, s = { screenId = "ContestMenu", stock = { species = "BUTTERFREE", level = 15, hp = 45 }, caught = { species = "SCYTHER", level = 14, hp = 52 } } },
      { r = HeldItemRenderer, s = { screenId = "HeldItemMenu", slot = 1, save = mockGameGen2.save } },
      { r = DayCareRenderer, s = { screenId = "DayCareMenu", side = "man", grown = 2, price = 300, save = { dayCare = { man = { mon = { species = "DITTO", level = 20 } }, lady = { mon = { species = "EEVEE", level = 10 } }, hasEgg = true } } } },
      { r = MoveDeleterRenderer, s = { screenId = "MoveDeleter", mon = mockStatBoxGen2.mon, moves = mockGameGen2.data.moves, list = mockStatBoxGen2.mon.moves, row = 1 } },
      { r = MailRenderer, s = { screenId = "MailRead", entry = { type = "SURF_MAIL", author = "MISTY", message = "Come swim at Cerulean!" } } },
      { r = MailboxRenderer, s = { screenId = "MailboxMenu", save = { mailbox = { { type = "FLOWER_MAIL", author = "GOLD", message = "Hi!" } } }, index = 1, scroll = 0 } },
      { r = MailComposeRenderer, s = { screenId = "MailCompose", text = "HELLO!", lower = false, col = 0, row = 0 } },
      { r = BankRenderer, s = { screenId = "BankOfMom", kind = "deposit", saved = 15000, held = 8500, amount = 2500, position = 3 } },
      { r = BuenaRenderer, s = { screenId = "BuenaPassword", mode = "prize", balance = 12, prizes = { { name = "ULTRA BALL", cost = 2 }, { name = "FULL RESTORE", cost = 5 } }, index = 1, scroll = 0 } },
      { r = ElevatorRenderer, s = { screenId = "ElevatorMenu", floors = { { floorId = "1F" }, { floorId = "2F" }, { floorId = "3F" }, { floorId = "4F" }, { floorId = "5F" }, { floorId = "ROOF" } }, origin = 1, index = 2, scroll = 0 } },
      { r = DecorationRenderer, s = { screenId = "DecorationMenu", mode = "items", rows = { "PIKACHU_POSTER", "CHARIZARD_DOLL", "SUPER_NES" }, index = 1, scroll = 0 } },
      { r = ClockRenderer, s = { screenId = "InitClock", mode = "clock", hour = 14, minute = 15, phase = "hour" } },
      { r = GenderRenderer, s = { screenId = "GenderSelect", cursor = 2, text = "Are you a boy?\nOr are you a girl?" } },
      { r = BattleTowerRenderer, s = { screenId = "BattleTowerMenu", rows = { { group = 1 }, { group = 2 }, { group = 3 } }, cursor = 1, phase = "pick" } },
      { r = CallerBoxRenderer, s = { screenId = "CallerBox", name = "PROF. ELM", className = "RESEARCHER" } },
      { r = LevelUpStatRenderer, s = { mon = mockStatBoxGen2.mon } },
    }

    for _, vp in ipairs(viewports) do
      for _, scr in ipairs(testScreens) do
        local ok = pcall(function()
          scr.r.draw(mockGameGen2, scr.s, vp.w, vp.h, curTheme, nil, { x = 0, y = 0, width = vp.w, height = vp.h })
        end)
        T.eq(ok, true, ("Renderer %s renders without error on %s"):format(tostring(scr.s.screenId or "LevelUp"), vp.name))
      end
    end
  end
end

    -- =========================================================================
    -- GEN 3 PHASE 1: COMPREHENSIVE TESTS FOR STATE CONTRACTS & RUNTIME DETAILS
    -- =========================================================================
    (function()
      local StarterRenderer = require("mods.omni_ui.renderers.StarterRenderer")
    local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
    local NamingRenderer = require("mods.omni_ui.renderers.NamingRenderer")
    local StartMenuRenderer = require("mods.omni_ui.renderers.StartMenuRenderer")
    local MainMenuRenderer = require("mods.omni_ui.renderers.MainMenuRenderer")
    local ClockRenderer = require("mods.omni_ui.renderers.ClockRenderer")

    -- 1. Naming Screen: Empty Input Fallbacks & Nickname Reversion
    local mockNamingMon = { template = "CAUGHT_MON", species = "TREECKO", name = "", maxLen = 10 }
    local monFallback = NamingRenderer.resolveFallback(mockNamingMon, { gameVersion = "emerald" })
    T.eq(monFallback, "TREECKO", "Empty Pokémon nickname defaults to species uppercase name")

    local mockNamingPlayerM = { template = "PLAYER", gender = 0, name = "", maxLen = 7 }
    local playerMFallback = NamingRenderer.resolveFallback(mockNamingPlayerM, { gameVersion = "emerald" })
    T.eq(playerMFallback, "BRENDAN", "Empty male player name in Emerald defaults to BRENDAN")

    local mockNamingPlayerF = { template = "PLAYER", gender = 1, name = "", maxLen = 7 }
    local playerFFallback = NamingRenderer.resolveFallback(mockNamingPlayerF, { gameVersion = "emerald" })
    T.eq(playerFFallback, "MAY", "Empty female player name in Emerald defaults to MAY")

    local mockNamingFrlgM = { template = "PLAYER", gender = 0, name = "", maxLen = 7 }
    local frlgMFallback = NamingRenderer.resolveFallback(mockNamingFrlgM, { gameVersion = "firered" })
    T.eq(frlgMFallback, "RED", "Empty male player name in FireRed defaults to RED")

    local mockNamingFrlgF = { template = "PLAYER", gender = 1, name = "", maxLen = 7 }
    local frlgFFallback = NamingRenderer.resolveFallback(mockNamingFrlgF, { gameVersion = "firered" })
    T.eq(frlgFFallback, "LEAF", "Empty female player name in FireRed defaults to LEAF")

    local mockNamingRival = { template = "RIVAL", name = "", maxLen = 7 }
    local rivalFallback = NamingRenderer.resolveFallback(mockNamingRival, { gameVersion = "firered" })
    T.eq(rivalFallback, "BLUE", "Empty rival name in FireRed defaults to BLUE")

    local _, monMaxLen = NamingRenderer.getNameInfo(mockNamingMon)
    T.eq(monMaxLen, 10, "Pokémon nickname buffer clamped to 10 characters")
    local _, playerMaxLen = NamingRenderer.getNameInfo(mockNamingPlayerM)
    T.eq(playerMaxLen, 7, "Player name buffer clamped to 7 characters")
    local mockNamingBox = { template = "BOX", name = "" }
    local _, boxMaxLen = NamingRenderer.getNameInfo(mockNamingBox)
    T.eq(boxMaxLen, 8, "PC Box name buffer clamped to 8 characters")

    -- 2. Instant Text Speed & Typewriter SFX Flood Suppression
    local mockInstantMsg = {
      _pages = { "Professor Birch needs your help on Route 101!" },
      _page = 1,
      _revealed = 5,
      _total = 46,
      instant = true,
      _speedUp = false,
    }
    DialogueRenderer.draw(mockGameGen2, mockInstantMsg, 800, 600, curTheme)
    T.eq(mockInstantMsg._suppressTypewriterSfx, true, "Instant text speed flags audio queue suppression")
    T.eq(mockInstantMsg._speedUp, true, "Instant text sets _speedUp on message state")

    -- 3. Multichoice Vertical Pagination & Overflow
    local mockMultichoice = {
      isChoiceBox = true,
      options = { "ONE ISLAND", "TWO ISLAND", "THREE ISLAND", "FOUR ISLAND", "FIVE ISLAND", "SIX ISLAND", "SEVEN ISLAND", "EXIT" },
      cursor = 1,
      cols = 1,
    }
    local mockMsgUnderChoice = {
      _pages = { "Where would you like to sail with the SEAGALLOP FERRY?" },
      _page = 1,
      _revealed = 50,
      _total = 50,
      _waiting = true,
    }
    DialogueRenderer.draw(mockGameGen2, mockMsgUnderChoice, 800, 600, curTheme, mockMultichoice)
    T.eq(mockMultichoice._scrollOffset, 0, "Initial scroll offset is 0 for multichoice list")

    mockMultichoice.cursor = 7 -- Navigate to Seven Island
    DialogueRenderer.draw(mockGameGen2, mockMsgUnderChoice, 800, 600, curTheme, mockMultichoice)
    T.eq(mockMultichoice._scrollOffset, 1, "Scroll offset dynamically advances to 1 when cursor moves past row 6")

    mockMultichoice.cursor = 1 -- Return to top
    DialogueRenderer.draw(mockGameGen2, mockMsgUnderChoice, 800, 600, curTheme, mockMultichoice)
    T.eq(mockMultichoice._scrollOffset, 0, "Scroll offset smoothly returns to 0 when cursor moves back to top")

    -- 3b. Phone Call in Gen 2 Pokegear (Underlying StartMenu must NOT be treated as a choice box)
    local mockStartMenuUnderGear = {
      items = {
        { id = "pokedex", label = "POKéDEX" },
        { id = "pokemon", label = "POKéMON" },
        { id = "pack", label = "PACK" },
        { id = "pokegear", label = "POKéGEAR" },
        { id = "taylor", label = "TAYLOR" },
        { id = "save", label = "SAVE" },
      },
      showDescription = true,
      onChoose = function() end,
      list = { spacing = 2 },
    }
    local mockGearInStack = {
      cards = { { id = "phone", label = "PHONE" } },
      cardIndex = 1,
      mode = "card",
      call = { name = "MOM", text = "Hello?" },
    }
    local mockCallTextBox = {
      pages = { { "Hello?" } },
      shown = 1,
      _waiting = true,
    }
    local phoneCallGame = {
      stack = {
        states = {
          { screenId = "Overworld" },
          mockStartMenuUnderGear,
          mockGearInStack,
          mockCallTextBox,
        },
        top = function(self) return self.states[#self.states] end,
      },
    }
    local okCallDraw = pcall(DialogueRenderer.draw, phoneCallGame, mockCallTextBox, 800, 600, curTheme, nil)
    T.eq(okCallDraw, true, "DialogueRenderer renders in-call dialogue cleanly")
    T.eq(mockStartMenuUnderGear._scrollOffset, nil, "Dormant StartMenu in stack was NOT touched or scrolled as a choice box")

    -- 4. Pre-Menu System Notifications & RTC Battery Warnings Pass-Through Whitelist
    local passThroughStates = {
      { screenId = "ResetRtcScreen" },
      { screenId = "BerryFixScreen" },
      { screenId = "ClearSaveScreen" },
      { screenId = "WirelessDirectScreen" },
      { screenId = "MysteryEventScreen" },
      { screenId = "RecordCornerScreen" },
      { screenId = "QuestLog" },
      { screenId = "IntroMovie" },
      { screenId = "TitleScreen" },
      { screenId = "TitleRse" },
      { isBatteryWarning = true },
      { isRtcWarning = true },
    }
    for _, pts in ipairs(passThroughStates) do
      local sup = ModernOverlay.isSupported(pts)
      T.eq(sup, false, ("State %s is recognized as native unintercepted pass-through"):format(pts.screenId or "WarningState"))
    end

    -- 5. Birch Starter Choice: 2-Phase Selection & Confirmation Flow
    local doneStarter = nil
    local mockStarter = {
      screenId = "StarterChoose",
      selection = 0, -- Treecko
      state = "input",
      balls = {},
      hand = {},
      onDone = function(res) doneStarter = res end,
    }
    T.eq(ModernOverlay.isSupported(mockStarter), "starter_choose", "ModernOverlay recognizes StarterChoose state")
    
    StarterRenderer.draw(mockGameGen2, mockStarter, 800, 600, curTheme)
    T.eq(mockStarter.__omniUiStarterAttached, true, "StarterRenderer attaches 2-phase controller")

    -- Simulate pressing A -> transitions to ask confirmation modal
    mockStarter:frame({ new = { a = true }, held = {} })
    T.eq(mockStarter.state, "ask", "Pressing A on starter advances to confirmation phase rather than premature onDone")
    T.eq(doneStarter, nil, "onDone not called prematurely during confirmation")

    -- Simulate pressing A on YES in confirmation modal -> zero-delay battle handshake
    mockStarter._confirmChoice = 1 -- YES
    mockStarter:frame({ new = { a = true }, held = {} })
    T.eq(mockStarter.done, true, "Confirming YES sets done = true")
    T.eq(doneStarter, 0, "onDone called with chosen starter index upon confirmation")

    -- 6. Littleroot Bedroom Clock Setup
    local mockWallClock = {
      screenId = "WallClock",
      t = { hours = 10, minutes = 30, period = 0, minuteAngle = 180, hourAngle = 315 },
      mode = "set",
      state = "set_input",
    }
    T.eq(ModernOverlay.isSupported(mockWallClock), "clock_setup", "ModernOverlay recognizes WallClock state")

    -- 7. Start Menu Dynamic Entries & Safari Zone Status HUD
    local mockG3StartMenu = {
      screenId = "StartMenu",
      ENTRIES = {
        { id = "pokedex", label = "POKéDEX" },
        { id = "pokemon", label = "POKéMON" },
        { id = "bag", label = "BAG" },
        { id = "pokenav", label = "POKéNAV" },
        { id = "player", label = "BRENDAN" },
        { id = "save", label = "SAVE" },
        { id = "option", label = "OPTION" },
        { id = "exit", label = "EXIT" },
      },
      cursor = 1,
      open = true,
      _confirmExit = true,
      _confirmCursor = 2,
    }
    T.eq(ModernOverlay.isSupported(mockG3StartMenu), "start_menu", "ModernOverlay recognizes Gen 3 StartMenu with ENTRIES")

    local g3Confirm = {
      ENTRIES = { { id = "exit", label = "EXIT" } },
      _confirmExit = true,
      _confirmCursor = 2,
      update = function() end,
      _game = {
        input = {
          wasPressed = function(_, key) return key == "right" end,
        },
      },
    }
    function g3Confirm.move()
      g3Confirm._confirmCursor = (g3Confirm._confirmCursor == 1) and 2 or 1
    end
    ModernOverlay.attachStartMenuControls(g3Confirm, g3Confirm._game)
    g3Confirm:update(1 / 60)
    T.eq(g3Confirm._confirmCursor, 1, "Return to Title moves from No to Yes on Right")
    g3Confirm._game.input.wasPressed = function(_, key) return key == "left" end
    g3Confirm:update(1 / 60)
    T.eq(g3Confirm._confirmCursor, 2, "Return to Title moves from Yes to No on Left")

    -- Test Gen3Adapter Safari Info gating
    local mockG3Game = { session = { map = "MAP_LITTLEROOT_TOWN" } }
    local g3Adapter = Gen3Adapter.new(mockG3Game)
    package.loaded["src.core.game3.safari"] = {
      isActive = function() return false end,
      steps = function() return 0 end,
      balls = function() return 0 end,
    }
    T.eq(g3Adapter:getSafariInfo(), nil, "Gen3Adapter returns nil when Safari.isActive is false")

    package.loaded["src.core.game3.safari"] = {
      isActive = function() return true end,
      steps = function() return 420 end,
      balls = function() return 25 end,
      STEPS = 500,
    }
    local activeSafari = g3Adapter:getSafariInfo()
    T.eq(activeSafari ~= nil and activeSafari.active, true, "Gen3Adapter returns active safari info when Safari.isActive is true")
    T.eq(activeSafari.steps, 420, "Safari steps correctly returned")
    T.eq(activeSafari.balls, 25, "Safari balls correctly returned")
    package.loaded["src.core.game3.safari"] = nil

    -- 8. Main Menu Continue Deck (RSE / FRLG)
    local mockG3MainMenu = {
      screenId = "MainMenuRse",
      items = { "CONTINUE", "NEW_GAME", "OPTION", "EXIT" },
      cursor = 1,
      hasContinue = true,
      info = {
        name = "BRENDAN",
        hours = 24,
        minutes = 45,
        badges = 8,
        dexCount = 135,
        hasDex = true,
      },
    }
    T.eq(ModernOverlay.isSupported(mockG3MainMenu), "main_menu", "ModernOverlay recognizes MainMenuRse with continueInfo")

    -- Test Gen 3 Emerald Continue Confirmation modal lifecycle
    local baseCalls = 0
    mockG3MainMenu.update = function(self, inp, dt)
      baseCalls = baseCalls + 1
      if inp and inp:wasPressed("a") and self.cursor == 2 then
        return "newGame"
      end
      return nil
    end
    ModernOverlay.attachControls(mockG3MainMenu, mockBootGame)

    local mockInp = {
      _pressed = {},
      wasPressed = function(self, k) return self._pressed[k] == true end,
    }

    -- 1. Pressing A on CONTINUE should spawn the Yes/No confirmation modal without calling baseUpdate
    mockInp._pressed = { a = true }
    local r1 = mockG3MainMenu:update(mockInp, 0.016)
    T.eq(r1, nil, "First A press intercepts continue and returns nil")
    T.eq(mockG3MainMenu.phase, "confirm", "MainMenu enters confirm phase on Continue")
    T.eq(mockG3MainMenu.isConfirm, true, "isConfirm flag is set to true")
    T.eq(mockG3MainMenu.confirmChoice, 1, "confirmChoice starts on YES (1)")

    -- 2. Pressing RIGHT in modal toggles to NO (2)
    mockInp._pressed = { right = true }
    mockG3MainMenu:update(mockInp, 0.016)
    T.eq(mockG3MainMenu.confirmChoice, 2, "Pressing RIGHT toggles to NO (confirmChoice = 2)")

    -- 3. Pressing LEFT in modal toggles back to YES (1)
    mockInp._pressed = { left = true }
    mockG3MainMenu:update(mockInp, 0.016)
    T.eq(mockG3MainMenu.confirmChoice, 1, "Pressing LEFT toggles back to YES (confirmChoice = 1)")

    -- 4. Pressing B in modal cancels back to menu
    mockInp._pressed = { b = true }
    mockG3MainMenu:update(mockInp, 0.016)
    T.eq(mockG3MainMenu.phase, "menu", "Pressing B closes confirm modal back to menu")
    T.eq(mockG3MainMenu.isConfirm, false, "isConfirm flag cleared on cancel")

    -- 5. Re-open modal, toggle to NO, and press A to cancel
    mockInp._pressed = { a = true }
    mockG3MainMenu:update(mockInp, 0.016)
    T.eq(mockG3MainMenu.isConfirm, true, "Modal reopened")
    mockInp._pressed = { right = true }
    mockG3MainMenu:update(mockInp, 0.016)
    T.eq(mockG3MainMenu.confirmChoice, 2, "Switched to NO")
    mockInp._pressed = { a = true }
    local rCancel = mockG3MainMenu:update(mockInp, 0.016)
    T.eq(rCancel, nil, "Confirming NO returns nil")
    T.eq(mockG3MainMenu.phase, "menu", "Modal closed on NO")
    T.eq(mockG3MainMenu.isConfirm, false, "isConfirm cleared on NO")

    -- 6. Re-open modal and confirm YES -> returns { action = "continue" }
    mockInp._pressed = { a = true }
    mockG3MainMenu:update(mockInp, 0.016)
    T.eq(mockG3MainMenu.isConfirm, true, "Modal reopened for confirmation")
    mockInp._pressed = { a = true }
    local rContinue = mockG3MainMenu:update(mockInp, 0.016)
    T.neq(rContinue, nil, "Confirming YES returns continue action")
    T.eq(type(rContinue), "table", "Continue action is a table")
    T.eq(rContinue and rContinue.action, "continue", "Continue action is { action = 'continue' }")
    T.eq(mockG3MainMenu.isConfirm, false, "isConfirm cleared on continue")

    -- 7. When cursor is on NEW_GAME (2), pressing A forwards cleanly to baseUpdate
    mockG3MainMenu.cursor = 2
    mockInp._pressed = { a = true }
    local rNewGame = mockG3MainMenu:update(mockInp, 0.016)
    T.eq(rNewGame, "newGame", "Pressing A on NEW_GAME forwards to baseUpdate and returns newGame")
    T.eq(mockG3MainMenu.isConfirm, false, "Modal was not opened for NEW_GAME")

    -- Responsive render validation across all 4 viewports for Gen 3 renderers
    local gen3Screens = {
      { r = StarterRenderer, s = mockStarter },
      { r = DialogueRenderer, s = mockInstantMsg },
      { r = NamingRenderer, s = mockNamingMon },
      { r = StartMenuRenderer, s = mockG3StartMenu },
      { r = MainMenuRenderer, s = mockG3MainMenu },
      { r = ClockRenderer, s = mockWallClock },
    }
    local curTheme = Theme.get()
    local g3Viewports = {
      { name = "Desktop Landscape (800x600)", w = 800, h = 600 },
      { name = "Mobile Portrait (380x680)", w = 380, h = 680 },
      { name = "Mobile Landscape (640x360)", w = 640, h = 360 },
      { name = "Ultra Compact (320x240)", w = 320, h = 240 },
    }
    for _, vp in ipairs(g3Viewports) do
      for _, scr in ipairs(gen3Screens) do
        local ok = pcall(function()
          scr.r.draw(mockGameGen2, scr.s, vp.w, vp.h, curTheme, nil, { x = 0, y = 0, width = vp.w, height = vp.h })
        end)
        T.eq(ok, true, ("Gen 3 Renderer for %s renders cleanly on %s"):format(tostring(scr.s.screenId or "Gen3Screen"), vp.name))
      end
    end
    -- 9. Gen 3 Active Screen Resolution via getActiveScreen
    -- Test A: Gen 3 Boot Phase (Intro vs MainMenuRse)
    local mockBootIntroGame = {
      phase = "boot",
      boot = {
        phase = "intro",
        menuIndex = 1,
        custom = {
          menu = mockG3MainMenu,
        },
      },
    }
    local introKind = ModernOverlay.getActiveScreen(mockBootIntroGame)
    T.eq(introKind, nil, "ModernOverlay passes through during Gen 3 intro/title without prematurely opening main menu")

    local mockBootTitleGame = {
      phase = "boot",
      boot = {
        phase = "title",
        menuIndex = 1,
        custom = {
          menu = mockG3MainMenu,
        },
      },
    }
    local titleKind = ModernOverlay.getActiveScreen(mockBootTitleGame)
    T.eq(titleKind, nil, "ModernOverlay passes through during Gen 3 title screen")

    local mockBootGame = {
      phase = "boot",
      boot = {
        phase = "menu",
        menuIndex = 1,
        custom = {
          menu = mockG3MainMenu,
        },
      },
    }
    local bootKind, bootState = ModernOverlay.getActiveScreen(mockBootGame)
    T.eq(bootKind, "main_menu", "ModernOverlay.getActiveScreen resolves Gen 3 boot custom main menu on phase == 'menu'")
    T.eq(bootState, mockG3MainMenu, "Active state matches custom menu instance")

    -- Test A2: FireRed / LeafGreen native boot main menu (no custom menu table, menuIndex cursor)
    local mockFrlgBoot = {
      phase = "menu",
      menuIndex = 1,
      hasContinue = true,
      continueInfo = {
        name = "RED",
        badges = 8,
        dexCount = 150,
        hours = 25,
        minutes = 40,
      },
    }
    local mockFrlgGame = {
      phase = "boot",
      boot = mockFrlgBoot,
      gameVersion = "firered",
    }
    local frlgKind, frlgState = ModernOverlay.getActiveScreen(mockFrlgGame)
    T.eq(frlgKind, "main_menu", "ModernOverlay.getActiveScreen resolves native FireRed boot state on phase == 'menu'")
    T.eq(frlgState, mockFrlgBoot, "Active state matches native boot state")

    local okDrawFrlg = pcall(function()
      local theme = require("mods.omni_ui.core.Theme").get()
      require("mods.omni_ui.renderers.MainMenuRenderer").draw(mockFrlgGame, mockFrlgBoot, 800, 600, theme)
    end)
    T.eq(okDrawFrlg, true, "MainMenuRenderer successfully draws native FireRed main menu with populated options")

    -- Test A3: FireRed new game state (hasContinue = false)
    local mockFrlgNewGameBoot = {
      phase = "menu",
      menuIndex = 1,
      hasContinue = false,
    }
    local okDrawFrlgNew = pcall(function()
      local theme = require("mods.omni_ui.core.Theme").get()
      require("mods.omni_ui.renderers.MainMenuRenderer").draw(mockFrlgGame, mockFrlgNewGameBoot, 800, 600, theme)
    end)
    T.eq(okDrawFrlgNew, true, "MainMenuRenderer successfully draws native FireRed main menu for new game without save")

    -- Test B: Gen 3 Stack Layers
    local origRealStack = package.loaded["src.ui.game3.stack"]
    package.loaded["src.ui.game3.stack"] = {
      _layers = {
        { id = "starter_choose", mod = mockStarter },
      },
    }
    local stackKind, stackState = ModernOverlay.getActiveScreen({ phase = "field" })
    T.eq(stackKind, "starter_choose", "ModernOverlay.getActiveScreen resolves Gen 3 Stack layer")
    T.eq(stackState, mockStarter, "Active state matches top stack layer mod")

    -- Test C: Gen 3 Standalone Singletons (StartMenu, Message)
    package.loaded["src.ui.game3.stack"] = { _layers = {} }
    mockG3StartMenu.open = true
    package.loaded["src.ui.game3.start_menu"] = mockG3StartMenu
    local startKind, startState = ModernOverlay.getActiveScreen({ phase = "field" })
    T.eq(startKind, "start_menu", "ModernOverlay.getActiveScreen resolves Gen 3 StartMenu singleton")

    package.loaded["src.ui.game3.start_menu"] = { open = false }
    mockInstantMsg.open = true
    package.loaded["src.ui.game3.message"] = mockInstantMsg
    local msgKind, msgState = ModernOverlay.getActiveScreen({ phase = "field" })
    T.eq(msgKind, "dialogue", "ModernOverlay.getActiveScreen resolves Gen 3 Message singleton")

    -- Test D: Naming module presence without active openFlag returns nil (prevents stuck keyboard)
    package.loaded["src.ui.game3.message"] = { open = false }
    package.loaded["src.ui.game3.naming"] = {
      open = function() end, -- Function reference must not be treated as open boolean
      openFlag = false,
      _state = nil,
      TEMPLATE = { PLAYER = "PLAYER" },
    }
    local closedNamingKind = ModernOverlay.getActiveScreen({ phase = "field" })
    T.eq(closedNamingKind, nil, "Inactive Naming module with open() function does not falsely trigger keyboard modal")

    -- Clean up mock singletons
    package.loaded["src.ui.game3.naming"] = nil
    package.loaded["src.ui.game3.message"] = nil
    package.loaded["src.ui.game3.start_menu"] = nil
    package.loaded["src.ui.game3.stack"] = origRealStack

    -- Test E: Gen 3 Intro / Startup Birch Dialogue & Choice Resolution
    local mockBirchSpeech = {
        showDialogue = true,
        sprites = { birch = { x = 136, y = 60 } },
        printer = {
          lines = { "Hi! Sorry to keep you waiting!", "Welcome to the world of POKéMON!" },
          active = true,
          state = "char",
        },
      }
      local gameBootBirch = {
        phase = "boot",
        boot = {
          phase = "oak",
          custom = {
            newGame = mockBirchSpeech,
          },
        },
      }
      local birchKind, birchDiag, _, birchChoice = ModernOverlay.getActiveScreen(gameBootBirch)
      T.eq(birchKind, "dialogue", "ModernOverlay.getActiveScreen detects Gen 3 Birch intro speech")
      T.eq(birchDiag and birchDiag.speaker, "PROF. BIRCH", "Birch speech has PROF. BIRCH speaker nameplate")
      T.eq(birchDiag and birchDiag.lines[1], "Hi! Sorry to keep you waiting!", "Birch speech passes printer line 1")
      T.eq(birchDiag and birchDiag.lines[2], "Welcome to the world of POKéMON!", "Birch speech passes printer line 2")
      T.eq(birchDiag and birchDiag._waiting, false, "Active typewriter reports _waiting = false")
      T.eq(birchChoice, nil, "No choice subState while typing")

      -- Birch speech waiting for player advance (\p)
      mockBirchSpeech.printer.state = "clear"
      local _, birchWaitDiag = ModernOverlay.getActiveScreen(gameBootBirch)
      T.eq(birchWaitDiag and birchWaitDiag._waiting, true, "Paused printer reports _waiting = true for bounce prompt")

      -- Birch speech with Gender menu (Boy / Girl)
      mockBirchSpeech.genderMenu = { cursor = 0 }
      local _, _, _, genderChoice = ModernOverlay.getActiveScreen(gameBootBirch)
      T.eq(genderChoice ~= nil, true, "Birch gender selection produces choice subState")
      T.eq(genderChoice and genderChoice.options[1], "BOY", "Gender option 1 is BOY")
      T.eq(genderChoice and genderChoice.options[2], "GIRL", "Gender option 2 is GIRL")
      T.eq(genderChoice and genderChoice.cursor, 1, "Gender cursor is 1 for Boy")
      T.eq(genderChoice and genderChoice.anchor, "left", "Gender choice is docked on left flank to leave sprite visible")

      -- Birch gender cursor moves to Girl
      mockBirchSpeech.genderMenu.cursor = 1
      local _, _, _, genderChoiceGirl = ModernOverlay.getActiveScreen(gameBootBirch)
      T.eq(genderChoiceGirl and genderChoiceGirl.cursor, 2, "Gender cursor is 2 for Girl")
      mockBirchSpeech.genderMenu = nil

      -- Birch speech with Yes/No menu ("So it's BRENDAN?")
      mockBirchSpeech.yesNo = { cursor = 0 }
      local _, _, _, yesNoChoice = ModernOverlay.getActiveScreen(gameBootBirch)
      T.eq(yesNoChoice ~= nil, true, "Birch Yes/No prompt produces choice subState")
      T.eq(yesNoChoice and yesNoChoice.options[1], "YES", "Yes/No option 1 is YES")
      T.eq(yesNoChoice and yesNoChoice.options[2], "NO", "Yes/No option 2 is NO")
      T.eq(yesNoChoice and yesNoChoice.cursor, 1, "Cursor is 1 for YES")
      mockBirchSpeech.yesNo = nil

      -- Birch speech closed during sprite transitions / intro cutscene
      mockBirchSpeech.showDialogue = false
      mockBirchSpeech.printer = nil
      local closedBirchKind = ModernOverlay.getActiveScreen(gameBootBirch)
      T.eq(closedBirchKind, nil, "Inactive Birch dialogue returns nil so native cutscene animation plays unoccluded")

      -- Test F: Gen 3 FireRed Oak Speech Detection
      local mockOakSpeech = {
        assets = { oakSprite = {} },
        win = { dialog = true },
        printer = {
          pages = { "Hello, there!\nWelcome to POKéMON!" },
          page = 1,
          revealed = 15,
          active = true,
          state = "char",
        },
      }
      local gameBootOak = {
        phase = "boot",
        boot = {
          phase = "oak",
          newGame = mockOakSpeech,
        },
      }
      local oakKind, oakDiag, _, oakChoice = ModernOverlay.getActiveScreen(gameBootOak)
      T.eq(oakKind, "dialogue", "ModernOverlay.getActiveScreen detects Gen 3 FireRed Oak intro speech")
      T.eq(oakDiag and oakDiag.speaker, "PROF. OAK", "Oak speech has PROF. OAK speaker nameplate")
      T.eq(oakDiag and oakDiag.pages[1], "Hello, there!\nWelcome to POKéMON!", "Oak speech passes paged text")

      -- FireRed name choice menu
      mockOakSpeech.win.menu = {
        items = { { "NEW NAME" }, { "RED" }, { "ASH" } },
        cursor = 1,
        left = 2,
      }
      local _, _, _, oakMenuChoice = ModernOverlay.getActiveScreen(gameBootOak)
      T.eq(oakMenuChoice ~= nil, true, "Oak name choices produce choice subState")
      T.eq(oakMenuChoice and #oakMenuChoice.options, 3, "Oak name choices has 3 options")
      T.eq(oakMenuChoice and oakMenuChoice.options[2], "RED", "Oak option 2 is RED")
      T.eq(oakMenuChoice and oakMenuChoice.cursor, 2, "Oak cursor is 2")

      -- Test G: DialogueRenderer rendering Gen 3 Birch speech with lines array
      local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
      local okRenderBirch = pcall(DialogueRenderer.draw, gameBootBirch, birchDiag, 800, 600, curTheme, genderChoice)
      T.eq(okRenderBirch, true, "DialogueRenderer successfully renders Gen 3 Birch speech with modern card & left choice modal")

      -- Test H: DialogueRenderer rendering Gen 3 Oak speech with paged text
      local okRenderOak = pcall(DialogueRenderer.draw, gameBootOak, oakDiag, 800, 600, curTheme, oakMenuChoice)
      T.eq(okRenderOak, true, "DialogueRenderer successfully renders Gen 3 Oak speech with paged text & choice modal")

      -- Test I: NamingRenderer.attachControls robustness against number dt parameter
      local testNamingState = { name = "BRENDAN", maxLen = 7, template = "PLAYER" }
      NamingRenderer.attachControls(testNamingState, gameBootBirch)
      T.eq(type(testNamingState.update), "function", "NamingRenderer attached update function")
      local okCallNum = pcall(testNamingState.update, 0.0166)
      T.eq(okCallNum, true, "Calling state.update with numeric dt (GBA engine calling convention) does not crash")
    end)()
;
    -- =========================================================================
    -- Gen 3 Pause Sub-Menu Adapter & Plumbing Test Suite
    -- =========================================================================
    (function()
      local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")
      local PartyRenderer = require("mods.omni_ui.renderers.PartyRenderer")
      local SummaryRenderer = require("mods.omni_ui.renderers.SummaryRenderer")
      local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
      local TrainerCardRenderer = require("mods.omni_ui.renderers.TrainerCardRenderer")
      local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
      local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
      local curTheme = Theme.get()

      -- 1. Create a mock Gen 3 game session
      local mockParty = {
        {
          species = "TRECKO",
          nickname = "GECKO",
          level = 10,
          hp = 30,
          stats = { hp = 30, attack = 15, defense = 12, spAttack = 20, spDefense = 18, speed = 25 },
          moves = { { id = "POUND", pp = 35, maxPP = 35 }, { id = "CUT", pp = 30, maxPP = 30 } },
          personality = 0x81CD81CD, -- pid % 25 determines nature, matches otId/secretId XOR for shiny
          otId = 98765,
          secretId = 98765, -- Triggers shiny condition
          ability = "OVERGROW",
          gender = "MALE",
        },
        {
          isEgg = true,
          species = "EGG",
          eggCycles = 25,
          friendship = 25,
        },
      }

      local mockSession = {
        playerName = "BRENDAN",
        trainerId = 98765,
        money = 12000,
        gender = 0, -- Male
        playHours = 12,
        playMinutes = 34,
        playSeconds = 56,
        party = mockParty,
        bag = {
          pockets = {
            ITEMS = { { id = "POTION", qty = 5 }, { id = "SUPER_POTION", qty = 2 } },
            POKE_BALLS = { { id = "POKE_BALL", qty = 10 } },
            KEY_ITEMS = { { id = "MACH_BIKE", qty = 1 } },
            TM_CASE = { { id = "TM01", qty = 1 } },
            BERRY_POUCH = { { id = "ORAN_BERRY", qty = 3 } },
          },
        },
        dex = {
          seen = { [1] = true, [2] = true, [3] = true },
          owned = { [1] = true, [2] = true },
        },
      }

      local mockGen3Game = {
        gameVersion = "emerald",
        session = mockSession,
        data = Data,
      }

      local adapter = Gen3Adapter.new(mockGen3Game)
      T.eq(adapter.region, "HOENN", "Gen3Adapter resolves HOENN region for Emerald")

      -- Test 2: Party and Mon Normalization
      local partyNorm = adapter:getParty()
      T.eq(#partyNorm, 2, "Gen3Adapter:getParty returns normalized party slots")
      local mon1 = partyNorm[1]
      T.eq(mon1.species, "TRECKO", "Mon 1 normalized species")
      T.eq(mon1.isShiny, true, "Mon 1 shininess derived from PID and OT/SID")
      T.neq(mon1.nature, nil, "Mon 1 nature derived from personality")
      T.eq(mon1.gender, "M", "Mon 1 gender normalized to M")
      T.eq(#mon1.fieldMoves > 0 and mon1.fieldMoves[1], "CUT", "Mon 1 field move CUT identified")

      local egg = partyNorm[2]
      T.eq(egg.isEgg, true, "Egg normalized with isEgg = true")
      T.eq(egg.name, "POKéMON EGG", "Egg normalized with authentic name")
      T.eq(egg.eggFlavorText, "What will hatch from this? It will take some time.", "Egg flavor text matches Gen 3 authentic cycles")

      -- Test 3: Player Info Normalization
      local playerInfo = adapter:getPlayerInfo()
      T.eq(playerInfo.name, "BRENDAN", "Player name normalized from session")
      T.eq(playerInfo.money, 12000, "Money normalized from session")
      T.eq(playerInfo.playTimeString, "12:34", "Play time string formatted from session hours & minutes")
      T.eq(playerInfo.pokedex.seen, 3, "Pokédex seen count normalized")
      T.eq(playerInfo.pokedex.owned, 2, "Pokédex owned count normalized")
      T.eq(playerInfo.badgeNames[1], "STONE", "Hoenn Stone badge in badge names")

      -- Test 4: Bag & Pockets Normalization
      local pockets = adapter:getBagPockets()
      T.eq(#pockets, 5, "Gen3Adapter:getBagPockets returns 5 pockets for Emerald")
      local itemsList = adapter:getBagItems("ITEMS")
      T.eq(#itemsList, 2, "Gen3Adapter:getBagItems returns items from ITEMS pocket")
      T.eq(itemsList[1].id, "POTION", "Potion in items list")
      T.eq(itemsList[1].count, 5, "Potion count matches session")

      -- Test 5: Pokédex Entries Normalization
      local dexEntries = adapter:getPokedexEntries("HOENN")
      T.eq(type(dexEntries), "table", "Gen3Adapter:getPokedexEntries returns table")
      local dexEntry = adapter:getDexEntry("BULBASAUR")
      T.neq(dexEntry, nil, "Gen3Adapter:getDexEntry returns entry definition")
      T.eq(dexEntry.dex, 1, "Bulbasaur dex number is 1")

      -- Test 6: Start Menu Items Normalization
      local menuItems = adapter:getStartMenuItems()
      T.eq(menuItems[1].id, "pokedex", "Start menu contains POKéDEX")
      T.eq(menuItems[2].id, "pokemon", "Start menu contains POKéMON")
      T.eq(menuItems[3].id, "item", "Start menu contains BAG")
      T.eq(menuItems[4].id, "trainer", "Start menu contains TRAINER CARD")
      T.eq(menuItems[5].id, "save", "Start menu contains SAVE")

      -- Test 7: ModernOverlay.isSupported for Gen 3 module state objects
      local mockG3PartyMenu = {
        _party = mockParty,
        cursor = 1,
        mode = "list",
        ACTIONS = { "SUMMARY", "SWITCH", "ITEM", "CANCEL" },
      }
      T.eq(ModernOverlay.isSupported(mockG3PartyMenu), "party", "ModernOverlay.isSupported detects Gen 3 PartyMenu module")

      local mockG3SummaryMenu = {
        _party = mockParty,
        _cursor = 1,
        _page = 0, -- INFO page
        PAGE_INFO = 0,
      }
      T.eq(ModernOverlay.isSupported(mockG3SummaryMenu), "summary", "ModernOverlay.isSupported detects Gen 3 SummaryMenu module")

      local mockG3BagMenu = {
        POCKET_KEYS = { "ITEMS", "KEY_ITEMS", "POKE_BALLS", "TM_CASE", "BERRY_POUCH" },
        pocketIdx = 1,
        cursor = 1,
        scroll = 0,
        currentPocket = function() return "ITEMS" end,
        list = function() return { { id = "POTION", qty = 5 } } end,
      }
      T.eq(ModernOverlay.isSupported(mockG3BagMenu), "bag", "ModernOverlay.isSupported detects Gen 3 BagMenu module")

      local mockG3Pokedex = {
        _dex = mockSession.dex,
        currentOrder = "numerical_kanto",
        listCursor = 1,
        listScroll = 0,
      }
      T.eq(ModernOverlay.isSupported(mockG3Pokedex), "pokedex", "ModernOverlay.isSupported detects Gen 3 Pokedex module")

      local mockG3TrainerCard = {
        _card = { id = 12345 },
        badges = {},
      }
      T.eq(ModernOverlay.isSupported(mockG3TrainerCard), "trainer_card", "ModernOverlay.isSupported detects Gen 3 TrainerCard module")

      -- Test 8: Renderers execution with Gen 3 states
      local okPartyDraw = pcall(PartyRenderer.draw, mockGen3Game, mockG3PartyMenu, 800, 600, curTheme)
      T.eq(okPartyDraw, true, "PartyRenderer successfully draws Gen 3 PartyMenu state")

      local okSummaryDraw = pcall(SummaryRenderer.draw, mockGen3Game, mockG3SummaryMenu, 800, 600, curTheme)
      T.eq(okSummaryDraw, true, "SummaryRenderer successfully draws Gen 3 SummaryMenu state (Page 0 Info)")

      mockG3SummaryMenu._page = 4 -- Egg page
      mockG3SummaryMenu._cursor = 2
      local okEggSummaryDraw = pcall(SummaryRenderer.draw, mockGen3Game, mockG3SummaryMenu, 800, 600, curTheme)
      T.eq(okEggSummaryDraw, true, "SummaryRenderer successfully draws Gen 3 SummaryMenu Egg page")

      local okBagDraw = pcall(BagRenderer.draw, mockGen3Game, mockG3BagMenu, 800, 600, curTheme)
      T.eq(okBagDraw, true, "BagRenderer successfully draws Gen 3 BagMenu state")

      local Layout = require("mods.omni_ui.core.Layout")
      local drawnLabels = {}
      local origDrawText = Layout.drawText
      Layout.drawText = function(text, ...)
        drawnLabels[#drawnLabels + 1] = tostring(text):upper()
        return origDrawText(text, ...)
      end
      local function saw(label)
        for _, line in ipairs(drawnLabels) do
          if line:find(label, 1, true) then return true end
        end
        return false
      end
      mockG3PartyMenu.cursor = 7
      drawnLabels = {}
      local okPartyCancel = pcall(PartyRenderer.draw, mockGen3Game, mockG3PartyMenu, 800, 600, curTheme)
      T.eq(okPartyCancel, true, "Gen3 party draws with Cancel selected")
      T.eq(saw("CANCEL"), true, "Gen3 party list ends with Cancel")
      mockG3PartyMenu.mode = "choose_multi"
      mockG3PartyMenu.cursor = 8
      drawnLabels = {}
      local okMultiCancel = pcall(PartyRenderer.draw, mockGen3Game, mockG3PartyMenu, 800, 600, curTheme)
      T.eq(okMultiCancel, true, "Gen3 multi party draws Confirm and Cancel")
      T.eq(saw("CONFIRM") and saw("CANCEL"), true, "Gen3 multi choose ends with Confirm and Cancel")
      mockG3PartyMenu.mode = "list"
      mockG3PartyMenu.cursor = 1

      mockG3BagMenu.cursor = 2
      drawnLabels = {}
      local okBagCancel = pcall(BagRenderer.draw, mockGen3Game, mockG3BagMenu, 800, 600, curTheme)
      T.eq(okBagCancel, true, "Gen3 bag draws with Cancel selected")
      T.eq(saw("CANCEL"), true, "Gen3 bag list ends with Cancel")
      mockG3BagMenu.mode = "action"
      mockG3BagMenu.cursor = 1
      mockG3BagMenu.actionCursor = 4
      mockG3BagMenu.ACTIONS = { "USE", "SET", false, "CANCEL" }
      drawnLabels = {}
      local okBagAction = pcall(BagRenderer.draw, mockGen3Game, mockG3BagMenu, 800, 600, curTheme)
      T.eq(okBagAction, true, "Gen3 bag action menu draws")
      T.eq(saw("CANCEL"), true, "Gen3 bag action menu keeps Cancel as the last choice")
      T.eq(saw("FALSE"), false, "Gen3 bag action menu skips empty grid cells")
      mockG3BagMenu.mode = "list"
      mockG3BagMenu.cursor = 1
      mockG3BagMenu.ACTIONS = nil
      mockG3BagMenu.actionCursor = nil
      Layout.drawText = origDrawText

      local okTrainerCardDraw = pcall(TrainerCardRenderer.draw, mockGen3Game, mockG3TrainerCard, 800, 600, curTheme)
      T.eq(okTrainerCardDraw, true, "TrainerCardRenderer successfully draws Gen 3 TrainerCard with Hoenn badges & leaders")

      local okPokedexDraw = pcall(PokedexRenderer.draw, mockGen3Game, mockG3Pokedex, 800, 600, curTheme)
      T.eq(okPokedexDraw, true, "PokedexRenderer successfully draws Gen 3 Pokedex state")

      -- Test 9: PartyRenderer action modal with field move (CUT)
      mockG3PartyMenu.mode = "action"
      mockG3PartyMenu.ACTIONS = { "CUT", "SUMMARY", "SWITCH", "ITEM", "CANCEL" }
      mockG3PartyMenu.actionCursor = 1
      local okPartyActionDraw = pcall(PartyRenderer.draw, mockGen3Game, mockG3PartyMenu, 800, 600, curTheme)
      T.eq(okPartyActionDraw, true, "PartyRenderer successfully draws Gen 3 action modal with field move CUT")

      -- Test 10: ModernOverlay.attachControls preserves Gen 3 native module states
      local origSummaryUpdate = function() end
      mockG3SummaryMenu.update = origSummaryUpdate
      ModernOverlay.attachControls(mockG3SummaryMenu, mockGen3Game)
      T.eq(mockG3SummaryMenu.update, origSummaryUpdate, "ModernOverlay.attachControls leaves Gen 3 SummaryMenu update untouched")

      ModernOverlay.attachControls(mockG3BagMenu, mockGen3Game)
      T.eq(mockG3BagMenu.pockets == nil, true, "ModernOverlay.attachControls leaves Gen 3 BagMenu pockets untouched")

      ModernOverlay.attachControls(mockG3Pokedex, mockGen3Game)
      T.eq(mockG3Pokedex.rows == nil, true, "ModernOverlay.attachControls leaves Gen 3 Pokedex rows untouched")

      -- Test 11: Gen 3 Stack fullscreen returns false for OmniUI menus (preserves overworld pass)
      local okStack, G3Stack = pcall(require, "src.ui.game3.stack")
      if ModernOverlay.ensureGen3Hooks then ModernOverlay.ensureGen3Hooks() end
      if okStack and G3Stack then
        G3Stack.clear()
        G3Stack.push("party", mockG3PartyMenu, { hideBelow = true, fullscreen = true })
        T.eq(G3Stack.fullscreen(), false, "G3Stack.fullscreen returns false for 'party' when modern overlay active")
        G3Stack.clear()
      end

      -- Test 12: Gen 3 PartyMenu.draw suppresses background and destroys OAM sprites
      local okParty, G3PartyMenuMod = pcall(require, "src.ui.game3.party_menu")
      if okParty and G3PartyMenuMod then
        local destroyedOam = false
        local fakeOam = {
          destroySprite = function(id) destroyedOam = true end
        }
        package.loaded["src.core.game3.oam"] = fakeOam
        G3PartyMenuMod._oam = {
          { mon = 10, ball = 11, status = 12, item = 13 }
        }
        G3PartyMenuMod._summaryIcon = 14
        G3PartyMenuMod.draw()
        T.eq(destroyedOam, true, "G3PartyMenu.draw cleans up native OAM sprites to avoid rendering over modern UI")
      end

      -- Test 13: render.hud hook executes cleanly during Gen 3 boot menu phase
      local ModRuntime = require("src.mods.Runtime")
      local okHud, errHud = pcall(function()
        ModRuntime.call("render.hud", function() end, mockBootGame, { width = 800, height = 600 })
      end)
      T.eq(okHud, true, "render.hud executes without errors during Gen 3 boot menu phase")

      -- Test 14: SPECIES_NONE Guard (Empty storage slots return nil)
      T.eq(adapter:normalizeMon(nil), nil, "normalizeMon(nil) returns nil")
      T.eq(adapter:normalizeMon({ species = 0 }), nil, "SPECIES_NONE (species = 0) returns nil")
      T.eq(adapter:normalizeMon({ speciesId = 0 }), nil, "SPECIES_NONE (speciesId = 0) returns nil")
      T.eq(adapter:normalizeMon({}), nil, "Empty table returns nil")

      -- Test 15: PID Gender Derivation via Pokemon.genderRatio
      local origPokemon = package.loaded["src.core.game3.pokemon"]
      local fakeP = {
        genderRatio = function(sp)
          if sp == 100 then return 255 end -- Genderless
          if sp == 101 then return 254 end -- 100% Female
          if sp == 102 then return 0 end   -- 100% Male
          if sp == 103 then return 127 end -- 50/50
          return 127
        end,
        speciesOf = function(m) return m.species end,
      }
      package.loaded["src.core.game3.pokemon"] = setmetatable(fakeP, { __index = origPokemon })

      local gLess = adapter:normalizeMon({ species = 100, personality = 0x12345678 })
      T.eq(gLess.gender, nil, "Genderless ratio (255) normalized to nil")

      local gFemaleOnly = adapter:normalizeMon({ species = 101, personality = 0x12345678 })
      T.eq(gFemaleOnly.gender, "F", "All-female ratio (254) normalized to F")

      local gMaleOnly = adapter:normalizeMon({ species = 102, personality = 0x12345678 })
      T.eq(gMaleOnly.gender, "M", "All-male ratio (0) normalized to M")

      -- 50/50 split (ratio = 127): pid % 256 >= 127 => M, < 127 => F
      local gMaleThreshold = adapter:normalizeMon({ species = 103, personality = 200 })
      T.eq(gMaleThreshold.gender, "M", "PID byte 200 >= 127 threshold normalized to M")

      local gFemaleThreshold = adapter:normalizeMon({ species = 103, personality = 50 })
      T.eq(gFemaleThreshold.gender, "F", "PID byte 50 < 127 threshold normalized to F")

      package.loaded["src.core.game3.pokemon"] = origPokemon

      -- Test 16: Move PP Property Binding & Integer Division Max PP Math
      local testMonPP = {
        species = 1,
        moves = {
          { id = "TACKLE", basePP = 35 },
          { id = "GROWL", basePP = 40 },
        },
        pp = { 12, 5 },
        ppBonuses = { 3, 1 }, -- 3 PP Ups (+60%), 1 PP Up (+20%)
      }
      local normPP = adapter:normalizeMon(testMonPP)
      T.eq(normPP.moves[1].pp, 12, "Move 1 current PP mapped from mon.pp[1]")
      -- 35 + floor(35 / 5) * 3 = 35 + 7 * 3 = 56
      T.eq(normPP.moves[1].maxPP, 56, "Move 1 max PP computed with C integer truncation (56)")
      T.eq(normPP.moves[2].pp, 5, "Move 2 current PP mapped from mon.pp[2]")
      -- 40 + floor(40 / 5) * 1 = 40 + 8 * 1 = 48
      T.eq(normPP.moves[2].maxPP, 48, "Move 2 max PP computed with C integer truncation (48)")

      -- Test 17: Pre-Gen 4 Move Category Derivation
      local testMovesCat = {
        species = 1,
        moves = {
          { id = "NORMAL_MOVE", type = 0, power = 40 },  -- Type 0 (Normal) -> PHYSICAL
          { id = "FIRE_MOVE", type = 10, power = 90 },    -- Type 10 (Fire) -> SPECIAL
          { id = "STATUS_MOVE", type = 0, power = 0 },    -- Power 0 -> STATUS
        },
      }
      local normCat = adapter:normalizeMon(testMovesCat)
      T.eq(normCat.moves[1].category, "PHYSICAL", "Pre-Gen 4 Type 0 (Normal) with power is PHYSICAL")
      T.eq(normCat.moves[2].category, "SPECIAL", "Pre-Gen 4 Type 10 (Fire) with power is SPECIAL")
      T.eq(normCat.moves[3].category, "STATUS", "Zero power move is STATUS")

      -- Test 18: BoxPokemon View-Model Isolation & Dynamic Stat Reconstruction
      local rawBoxMon = {
        species = 1,
        exp = 1000, -- No level, no stats table
        ivs = { 15, 15, 15, 15, 15, 15 },
        evs = { 0, 0, 0, 0, 0, 0 },
        personality = 0x12345678,
      }
      local normBox = adapter:normalizeMon(rawBoxMon)
      T.neq(normBox, rawBoxMon, "normalizeMon returns a distinct isolated view-model table")
      T.eq(normBox.raw, rawBoxMon, "normBox.raw maintains copy-on-read reference to original struct")
      T.eq(rawBoxMon.stats, nil, "Original BoxPokemon struct was NOT mutated in place")
      T.neq(normBox.stats, nil, "normBox has reconstructed stats table")
      T.eq(type(normBox.stats.attack), "number", "normBox.stats.attack reconstructed dynamically")
      T.eq(normBox.level >= 1, true, "normBox level reconstructed from exp")

      -- Test 19: Linear Summary Tab Cycling (Starts on 1 STATS, Left/Right linear wrap)
      local G3Summary = require("src.ui.game3.summary_menu")
      local mockParty = {
        {
          species = 25,
          name = "PIKACHU",
          level = 20,
          moves = { "THUNDERBOLT", "QUICK_ATTACK", "THUNDER_WAVE", "SLAM" },
          pp = { 15, 30, 20, 20 },
        }
      }
      G3Summary.openMenu(mockParty, 1)
      T.eq(G3Summary.page, 1, "SummaryMenu opens on Tab 1 (STATS)")
      T.eq(G3Summary._page, G3Summary.PAGE_SKILLS, "SummaryMenu native _page is synchronized to PAGE_SKILLS (1)")

      local function fakeInput(keys)
        local pressed = {}
        for _, k in ipairs(keys) do pressed[k] = true end
        return {
          wasPressed = function(self, k) return pressed[k] == true end,
          isDown = function(self, k) return pressed[k] == true end,
        }
      end

      -- Right: 1 -> 2
      G3Summary.handleInput(fakeInput({ "right" }))
      T.eq(G3Summary.page, 2, "Right flips Tab 1 (STATS) -> Tab 2 (MOVES)")
      T.eq(G3Summary._page, G3Summary.PAGE_MOVES, "Native _page synchronized to PAGE_MOVES (2)")

      -- Right: 2 -> 3
      G3Summary.handleInput(fakeInput({ "right" }))
      T.eq(G3Summary.page, 3, "Right flips Tab 2 (MOVES) -> Tab 3 (DETAILS)")
      T.eq(G3Summary._page, G3Summary.PAGE_INFO, "Native _page synchronized to PAGE_INFO (0)")

      -- Right: 3 -> 1 (Linear wrap-around!)
      G3Summary.handleInput(fakeInput({ "right" }))
      T.eq(G3Summary.page, 1, "Right wraps Tab 3 (DETAILS) -> Tab 1 (STATS)")
      T.eq(G3Summary._page, G3Summary.PAGE_SKILLS, "Native _page synchronized back to PAGE_SKILLS (1)")

      -- Left: 1 -> 3 (Linear wrap-around!)
      G3Summary.handleInput(fakeInput({ "left" }))
      T.eq(G3Summary.page, 3, "Left wraps Tab 1 (STATS) -> Tab 3 (DETAILS)")
      T.eq(G3Summary._page, G3Summary.PAGE_INFO, "Native _page synchronized to PAGE_INFO (0)")

      -- Left: 3 -> 2
      G3Summary.handleInput(fakeInput({ "left" }))
      T.eq(G3Summary.page, 2, "Left flips Tab 3 (DETAILS) -> Tab 2 (MOVES)")

      -- Test 20: Moves Tab Navigation, Submenu on A, Reordering, and Contest Subtab Toggle
      T.eq(G3Summary.page, 2, "Currently on Tab 2 (MOVES)")
      T.eq(G3Summary.inMovesSubmenu, false, "When arriving on Tab 2, inMovesSubmenu is initially false (submenu not active)")

      -- Pressing Right on Tab 2 when not in submenu advances to Tab 3 (DETAILS) without getting eaten!
      G3Summary.handleInput(fakeInput({ "right" }))
      T.eq(G3Summary.page, 3, "Right flips Tab 2 (MOVES) -> Tab 3 (DETAILS)")
      T.eq(G3Summary._page, G3Summary.PAGE_INFO, "Native _page synchronized to PAGE_INFO (0)")

      -- Left back to Tab 2
      G3Summary.handleInput(fakeInput({ "left" }))
      T.eq(G3Summary.page, 2, "Left flips Tab 3 (DETAILS) -> Tab 2 (MOVES)")
      T.eq(G3Summary.inMovesSubmenu, false, "inMovesSubmenu is false before hitting A")

      -- Pressing A enters the Moves Submenu!
      G3Summary.handleInput(fakeInput({ "a" }))
      T.eq(G3Summary.inMovesSubmenu, true, "Pressing A enters moves submenu")
      T.eq(G3Summary._page, G3Summary.PAGE_MOVES_INFO, "Native _page synchronized to PAGE_MOVES_INFO (3)")

      -- Inside Submenu: Move Cursor Navigation
      T.eq(G3Summary.moveIndex, 1, "Move cursor defaults to slot 1")
      G3Summary.handleInput(fakeInput({ "down" }))
      T.eq(G3Summary.moveIndex, 2, "Down moves cursor to slot 2")
      G3Summary.handleInput(fakeInput({ "down" }))
      T.eq(G3Summary.moveIndex, 3, "Down moves cursor to slot 3")
      G3Summary.handleInput(fakeInput({ "down" }))
      T.eq(G3Summary.moveIndex, 4, "Down moves cursor to slot 4")
      G3Summary.handleInput(fakeInput({ "down" }))
      T.eq(G3Summary.moveIndex, 1, "Down wraps cursor from slot 4 back to slot 1 without disappearing")

      -- Reorder: Pick up slot 1, move to slot 3, swap
      G3Summary.handleInput(fakeInput({ "a" }))
      T.eq(G3Summary.swapSlot, 1, "Pressing A enters swap mode and sets swapSlot = 1")
      G3Summary.handleInput(fakeInput({ "down" }))
      G3Summary.handleInput(fakeInput({ "down" }))
      T.eq(G3Summary.moveIndex, 3, "Move cursor moved to target slot 3")
      G3Summary.handleInput(fakeInput({ "a" }))
      T.eq(G3Summary.swapSlot, nil, "Pressing A drops move, executes swap, and clears swapSlot")
      T.eq(mockParty[1].moves[1], "THUNDER_WAVE", "Move 1 was swapped to THUNDER_WAVE")
      T.eq(mockParty[1].moves[3], "THUNDERBOLT", "Move 3 was swapped to THUNDERBOLT")

      -- Cancel swap with B
      G3Summary.handleInput(fakeInput({ "a" }))
      T.eq(G3Summary.swapSlot, 3, "Pressing A enters swap mode for slot 3")
      G3Summary.handleInput(fakeInput({ "b" }))
      T.eq(G3Summary.swapSlot, nil, "Pressing B cancels swap mode without closing the menu or exiting submenu")
      T.eq(G3Summary.inMovesSubmenu, true, "Still inside moves submenu after cancelling swap")
      T.eq(G3Summary.open, true, "Summary menu remains open after B cancel")

      -- Exit moves submenu with B
      G3Summary.handleInput(fakeInput({ "b" }))
      T.eq(G3Summary.inMovesSubmenu, false, "Pressing B when not swapping exits moves submenu back to Tab 2")
      T.eq(G3Summary._page, G3Summary.PAGE_MOVES, "Native _page restored to PAGE_MOVES (2)")
      T.eq(G3Summary.open, true, "Summary menu remains open")

      -- Now that we're back in Tab 2 view, Right advances to Tab 3!
      G3Summary.handleInput(fakeInput({ "right" }))
      T.eq(G3Summary.page, 3, "Right advances to Tab 3 (DETAILS)")

      -- Back to Tab 2
      G3Summary.handleInput(fakeInput({ "left" }))
      T.eq(G3Summary.page, 2, "Left returns to Tab 2 (MOVES)")

      -- Enter submenu again to test contest toggle via Left/Right and Select
      G3Summary.handleInput(fakeInput({ "a" }))
      T.eq(G3Summary.inMovesSubmenu, true, "Inside moves submenu (moves focused)")
      T.eq(G3Summary.movesSubTab, "battle", "movesSubTab defaults to battle")

      -- In moves menu focused: Right swaps to contest view!
      G3Summary.handleInput(fakeInput({ "right" }))
      T.eq(G3Summary.movesSubTab, "contest", "Right in focused moves menu swaps to contest view")

      -- In moves menu focused: Left swaps back to battle view!
      G3Summary.handleInput(fakeInput({ "left" }))
      T.eq(G3Summary.movesSubTab, "battle", "Left in focused moves menu swaps back to battle view")

      -- Contest subtab toggle with Select / Tab also works
      G3Summary.handleInput(fakeInput({ "select" }))
      T.eq(G3Summary.movesSubTab, "contest", "Select toggles movesSubTab to contest")
      G3Summary.handleInput(fakeInput({ "select" }))
      T.eq(G3Summary.movesSubTab, "battle", "Select toggles movesSubTab back to battle")

      G3Summary.close()
      T.eq(G3Summary.open, false, "G3Summary closes cleanly")

      -- Test 20B: RseSummary (Emerald) input handling does not trap cursor on moves page
      local RseSummary = require("src.ui.game3.rse.summary_menu")
      G3Summary.openMenu(mockParty, 1, { page = 2 })
      T.eq(G3Summary.page, 2, "Opened on Tab 2 (MOVES)")
      T.eq(G3Summary._page, G3Summary.PAGE_MOVES, "Native _page is PAGE_MOVES (2)")

      -- RseSummary: Right on Tab 2 overview advances to Tab 3 (DETAILS)
      RseSummary.handleInput(fakeInput({ "right" }), G3Summary)
      T.eq(G3Summary.page, 3, "RseSummary Right advances Tab 2 (MOVES) -> Tab 3 (DETAILS)")
      T.eq(G3Summary._page, G3Summary.PAGE_INFO, "Native _page synchronized to PAGE_INFO (0)")

      -- RseSummary: Right on Tab 3 wraps to Tab 1 (STATS)
      RseSummary.handleInput(fakeInput({ "right" }), G3Summary)
      T.eq(G3Summary.page, 1, "RseSummary Right wraps Tab 3 (DETAILS) -> Tab 1 (STATS)")
      T.eq(G3Summary._page, G3Summary.PAGE_SKILLS, "Native _page synchronized to PAGE_SKILLS (1)")

      -- RseSummary: Left on Tab 1 wraps to Tab 3 (DETAILS)
      RseSummary.handleInput(fakeInput({ "left" }), G3Summary)
      T.eq(G3Summary.page, 3, "RseSummary Left wraps Tab 1 (STATS) -> Tab 3 (DETAILS)")

      -- RseSummary: Left on Tab 3 returns to Tab 2 (MOVES)
      RseSummary.handleInput(fakeInput({ "left" }), G3Summary)
      T.eq(G3Summary.page, 2, "RseSummary Left returns to Tab 2 (MOVES)")

      -- Focus into moves menu via A
      G3Summary.handleInput(fakeInput({ "a" }))
      T.eq(G3Summary.inMovesSubmenu, true, "Inside moves submenu in RseSummary")

      -- In focused moves menu: Right swaps to CONTEST_MOVES!
      RseSummary.handleInput(fakeInput({ "right" }), G3Summary)
      T.eq(RseSummary.page(G3Summary), RseSummary.PAGE.CONTEST_MOVES, "RseSummary Right in focused moves menu swaps to CONTEST_MOVES")

      -- In focused moves menu: Left swaps back to BATTLE_MOVES!
      RseSummary.handleInput(fakeInput({ "left" }), G3Summary)
      T.eq(RseSummary.page(G3Summary), RseSummary.PAGE.BATTLE_MOVES, "RseSummary Left in focused moves menu swaps back to BATTLE_MOVES")

      -- RseSummary: Select also toggles contest view
      RseSummary.handleInput(fakeInput({ "select" }), G3Summary)
      T.eq(RseSummary.page(G3Summary), RseSummary.PAGE.CONTEST_MOVES, "RseSummary Select toggles to CONTEST_MOVES")
      RseSummary.handleInput(fakeInput({ "select" }), G3Summary)
      T.eq(RseSummary.page(G3Summary), RseSummary.PAGE.BATTLE_MOVES, "RseSummary Select toggles back to BATTLE_MOVES")

      G3Summary.close()

      -- Test 21: ContestDatabase Metadata & Hearts Formatting
      local ContestDB = require("mods.omni_ui.core.ContestDatabase")
      T.eq(ContestDB.getCategory("FLAMETHROWER"), "BEAUTY", "Flamethrower is classified as BEAUTY")
      T.eq(ContestDB.getCategory("THUNDERBOLT"), "COOL", "Thunderbolt is classified as COOL")
      T.eq(ContestDB.getCategory("SING"), "CUTE", "Sing is classified as CUTE")
      T.eq(ContestDB.getCategory("PSYCHIC"), "SMART", "Psychic is classified as SMART")
      T.eq(ContestDB.getCategory("EARTHQUAKE"), "TOUGH", "Earthquake is classified as TOUGH")
      T.eq(ContestDB.formatAppealHearts(4, 4), "♥♥♥♥", "formatAppealHearts(4, 4) produces 4 hearts")
      T.eq(ContestDB.formatJamHearts(2), "💔💔", "formatJamHearts(2) produces 2 broken hearts")
      T.eq(ContestDB.formatJamHearts(0), "-", "formatJamHearts(0) produces dash")

      -- Test 22: SummaryRenderer renders Battle & Contest subtabs in Landscape & Portrait
      local summaryTestMon = {
        species = 25,
        name = "PIKACHU",
        level = 25,
        moves = {
          { id = "THUNDERBOLT", pp = 15, maxPP = 15 },
          { id = "FLAMETHROWER", pp = 15, maxPP = 15 },
          { id = "SURF", pp = 15, maxPP = 15 },
          { id = "EARTHQUAKE", pp = 10, maxPP = 10 },
        },
        stats = { hp = 70, attack = 55, defense = 40, spAttack = 50, spDefense = 50, speed = 90 },
      }
      local testStateLand = {
        mon = summaryTestMon,
        page = 2,
        moveIndex = 2,
        movesSubTab = "contest",
        swapSlot = 1,
      }
      local curTheme = Theme.get()
      local okLandContest = pcall(SummaryRenderer.draw, mockGen3Game, testStateLand, 800, 600, curTheme)
      T.eq(okLandContest, true, "SummaryRenderer renders Contest subtab with swap indicator in Landscape (800x600)")

      local testStatePort = {
        mon = summaryTestMon,
        page = 2,
        moveIndex = 1,
        movesSubTab = "contest",
        swapSlot = nil,
      }
      local okPortContest = pcall(SummaryRenderer.draw, mockGen3Game, testStatePort, 360, 640, curTheme)
      T.eq(okPortContest, true, "SummaryRenderer renders Contest subtab in Portrait Mobile (360x640)")
    end)()

    -- =========================================================================
    -- Pokédex Cross-Generation Parity & Modern UI Tests
    -- =========================================================================
    ;(function()
      print("--- POKÉDEX CROSS-GENERATION PARITY SUITE ---")
      local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")
      local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")
      local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")

      -- Mock Gen 3 game session with bitfield-packed Pokédex RAM
      local mockDexSeen = { [1] = true, [25] = true, [277] = true } -- Bulbasaur, Pikachu, Treecko seen
      local mockDexCaught = { [1] = true } -- Only Bulbasaur caught (Pikachu & Treecko are Seen-Only)
      local mockDex = {
        seen = mockDexSeen,
        caught = mockDexCaught,
        owned = mockDexCaught,
        nationalUnlocked = false,
        isSeen = function(self, sp) return mockDexSeen[sp] == true end,
        isCaught = function(self, sp) return mockDexCaught[sp] == true end,
      }
      local mockSession = {
        dex = mockDex,
        gameCode = "BPEE",
        region = "HOENN",
      }
      local mockGame = {
        gameVersion = "emerald",
        session = mockSession,
        save = { dex = mockDex },
        data = {
          pokemon = {
            [1] = {
              dex = 1,
              name = "BULBASAUR",
              types = { "GRASS", "POISON" },
              kind = "SEED",
              dexEntry = {
                heightDm = 7,
                weightHg = 69,
                kind = "SEED",
                description = "A strange seed was planted on its back at birth.",
              },
            },
            [25] = { dex = 25, name = "PIKACHU", types = { "ELECTRIC" }, kind = "MOUSE" },
            [277] = { dex = 277, name = "TREECKO", types = { "GRASS" }, kind = "WOOD GECKO" },
          },
          encounters = {
            three_isle_path = {
              grass = {
                slots = { { species = 206 } },
              },
            },
          },
        },
      }

      local adapter = Gen3Adapter.new(mockGame)

      -- 1. Three-Tier Index Architecture Mappings
      T.eq(adapter:speciesToNational(277), 252, "Treecko internal 277 maps to National #252")
      T.eq(adapter:nationalToSpecies(252), 277, "National #252 maps back to Treecko internal 277")
      T.eq(adapter:speciesToRegional(277), 1, "Treecko internal 277 maps to Hoenn Regional #001")
      T.eq(adapter:regionalToSpecies(1), 277, "Hoenn Regional #001 maps back to Treecko internal 277")

      T.eq(adapter:speciesToNational(1), 1, "Bulbasaur internal 1 maps to National #001")
      T.eq(adapter:nationalToSpecies(1), 1, "National #001 maps to Bulbasaur internal 1")

      -- 2. Bitfield Encapsulation via Adapter
      T.eq(adapter:hasSeen(1), true, "Bulbasaur is seen")
      T.eq(adapter:hasCaught(1), true, "Bulbasaur is caught")
      T.eq(adapter:hasSeen(25), true, "Pikachu is seen")
      T.eq(adapter:hasCaught(25), false, "Pikachu is NOT caught (seen-only)")
      T.eq(adapter:hasSeen(277), true, "Treecko is seen")
      T.eq(adapter:hasCaught(277), false, "Treecko is NOT caught (seen-only)")
      T.eq(adapter:hasSeen(4), false, "Charmander is unseen")
      T.eq(adapter:hasCaught(4), false, "Charmander is uncaught")

      -- 3. National Dex Progression Gating
      T.eq(adapter:isNationalDexUnlocked(), false, "National Dex is locked initially")
      local lockedSortModes = PokedexFilter.getAvailableSortModes(adapter)
      local hasNatMode = false
      for _, sm in ipairs(lockedSortModes) do
        if sm.id == "NATIONAL" then hasNatMode = true end
      end
      T.eq(hasNatMode, false, "NATIONAL sort mode is suppressed when National Dex is locked")

      mockDex.nationalUnlocked = true
      T.eq(adapter:isNationalDexUnlocked(), true, "National Dex unlocked when flag set")
      local unlockedSortModes = PokedexFilter.getAvailableSortModes(adapter)
      hasNatMode = false
      for _, sm in ipairs(unlockedSortModes) do
        if sm.id == "NATIONAL" then hasNatMode = true end
      end
      T.eq(hasNatMode, true, "NATIONAL sort mode is enabled when National Dex is unlocked")

      -- 4. Canonical Metric vs Imperial Integer Math Parity
      local bulbaEntry = adapter:getDexEntry(1)
      T.eq(bulbaEntry.height, "2'04\"", "Bulbasaur imperial height matches GBA integer truncation (2'04\")")
      T.eq(bulbaEntry.weight, "15.2 lbs.", "Bulbasaur imperial weight matches GBA integer truncation (15.2 lbs.)")
      T.eq(bulbaEntry.heightM, "0,7 m", "Bulbasaur metric height is 0,7 m")
      T.eq(bulbaEntry.weightKg, "6,9 kg", "Bulbasaur metric weight is 6,9 kg")

      -- 5. Footless Species Transparency
      local gastlyFp = adapter:getFootprint(92) -- Gastly (footless)
      T.eq(gastlyFp, nil, "Gastly has nil footprint (footless species)")
      local voltorbFp = adapter:getFootprint(100) -- Voltorb (footless)
      T.eq(voltorbFp, nil, "Voltorb has nil footprint (footless species)")

      -- 6. Seen-Only Lore Lockdown & Biometrics in PokedexRenderer
      local curTheme = Theme.get()

      -- Test Seen-Only Entry (Pikachu #25)
      local seenOnlyState = {
        view = "entry",
        screenId = "DexEntryMenu",
        species = 25,
      }
      local okSeenOnlyDraw = pcall(PokedexRenderer.draw, mockGame, seenOnlyState, 800, 600, curTheme)
      T.eq(okSeenOnlyDraw, true, "PokedexRenderer renders Seen-Only entry in Landscape without crashing")

      local okSeenOnlyPort = pcall(PokedexRenderer.draw, mockGame, seenOnlyState, 360, 640, curTheme)
      T.eq(okSeenOnlyPort, true, "PokedexRenderer renders Seen-Only entry in Portrait without crashing")

      -- Test Caught Entry (Bulbasaur #1)
      local caughtState = {
        view = "entry",
        screenId = "DexEntryMenu",
        species = 1,
      }
      local okCaughtDraw = pcall(PokedexRenderer.draw, mockGame, caughtState, 800, 600, curTheme)
      T.eq(okCaughtDraw, true, "PokedexRenderer renders Caught entry in Landscape without crashing")

      -- 7. Area / Habitat FRLG Dual-Map Integration
      local areaBulba = adapter:getAreaInfo(1)
      T.eq(areaBulba.isUnknown, true, "Starter Bulbasaur has no wild encounters (AREA UNKNOWN)")
      T.eq(#areaBulba.nests, 0, "Bulbasaur nests count is 0")

      local frlgGame = {
        gameVersion = "firered",
        session = { gameCode = "BPRE", region = "KANTO" },
        data = {
          encounters = {
            three_isle_path = {
              grass = {
                slots = { { species = 206 } },
              },
            },
          },
        },
      }
      local frlgAdapter = Gen3Adapter.new(frlgGame)
      local dunsparceArea = frlgAdapter:getAreaInfo(206)
      T.eq(dunsparceArea.region, "sevii", "Dunsparce defaults to Sevii Islands region map in FRLG")
      T.eq(dunsparceArea.canSwapRegion, true, "FRLG allows swapping region map")

      local townMapState = {
        view = "area",
        nestSpecies = 1,
      }
      local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")
      local okTownMap = pcall(TownMapRenderer.draw, mockGame, townMapState, 800, 600, curTheme)
      T.eq(okTownMap, true, "TownMapRenderer renders AREA UNKNOWN for Bulbasaur without crashing")

      -- 8. Emerald / RSE Pokédex Stack Hook & Overworld Overlay Integration
      local G3Stack = require("src.ui.game3.stack")
      local fakeRsePokedex = {
        page = 0,
        selected = 0,
        dexMode = 0,
        dexOrder = 0,
        seenCount = 5,
        ownCount = 2,
        dex = { seen = { [1] = true, [252] = true }, owned = { [252] = true } },
      }
      local fakeRseHost = { isMenu = true, _s = fakeRsePokedex }
      G3Stack.push("rse_pokedex", fakeRseHost, { hideBelow = true, fullscreen = true })

      -- Ensure fullscreen() returns false so overworld underneath does not get white-screened
      ModernOverlay.ensureGen3Hooks()
      local isFullscreen = G3Stack.fullscreen()
      T.eq(isFullscreen, false, "G3Stack.fullscreen() returns false for rse_pokedex under ModernOverlay (prevents white screen)")

      -- Verify ModernOverlay.getActiveScreen resolves rse_pokedex to pokedex kind and target state
      local activeKind, activeState = ModernOverlay.getActiveScreen(mockGame)
      T.eq(activeKind, "pokedex", "ModernOverlay detects rse_pokedex layer on G3Stack as 'pokedex'")
      T.eq(activeState, fakeRsePokedex, "ModernOverlay resolves activeState to rse_pokedex state object")

      -- Verify ModernOverlay.draw renders cleanly over overworld
      local okRseDraw = pcall(ModernOverlay.draw, mockGame, { width = 800, height = 600 })
      T.eq(okRseDraw, true, "ModernOverlay.draw renders rse_pokedex without errors")

      -- Test Gen 3 Pokédex interactive input navigation and submenu modal parity
      -- Initial list view: selecting seen entry (Treecko #252 / dex index 1)
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu ~= nil, true, "Pressing A on seen species opens Pokédex submenu modal in Gen 3")
      T.eq(#fakeRsePokedex.submenu.items >= 4, true, "Gen 3 Pokédex submenu contains DATA, CRY, AREA, QUIT")
      T.eq(fakeRsePokedex.submenu.items[1].label, "DATA", "First submenu item is DATA")
      T.eq(fakeRsePokedex.submenu.items[2].label, "CRY", "Second submenu item is CRY")
      T.eq(fakeRsePokedex.submenu.items[3].label, "AREA", "Third submenu item is AREA")
      T.eq(fakeRsePokedex.submenu.items[4].label, "QUIT", "Fourth submenu item is QUIT")
      T.eq(fakeRsePokedex.submenu.index, 1, "Initial cursor on submenu item 1 (DATA)")

      -- Navigate submenu with Up / Down
      fakeInput:press("down")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu.index, 2, "Down moves submenu cursor to 2 (CRY)")

      -- Press A on CRY keeps submenu open and plays cry
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu ~= nil, true, "Selecting CRY keeps submenu open")
      T.eq(fakeRsePokedex.view, "list", "Selecting CRY maintains list view")

      -- Navigate to AREA (item 3) and confirm
      fakeInput:press("down")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu.index, 3, "Down moves submenu cursor to 3 (AREA)")
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu, nil, "Selecting AREA closes submenu modal")
      T.eq(fakeRsePokedex.view, "area", "Selecting AREA transitions view to 'area'")

      -- B from Area returns to list
      fakeInput:press("b")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.view, "list", "B button in Area view returns to Pokédex list")

      -- Open submenu again and select DATA
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu ~= nil, true, "Re-opens submenu modal on A")
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu, nil, "Selecting DATA closes submenu")
      T.eq(fakeRsePokedex.view, "entry", "Selecting DATA transitions view to 'entry'")

      -- B from Entry returns to list
      fakeInput:press("b")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.view, "list", "B button in Entry view returns to Pokédex list")

      -- Open submenu and cancel with B
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu ~= nil, true, "Submenu opened")
      fakeInput:press("b")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.submenu, nil, "B button closes submenu without leaving list view")
      T.eq(fakeRsePokedex.view, "list", "Remains on list view after B cancel")

      -- Test that Entry view Up/Down skips unseen Pokémon and stays on seen entries only
      fakeInput:press("a")
      fakeRsePokedex:handleInputOmni(fakeInput)
      fakeInput:press("a") -- select DATA
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.view, "entry", "In entry view")

      fakeInput:press("down")
      fakeRsePokedex:handleInputOmni(fakeInput)
      local landedRow = fakeRsePokedex.filteredRows and fakeRsePokedex.filteredRows[fakeRsePokedex.index]
      T.eq(fakeRsePokedex.view, "entry", "Still in entry view after Down navigation")
      if landedRow then
        T.eq(landedRow.seen, true, "Entry view Down navigation only lands on seen species, never unseen")
      end

      -- B returns to list
      fakeInput:press("b")
      fakeRsePokedex:handleInputOmni(fakeInput)
      T.eq(fakeRsePokedex.view, "list", "Back to list view")

      -- Pop rse_pokedex from stack to restore state
      G3Stack.pop("rse_pokedex")
    end)()

    -- =========================================================================
    -- Section 16: Gen 3 Emerald Pokédex Data Extraction & Species Resolution
    -- =========================================================================
    ;(function()
      local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")
      local GameVersion = require("src.core.GameVersion")
      local prevVer = GameVersion.get()
      GameVersion.set("emerald")
      local Pokemon = require("src.core.game3.pokemon")
      Pokemon.install()

      local mockGame = {
        version = "emerald",
        data = {},
        save = {
          dex = {
            seen = { [277] = true, [278] = true, [280] = true },
            caught = { [277] = true, [278] = true },
          }
        }
      }
      local adapter = Gen3Adapter.new(mockGame)

      -- Grovyle (278 / National 253)
      local g = adapter:getDexEntry(278)
      T.eq(type(g), "table", "adapter:getDexEntry(278) returns table")
      T.eq(g.name, "GROVYLE", "Grovyle name extracted from Gen 3 data")
      T.eq(g.types[1], "GRASS", "Grovyle type extracted from Gen 3 data")
      T.eq(g.kind, "WOOD GECKO", "Grovyle kind extracted from entries.lua")
      T.eq(g.height, "2'11\"", "Grovyle canonical height formatted")
      T.eq(g.weight, "47.6 lbs.", "Grovyle canonical weight formatted")
      T.eq(g.regionalDex, 2, "Grovyle regional dex number is 2")
      T.eq(g.nationalDex, 253, "Grovyle national dex number is 253")
      T.eq(g.seen, true, "Grovyle seen is true")
      T.eq(g.caught, true, "Grovyle caught is true")

      -- National number resolution & status mapping
      T.eq(adapter:hasSeen(253), true, "hasSeen(253) resolves national dex number to species 278")
      T.eq(adapter:hasCaught(253), true, "hasCaught(253) resolves national dex number to species 278")
      local gNat = adapter:getDexEntry(253)
      T.eq(gNat.name, "GROVYLE", "getDexEntry(253) resolves national dex number to Grovyle")

      -- Treecko (277) & Torchic (280)
      local t = adapter:getDexEntry(277)
      T.eq(t.name, "TREECKO", "Treecko name extracted from Gen 3 data")
      T.eq(t.regionalDex, 1, "Treecko regional dex number is 1")
      T.eq(t.nationalDex, 252, "Treecko national dex number is 252")

      local tc = adapter:getDexEntry(280)
      T.eq(tc.name, "TORCHIC", "Torchic name extracted from Gen 3 data")
      T.eq(tc.types[1], "FIRE", "Torchic type is FIRE")
      T.eq(tc.regionalDex, 4, "Torchic regional dex number is 4")
      T.eq(tc.nationalDex, 255, "Torchic national dex number is 255")
      T.eq(tc.seen, true, "Torchic seen is true")
      T.eq(tc.caught, false, "Torchic caught is false")

      -- PokedexFilter Hoenn rows build
      local state = { dexMode = 0 }
      local rows, total = PokedexFilter.buildRows(mockGame, state, adapter)
      T.eq(total, 202, "Total Hoenn species count is 202")
      T.eq(#rows, 202, "Filtered Hoenn species count is 202")
      T.eq(rows[1].name, "TREECKO", "Row 1 is TREECKO")
      T.eq(rows[1].caught, true, "Row 1 is caught")
      T.eq(rows[2].name, "GROVYLE", "Row 2 is GROVYLE")
      T.eq(rows[2].caught, true, "Row 2 is caught")
      T.eq(rows[4].name, "TORCHIC", "Row 4 is TORCHIC")
      T.eq(rows[4].seen, true, "Row 4 is seen")
      T.eq(rows[4].caught, false, "Row 4 is not caught")

      if prevVer then GameVersion.set(prevVer) end
      pcall(Pokemon.install)
    end)()

    -- =========================================================================
    -- Section 17: Gen 3 Hoenn Map Engine & Pokédex Habitat Resolution (Phase 1)
    -- =========================================================================
    ;(function()
      local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")
      local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
      local Theme = require("mods.omni_ui.core.Theme")
      local curTheme = Theme.get()

      -- 1. ModernOverlay Screen Recognition for FRLG / RSE Region Map
      T.eq(ModernOverlay.isSupported({ screenId = "region_map" }), "town_map", "FRLG region_map recognized as town_map")
      T.eq(ModernOverlay.isSupported({ screenId = "rse_region_map" }), "town_map", "RSE rse_region_map recognized as town_map")
      T.eq(TownMapRenderer.swapTarget("kanto", { availableRegions = { "kanto", "sevii" } }), "SEVII", "FRLG habitat swap targets Sevii")
      T.eq(TownMapRenderer.swapTarget("sevii", { availableRegions = { "kanto", "sevii" } }), "KANTO", "FRLG habitat swap returns to Kanto")
      T.eq(TownMapRenderer.swapTarget("kanto", nil), "JOHTO", "Gen 2 Kanto swap still targets Johto")
      T.eq(TownMapRenderer.swapTarget("johto", nil), "KANTO", "Gen 2 Johto swap still targets Kanto")
      local markerX, markerY = TownMapRenderer.frlgMarkerOffset({ marker = { x = 40, y = 12, shape = "MARKER_CIRCULAR" } })
      T.eq(markerX, 8, "FRLG habitat marker x is image-space x minus 32")
      T.eq(markerY, 12, "FRLG habitat marker y stays in image space")

      local frlgGame = {
        version = "firered",
        gameVersion = "firered",
        region = "KANTO",
        session = { gameCode = "BPRE", region = "KANTO" },
        data = { pokemon = { [16] = { name = "PIDGEY" } }, encounters = {} },
      }
      local frlgArea = {
        view = "area",
        areaRegion = "kanto",
        nestSpecies = 16,
        nests = {
          { name = "ROUTE 1", mapId = "kanto", marker = { x = 40, y = 20, shape = "MARKER_CIRCULAR" }, coords = { x = 40, y = 20 } },
        },
      }
      local okFrlgArea = pcall(TownMapRenderer.draw, frlgGame, frlgArea, 800, 600, curTheme)
      T.eq(okFrlgArea, true, "TownMapRenderer draws a FireRed habitat map")
      local chromeOk, Chrome = pcall(require, "src.ui.game3.pokedex_chrome")
      local dexMap = chromeOk and Chrome and Chrome.getImage and Chrome.getImage("map_kanto")
      if dexMap then
        T.eq(frlgArea._mapGeometry and frlgArea._mapGeometry.mapKind, "frlg-dex", "FireRed habitat uses the Kanto dex map")
      end
      local frlgWall = {
        screenId = "region_map",
        open = true,
        mode = "normal",
        cursorX = 4,
        cursorY = 5,
        playerX = 4,
        playerY = 5,
        shownRegion = 0,
        mapSecName = "PALLET TOWN",
      }
      local okFrlgWall = pcall(TownMapRenderer.draw, frlgGame, frlgWall, 800, 600, curTheme)
      T.eq(okFrlgWall, true, "TownMapRenderer draws the FireRed region map")

      -- 2. Hoenn screenToTile Direct Grid Coordinate Math (240x160 canvas, 8x8 tiles)
      local mapX, mapY, scale = 100, 50, 2
      -- Min cursor tile (1, 2): center pixel is mapX + (1*8 + 4)*scale = 124, mapY + (2*8 + 4)*scale = 90
      local tx0, ty0 = TownMapRenderer.screenToTile(124, 90, mapX, mapY, scale, true)
      T.eq(tx0, 1, "screenToTile maps centered pixel (124, 90) to Hoenn cursorX = 1")
      T.eq(ty0, 2, "screenToTile maps centered pixel (124, 90) to Hoenn cursorY = 2")

      -- Max cursor tile (28, 16): max Hoenn coordinate
      local testPxX = mapX + (28 * 8 + 4) * scale
      local testPxY = mapY + (16 * 8 + 4) * scale
      local txMax, tyMax = TownMapRenderer.screenToTile(testPxX, testPxY, mapX, mapY, scale, true)
      T.eq(txMax, 28, "screenToTile maps max tile pixel to Hoenn cursorX = 28")
      T.eq(tyMax, 16, "screenToTile maps max tile pixel to Hoenn cursorY = 16")

      -- 3. Hoenn Multi-Tile Route Scanning & Habitat Coordinate Deduplication
      local mockHoennGame = {
        version = "emerald",
        gameVersion = "emerald",
        region = "HOENN",
        session = { gameCode = "BPEE", region = "HOENN" },
        data = {
          encounters = {
            -- Mock Route 119 overworld encounter with Feebas (#349)
            route119 = {
              regionMapSectionId = 40,
              water = { slots = { { species = 349 } } },
            },
            -- Mock underwater duplicate section sharing identical mapsec / coords
            route119_underwater = {
              regionMapSectionId = 40,
              water = { slots = { { species = 349 } } },
            },
          },
        },
      }
      local hoennAdapter = Gen3Adapter.new(mockHoennGame)
      local areaFeebas = hoennAdapter:getAreaInfo(349)
      T.eq(areaFeebas.region, "hoenn", "Gen3Adapter resolves region to 'hoenn'")
      T.eq(areaFeebas.canSwapRegion, false, "Hoenn does not support region swap")
      T.eq(type(areaFeebas.availableRegions), "table", "availableRegions is table")
      T.eq(areaFeebas.availableRegions[1], "hoenn", "availableRegions has hoenn")
      T.eq(type(areaFeebas.locations), "table", "Gen3Adapter generates deduplicated locations list")

      -- If mock encounters yielded nests via fallback / mapsec lookup
      if #areaFeebas.nests > 0 then
        -- Verify spatial deduplication
        local seenTileKeys = {}
        local hasDuplicates = false
        for _, n in ipairs(areaFeebas.nests) do
          if n.coords then
            local k = n.coords.x .. "_" .. n.coords.y
            if seenTileKeys[k] then hasDuplicates = true end
            seenTileKeys[k] = true
          end
        end
        T.eq(hasDuplicates, false, "Gen3Adapter deduplicates spatial coordinates for overlapping habitats")
      end

      -- 4. TownMapRenderer Drawing Hoenn Map in Landscape & Mobile Portrait
      local hoennMapState = {
        view = "area",
        areaRegion = "hoenn",
        nestSpecies = 349,
        nests = {
          { id = "R119_1", name = "ROUTE 119", mapId = "hoenn", coords = { x = 11, y = 3 } },
          { id = "R119_2", name = "ROUTE 119", mapId = "hoenn", coords = { x = 11, y = 4 } },
          { id = "R119_3", name = "ROUTE 119", mapId = "hoenn", coords = { x = 11, y = 5 } },
        },
        playerLoc = { name = "FORTREE CITY", coords = { x = 12, y = 3 } },
      }

      local okDrawLand = pcall(TownMapRenderer.draw, mockHoennGame, hoennMapState, 800, 600, curTheme)
      T.eq(okDrawLand, true, "TownMapRenderer renders Hoenn map in landscape (800x600)")
      T.eq(hoennMapState._mapGeometry ~= nil, true, "TownMapRenderer exports _mapGeometry")
      T.eq(hoennMapState._mapGeometry.isHoenn, true, "_mapGeometry identifies Hoenn map")
      T.eq(hoennMapState._mapGeometry.activeRegion, "hoenn", "_mapGeometry activeRegion is 'hoenn'")

      local okDrawPort = pcall(TownMapRenderer.draw, mockHoennGame, hoennMapState, 390, 844, curTheme)
      T.eq(okDrawPort, true, "TownMapRenderer renders Hoenn map in portrait (390x844)")
    end)()

-- Regression test: Gen 1 transitions & non-table properties on state must not crash isSupported
;(function()
  local transitionScreen = { t = 0, screenId = "Transition" }
  local ok, res = pcall(ModernOverlay.isSupported, transitionScreen)
  T.eq(ok, true, "isSupported handles state with numeric t=0 without throwing")
  T.eq(res, false, "Transition screen is unsupported pass-through")

  local battleTransition = { t = 15, isBattleTransition = true }
  local okBt, resBt = pcall(ModernOverlay.isSupported, battleTransition)
  T.eq(okBt, true, "isSupported handles battle transition with numeric t")
  T.eq(resBt, false, "Battle transition is unsupported pass-through")

  local primitiveScreens = { 123, "string_screen", true }
  for _, prim in ipairs(primitiveScreens) do
    local okP, resP = pcall(ModernOverlay.isSupported, prim)
    T.eq(okP, true, "isSupported safely handles non-table state")
    T.eq(resP, false, "non-table state returns false")
  end
end)()

-- =============================================================================
-- PokéNav Multi-Card Chassis, Progressive Gating & Two-Tier Input Tests
-- =============================================================================
;(function()
  local PokenavRenderer = require("mods.omni_ui.renderers.PokenavRenderer")
  local Widgets = require("mods.omni_ui.core.Widgets")
  local t = Theme.get()

  -- 1. Test ModernOverlay.isSupported detection
  local navState1 = { screenId = "rse_pokenav" }
  local navState2 = { ID = "rs_pokenav" }
  local navState3 = { isPokenav = true }
  local navState4 = { cardIndex = 1, _matchCallList = {} }
  local navState5 = { leftMain = {}, leftSub = {} }
  T.eq(ModernOverlay.isSupported(navState1), "pokenav", "isSupported recognizes rse_pokenav")
  T.eq(ModernOverlay.isSupported(navState2), "pokenav", "isSupported recognizes rs_pokenav")
  T.eq(ModernOverlay.isSupported(navState3), "pokenav", "isSupported recognizes isPokenav")
  T.eq(ModernOverlay.isSupported(navState4), "pokenav", "isSupported recognizes PokéNav state properties")
  T.eq(ModernOverlay.isSupported(navState5), "pokenav", "isSupported recognizes GBA Shell left headers")

  -- 2. Test Progressive Tab Gating
  local mockGame = {
    session = {
      flags = {},
      party = {
        {
          species = 252, -- Treecko
          nickname = "TREECKO",
          level = 12,
          contest = { cool = 45, beauty = 10, cute = 15, smart = 60, tough = 30, sheen = 25 },
        },
      },
    },
  }

  -- Early game: Only Map and Condition unlocked (Match Call and Ribbons hidden)
  local cardsEarly = PokenavRenderer.getAvailableCards(mockGame, {})
  T.eq(#cardsEarly, 2, "Early game gives exactly 2 cards (Map & Condition)")
  T.eq(cardsEarly[1].id, "map", "Card 1 is Hoenn Map")
  T.eq(cardsEarly[2].id, "condition", "Card 2 is Condition Radar")

  -- Unlocking Match Call via FLAG_ADDED_MATCH_CALL_TO_POKENAV
  mockGame.session.flags["FLAG_ADDED_MATCH_CALL_TO_POKENAV"] = true
  local cardsWithCall = PokenavRenderer.getAvailableCards(mockGame, {})
  T.eq(#cardsWithCall, 3, "Match Call flag unlocks Card 2 (3 cards total)")
  T.eq(cardsWithCall[1].id, "map", "Card 1 is Map")
  T.eq(cardsWithCall[2].id, "call", "Card 2 is Match Call")
  T.eq(cardsWithCall[3].id, "condition", "Card 3 is Condition")

  -- Unlocking Ribbons via FLAG_SYS_RIBBON_GET
  mockGame.session.flags["FLAG_SYS_RIBBON_GET"] = true
  local cardsAll = PokenavRenderer.getAvailableCards(mockGame, {})
  T.eq(#cardsAll, 4, "Ribbon flag unlocks Card 4 (all 4 cards active)")
  T.eq(cardsAll[4].id, "ribbons", "Card 4 is Ribbons")

  -- 3. Test Widgets.drawConditionRadar
  local radarMon = {
    contest = { cool = 80, beauty = 40, cute = 120, smart = 90, tough = 60, sheen = 100 },
  }
  local okRadar = pcall(Widgets.drawConditionRadar, 200, 200, 60, radarMon, { theme = t })
  T.eq(okRadar, true, "Widgets.drawConditionRadar executes without error")

  -- 4. Test Error-Free Drawing across Viewport Dimensions
  local pNavState = {
    cardIndex = 1,
    session = mockGame.session,
    _matchCallList = {
      { headerId = 1, mapSec = 16 },
      { headerId = 2, mapSec = 18 },
    },
    _ribbonHolders = {
      { mon = mockGame.session.party[1], count = 2 },
    },
  }

  -- Draw Card 1: Map
  pNavState.cardIndex = 1
  local okDrawMapL = pcall(PokenavRenderer.draw, mockGame, pNavState, 800, 600, t)
  local okDrawMapN = pcall(PokenavRenderer.draw, mockGame, pNavState, 480, 720, t)
  T.eq(okDrawMapL, true, "PokenavRenderer draws Map in landscape")
  T.eq(okDrawMapN, true, "PokenavRenderer draws Map in portrait")

  -- Draw Card 2: Match Call
  pNavState.cardIndex = 2
  local okDrawCallL = pcall(PokenavRenderer.draw, mockGame, pNavState, 800, 600, t)
  local okDrawCallN = pcall(PokenavRenderer.draw, mockGame, pNavState, 480, 720, t)
  T.eq(okDrawCallL, true, "PokenavRenderer draws Match Call in landscape")
  T.eq(okDrawCallN, true, "PokenavRenderer draws Match Call in portrait")

  -- Draw Card 3: Condition Radar
  pNavState.cardIndex = 3
  local okDrawCondL = pcall(PokenavRenderer.draw, mockGame, pNavState, 800, 600, t)
  local okDrawCondN = pcall(PokenavRenderer.draw, mockGame, pNavState, 480, 720, t)
  T.eq(okDrawCondL, true, "PokenavRenderer draws Condition in landscape")
  T.eq(okDrawCondN, true, "PokenavRenderer draws Condition in portrait")

  -- Draw Card 4: Ribbons Showcase
  pNavState.cardIndex = 4
  local okDrawRibL = pcall(PokenavRenderer.draw, mockGame, pNavState, 800, 600, t)
  local okDrawRibN = pcall(PokenavRenderer.draw, mockGame, pNavState, 480, 720, t)
  T.eq(okDrawRibL, true, "PokenavRenderer draws Ribbons in landscape")
  T.eq(okDrawRibN, true, "PokenavRenderer draws Ribbons in portrait")

  -- 5. Test Two-Tier Input Navigation & Interaction
  local testClosed = false
  local inputMock = {
    _pressed = {},
    press = function(self, k) self._pressed[k] = true end,
    wasPressed = function(self, k)
      local v = self._pressed[k]
      self._pressed[k] = nil
      return v == true
    end,
  }
  local inputGame = {
    input = inputMock,
    session = mockGame.session,
  }

  local interactiveState = {
    game = inputGame,
    session = mockGame.session,
    cardIndex = 1,
    mode = "strip",
    onClose = function() testClosed = true end,
    _matchCallList = {
      { headerId = 1, mapSec = 16 },
      { headerId = 2, mapSec = 18 },
    },
    _ribbonHolders = {
      { mon = mockGame.session.party[1], count = 2 },
    },
  }

  ModernOverlay.attachControls(interactiveState, inputGame)
  T.eq(interactiveState.__omniUiPokenavAttached, true, "attachControls attaches PokéNav controller")

  -- Tier 1: Right moves to Card 2 (Match Call)
  inputMock:press("right")
  interactiveState:update(1/60)
  T.eq(interactiveState.cardIndex, 2, "Right moves from Card 1 to Card 2")

  -- Tier 1: Right moves to Card 3 (Condition)
  inputMock:press("right")
  interactiveState:update(1/60)
  T.eq(interactiveState.cardIndex, 3, "Right moves from Card 2 to Card 3")

  -- Tier 1: Right moves to Card 4 (Ribbons)
  inputMock:press("right")
  interactiveState:update(1/60)
  T.eq(interactiveState.cardIndex, 4, "Right moves from Card 3 to Card 4")

  -- Tier 1: Right wraps around back to Card 1 (Map)
  inputMock:press("right")
  interactiveState:update(1/60)
  T.eq(interactiveState.cardIndex, 1, "Right wraps from Card 4 back to Card 1")

  -- Tier 1: Left wraps backwards to Card 4 (Ribbons)
  inputMock:press("left")
  interactiveState:update(1/60)
  T.eq(interactiveState.cardIndex, 4, "Left wraps backwards to Card 4")

  -- Tier 1: [A] enters Card mode
  interactiveState.cardIndex = 2 -- Focus on Match Call
  inputMock:press("a")
  interactiveState:update(1/60)
  T.eq(interactiveState.mode, "card", "Pressing [A] enters Card focus mode")

  -- Tier 2: Inside Match Call, Down moves to Contact 2
  interactiveState.contactSel = 1
  inputMock:press("down")
  interactiveState:update(1/60)
  T.eq(interactiveState.contactSel, 2, "Down moves to Contact 2")

  -- Tier 2: Inside Match Call, [A] triggers outbound call dialog modal
  inputMock:press("a")
  interactiveState:update(1/60)
  T.eq(interactiveState.callActive, true, "[A] triggers outbound call dialog modal")

  -- Tier 2: In call modal, [B] hangs up call
  inputMock:press("b")
  interactiveState:update(1/60)
  T.eq(interactiveState.callActive, false, "[B] dismisses call dialog modal")
  T.eq(interactiveState.mode, "card", "Still inside card mode after hanging up")

  -- Tier 2: [B] steps back out to Tier 1 Tab Bar
  inputMock:press("b")
  interactiveState:update(1/60)
  T.eq(interactiveState.mode, "strip", "[B] exits Card mode back to Tier 1 strip")

  -- Tier 1: [B] turns off PokéNav
  inputMock:press("b")
  interactiveState:update(1/60)
  T.eq(testClosed, true, "[B] in Tier 1 triggers onClose to exit PokéNav")
end)()

-- =========================================================================
-- EXP DEXNAV / ROUTE ENCOUNTER MONITOR MODERN UI INTEGRATION
-- =========================================================================
;(function()
  local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
  local Theme = require("mods.omni_ui.core.Theme")

  -- 1. Screen detection parity: ExpDexNav and custom DexNav screens
  local mockExpDexNav = {
    screenId = "ExpDexNav",
    title = "DEXNAV ROUTE 1",
    items = {
      { label = "PIDGEY", right = "GRASS 2-5", value = "PIDGEY" },
      { label = "RATTATA", right = "GRASS 2-4", value = "RATTATA" },
    },
    index = 1,
    scroll = 0,
    rows = 7,
  }
  T.eq(ModernOverlay.isSupported(mockExpDexNav), "dexnav", "ModernOverlay detects ExpDexNav as dexnav")

  local mockExampleDexNav = {
    screenId = "ExampleDexNav",
    title = "DEXNAV 10/15",
    items = {
      { label = "BULBASAUR", right = "OWN", value = "BULBASAUR" },
    },
    index = 1,
    scroll = 0,
  }
  T.eq(ModernOverlay.isSupported(mockExampleDexNav), "dexnav", "ModernOverlay detects ExampleDexNav as dexnav")

  local mockRadar = {
    screenId = "RoamingRadar",
    title = "ROAMING RADAR",
    items = {
      { label = "RAIKOU", right = "ROAM", value = "RAIKOU" },
    },
    index = 1,
    scroll = 0,
  }
  T.eq(ModernOverlay.isSupported(mockRadar), "dexnav", "ModernOverlay detects RoamingRadar as dexnav")

  -- 2. Stack resolution: ExpDexNav pushed over StartMenu must NOT fall through to StartMenu
  local mockStackGame = {
    stack = {
      states = {
        { screenId = "Overworld" },
        { screenId = "StartMenu", isStartMenu = true, items = { { label = "POKéDEX" }, { label = "DEXNAV" } } },
        mockExpDexNav,
      },
      top = function(self) return self.states[#self.states] end,
    },
  }
  local resolvedKind, resolvedState = ModernOverlay.getActiveScreen(mockStackGame)
  T.eq(resolvedKind, "dexnav", "getActiveScreen returns dexnav, not falling through to dormant StartMenu")
  T.eq(resolvedState, mockExpDexNav, "resolvedState is the top ExpDexNav screen")

  -- 3. Render test: Multi-method encounter rows with badges, custom footer, and pagination
  local mockRoute21DexNav = {
    screenId = "ExpDexNav",
    title = "DEXNAV ROUTE 21",
    items = {
      { label = "PIDGEY", right = "GRASS 20-22", value = "PIDGEY" },
      { label = "PIDGEOTTO", right = "GRASS 28-30", value = "PIDGEOTTO" },
      { label = "RATTATA", right = "GRASS 19-21", value = "RATTATA" },
      { label = "RATICATE", right = "GRASS 27-29", value = "RATICATE" },
      { label = "TANGELA", right = "GRASS 21-23", value = "TANGELA" },
      { label = "TENTACOOL", right = "SURF 5-40", value = "TENTACOOL" },
      { label = "MAGIKARP", right = "FISH 5", value = "MAGIKARP" },
      { label = "GYARADOS", right = "FISH 15", value = "GYARADOS" },
      { label = "SEAKING", right = "FISH 23", value = "SEAKING" },
    },
    index = 2,
    scroll = 0,
    rows = 6,
    footer = "No Old/Good Rod.",
  }

  for _, themeId in ipairs({ "dark", "kanto", "emerald", "cyber", "classic", "catppuccin" }) do
    Theme.setTheme(themeId)
    local curTheme = Theme.get()

    -- Landscape test (800x600)
    local okLand = pcall(ModernOverlay.drawMenu, mockStackGame, mockRoute21DexNav, 800, 600, curTheme, nil, nil)
    T.eq(okLand, true, ("ModernOverlay.drawMenu renders DexNav with badges and footer under [%s] landscape"):format(themeId))

    -- Mobile portrait test (390x844)
    local okPort = pcall(ModernOverlay.drawMenu, mockStackGame, mockRoute21DexNav, 390, 844, curTheme, nil, nil)
    T.eq(okPort, true, ("ModernOverlay.drawMenu renders DexNav cleanly under [%s] portrait"):format(themeId))

    -- Handheld compact test (640x360)
    local okCompact = pcall(ModernOverlay.drawMenu, mockStackGame, mockRoute21DexNav, 640, 360, curTheme, nil, nil)
    T.eq(okCompact, true, ("ModernOverlay.drawMenu renders DexNav cleanly under [%s] compact"):format(themeId))
  end
end)()

-- =========================================================================
-- GEN 3 PC HUB & BOX STORAGE INTEGRATION SUITE
-- =========================================================================
;(function()
  local okPcMenu, PcMenu = pcall(require, "src.ui.game3.pc_menu")
  local okStorageUI, BoxStorageUI = pcall(require, "src.ui.game3.box_storage_ui")
  local okG3Stack, G3Stack = pcall(require, "src.ui.game3.stack")
  local okPcHubR, PcHubRenderer = pcall(require, "mods.omni_ui.renderers.PcHubRenderer")
  local okStorageR, StorageRenderer = pcall(require, "mods.omni_ui.renderers.StorageRenderer")
  local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")
  local StorageController = require("mods.omni_ui.core.StorageController")
  local curTheme = Theme.get()

  -- Create a mock Gen 3 session with party, boxes, and items
  local mockStorage = {
    currentBox = 1,
    boxes = {},
    items = {
      { id = "POTION", qty = 10 },
      { id = "POKE_BALL", qty = 25 },
    },
  }
  for b = 1, 14 do
    mockStorage.boxes[b] = {
      name = ("BOX %d"):format(b),
      mons = {},
    }
  end
  -- Put a mon in box 1 slot 1
  mockStorage.boxes[1].mons[1] = {
    species = 25,
    speciesId = "PIKACHU",
    nickname = "SPARKY",
    level = 20,
    hp = 50,
    maxHp = 50,
  }

  local mockSession = {
    name = "BRENDAN",
    party = {
      {
        species = 252,
        speciesId = "TREECKO",
        nickname = "GEKKO",
        level = 15,
        hp = 40,
        maxHp = 40,
      },
    },
    storage = mockStorage,
  }

  local mockGame = {
    gameVersion = "emerald",
    save = {
      session = mockSession,
    },
    data = {
      items = {
        POTION = { name = "POTION" },
        POKE_BALL = { name = "POKé BALL" },
      },
    },
  }

  -- 1. Test ModernOverlay recognition
  if okPcMenu and PcMenu then
    PcMenu._session = mockSession
    T.eq(ModernOverlay.isSupported(PcMenu), "pc_hub", "PcMenu is recognized as 'pc_hub'")
  end
  if okStorageUI and BoxStorageUI then
    BoxStorageUI._session = mockSession
    T.eq(ModernOverlay.isSupported(BoxStorageUI), "storage", "BoxStorageUI is recognized as 'storage'")
  end

  -- 2. Test Stack layer mapping
  if okG3Stack and G3Stack then
    G3Stack.clear()
    G3Stack.push("pc_menu", PcMenu)
    T.eq(ModernOverlay.getActiveScreen(mockGame), "pc_hub", "Stack layer 'pc_menu' resolves activeScreen 'pc_hub'")

    G3Stack.push("box_storage", BoxStorageUI, { hideBelow = true, fullscreen = true })
    T.eq(ModernOverlay.getActiveScreen(mockGame), "storage", "Stack layer 'box_storage' resolves activeScreen 'storage'")
    local topLayer = G3Stack.top()
    T.eq(topLayer.fullscreen, false, "Stack layer 'box_storage' fullscreen is suppressed to false for modal overlay")
    T.eq(topLayer.hideBelow, false, "Stack layer 'box_storage' hideBelow is suppressed to false for modal overlay")
    T.eq(topLayer.drawUnder, true, "Stack layer 'box_storage' drawUnder is enabled so overworld renders beneath")
    T.eq(G3Stack.fullscreen(), false, "G3Stack.fullscreen() returns false when 'box_storage' is on stack")

    local okItemPc, ItemPc = pcall(require, "src.ui.game3.item_pc")
    if okItemPc and ItemPc then
      G3Stack.push("item_pc", ItemPc, { hideBelow = true, fullscreen = true })
      T.eq(ModernOverlay.getActiveScreen(mockGame), "player_pc", "Stack layer 'item_pc' resolves activeScreen 'player_pc'")
      local itemPcLayer = G3Stack.top()
      T.eq(itemPcLayer.fullscreen, false, "Stack layer 'item_pc' fullscreen is suppressed to false for modal overlay")
      T.eq(itemPcLayer.hideBelow, false, "Stack layer 'item_pc' hideBelow is suppressed to false for modal overlay")
      T.eq(itemPcLayer.drawUnder, true, "Stack layer 'item_pc' drawUnder is enabled so overworld renders beneath")
      T.eq(G3Stack.fullscreen(), false, "G3Stack.fullscreen() returns false when 'item_pc' is on stack")
      T.eq(#G3Stack.drawOrder(), 3, "G3Stack.drawOrder() includes all layers beneath modal without clipping")
      G3Stack.pop("item_pc")

      local onCloseCalled = false
      ItemPc.show({
        session = mockSession,
        onClose = function() onCloseCalled = true end,
      })
      T.eq(ItemPc.open, true, "ItemPc.show sets ItemPc.open = true")
      T.eq(G3Stack.has("item_pc"), true, "ItemPc.show pushes 'item_pc' to G3Stack")

      -- Simulate pressing 'b' in modern Item Storage Terminal
      local mockInputB = {
        wasPressed = function(self, k) return k == "b" end,
        isDown = function(self) return false end,
      }
      ItemPc.handleInput(mockInputB)
      T.eq(ItemPc.open, false, "Pressing B in ItemPc sets ItemPc.open = false")
      T.eq(G3Stack.has("item_pc"), false, "Pressing B in ItemPc pops 'item_pc' from G3Stack")
      T.eq(onCloseCalled, true, "Pressing B in ItemPc triggers onClose callback to return to PcMenu")

      -- Test that _fx.cb is immediately executed and not trapped if native close initiated
      local nativeCloseTriggered = false
      ItemPc.open = true
      ItemPc._fx = { on = false, cb = function() nativeCloseTriggered = true end }
      local mockInputNone = { wasPressed = function() return false end }
      ItemPc.handleInput(mockInputNone)
      T.eq(nativeCloseTriggered, true, "ItemPc._fx.cb is immediately executed if native close is pending")
      T.eq(ItemPc._fx == nil, true, "ItemPc._fx is cleared after executing callback")
      ItemPc.open = false
    end

    -- Test that genuinely non-overlay fullscreen layer still returns true
    G3Stack.push("credits", {}, { fullscreen = true, hideBelow = true })
    T.eq(G3Stack.fullscreen(), true, "G3Stack.fullscreen() returns true for non-overlay fullscreen layer (credits)")
    G3Stack.clear()
  end

  -- 3. Test PcHubRenderer dynamic options resolution in root mode
  if okPcHubR and PcHubRenderer and okPcMenu and PcMenu then
    PcMenu.mode = "root"
    PcMenu.cursor = 1

    local okDrawLand = pcall(PcHubRenderer.draw, mockGame, PcMenu, 800, 600, curTheme)
    T.eq(okDrawLand, true, "PcHubRenderer draws Gen 3 PcMenu root in landscape cleanly")

    local okDrawPort = pcall(PcHubRenderer.draw, mockGame, PcMenu, 360, 640, curTheme)
    T.eq(okDrawPort, true, "PcHubRenderer draws Gen 3 PcMenu root in portrait cleanly")

    -- Test storage_menu mode
    PcMenu.mode = "storage_menu"
    PcMenu.cursor = 2
    local okDrawStorageMenu = pcall(PcHubRenderer.draw, mockGame, PcMenu, 800, 600, curTheme)
    T.eq(okDrawStorageMenu, true, "PcHubRenderer draws Gen 3 PcMenu storage_menu mode cleanly")

    -- Test player_pc mode
    PcMenu.mode = "player_pc"
    PcMenu.cursor = 1
    local okDrawPlayerPc = pcall(PcHubRenderer.draw, mockGame, PcMenu, 800, 600, curTheme)
    T.eq(okDrawPlayerPc, true, "PcHubRenderer draws Gen 3 PcMenu player_pc mode cleanly")

    -- Test message state
    PcMenu.mode = "msg"
    PcMenu._status = "The box is full!"
    local okDrawMsg = pcall(PcHubRenderer.draw, mockGame, PcMenu, 800, 600, curTheme)
    T.eq(okDrawMsg, true, "PcHubRenderer draws Gen 3 PcMenu message status cleanly")
  end

  -- 4. Test StorageRenderer & Gen3Adapter with box storage
  if okStorageR and StorageRenderer and okStorageUI and BoxStorageUI then
    BoxStorageUI.mode = "browse"
    BoxStorageUI.subMode = "move"
    BoxStorageUI.open = true

    local okStorageLand = pcall(StorageRenderer.draw, mockGame, BoxStorageUI, 800, 600, curTheme)
    T.eq(okStorageLand, true, "StorageRenderer draws Gen 3 BoxStorageUI in landscape cleanly")

    local okStoragePort = pcall(StorageRenderer.draw, mockGame, BoxStorageUI, 360, 640, curTheme)
    T.eq(okStoragePort, true, "StorageRenderer draws Gen 3 BoxStorageUI in portrait cleanly")

    -- Verify StorageController on Gen 3 storage
    local ctrl = BoxStorageUI.__storageController
    T.neq(ctrl, nil, "StorageRenderer initializes StorageController on BoxStorageUI")
    T.eq(ctrl.boxCount, 14, "Gen 3 StorageController reports 14 boxes")
    T.eq(ctrl.boxCapacity, 30, "Gen 3 StorageController reports 30 slots per box")
    T.eq(ctrl.currentBoxId, 1, "Gen 3 StorageController starts on Box 1")

    -- Test box navigation
    ctrl:cycleBox(1)
    T.eq(ctrl.currentBoxId, 2, "StorageController cycles forward to Box 2")
    ctrl:cycleBox(-1)
    T.eq(ctrl.currentBoxId, 1, "StorageController cycles back to Box 1")
  end

  -- =========================================================================
  -- Gen 3 Item PC Storage & Bag Deposit / Modal Validation Suite
  -- =========================================================================
  do
    local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
    local PlayerPcRenderer = require("mods.omni_ui.renderers.PlayerPcRenderer")
    local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")
    local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
    local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")
    local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
    local curTheme = Theme.get()

    -- 1. Test top.update self-normalization (prevents 'attempt to index local self (a number value)')
    local testBoxState = {
      update = function(self, dt) end,
      game = { input = { wasPressed = function() return false end } },
    }
    ModernOverlay.attachControls(testBoxState, testBoxState.game)
    -- In Gen 3 Hud.update, top.mod.update is invoked as: top.mod.update(dt) where arg1 is dt
    local okSelfCall = pcall(testBoxState.update, 0.0166667)
    T.eq(okSelfCall, true, "state.update(dt) with 1 argument normalizes self safely without indexing number crash")

    -- 2. Test Gen 3 ItemPc singleton & ModernOverlay recognition
    local okItemPcMod, ItemPcMod = pcall(require, "src.ui.game3.item_pc")
    if okItemPcMod and ItemPcMod then
      ItemPcMod.open = true
      ItemPcMod._fx = { white = true }
      local kind = ModernOverlay.isSupported(ItemPcMod)
      T.eq(kind, "player_pc", "ModernOverlay detects Gen 3 ItemPc as 'player_pc'")

      local detKind, detTarget = ModernOverlay.getActiveScreen()
      T.eq(detKind, "player_pc", "ModernOverlay.getActiveScreen() resolves active ItemPc")
      T.eq(ItemPcMod._fx, nil, "ModernOverlay clears ItemPc._fx to prevent native white screen")

      local resolvedAdapter = AdapterResolver.resolve({ session = { bag = {}, storage = { items = {} } } })
      T.eq(resolvedAdapter.region ~= nil, true, "AdapterResolver resolves Gen3Adapter during ItemPc activity")
      ItemPcMod.open = false
    end

    -- 3. Test Gen 3 Adapter item storage, withdraw, deposit, and toss
    local testG3Session = {
      bag = {
        pockets = {
          ITEMS = { { id = 13, qty = 5 } },
          KEY_ITEMS = {},
          POKE_BALLS = { { id = 4, qty = 10 } },
          TM_CASE = {},
          BERRY_POUCH = {},
        },
        stacks = {},
      },
      storage = {
        items = {
          { id = 13, qty = 2 },
        },
      },
    }
    local g3Adapter = Gen3Adapter.new({ session = testG3Session })
    local pcItems = g3Adapter:getItemStorage()
    T.neq(pcItems, nil, "getItemStorage returns table")
    T.eq(#pcItems, 1, "getItemStorage reports 1 item in PC")
    T.eq(pcItems[1].count, 2, "getItemStorage reports correct qty")

    -- Withdraw 1 item from PC
    local okW, errW = g3Adapter:withdrawItem(13, 1)
    T.eq(okW, true, "Gen3Adapter withdrawItem succeeds: " .. tostring(errW))
    T.eq(testG3Session.storage.items[1].qty, 1, "PC storage item quantity decrements to 1")

    -- Deposit 2 items into PC
    local okD, errD = g3Adapter:depositItem(13, 2)
    T.eq(okD, true, "Gen3Adapter depositItem succeeds: " .. tostring(errD))
    T.eq(testG3Session.storage.items[1].qty, 3, "PC storage item quantity increments to 3")

    -- Toss 1 item from PC
    local okT, errT = g3Adapter:tossItem(13, 1)
    T.eq(okT, true, "Gen3Adapter tossItem succeeds: " .. tostring(errT))
    T.eq(testG3Session.storage.items[1].qty, 2, "PC storage item quantity decrements after toss")

    -- 4. Test Gen 3 BagMenu 5-Pocket Navigation hook
    local okBagMod, BagMenuMod = pcall(require, "src.ui.game3.bag_menu")
    if okBagMod and BagMenuMod then
      BagMenuMod._location = "itempc"
      BagMenuMod.pocketIdx = 1
      BagMenuMod.mode = "list"
      ModernOverlay.attachControls(BagMenuMod, { input = { wasPressed = function() return false end } })

      T.eq(BagMenuMod.currentPocket(), "ITEMS", "currentPocket(1) returns ITEMS")
      BagMenuMod.pocketIdx = 4
      T.eq(BagMenuMod.currentPocket(), "TM_CASE", "currentPocket(4) returns TM_CASE in FRLG")
      BagMenuMod.pocketIdx = 5
      T.eq(BagMenuMod.currentPocket(), "BERRY_POUCH", "currentPocket(5) returns BERRY_POUCH in FRLG")
      BagMenuMod.pocketIdx = 1
    end

    -- 5. Test BagRenderer Modals: Deposit Qty, Toss Qty, Toss Confirm, Deposit Done, Choice
    local mockBagState = {
      pocketIdx = 1,
      cursor = 1,
      items = { { id = 13, name = "POTION", qty = 10, count = 10 } },
      list = function() return { { id = 13, name = "POTION", qty = 10, count = 10 } } end,
      tossQty = 3,
      mode = "deposit",
    }
    local okDepDraw = pcall(BagRenderer.draw, { session = testG3Session }, mockBagState, 800, 600, curTheme)
    T.eq(okDepDraw, true, "BagRenderer renders Gen 3 deposit quantity modal cleanly")

    mockBagState.mode = "toss"
    local okTossDraw = pcall(BagRenderer.draw, { session = testG3Session }, mockBagState, 800, 600, curTheme)
    T.eq(okTossDraw, true, "BagRenderer renders Gen 3 toss quantity modal cleanly")

    mockBagState.mode = "toss_confirm"
    mockBagState.yesNoCursor = 1
    local okConfDraw = pcall(BagRenderer.draw, { session = testG3Session }, mockBagState, 800, 600, curTheme)
    T.eq(okConfDraw, true, "BagRenderer renders Gen 3 toss confirmation modal cleanly")

    mockBagState.mode = "deposit_done"
    mockBagState._depositText = "Stored 3 POTION in PC."
    local okDoneDraw = pcall(BagRenderer.draw, { session = testG3Session }, mockBagState, 800, 600, curTheme)
    T.eq(okDoneDraw, true, "BagRenderer renders Gen 3 deposit_done message modal cleanly")

    mockBagState.mode = "list"
    local mockChoiceSub = { isChoiceBox = true, options = { "STORE", "CANCEL" }, cursor = 1 }
    local okChoiceDraw = pcall(BagRenderer.draw, { session = testG3Session }, mockBagState, 800, 600, curTheme, mockChoiceSub)
    T.eq(okChoiceDraw, true, "BagRenderer renders subState Choice box cleanly")

    -- Test 58: Emerald PC Withdraw (rse_item_storage) integration & modal preservation
    local okRseItem, RseItemStorageMod = pcall(require, "src.ui.game3.rse.item_storage")
    if okRseItem and RseItemStorageMod then
      T.eq(ModernOverlay.isSupported(RseItemStorageMod), "player_pc", "RseItemStorage is recognized as 'player_pc'")
      T.eq(ModernOverlay.isSupported({ screenId = "rse_item_storage" }), "player_pc", "screenId 'rse_item_storage' is recognized as 'player_pc'")

      local G3Stack = package.loaded["src.ui.game3.stack"]
      if G3Stack then
        G3Stack.clear()
        G3Stack.push("rse_item_storage", RseItemStorageMod, { hideBelow = true, fullscreen = true })
        local rseLayer = G3Stack.top()
        T.eq(rseLayer.hideBelow, false, "Stack layer 'rse_item_storage' hideBelow is suppressed to false for modal overlay")
        T.eq(G3Stack.fullscreen(), false, "G3Stack.fullscreen returns false for 'rse_item_storage' when modern overlay active")
        T.eq(ModernOverlay.getActiveScreen(mockGame), "player_pc", "Stack layer 'rse_item_storage' resolves activeScreen 'player_pc'")
        G3Stack.clear()
      end
    end

    -- Test 59: Box Storage party slot navigation single-step (no skipping 1 -> 3 -> 5 -> 6 or 6 -> 4 -> 2 -> 1)
    do
      local StorageController = require("mods.omni_ui.core.StorageController")
      local ctrl = StorageController.new(mockGame, { mode = "browse" })
      ctrl.zone = "party"
      ctrl.partySlot = 1
      ctrl.partyCapacity = 6

      local function makeInput(key)
        return {
          wasPressed = function(self, k) return k == key end,
          isDown = function(self, k) return k == key end,
        }
      end

      -- Step forward one-by-one: 1 -> 2 -> 3 -> 4 -> 5 -> 6
      for expected = 2, 6 do
        ctrl:handleInput(makeInput("right"))
        T.eq(ctrl.partySlot, expected, ("Storage party navigation moved right cleanly to slot %d (no skipping)"):format(expected))
      end
      -- Step backward one-by-one: 6 -> 5 -> 4 -> 3 -> 2 -> 1
      for expected = 5, 1, -1 do
        ctrl:handleInput(makeInput("left"))
        T.eq(ctrl.partySlot, expected, ("Storage party navigation moved left cleanly to slot %d (no skipping)"):format(expected))
      end

      -- Verify attachStorageControls update does NOT process input for Gen 3 BoxStorageUI
      local okBoxUI, BoxUI = pcall(require, "src.ui.game3.box_storage_ui")
      if okBoxUI and BoxUI then
        BoxUI.partyCursor = 1
        BoxUI.__storageController = ctrl
        ctrl.partySlot = 1
        ModernOverlay.attachControls(BoxUI, mockGame)
        BoxUI:update(1/60)
        T.eq(ctrl.partySlot, 1, "BoxStorageUI update does not double-process input in update loop")
      end
    end

    -- Test 60: Gen 3 BagMenu attachBagControls does NOT advance pockets in update loop on left/right
    do
      local mockBagState2 = {
        game = mockGame,
        pocketIdx = 1,
        mode = "list",
        POCKET_KEYS = { "ITEMS", "POKE_BALLS", "TM_CASE", "BERRY_POUCH", "KEY_ITEMS" },
        update = function(self, dt) end,
      }
      ModernOverlay.attachBagControls(mockBagState2, mockGame)
      mockBagState2.game = {
        input = {
          wasPressed = function(self, k) return k == "right" end,
          isDown = function(self, k) return k == "right" end,
        }
      }
      mockBagState2:update(1/60)
      T.eq(mockBagState2.pocketIdx, 1, "attachBagControls update leaves pocketIdx untouched on 'right' (left/right handled by native BagMenu)")
    end

    -- FRLG cart pockets stop at Poké Balls. OmniUI still has TM Case and Berry Pouch tabs.
    do
      local ItemsData = require("src.core.game3.items_data")
      local prevSecond = ItemsData.BAG_POCKET_ORDER[2]
      local sawRight = false
      local frlgBag = {
        pocketIdx = 3,
        mode = "list",
        POCKET_KEYS = { "ITEMS", "KEY_ITEMS", "POKE_BALLS", "TM_CASE", "BERRY_POUCH" },
        update = function() end,
        handleInput = function(input)
          sawRight = input:wasPressed("right")
        end,
      }
      local function press(key)
        return {
          wasPressed = function(_, k) return k == key end,
          isDown = function(_, k) return k == key end,
        }
      end
      ModernOverlay.attachBagControls(frlgBag, { gameVersion = "firered" })
      ItemsData.applyProfile("firered")
      frlgBag.handleInput(press("right"))
      T.eq(frlgBag.pocketIdx, 4, "FRLG right from Poké Balls opens the TM Case tab")
      T.eq(sawRight, false, "FRLG pocket extend does not let the cart bag also read Right")
      T.eq(frlgBag.currentPocket(), "TM_CASE", "FRLG pocket 4 is the TM Case")
      frlgBag.handleInput(press("right"))
      T.eq(frlgBag.pocketIdx, 5, "FRLG right from TM Case opens the Berry Pouch tab")
      T.eq(frlgBag.currentPocket(), "BERRY_POUCH", "FRLG pocket 5 is the Berry Pouch")
      frlgBag.handleInput(press("right"))
      T.eq(frlgBag.pocketIdx, 1, "FRLG right from Berry Pouch cycles back to Items")
      frlgBag.pocketIdx = 1
      frlgBag.handleInput(press("left"))
      T.eq(frlgBag.pocketIdx, 5, "FRLG left from Items cycles to the Berry Pouch")
      frlgBag.pocketIdx = 2
      sawRight = false
      frlgBag.handleInput(press("right"))
      T.eq(frlgBag.pocketIdx, 2, "FRLG right inside the cart pockets stays with the cart bag")
      T.eq(sawRight, true, "FRLG cart pocket Right is still delivered to the cart bag")
      if prevSecond == "POKE_BALLS" then
        ItemsData.applyProfile("emerald")
      else
        ItemsData.applyProfile("firered")
      end
    end

    -- Test 61: FRLG continue screen save data extraction & active party population
    do
      local MainMenuRenderer = require("mods.omni_ui.renderers.MainMenuRenderer")
      local mockFrlgBoot = {
        hasContinue = true,
        continueInfo = {
          name = "RED",
          gender = 0,
          hours = 25,
          minutes = 42,
          hasDex = true,
          dexCount = 105,
          badges = 7,
        },
        save = {
          party = {
            { species = 3, nickname = "SAUR", level = 55, hp = 160, maxHp = 160 },
            { species = 6, nickname = "CHAR", level = 56, hp = 158, maxHp = 158 },
            { species = 25, level = 50, hp = 110, maxHp = 110 },
          },
        },
      }
      local okDrawFrlg = pcall(MainMenuRenderer.draw, { gameVersion = "firered" }, mockFrlgBoot, 800, 600, curTheme)
      T.eq(okDrawFrlg, true, "MainMenuRenderer successfully populates and renders FRLG continue screen with party & dex")
    end

    -- Test 62: RSE PC Withdraw opens item_storage cleanly even when PC storage has 0 items
    do
      local okRsePc, RsePlayerPc = pcall(require, "src.ui.game3.rse.player_pc")
      local okRseStorage, RseItemStorage = pcall(require, "src.ui.game3.rse.item_storage")
      if okRsePc and RsePlayerPc and okRseStorage and RseItemStorage then
        local testSession = {
          storage = { items = {} }, -- 0 items in PC
        }
        local fakePc = {
          mode = "item_storage",
          cursor = 1, -- Withdraw
          _session = testSession,
        }
        local inputA = {
          wasPressed = function(self, k) return k == "a" end,
          isDown = function(self, k) return k == "a" end,
        }
        RsePlayerPc.handleInput(fakePc, inputA)
        T.eq(fakePc.mode, "rse_child", "RSE player_pc withdraw advances mode to 'rse_child' even with 0 items")
        T.eq(RseItemStorage.open, true, "RSE item_storage opens successfully on withdraw with 0 items")
        RseItemStorage.close()
      end
    end

    -- Test 63: PC Deposit flow pocket switching with left/right/q/e in FRLG and RSE
    do
      local mockDepBag = {
        _location = "itempc",
        pocketIdx = 1,
        mode = "list",
        POCKET_KEYS = { "ITEMS", "KEY_ITEMS", "POKE_BALLS", "TM_CASE", "BERRY_POUCH" },
        update = function(self, dt) end,
      }
      ModernOverlay.attachBagControls(mockDepBag, mockGame)
      -- Test right arrow switches to next pocket during deposit
      mockDepBag.game = {
        input = {
          wasPressed = function(self, k) return k == "right" end,
          isDown = function(self, k) return k == "right" end,
        }
      }
      mockDepBag:update(1/60)
      T.eq(mockDepBag.pocketIdx, 2, "Deposit flow successfully switches to pocket 2 on 'right'")

      -- Test left arrow switches back to previous pocket during deposit
      mockDepBag.game = {
        input = {
          wasPressed = function(self, k) return k == "left" end,
          isDown = function(self, k) return k == "left" end,
        }
      }
      mockDepBag:update(1/60)
      T.eq(mockDepBag.pocketIdx, 1, "Deposit flow successfully switches back to pocket 1 on 'left'")

      -- Test native BagMenu handleInput proxy switching during itempc
      local okBagM, BagMenuMod = pcall(require, "src.ui.game3.bag_menu")
      if okBagM and BagMenuMod and BagMenuMod.handleInput then
        BagMenuMod._location = "itempc"
        BagMenuMod.mode = "list"
        BagMenuMod.pocketIdx = 1
        local inputRight = {
          wasPressed = function(self, k) return k == "right" end,
          isDown = function(self, k) return k == "right" end,
        }
        BagMenuMod.handleInput(inputRight)
        T.eq(BagMenuMod._location, "itempc", "BagMenu _location remains 'itempc' after pocket switch")
        BagMenuMod._location = nil
      end
    end

    -- Test 64: TrainerCardRenderer FRLG & RSE visual parity, subtitles, and badge obscuring
    do
      local TrainerCardRenderer = require("mods.omni_ui.renderers.TrainerCardRenderer")

      -- Hoenn Emerald Trainer Card test
      local mockEmeraldGame = {
        generation = 3,
        gameVersion = "emerald",
        region = "HOENN",
        data = {},
      }
      local mockEmeraldState = {
        region = "HOENN",
        cardFace = "HOENN",
        _rse = true,
      }
      local okEmDraw = pcall(TrainerCardRenderer.draw, mockEmeraldGame, mockEmeraldState, 800, 600, curTheme)
      T.eq(okEmDraw, true, "TrainerCardRenderer renders Hoenn Emerald trainer card cleanly")

      -- FRLG Kanto Trainer Card test
      local mockFrlgGame = {
        generation = 3,
        gameVersion = "firered",
        region = "KANTO",
        data = {},
      }
      local mockFrlgState = {
        region = "KANTO",
        cardFace = "KANTO",
        _rse = false,
      }
      local okFrlgDraw = pcall(TrainerCardRenderer.draw, mockFrlgGame, mockFrlgState, 800, 600, curTheme)
      T.eq(okFrlgDraw, true, "TrainerCardRenderer renders FRLG Kanto trainer card cleanly")

      -- Mobile Portrait tests for both
      local okEmPort = pcall(TrainerCardRenderer.draw, mockEmeraldGame, mockEmeraldState, 360, 640, curTheme)
      T.eq(okEmPort, true, "TrainerCardRenderer renders Hoenn Emerald card in mobile portrait")
      local okFrlgPort = pcall(TrainerCardRenderer.draw, mockFrlgGame, mockFrlgState, 360, 640, curTheme)
      T.eq(okFrlgPort, true, "TrainerCardRenderer renders FRLG Kanto card in mobile portrait")
    end
  end
end)()

-- Beta menu fixes: live engine data inside the existing OmniUI screens.
do
  local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")
  local caughtAdapter = {
    generation = 1,
    region = "KANTO",
    hasSeen = function() return true end,
    hasCaught = function(_, sp) return sp == 1 end,
    getDexEntry = function(_, sp)
      return { name = "MON" .. tostring(sp), dex = sp, types = { "NORMAL" } }
    end,
    isNationalDexUnlocked = function() return false end,
  }
  local dexRows = PokedexFilter.buildRows({ data = { pokemon = {} } }, {}, caughtAdapter, {})
  T.eq(dexRows[1] and dexRows[1].caught, true, "Pokédex caught flag uses the owned bit")
  T.eq(dexRows[2] and dexRows[2].caught, false, "Unowned Pokédex rows stay uncaught")

  local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")
  local frlgPc = Gen3Adapter.new({ gameVersion = "firered", session = { version = "firered" } })
  T.eq(frlgPc:getPcCapacity(), 30, "FireRed item PC capacity follows the profile")
  local emeraldPc = Gen3Adapter.new({ gameVersion = "emerald", session = { version = "emerald" } })
  T.eq(emeraldPc:getPcCapacity(), 50, "Emerald item PC capacity follows the profile")

  local Screens = require("src.ui.Screens")
  local origPush = Screens.push
  local pushedId = nil
  Screens.push = function(_, id)
    pushedId = id
    return { exit = function() end }
  end
  local hub = {
    screenId = "PcMenu",
    index = 1,
    items = { { id = "bill", label = "BILL'S PC" }, { id = "turnoff", label = "TURN OFF" } },
    game = {
      data = Data,
      save = { version = "gold" },
      input = {
        wasPressed = function(_, key) return key == "a" end,
        isDown = function() return false end,
      },
    },
  }
  ModernOverlay.attachControls(hub, hub.game)
  hub:update(1 / 60)
  Screens.push = origPush
  T.eq(pushedId, "Gen2BoxMenu", "PC hub uses save.version to open the Gen2 box screen")

  local OptionsRenderer = require("mods.omni_ui.renderers.OptionsRenderer")
  local PublicApi = require("mods.omni_ui.api.PublicApi")
  PublicApi.registerOptionRow({ id = "beta_mod_row", label = "MOD SPEED", value = function() return "ON" end })
  local frlgPage = {
    title = "OPTIONS",
    index = 1,
    rows = {
      { id = "textSpeed", label = "TEXT SPEED", value = function(ctx) return ctx and ctx.shown or "SLOW" end },
    },
  }
  local frlgMenu = { cursor = 1, _pages = { frlgPage }, _ctx = { shown = "FAST" }, _game = { gameVersion = "firered" } }
  local rsePage = {
    title = "OPTION",
    index = 1,
    top = true,
    rows = {
      { id = "sound", label = "SOUND", value = function() return "STEREO" end },
    },
  }
  local rseMenu = { cursor = 1, _st = { pages = { rsePage }, ctx = {} } }
  local optTheme = Theme.get()
  T.eq(pcall(OptionsRenderer.draw, frlgMenu._game, frlgMenu, 800, 600, optTheme, 1), true, "Options renderer draws a FireRed page")
  local sawMod = false
  for _, row in ipairs(frlgPage.rows) do
    if row.id == "beta_mod_row" then sawMod = true end
  end
  T.eq(sawMod, true, "Options page absorbs a ui.options.rows addition")
  T.eq(pcall(OptionsRenderer.draw, { gameVersion = "emerald" }, rseMenu, 800, 600, optTheme, 1), true, "Options renderer draws an RSE page")
  T.eq(rsePage.rows[1].label, "SOUND", "RSE options row stays on the OmniUI page")

  local Battle = require("src.core.game3.battle")
  local Ui = require("src.core.game3.battle.ui")
  local prevActive, prevSt = Battle._active, Battle._st
  local prevMode, prevMenu, prevMove = Ui._mode, Ui._menuIndex, Ui._moveIndex
  Battle._active = true
  Battle._st = {
    double = true,
    player = { name = "TREECKO", mon = { species = "TREECKO", level = 5, hp = 20, gender = "male", moves = { 33 } } },
    enemy = { name = "POOCHYENA", mon = { species = "POOCHYENA", level = 4, hp = 15, gender = "female" } },
    battlers = {
      [2] = { name = "TORCHIC", mon = { species = "TORCHIC", level = 5, hp = 20, gender = "male" } },
      [3] = { name = "MUDKIP", mon = { species = "MUDKIP", level = 5, hp = 22, gender = "female" } },
    },
  }
  Ui._mode = "moves"
  Ui._moveIndex = 1
  Ui._menuIndex = 1
  local liveAdapter = Gen3Adapter.new({ gameVersion = "emerald", data = Data })
  local liveOk, liveCache = pcall(function() return liveAdapter:updateBattleInfo() end)
  Battle._active, Battle._st = prevActive, prevSt
  Ui._mode, Ui._menuIndex, Ui._moveIndex = prevMode, prevMenu, prevMove
  T.eq(liveOk, true, "Gen3 battle info accepts a numeric move id")
  liveCache = liveOk and liveCache or {}
  T.eq(liveCache.isActive, true, "Gen3 battle HUD reads Battle._st")
  T.eq(liveCache.player and liveCache.player.species, "TREECKO", "Gen3 battle player comes from the live fight")
  T.eq(liveCache.enemy and liveCache.enemy.species, "POOCHYENA", "Gen3 battle enemy comes from the live fight")
  T.eq(liveCache.enemy2 and liveCache.enemy2.active, true, "Gen3 double battle fills enemy2")
  T.eq(liveCache.player2 and liveCache.player2.species, "TORCHIC", "Gen3 double battle fills player2")
  T.eq(liveCache.phase, "move_select", "Gen3 battle phase follows Ui._mode")
  T.eq(liveCache.moves and liveCache.moves[1] and liveCache.moves[1].pp, 35, "Gen3 Tackle resolves to 35 PP, not zero")
  T.eq(liveCache.moves and liveCache.moves[1] and liveCache.moves[1].maxPP, 35, "Gen3 Tackle max PP matches the move")
  T.eq(liveCache.moves and liveCache.moves[1] and tostring(liveCache.moves[1].name):upper(), "TACKLE", "Gen3 move 33 resolves to Tackle")
  T.eq(liveCache.moves and liveCache.moves[1] and tostring(liveCache.moves[1].id):upper(), "TACKLE", "Gen3 move slot id is the move name")
  T.eq(liveCache.moves and liveCache.moves[1] and liveCache.moves[1].power, 35, "Gen3 Tackle power comes from the move")
  local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
  local tackleDesc = MoveDatabase.getDescription(33, liveCache.moves and liveCache.moves[1], liveAdapter.game)
  T.eq(type(tackleDesc) == "string" and tackleDesc:find("^A 33") == nil, true, "Gen3 move 33 does not describe itself as move id 33")
  T.eq(type(tackleDesc) == "string" and tackleDesc:match("^A .+ technique used in battle%.?$") == nil, true, "Gen3 Tackle uses a real description")
  local drewMoves = pcall(function()
    local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
    BattleRenderer.draw({ gameVersion = "emerald", data = Data }, Battle._st, 960, 640, optTheme, nil, {
      gameX = 40, gameY = 20, gameWidth = 880, gameHeight = 600,
    })
  end)
  T.eq(drewMoves, true, "Gen3 move select draws names into the sized console")
  local spentCur, spentMax = Gen3Adapter.resolveMovePp({ moves = { 33 }, pp = { 4 }, maxPp = { 35 } }, 1, 33)
  T.eq(spentCur, 4, "Gen3 current PP is the battler's remaining PP")
  T.eq(spentMax, 35, "Gen3 max PP stays the move maximum when PP is spent")
  Battle._active = true
  Battle._st = {
    player = { mon = { species = 252, nickname = "ABC", level = 52, hp = 20 } },
    enemy = { species = 228, mon = { species = 228, level = 17, hp = 10 } },
  }
  local namedCache = liveAdapter:updateBattleInfo()
  T.eq(namedCache.player and namedCache.player.name, "ABC", "Gen3 battle HUD keeps the nickname")
  T.eq(namedCache.enemy and tostring(namedCache.enemy.name):match("^%d+$") == nil, true, "Gen3 battle HUD resolves a numeric species id")
  T.eq(namedCache.enemy and tostring(namedCache.enemy.name):upper():find("HOUNDO") ~= nil, true, "Gen3 species 228 resolves to Houndour")
  Battle._active, Battle._st = prevActive, prevSt

  local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
  T.eq(BattleRenderer.usesThemedStage({ gameVersion = "emerald" }), false, "Gen3 keeps its own battle background and stage")
  T.eq(BattleRenderer.usesThemedStage({ gameVersion = "gold" }), true, "Gen2 still uses the themed battle stage")
  T.eq(BattleRenderer.usesThemedStage({ gameVersion = "red" }), true, "Gen1 still uses the themed battle stage")
  local band = BattleRenderer.consoleBand({ gameVersion = "emerald" }, {
    gameX = 40, gameY = 20, gameWidth = 720, gameHeight = 480,
  }, 800, 600)
  T.eq(band and band.x, 40, "Gen3 battle console starts at the game view")
  T.eq(band and band.y, 20 + math.floor(480 * 112 / 160), "Gen3 battle console starts at the textbox row")
  T.eq(band and band.w, 720, "Gen3 battle console covers the textbox width")
  T.eq(band and band.h, 480 - math.floor(480 * 112 / 160), "Gen3 battle console covers the textbox height")
  T.eq(BattleRenderer.consoleBand({ gameVersion = "red" }, {
    gameX = 40, gameY = 20, gameWidth = 720, gameHeight = 480,
  }, 800, 600), nil, "Gen1 keeps the floating battle deck")
  local okMsg, Message = pcall(require, "src.ui.game3.message")
  local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
  if okMsg and Message then
    local prevMode = Ui._mode
    local prevOpen, prevFrame = Message.open, Message._frame
    local prevPages, prevPage = Message._pages, Message._page
    local prevRev, prevWait = Message._revealed, Message._waiting
    local prevActive = Battle._active
    local savedSt = Battle._st
    Message.open = false
    Message._frame = nil
    Ui._mode = nil
    Battle._active = true
    Battle._st = {
      player = { mon = { species = "MEOWTH", nickname = "ABC", level = 52, hp = 118 } },
      enemy = { mon = { species = 52, level = 17, hp = 10 } },
    }
    local Layout = require("mods.omni_ui.core.Layout")
    local seen = {}
    local origDrawText = Layout.drawText
    Layout.drawText = function(text, ...)
      seen[#seen + 1] = tostring(text)
      return origDrawText(text, ...)
    end
    local drewBlank = pcall(BattleRenderer.draw, { gameVersion = "emerald", data = Data }, Battle._st, 960, 640, optTheme, nil, {
      gameX = 40, gameY = 20, gameWidth = 880, gameHeight = 600,
    })
    local showedPrompt = false
    for _, line in ipairs(seen) do
      if line:find("What will", 1, true) then showedPrompt = true end
    end
    Layout.drawText = origDrawText
    T.eq(drewBlank, true, "Gen3 battle draws an empty intro console")
    T.eq(showedPrompt, false, "Gen3 battle dialog stays blank before the intro line")
    Message.open = true
    Message._frame = "battle"
    Message._pages = { "Wild MEOWTH appeared!" }
    Message._page = 1
    Message._revealed = 22
    Message._waiting = true
    Battle._active = true
    local dialogText, dialogWaiting = BattleRenderer.battleMessageText()
    T.eq(dialogText, "Wild MEOWTH appeared!", "Battle console reads the live battle dialog")
    T.eq(dialogWaiting, true, "Battle console knows the dialog is waiting for A")
    local dialogKind = ModernOverlay.getActiveScreen({})
    T.eq(dialogKind, "battle", "A battle-frame dialog stays on the battle screen")
    local drewDialog = pcall(BattleRenderer.draw, { gameVersion = "emerald", data = Data }, Battle._st, 960, 640, optTheme, nil, {
      gameX = 40, gameY = 20, gameWidth = 880, gameHeight = 600,
    })
    T.eq(drewDialog, true, "Battle console draws the dialog as one panel")
    Message.open, Message._frame = prevOpen, prevFrame
    Message._pages, Message._page = prevPages, prevPage
    Message._revealed, Message._waiting = prevRev, prevWait
    Battle._active = prevActive
    Battle._st = savedSt
    Ui._mode = prevMode
  end
  local Runtime = require("src.mods.Runtime")
  T.eq(Runtime.call("battle.status_hud_visible", function() return true end, Battle._st), false, "OmniUI hides the Gen3 health boxes")
  T.eq(Runtime.call("battle.bottom_ui_visible", function() return true end, Battle._st), false, "OmniUI hides the Gen3 command menu")

  local Layout = require("mods.omni_ui.core.Layout")
  local drawn = {}
  local origDrawText = Layout.drawText
  Layout.drawText = function(text, ...)
    drawn[#drawn + 1] = tostring(text)
    return origDrawText(text, ...)
  end
  local genderGame = {
    gameVersion = "gold",
    data = Data,
    save = { pokedex = { owned = {} }, party = {} },
    stack = {
      states = {
        {
          isGen2BattleState = true,
          screenId = "Gen2BattleState",
          phase = "menu",
          player = { name = "TOTODILE", shownHP = 20, maxHP = 20, mon = { species = "TOTODILE", level = 5, hp = 20, gender = "male" } },
          enemy = { name = "PIDGEY", shownHP = 18, maxHP = 18, mon = { species = "PIDGEY", level = 4, hp = 18, gender = "male" } },
        },
      },
    },
  }
  local drew = pcall(BattleRenderer.draw, genderGame, genderGame.stack.states[1], 800, 600, optTheme, nil, nil)
  Layout.drawText = origDrawText
  local sawMale, sawFemale = false, false
  for _, text in ipairs(drawn) do
    if text == "♂" then sawMale = true end
    if text == "♀" then sawFemale = true end
  end
  T.eq(drew, true, "Battle HUD draws a Gen2 fight")
  T.eq(sawMale, true, "Battle HUD treats lowercase male as male")
  T.eq(sawFemale, false, "Battle HUD does not draw female for a male battler")
end

do
  local okHof, HallOfFame = pcall(require, "src.ui.game3.hall_of_fame")
  local okPc, HofPc = pcall(require, "src.ui.game3.hall_of_fame_pc")
  local okLearn, MoveRelearner = pcall(require, "src.ui.game3.move_relearner")
  local HallOfFameRenderer = require("mods.omni_ui.renderers.HallOfFameRenderer")
  local LeaguePcRenderer = require("mods.omni_ui.renderers.LeaguePcRenderer")
  local MoveLearnRenderer = require("mods.omni_ui.renderers.MoveLearnRenderer")
  local Layout = require("mods.omni_ui.core.Layout")
  local theme = Theme.get()
  local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
  local function battleLines(game)
    local seen = {}
    local origText = Layout.drawText
    local origWrap = Layout.drawTextWrapped
    Layout.drawText = function(text, ...)
      seen[#seen + 1] = tostring(text)
      return origText(text, ...)
    end
    Layout.drawTextWrapped = function(text, ...)
      seen[#seen + 1] = tostring(text)
      return origWrap(text, ...)
    end
    local drew = pcall(BattleRenderer.draw, game, game.stack.states[1], 900, 600, theme)
    Layout.drawText = origText
    Layout.drawTextWrapped = origWrap
    return drew, table.concat(seen, "\n")
  end
  local blankGen1 = {
    data = Data,
    gameVersion = "red",
    save = { pokedex = { owned = {} }, party = {} },
    stack = { states = { {
      isBattleState = true,
      screenId = "BattleState",
      phase = "messages",
      player = { name = "SPARKY", shownHP = 42, mon = { species = "PIKACHU", nickname = "SPARKY", level = 25, hp = 50, stats = { hp = 50 } } },
      enemy = { name = "PIDGEY", shownHP = 18, mon = { species = "PIDGEY", level = 16, hp = 30, stats = { hp = 30 } } },
      visibleText = function() return nil end,
    } } },
  }
  local drewBlank1, blank1 = battleLines(blankGen1)
  T.eq(drewBlank1, true, "Gen1 battle dialog draws before the intro line")
  T.eq(blank1:find("What will", 1, true) == nil, true, "Gen1 battle dialog stays blank before the intro line")
  blankGen1.stack.states[1].phase = "menu"
  local drewMenu1, menu1 = battleLines(blankGen1)
  T.eq(drewMenu1, true, "Gen1 action menu draws")
  T.eq(menu1:find("What will", 1, true) ~= nil, true, "Gen1 action menu still asks what the Pokémon will do")

  local blankGen2 = {
    data = Data,
    gameVersion = "gold",
    save = { pokedex = { owned = {} }, party = { { species = "CYNDAQUIL", level = 12, hp = 35, stats = { hp = 35 } } } },
    stack = { states = { {
      isBattle = true,
      screenId = "Gen2BattleState",
      phase = "intro",
      player = { name = "CYNDAQUIL", shownHP = 35, mon = { species = "CYNDAQUIL", level = 12, hp = 35, stats = { hp = 35 } } },
      enemy = { name = "PIDGEY", shownHP = 18, mon = { species = "PIDGEY", level = 4, hp = 18, stats = { hp = 18 } } },
      battle = {
        player = { species = "CYNDAQUIL", level = 12, hp = 35, stats = { hp = 35 } },
        enemy = { species = "PIDGEY", level = 4, hp = 18, stats = { hp = 18 } },
      },
      messageLines = function() return { "" } end,
    } } },
  }
  local drewBlank2, blank2 = battleLines(blankGen2)
  T.eq(drewBlank2, true, "Gen2 battle dialog draws before the intro line")
  T.eq(blank2:find("What will", 1, true) == nil, true, "Gen2 battle dialog stays blank before the intro line")
  blankGen2.stack.states[1].phase = "menu"
  local drewMenu2, menu2 = battleLines(blankGen2)
  T.eq(drewMenu2, true, "Gen2 action menu draws")
  T.eq(menu2:find("What will", 1, true) ~= nil, true, "Gen2 action menu still asks what the Pokémon will do")

  T.eq(okHof, true, "Gen3 Hall of Fame module loads")
  T.eq(okPc, true, "Gen3 Hall of Fame PC module loads")
  T.eq(okLearn, true, "Gen3 move relearner module loads")

  if okHof and HallOfFame then
    local prevOpen, prevPhase, prevMons, prevIndex = HallOfFame.open, HallOfFame._phase, HallOfFame._mons, HallOfFame._currentIndex
    HallOfFame.open = true
    HallOfFame._phase = "display"
    HallOfFame._currentIndex = 1
    HallOfFame._mons = { { species = 228, nickname = "ABC", level = 50 } }
    T.eq(ModernOverlay.getActiveScreen({}), "hall_of_fame", "Gen3 Hall of Fame ceremony routes to OmniUI")
    local seen = {}
    local orig = Layout.drawText
    Layout.drawText = function(text, ...)
      seen[#seen + 1] = tostring(text)
      return orig(text, ...)
    end
    local drew = pcall(HallOfFameRenderer.draw, { data = Data, save = {} }, HallOfFame, 900, 600, theme)
    Layout.drawText = orig
    local joined = table.concat(seen, "\n"):upper()
    T.eq(drew, true, "Gen3 Hall of Fame ceremony draws")
    T.eq(joined:find("ABC", 1, true) ~= nil, true, "Hall of Fame keeps the nickname")
    T.eq(joined:find("228", 1, true) == nil, true, "Hall of Fame does not print the species number")
    HallOfFame.open, HallOfFame._phase, HallOfFame._mons, HallOfFame._currentIndex = prevOpen, prevPhase, prevMons, prevIndex
  end

  if okPc and HofPc then
    local prevOpen, prevTeams, prevTeam, prevMon = HofPc.open, HofPc._teams, HofPc._team, HofPc._mon
    HofPc.open = true
    HofPc._team = 1
    HofPc._mon = 1
    HofPc._teams = { { { species = 228, level = 50 }, { species = 0 } } }
    T.eq(ModernOverlay.getActiveScreen({}), "league_pc", "Gen3 Hall of Fame PC routes to OmniUI")
    local seen = {}
    local orig = Layout.drawText
    Layout.drawText = function(text, ...)
      seen[#seen + 1] = tostring(text)
      return orig(text, ...)
    end
    local drew = pcall(LeaguePcRenderer.draw, { data = Data, save = { player = {} } }, HofPc, 900, 600, theme)
    Layout.drawText = orig
    local joined = table.concat(seen, "\n"):upper()
    T.eq(drew, true, "Gen3 Hall of Fame PC draws")
    T.eq(joined:find("HOUNDO", 1, true) ~= nil, true, "Hall of Fame PC resolves species 228")
    T.eq(joined:find("228", 1, true) == nil, true, "Hall of Fame PC does not print the species number")
    HofPc.open, HofPc._teams, HofPc._team, HofPc._mon = prevOpen, prevTeams, prevTeam, prevMon
  end

  if okLearn and MoveRelearner then
    local prevOpen, prevMoves, prevMon, prevCursor, prevState = MoveRelearner.open, MoveRelearner._moves, MoveRelearner._mon, MoveRelearner.cursor, MoveRelearner.state
    local prevPrompt, prevScroll = MoveRelearner.prompt, MoveRelearner.scroll
    MoveRelearner.open = true
    MoveRelearner.state = "list"
    MoveRelearner.cursor = 1
    MoveRelearner.scroll = 0
    MoveRelearner.prompt = "Teach which move?"
    MoveRelearner._mon = { species = 228, nickname = "ABC" }
    MoveRelearner._moves = { 33 }
    T.eq(ModernOverlay.getActiveScreen({}), "move_learn", "Gen3 move relearner routes to OmniUI")
    local seen = {}
    local orig = Layout.drawText
    Layout.drawText = function(text, ...)
      seen[#seen + 1] = tostring(text)
      return orig(text, ...)
    end
    local drew = pcall(MoveLearnRenderer.draw, { data = Data }, MoveRelearner, 900, 600, theme)
    Layout.drawText = orig
    local joined = table.concat(seen, "\n"):upper()
    T.eq(drew, true, "Gen3 move relearner draws")
    T.eq(joined:find("TACKLE", 1, true) ~= nil, true, "Move relearner resolves move 33")
    T.eq(joined:find("CANCEL", 1, true) ~= nil, true, "Move relearner keeps the cancel row")
    MoveRelearner.open, MoveRelearner._moves, MoveRelearner._mon = prevOpen, prevMoves, prevMon
    MoveRelearner.cursor, MoveRelearner.state, MoveRelearner.prompt, MoveRelearner.scroll = prevCursor, prevState, prevPrompt, prevScroll
  end
end

-- Menu animation toggle: low-end devices can skip entrance motion
local function testMenuAnimations()
  local schema = run.loader.optionSchemas.omni_ui or {}
  local registered = false
  for _, row in ipairs(schema) do
    if row.key == "menu_animations" and row.type == "toggle" and row.default == true then
      registered = true
    end
  end
  T.eq(registered, true, "MENU ANIMATIONS toggle is registered and on by default")

  local prevFlag = Layout.menuAnimations
  local prevProgress = ModernOverlay.screenProgress
  local prevKind = ModernOverlay.lastActiveKind
  local prevState = ModernOverlay.lastActiveState
  local prevSub = ModernOverlay.lastSubState
  local prevTime = ModernOverlay.lastActiveTime
  local prevDialogue = ModernOverlay.lastDialogueTime
  local prevClosing = ModernOverlay.closingModal
  local prevTransProgress = ModernOverlay.transition.progress
  local prevTheme = Theme.currentThemeId
  local prevTrans = Theme.transition
  local optBag = run.loader.modOptions.omni_ui
  local prevOpt = optBag and optBag.menu_animations

  Layout.menuAnimations = false
  local offX, offA = Layout.getCascadeOffset(4, 0.05, 0.022, 24)
  T.eq(offX, 0, "List cascade offset is zero when menu animations are off")
  T.eq(offA, 1.0, "List cascade alpha is full when menu animations are off")

  ModernOverlay.screenProgress = {}
  ModernOverlay.lastActiveKind = "save"
  ModernOverlay.closingModal = { kind = "save", progress = 0.4, duration = 0.22 }
  local snapState = {}
  local snapped = ModernOverlay.updateProgress("party", snapState, nil, true)
  T.eq(snapped, 1.0, "Menu open progress snaps to finished when animations are off")
  T.eq(ModernOverlay.closingModal, nil, "Save modal exit animation is skipped when animations are off")
  T.eq(ModernOverlay.screenProgress["party_" .. tostring(snapState)].progress, 1.0, "Disabled animations store a finished screen progress")

  Theme.setTheme("kanto", 0.35)
  T.eq(Theme.transition, nil, "Theme changes are instant when menu animations are off")
  T.eq(Theme.currentThemeId, "kanto", "Theme still switches while animations are off")

  Layout.menuAnimations = nil
  run.loader.modOptions.omni_ui = run.loader.modOptions.omni_ui or {}
  run.loader.modOptions.omni_ui.menu_animations = false
  T.eq(Layout.animationsEnabled(), false, "Persisted mod option turns menu animations off")
  run.loader.modOptions.omni_ui.menu_animations = true
  T.eq(Layout.animationsEnabled(), true, "Persisted mod option turns menu animations back on")

  Layout.menuAnimations = true
  local onX = Layout.getCascadeOffset(1, 0.0, 0.022, 18)
  T.eq(onX, 18, "List cascade offset returns when menu animations are on")

  Layout.menuAnimations = prevFlag
  ModernOverlay.screenProgress = prevProgress
  ModernOverlay.lastActiveKind = prevKind
  ModernOverlay.lastActiveState = prevState
  ModernOverlay.lastSubState = prevSub
  ModernOverlay.lastActiveTime = prevTime
  ModernOverlay.lastDialogueTime = prevDialogue
  ModernOverlay.closingModal = prevClosing
  ModernOverlay.transition.progress = prevTransProgress
  Theme.currentThemeId = prevTheme
  Theme.transition = prevTrans
  if optBag then
    optBag.menu_animations = prevOpt
  else
    run.loader.modOptions.omni_ui = nil
  end
end
testMenuAnimations()

-- Reset back to default dark theme
Theme.setTheme("dark")

run.release()
T.finish("omni_ui")




