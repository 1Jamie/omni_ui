-- OmniUI Modern Overlay Presenter
-- Unified Cross-Generation (Gen 1-3) Modern UI Framework
-- Centralized orchestrator that delegates to modular screen renderers.

local Theme = require("mods.omni_ui.core.Theme")
local Layout = require("mods.omni_ui.core.Layout")
local LegacyV1Shim = require("mods.omni_ui.compat.LegacyV1Shim")

-- Modular Renderers
local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
local StartMenuRenderer = require("mods.omni_ui.renderers.StartMenuRenderer")
local MainMenuRenderer = require("mods.omni_ui.renderers.MainMenuRenderer")
local PartyRenderer = require("mods.omni_ui.renderers.PartyRenderer")
local SummaryRenderer = require("mods.omni_ui.renderers.SummaryRenderer")
local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
local TrainerCardRenderer = require("mods.omni_ui.renderers.TrainerCardRenderer")
local SaveRenderer = require("mods.omni_ui.renderers.SaveRenderer")
local OptionsRenderer = require("mods.omni_ui.renderers.OptionsRenderer")
local PokedexRenderer = require("mods.omni_ui.renderers.PokedexRenderer")
local ShopRenderer = require("mods.omni_ui.renderers.ShopRenderer")
local ModManagerRenderer = require("mods.omni_ui.renderers.ModManagerRenderer")
local LoadReportRenderer = require("mods.omni_ui.renderers.LoadReportRenderer")
local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")
local NamingRenderer = require("mods.omni_ui.renderers.NamingRenderer")
local MoveLearnRenderer = require("mods.omni_ui.renderers.MoveLearnRenderer")
local PrizeCounterRenderer = require("mods.omni_ui.renderers.PrizeCounterRenderer")
local BoxMenuRenderer = require("mods.omni_ui.renderers.BoxMenuRenderer")
local StorageRenderer = require("mods.omni_ui.renderers.StorageRenderer")
local PlayerPcRenderer = require("mods.omni_ui.renderers.PlayerPcRenderer")
local PcHubRenderer = require("mods.omni_ui.renderers.PcHubRenderer")
local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")
local LegacyRenderer = require("mods.omni_ui.renderers.LegacyRenderer")
local EvolutionRenderer = require("mods.omni_ui.renderers.EvolutionRenderer")
local HallOfFameRenderer = require("mods.omni_ui.renderers.HallOfFameRenderer")
local LeaguePcRenderer = require("mods.omni_ui.renderers.LeaguePcRenderer")
local DiplomaRenderer = require("mods.omni_ui.renderers.DiplomaRenderer")
local FlyMenuRenderer = require("mods.omni_ui.renderers.FlyMenuRenderer")
local PokegearRenderer = require("mods.omni_ui.renderers.PokegearRenderer")
local LevelUpStatRenderer = require("mods.omni_ui.renderers.LevelUpStatRenderer")
local BankRenderer = require("mods.omni_ui.renderers.BankRenderer")
local BuenaRenderer = require("mods.omni_ui.renderers.BuenaRenderer")
local ElevatorRenderer = require("mods.omni_ui.renderers.ElevatorRenderer")
local DecorationRenderer = require("mods.omni_ui.renderers.DecorationRenderer")
local TradeRenderer = require("mods.omni_ui.renderers.TradeRenderer")
local ContestRenderer = require("mods.omni_ui.renderers.ContestRenderer")
local HeldItemRenderer = require("mods.omni_ui.renderers.HeldItemRenderer")
local DayCareRenderer = require("mods.omni_ui.renderers.DayCareRenderer")
local MoveDeleterRenderer = require("mods.omni_ui.renderers.MoveDeleterRenderer")
local MailRenderer = require("mods.omni_ui.renderers.MailRenderer")
local MailboxRenderer = require("mods.omni_ui.renderers.MailboxRenderer")
local MailComposeRenderer = require("mods.omni_ui.renderers.MailComposeRenderer")
local ClockRenderer = require("mods.omni_ui.renderers.ClockRenderer")
local GenderRenderer = require("mods.omni_ui.renderers.GenderRenderer")
local BattleTowerRenderer = require("mods.omni_ui.renderers.BattleTowerRenderer")
local CallerBoxRenderer = require("mods.omni_ui.renderers.CallerBoxRenderer")
local StarterRenderer = require("mods.omni_ui.renderers.StarterRenderer")
local PokenavRenderer = require("mods.omni_ui.renderers.PokenavRenderer")

local ModernOverlay = {}

-- Expose individual renderers on ModernOverlay for backward compatibility
ModernOverlay.drawDialogue = DialogueRenderer.draw
ModernOverlay.drawStartMenu = StartMenuRenderer.draw
ModernOverlay.drawMainMenu = MainMenuRenderer.draw
ModernOverlay.drawParty = PartyRenderer.draw
ModernOverlay.drawSummary = SummaryRenderer.draw
ModernOverlay.drawBag = BagRenderer.draw
ModernOverlay.drawTrainerCard = TrainerCardRenderer.draw
ModernOverlay.drawSaveMenu = SaveRenderer.draw
ModernOverlay.drawOptionsMenu = OptionsRenderer.draw
ModernOverlay.drawPokedexMenu = PokedexRenderer.draw
ModernOverlay.drawShopMenu = ShopRenderer.draw
ModernOverlay.drawStarterChoose = StarterRenderer.draw
ModernOverlay.drawTownMap = TownMapRenderer.draw
ModernOverlay.drawPokegear = PokegearRenderer.draw
ModernOverlay.drawPokenav = PokenavRenderer.draw
ModernOverlay.drawNaming = NamingRenderer.draw
ModernOverlay.drawMoveLearn = MoveLearnRenderer.draw
ModernOverlay.drawPrizeCounter = PrizeCounterRenderer.draw
ModernOverlay.drawStorage = StorageRenderer.draw
ModernOverlay.drawPlayerPc = PlayerPcRenderer.draw
ModernOverlay.drawPcHub = PcHubRenderer.draw
ModernOverlay.drawBattle = BattleRenderer.draw
ModernOverlay.drawModManager = ModManagerRenderer.draw
ModernOverlay.drawLoadReport = LoadReportRenderer.draw
ModernOverlay.drawLegacy = LegacyRenderer.draw
ModernOverlay.drawEvolution = EvolutionRenderer.draw
ModernOverlay.drawHallOfFame = HallOfFameRenderer.draw
ModernOverlay.drawLeaguePc = LeaguePcRenderer.draw
ModernOverlay.drawDiploma = DiplomaRenderer.draw
ModernOverlay.drawFlyMenu = FlyMenuRenderer.draw
ModernOverlay.drawLevelUpStat = LevelUpStatRenderer.draw
ModernOverlay.drawBankOfMom = BankRenderer.draw
ModernOverlay.drawBuenaPassword = BuenaRenderer.draw
ModernOverlay.drawElevator = ElevatorRenderer.draw
ModernOverlay.drawDecoration = DecorationRenderer.draw
ModernOverlay.drawTrade = TradeRenderer.draw
ModernOverlay.drawContest = ContestRenderer.draw
ModernOverlay.drawHeldItem = HeldItemRenderer.draw
ModernOverlay.drawDayCare = DayCareRenderer.draw
ModernOverlay.drawMoveDeleter = MoveDeleterRenderer.draw
ModernOverlay.drawMail = MailRenderer.draw
ModernOverlay.drawMailbox = MailboxRenderer.draw
ModernOverlay.drawMailCompose = MailComposeRenderer.draw
ModernOverlay.drawClock = ClockRenderer.draw
ModernOverlay.drawGender = GenderRenderer.draw
ModernOverlay.drawNamePick = NamingRenderer.drawNamePick
ModernOverlay.drawBattleTower = BattleTowerRenderer.draw
ModernOverlay.drawCallerBox = CallerBoxRenderer.draw
ModernOverlay.drawDexNav = ModernOverlay.drawMenu

function ModernOverlay.ensureGen3Hooks(options)
  options = options or ModernOverlay.options
  local G3Stack = package and package.loaded and package.loaded["src.ui.game3.stack"]
  if not G3Stack then
    local okStack, s = pcall(require, "src.ui.game3.stack")
    if okStack then G3Stack = s end
  end
  local isModalId = {
    box_storage = true,
    item_pc = true,
    rse_item_storage = true,
    pc_menu = true,
    pc = true,
    bag = true,
    party = true,
    summary = true,
    pokedex = true,
    rse_pokedex = true,
    rs_pokedex = true,
    rse_pokenav = true,
    rs_pokenav = true,
    pokenav = true,
    trainer = true,
    trainer_card = true,
    option = true,
    options = true,
    save = true,
    start = true,
    start_menu = true,
    shop = true,
    naming = true,
    rs_daycare_level = true,
    rs_daycare_party = true,
    hall_of_fame = true,
    hall_of_fame_pc = true,
    move_relearner = true,
    mod_manager = true,
  }

  if G3Stack and not G3Stack.__omniHooked then
    G3Stack.__omniHooked = true

    if type(G3Stack.push) == "function" then
      local origPush = G3Stack.push
      G3Stack.push = function(id, mod, opts)
        opts = opts or {}
        if not options or options:get("overlay") ~= false then
          if isModalId[id] then
            opts.hideBelow = false
            opts.drawUnder = true
            opts.fullscreen = false
          end
        end
        return origPush(id, mod, opts)
      end
    end

    if type(G3Stack.drawOrder) == "function" then
      local origDrawOrder = G3Stack.drawOrder
      G3Stack.drawOrder = function(...)
        if not options or options:get("overlay") ~= false then
          local layers = G3Stack._layers or {}
          local n = #layers
          if n > 0 and isModalId[layers[n].id] then
            local out = {}
            for i = 1, n do out[#out + 1] = layers[i] end
            return out
          end
        end
        return origDrawOrder(...)
      end
    end

    if type(G3Stack.fullscreen) == "function" then
      local origFullscreen = G3Stack.fullscreen
      G3Stack.fullscreen = function(...)
        if not options or options:get("overlay") ~= false then
          local layers = (type(G3Stack.drawOrder) == "function" and G3Stack.drawOrder()) or (G3Stack._layers or {})
          local hasNonOverlayFullscreen = false
          for _, layer in ipairs(layers) do
            local f = layer.fullscreen
            if type(f) == "function" then f = f() end
            if f then
              if not isModalId[layer.id] then
                hasNonOverlayFullscreen = true
                break
              end
            end
          end
          if not hasNonOverlayFullscreen then
            return false
          end
        end
        return origFullscreen(...)
      end
    end
  end

  if G3Stack and G3Stack._layers and (not options or options:get("overlay") ~= false) then
    for _, layer in ipairs(G3Stack._layers) do
      if layer and isModalId[layer.id] then
        layer.hideBelow = false
        layer.drawUnder = true
        layer.fullscreen = false
      end
    end
  end

  local g3MenuModules = {
    "src.ui.game3.summary_menu",
    "src.ui.game3.rse.summary_menu",
    "src.ui.game3.bag_menu",
    "src.ui.game3.rse.bag_menu",
    "src.ui.game3.pokedex",
    "src.ui.game3.rse.pokedex",
    "src.ui.game3.rs.pokedex",
    "src.ui.game3.trainer_card",
    "src.ui.game3.start_menu",
    "src.ui.game3.start_menu_frlg",
    "src.ui.game3.save_menu",
    "src.ui.game3.option_menu",
    "src.ui.game3.rse.option_menu",
    "src.ui.game3.pc_menu",
    "src.ui.game3.box_storage_ui",
    "src.ui.game3.item_pc",
    "src.ui.game3.rse.item_storage",
  }
  for _, modPath in ipairs(g3MenuModules) do
    local M = package and package.loaded and package.loaded[modPath]
    if not M then
      local okM, m = pcall(require, modPath)
      if okM then M = m end
    end
    if M and type(M) == "table" and type(M.draw) == "function" and not M.__omniHooked then
      M.__omniHooked = true
      local origDraw = M.draw
      M.draw = function(...)
        if not options or options:get("overlay") ~= false then
          return
        end
        return origDraw(...)
      end
    end
  end

  local G3PartyMenu = package and package.loaded and package.loaded["src.ui.game3.party_menu"]
  if not G3PartyMenu then
    local okParty, p = pcall(require, "src.ui.game3.party_menu")
    if okParty then G3PartyMenu = p end
  end
  if G3PartyMenu and type(G3PartyMenu.draw) == "function" and not G3PartyMenu.__omniHooked then
    G3PartyMenu.__omniHooked = true
    local origPartyDraw = G3PartyMenu.draw
    G3PartyMenu.draw = function(...)
      if not options or options:get("overlay") ~= false then
        local Oam = package and package.loaded and package.loaded["src.core.game3.oam"]
        if not Oam then
          local okO, o = pcall(require, "src.core.game3.oam")
          if okO then Oam = o end
        end
        if G3PartyMenu._oam then
          local slots = G3PartyMenu._oam
          G3PartyMenu._oam = nil
          if Oam and slots then
            for i = 1, 6 do
              local s = slots[i]
              if s then
                if s.mon then Oam.destroySprite(s.mon) end
                if s.ball then Oam.destroySprite(s.ball) end
                if s.status then Oam.destroySprite(s.status) end
                if s.item then Oam.destroySprite(s.item) end
              end
            end
          end
        end
        if G3PartyMenu._summaryIcon and Oam then
          Oam.destroySprite(G3PartyMenu._summaryIcon)
          G3PartyMenu._summaryIcon = nil
        end
        return
      end
      return origPartyDraw(...)
    end
  end

  local RsePokedex = package and package.loaded and package.loaded["src.ui.game3.rse.pokedex"]
  if not RsePokedex then
    local okP, p = pcall(require, "src.ui.game3.rse.pokedex")
    if okP then RsePokedex = p end
  end
  if RsePokedex and RsePokedex.Host and type(RsePokedex.Host.handleInput) == "function" and not RsePokedex.Host.__omniHookedInput then
    RsePokedex.Host.__omniHookedInput = true
    local origHostHandleInput = RsePokedex.Host.handleInput
    RsePokedex.Host.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        local s = RsePokedex.Host._s or (RsePokedex.active and RsePokedex.active())
        if s then
          if ModernOverlay.attachPokedexControls then
            ModernOverlay.attachPokedexControls(s, ModernOverlay.currentGame)
          elseif ModernOverlay.attachControls then
            ModernOverlay.attachControls(s, ModernOverlay.currentGame)
          end
          if s.handleInputOmni and s:handleInputOmni(input) then
            return
          end
        end
      end
      return origHostHandleInput(input)
    end
  end

  local FrlgPokedex = package and package.loaded and package.loaded["src.ui.game3.pokedex"]
  if not FrlgPokedex then
    local okP, p = pcall(require, "src.ui.game3.pokedex")
    if okP then FrlgPokedex = p end
  end
  if FrlgPokedex and type(FrlgPokedex.handleInput) == "function" and not FrlgPokedex.__omniHookedInput then
    FrlgPokedex.__omniHookedInput = true
    local origFrlgHandleInput = FrlgPokedex.handleInput
    FrlgPokedex.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        if ModernOverlay.attachPokedexControls then
          ModernOverlay.attachPokedexControls(FrlgPokedex, ModernOverlay.currentGame)
        elseif ModernOverlay.attachControls then
          ModernOverlay.attachControls(FrlgPokedex, ModernOverlay.currentGame)
        end
        if FrlgPokedex.handleInputOmni and FrlgPokedex:handleInputOmni(input) then
          return
        end
      end
      return origFrlgHandleInput(input)
    end
  end

  local RsePokenav = package and package.loaded and package.loaded["src.ui.game3.rse.pokenav.init"]
  if not RsePokenav then
    local okP, p = pcall(require, "src.ui.game3.rse.pokenav.init")
    if okP then RsePokenav = p end
  end
  if RsePokenav and RsePokenav.Host and type(RsePokenav.Host.handleInput) == "function" and not RsePokenav.Host.__omniHookedInput then
    RsePokenav.Host.__omniHookedInput = true
    local origRseNavHandleInput = RsePokenav.Host.handleInput
    RsePokenav.Host.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        local s = RsePokenav.Host._s or (RsePokenav.active and RsePokenav.active())
        if s then
          if ModernOverlay.attachPokenavControls then
            ModernOverlay.attachPokenavControls(s, ModernOverlay.currentGame)
          elseif ModernOverlay.attachControls then
            ModernOverlay.attachControls(s, ModernOverlay.currentGame)
          end
          if s.handleInputOmni and s:handleInputOmni(input) then
            return
          end
        end
      end
      return origRseNavHandleInput(input)
    end
  end

  local RsPokenav = package and package.loaded and package.loaded["src.ui.game3.rs.pokenav.init"]
  if not RsPokenav then
    local okP, p = pcall(require, "src.ui.game3.rs.pokenav.init")
    if okP then RsPokenav = p end
  end
  if RsPokenav and RsPokenav.Host and type(RsPokenav.Host.handleInput) == "function" and not RsPokenav.Host.__omniHookedInput then
    RsPokenav.Host.__omniHookedInput = true
    local origRsNavHandleInput = RsPokenav.Host.handleInput
    RsPokenav.Host.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        local s = RsPokenav.Host._s or (RsPokenav.active and RsPokenav.active())
        if s then
          if ModernOverlay.attachPokenavControls then
            ModernOverlay.attachPokenavControls(s, ModernOverlay.currentGame)
          elseif ModernOverlay.attachControls then
            ModernOverlay.attachControls(s, ModernOverlay.currentGame)
          end
          if s.handleInputOmni and s:handleInputOmni(input) then
            return
          end
        end
      end
      return origRsNavHandleInput(input)
    end
  end

  local G3Summary = package and package.loaded and package.loaded["src.ui.game3.summary_menu"]
  if not G3Summary then
    local okS, s = pcall(require, "src.ui.game3.summary_menu")
    if okS then G3Summary = s end
  end
  if G3Summary and type(G3Summary.handleInput) == "function" and not G3Summary.__omniHookedInput then
    G3Summary.__omniHookedInput = true
    local origOpenMenu = G3Summary.openMenu
    if origOpenMenu then
      G3Summary.openMenu = function(party, index, opts)
        opts = opts or {}
        local res = origOpenMenu(party, index, opts)
        if not options or options:get("overlay") ~= false then
          if opts.mode == "select_move" then
            G3Summary._page = G3Summary.PAGE_MOVES_INFO
            G3Summary.page = 2
            G3Summary.inMovesSubmenu = true
          else
            G3Summary.page = tonumber(opts.page) or 1
            G3Summary._page = (G3Summary.page == 2) and G3Summary.PAGE_MOVES or ((G3Summary.page == 3) and G3Summary.PAGE_INFO or G3Summary.PAGE_SKILLS)
            G3Summary.inMovesSubmenu = false
          end
          G3Summary.moveIndex = 1
          G3Summary._moveCursor = 1
          G3Summary.movesSubTab = "battle"
          G3Summary.swapSlot = nil
          G3Summary._swapSlot = nil
        end
        return res
      end
    end

    local origClose = G3Summary.close
    if origClose then
      G3Summary.close = function(...)
        if not options or options:get("overlay") ~= false then
          G3Summary.inMovesSubmenu = false
          G3Summary.swapSlot = nil
          G3Summary._swapSlot = nil
        end
        return origClose(...)
      end
    end

    local origSummaryHandleInput = G3Summary.handleInput
    G3Summary.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        local mon = G3Summary.mon or (G3Summary._party and G3Summary._party[G3Summary._cursor or 1])
        if G3Summary.open and mon and not (G3Summary._slide and G3Summary._slide.active) then
          -- Move detail & swap mode
          if G3Summary.inMovesSubmenu or G3Summary._page == G3Summary.PAGE_MOVES_INFO then
            local moves = (mon and mon.moves) or {}
            local moveCount = 0
            for _, mv in ipairs(moves) do
              if (type(mv) == "table" and mv.id) or mv then moveCount = moveCount + 1 end
            end
            moveCount = math.max(1, math.min(4, moveCount))
            G3Summary.moveIndex = math.max(1, math.min(moveCount, G3Summary.moveIndex or 1))

            if input:wasPressed("right") or input:wasPressed("left") or input:wasPressed("select") or input:wasPressed("tab") then
              pcall(function() require("src.core.game3.audio").playSe(5) end)
              G3Summary.movesSubTab = (G3Summary.movesSubTab == "contest") and "battle" or "contest"
              return
            end

            if input:wasPressed("up") then
              G3Summary.moveIndex = ((G3Summary.moveIndex - 2 + moveCount) % moveCount) + 1
              G3Summary._moveCursor = G3Summary.moveIndex
              pcall(function() require("src.core.game3.audio").playSe(5) end)
              return
            elseif input:wasPressed("down") then
              G3Summary.moveIndex = (G3Summary.moveIndex % moveCount) + 1
              G3Summary._moveCursor = G3Summary.moveIndex
              pcall(function() require("src.core.game3.audio").playSe(5) end)
              return
            elseif input:wasPressed("a") then
              pcall(function() require("src.core.game3.audio").playSe(5) end)
              if G3Summary.swapSlot == nil then
                G3Summary.swapSlot = G3Summary.moveIndex
                G3Summary._swapSlot = G3Summary.moveIndex
              else
                local s1 = G3Summary.swapSlot
                local s2 = G3Summary.moveIndex
                if s1 ~= s2 then
                  local Pokemon = package.loaded["src.battle.game3.pokemon"]
                  if not Pokemon then pcall(function() Pokemon = require("src.battle.game3.pokemon") end) end
                  if Pokemon and Pokemon.swapMoves then
                    Pokemon.swapMoves(mon, s1, s2)
                  elseif mon and mon.moves then
                    mon.moves[s1], mon.moves[s2] = mon.moves[s2], mon.moves[s1]
                    if mon.pp then mon.pp[s1], mon.pp[s2] = mon.pp[s2], mon.pp[s1] end
                  end
                end
                G3Summary.swapSlot = nil
                G3Summary._swapSlot = nil
              end
              return
            elseif input:wasPressed("b") then
              pcall(function() require("src.core.game3.audio").playSe(5) end)
              if G3Summary.swapSlot ~= nil then
                G3Summary.swapSlot = nil
                G3Summary._swapSlot = nil
                return
              else
                G3Summary.inMovesSubmenu = false
                G3Summary._page = G3Summary.PAGE_MOVES
                G3Summary.swapSlot = nil
                G3Summary._swapSlot = nil
                return
              end
            end
            return
          end

          -- Linear tab cycling: Left and Right arrows (1: STATS <-> 2: MOVES <-> 3: DETAILS)
          local maxPage = G3Summary._expMaxPage or 3
          if input:wasPressed("right") then
            pcall(function() require("src.core.game3.audio").playSe(5) end)
            local curP = G3Summary.page or 1
            G3Summary.page = (curP >= maxPage) and 1 or (curP + 1)
            G3Summary.inMovesSubmenu = false
            G3Summary.swapSlot = nil
            G3Summary._swapSlot = nil
            if G3Summary.page == 1 then
              G3Summary._page = G3Summary.PAGE_SKILLS
            elseif G3Summary.page == 2 then
              G3Summary._page = G3Summary.PAGE_MOVES
            elseif G3Summary.page == 3 then
              G3Summary._page = G3Summary.PAGE_INFO
            end
            return
          elseif input:wasPressed("left") then
            pcall(function() require("src.core.game3.audio").playSe(5) end)
            local curP = G3Summary.page or 1
            G3Summary.page = (curP <= 1) and maxPage or (curP - 1)
            G3Summary.inMovesSubmenu = false
            G3Summary.swapSlot = nil
            G3Summary._swapSlot = nil
            if G3Summary.page == 1 then
              G3Summary._page = G3Summary.PAGE_SKILLS
            elseif G3Summary.page == 2 then
              G3Summary._page = G3Summary.PAGE_MOVES
            elseif G3Summary.page == 3 then
              G3Summary._page = G3Summary.PAGE_INFO
            end
            return
          end

          -- Tab 2 (MOVES): Pressing A enters the move submenu
          if (G3Summary.page == 2 or G3Summary._page == G3Summary.PAGE_MOVES) and input:wasPressed("a") then
            pcall(function() require("src.core.game3.audio").playSe(5) end)
            G3Summary.inMovesSubmenu = true
            G3Summary._page = G3Summary.PAGE_MOVES_INFO
            G3Summary.moveIndex = 1
            G3Summary._moveCursor = 1
            G3Summary.swapSlot = nil
            G3Summary._swapSlot = nil
            return
          end

          if input:wasPressed("up") then
            local n = #(G3Summary._party or {})
            if n > 1 then
              G3Summary._cursor = ((G3Summary._cursor - 2 + n) % n) + 1
              if G3Summary.resetPicBounce then G3Summary.resetPicBounce() end
            end
            return
          elseif input:wasPressed("down") then
            local n = #(G3Summary._party or {})
            if n > 1 then
              G3Summary._cursor = (G3Summary._cursor % n) + 1
              if G3Summary.resetPicBounce then G3Summary.resetPicBounce() end
            end
            return
          elseif input:wasPressed("b") or input:wasPressed("start") then
            G3Summary.close()
            return
          end
        end
      end
      return origSummaryHandleInput(input)
    end
  end

  local RseSummary = package and package.loaded and package.loaded["src.ui.game3.rse.summary_menu"]
  if not RseSummary then
    local okS, s = pcall(require, "src.ui.game3.rse.summary_menu")
    if okS then RseSummary = s end
  end
  if RseSummary and not RseSummary.__omniHookedRse then
    RseSummary.__omniHookedRse = true
    local origPage = RseSummary.page
    RseSummary.page = function(Sm)
      Sm = Sm or G3Summary
      if Sm and (Sm.movesSubTab == "contest") then
        local p = Sm._page
        if p == Sm.PAGE_MOVES or p == Sm.PAGE_MOVES_INFO or Sm._mode == "select_move" then
          return RseSummary.PAGE.CONTEST_MOVES
        end
      end
      return origPage(Sm)
    end

    local origDetail = RseSummary.detail
    RseSummary.detail = function(Sm)
      Sm = Sm or G3Summary
      if Sm and Sm.inMovesSubmenu == true then
        return true
      end
      return origDetail(Sm)
    end

    local origRseHandleInput = RseSummary.handleInput
    RseSummary.handleInput = function(input, Sm)
      Sm = Sm or G3Summary
      if not options or options:get("overlay") ~= false then
        if Sm and input then
          local movesPage = (Sm._page == Sm.PAGE_MOVES or Sm.page == 2 or Sm._page == Sm.PAGE_MOVES_INFO or Sm.inMovesSubmenu) and not (Sm._slide and Sm._slide.active)
          local selecting = Sm._mode == "select_move"
          local focusedMoves = (Sm._page == Sm.PAGE_MOVES_INFO or Sm.inMovesSubmenu == true or selecting)

          if focusedMoves then
            local lr = false
            pcall(function() lr = require("src.core.game3.options").lrMode(Sm._playerState) end)
            local right = input:wasPressed("right") or (lr and input:wasPressed("r"))
            local left = input:wasPressed("left") or (lr and input:wasPressed("l"))
            local selectTab = input:wasPressed("select") or input:wasPressed("tab")
            if right or left or selectTab then
              Sm.movesSubTab = (Sm.movesSubTab == "contest") and "battle" or "contest"
              pcall(function() require("src.core.game3.audio").playSe(5) end)
              return
            end
          end

          if movesPage and (input:wasPressed("select") or input:wasPressed("tab")) then
            Sm.movesSubTab = (Sm.movesSubTab == "contest") and "battle" or "contest"
            pcall(function() require("src.core.game3.audio").playSe(5) end)
            return
          end

          if movesPage and not focusedMoves and (input:wasPressed("right") or input:wasPressed("left")) then
            return Sm.handleInput(input)
          end
        end
      end
      return origRseHandleInput(input, Sm)
    end
  end

  local G3ItemPc = package and package.loaded and package.loaded["src.ui.game3.item_pc"]
  if not G3ItemPc then
    local okI, itemPcMod = pcall(require, "src.ui.game3.item_pc")
    if okI then G3ItemPc = itemPcMod end
  end
  if G3ItemPc and type(G3ItemPc.handleInput) == "function" and not G3ItemPc.__omniHookedInput then
    G3ItemPc.__omniHookedInput = true
    local origItemPcHandleInput = G3ItemPc.handleInput
    local function closeItemPc()
      if G3ItemPc._fx and G3ItemPc._fx.cb then
        local cb = G3ItemPc._fx.cb
        G3ItemPc._fx = nil
        cb()
        return
      end
      G3ItemPc.__playerPcController = nil
      G3ItemPc.open = false
      G3ItemPc._fx = nil
      local G3Stack = package and package.loaded and package.loaded["src.ui.game3.stack"]
      if not G3Stack then
        local okS, s = pcall(require, "src.ui.game3.stack")
        if okS then G3Stack = s end
      end
      if G3Stack and G3Stack.has and G3Stack.has("item_pc") then
        G3Stack.pop("item_pc")
      end
      if G3ItemPc._onClose then
        local cb = G3ItemPc._onClose
        G3ItemPc._onClose = nil
        cb()
      end
      local g = ModernOverlay.currentGame
      if g and g.data then
        pcall(function() require("src.core.Sound").play(g.data, "Turn_Off_PC") end)
      end
    end

    G3ItemPc.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        if G3ItemPc._fx then
          if G3ItemPc._fx.cb then
            local cb = G3ItemPc._fx.cb
            G3ItemPc._fx = nil
            cb()
            return
          end
          G3ItemPc._fx = nil
        end
        local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")
        if not G3ItemPc.__playerPcController then
          G3ItemPc.__playerPcController = PlayerPcController.new(ModernOverlay.currentGame, {
            tab = (G3ItemPc.kind == "pc_item_deposit" or G3ItemPc.mode == "deposit") and "bag" or "pc",
          })
        end
        local ctrl = G3ItemPc.__playerPcController
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
        if G3ItemPc._fx and G3ItemPc._fx.cb then
          local cb = G3ItemPc._fx.cb
          G3ItemPc._fx = nil
          cb()
          return
        end
        if not okInput and errInput and errInput:find("attempt to index a nil value") then
          G3ItemPc.mode = "list"
          return
        end
        return
      end
    end
  end

  local G3RseItemStorage = package and package.loaded and package.loaded["src.ui.game3.rse.item_storage"]
  if not G3RseItemStorage then
    local okS, sMod = pcall(require, "src.ui.game3.rse.item_storage")
    if okS then G3RseItemStorage = sMod end
  end
  if G3RseItemStorage and type(G3RseItemStorage.handleInput) == "function" and not G3RseItemStorage.__omniHookedInput then
    G3RseItemStorage.__omniHookedInput = true
    local origRseItemStorageDraw = G3RseItemStorage.draw
    G3RseItemStorage.draw = function(...)
      if not options or options:get("overlay") ~= false then
        return
      end
      if origRseItemStorageDraw then return origRseItemStorageDraw(...) end
    end

    local function closeRseItemStorage()
      G3RseItemStorage.__playerPcController = nil
      G3RseItemStorage.open = false
      local G3Stack = package and package.loaded and package.loaded["src.ui.game3.stack"]
      if G3Stack and G3Stack.has and G3Stack.has("rse_item_storage") then
        G3Stack.pop("rse_item_storage")
      end
      if G3RseItemStorage._onClose then
        local cb = G3RseItemStorage._onClose
        G3RseItemStorage._onClose = nil
        cb()
      end
      local g = ModernOverlay.currentGame
      if g and g.data then
        pcall(function() require("src.core.Sound").play(g.data, "Turn_Off_PC") end)
      end
    end

    local origRseItemStorageHandleInput = G3RseItemStorage.handleInput
    G3RseItemStorage.handleInput = function(input)
      if not options or options:get("overlay") ~= false and G3RseItemStorage.open then
        local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")
        if not G3RseItemStorage.__playerPcController then
          G3RseItemStorage.__playerPcController = PlayerPcController.new(ModernOverlay.currentGame, {
            tab = G3RseItemStorage._toss and "pc" or "pc",
          })
        end
        local ctrl = G3RseItemStorage.__playerPcController
        if ctrl and input then
          local action = ctrl:handleInput(input)
          if action == "close" then
            closeRseItemStorage()
            return
          elseif action == true then
            return
          end
        end
      end
      if origRseItemStorageHandleInput then
        return origRseItemStorageHandleInput(input)
      end
    end
  end

  local G3RsePlayerPc = package and package.loaded and package.loaded["src.ui.game3.rse.player_pc"]
  if not G3RsePlayerPc then
    local okP, pMod = pcall(require, "src.ui.game3.rse.player_pc")
    if okP then G3RsePlayerPc = pMod end
  end
  if G3RsePlayerPc and type(G3RsePlayerPc.handleInput) == "function" and not G3RsePlayerPc.__omniHookedInput then
    G3RsePlayerPc.__omniHookedInput = true
    local origRsePcHandleInput = G3RsePlayerPc.handleInput
    G3RsePlayerPc.handleInput = function(pc, input)
      if not options or options:get("overlay") ~= false then
        if pc and pc.mode == "item_storage" and input and input:wasPressed("a") then
          local cursor = pc.cursor or 1
          if cursor == 1 then
            local sess = pc._session or (pc.session)
            local okItemStorage, RseItemStorage = pcall(require, "src.ui.game3.rse.item_storage")
            if okItemStorage and RseItemStorage and RseItemStorage.show then
              pc.mode = "rse_child"
              RseItemStorage.show({
                session = sess,
                toss = false,
                onClose = function()
                  if G3RsePlayerPc.openItemStorage then
                    G3RsePlayerPc.openItemStorage(pc, 1)
                  else
                    pc.mode = "item_storage"
                    pc.cursor = 1
                  end
                end,
              })
              return
            end
          end
        end
      end
      if origRsePcHandleInput then return origRsePcHandleInput(pc, input) end
    end
  end

  local G3Bag = package and package.loaded and package.loaded["src.ui.game3.bag_menu"]
  if not G3Bag then
    local okBag, bMod = pcall(require, "src.ui.game3.bag_menu")
    if okBag then G3Bag = bMod end
  end
  if G3Bag and type(G3Bag.handleInput) == "function" and not G3Bag.__omniHookedDeposit then
    G3Bag.__omniHookedDeposit = true
    local origBagHandleInput = G3Bag.handleInput
    G3Bag.handleInput = function(input)
      local isItemPc = (G3Bag._location == "itempc")
      if isItemPc and (G3Bag.mode == nil or G3Bag.mode == "list") and input then
        local wantsLeft = input:wasPressed("left") or input:wasPressed("l") or input:wasPressed("q")
        local wantsRight = input:wasPressed("right") or input:wasPressed("r") or input:wasPressed("e") or input:wasPressed("tab")
        if wantsLeft or wantsRight then
          local proxyInput = setmetatable({
            wasPressed = function(t, key)
              if wantsLeft and key == "left" then return true end
              if wantsRight and key == "right" then return true end
              if key == "l" or key == "r" or key == "q" or key == "e" or key == "tab" then return false end
              return input:wasPressed(key)
            end
          }, { __index = input })
          local savedLoc = G3Bag._location
          G3Bag._location = nil
          local ok, res = pcall(origBagHandleInput, proxyInput)
          G3Bag._location = savedLoc
          if not ok then error(res) end
          return res
        end
      end
      return origBagHandleInput(input)
    end
  end

  local G3RseBag = package and package.loaded and package.loaded["src.ui.game3.rse.bag_menu"]
  if not G3RseBag then
    local okRseBag, rbMod = pcall(require, "src.ui.game3.rse.bag_menu")
    if okRseBag then G3RseBag = rbMod end
  end
  if G3RseBag and type(G3RseBag.handleInput) == "function" and not G3RseBag.__omniHookedDeposit then
    G3RseBag.__omniHookedDeposit = true
    local origRseBagHandleInput = G3RseBag.handleInput
    G3RseBag.handleInput = function(Bag, input)
      local targetBag = Bag or G3Bag or package.loaded["src.ui.game3.bag_menu"]
      local isItemPc = targetBag and (targetBag._location == "itempc")
      if isItemPc and (targetBag.mode == nil or targetBag.mode == "list") and input then
        local wantsLeft = input:wasPressed("left") or input:wasPressed("l") or input:wasPressed("q")
        local wantsRight = input:wasPressed("right") or input:wasPressed("r") or input:wasPressed("e") or input:wasPressed("tab")
        if wantsLeft or wantsRight then
          local proxyInput = setmetatable({
            wasPressed = function(t, key)
              if wantsLeft and key == "left" then return true end
              if wantsRight and key == "right" then return true end
              if key == "l" or key == "r" or key == "q" or key == "e" or key == "tab" then return false end
              return input:wasPressed(key)
            end
          }, { __index = input })
          local savedLoc = targetBag._location
          targetBag._location = nil
          local ok, res = pcall(origRseBagHandleInput, Bag, proxyInput)
          targetBag._location = savedLoc
          if not ok then error(res) end
          return res
        end
      end
      return origRseBagHandleInput(Bag, input)
    end
  end

  local G3BoxStorage = package and package.loaded and package.loaded["src.ui.game3.box_storage_ui"]
  if not G3BoxStorage then
    local okB, boxMod = pcall(require, "src.ui.game3.box_storage_ui")
    if okB then G3BoxStorage = boxMod end
  end
  if G3BoxStorage and type(G3BoxStorage.handleInput) == "function" and not G3BoxStorage.__omniHookedInput then
    G3BoxStorage.__omniHookedInput = true
    local origStorageHandleInput = G3BoxStorage.handleInput
    G3BoxStorage.handleInput = function(input)
      if not options or options:get("overlay") ~= false then
        local StorageController = require("mods.omni_ui.core.StorageController")
        if not G3BoxStorage.__storageController then
          G3BoxStorage.__storageController = StorageController.new(ModernOverlay.currentGame, {
            mode = G3BoxStorage.mode or "browse",
            subMode = G3BoxStorage.subMode or "move",
          })
        end
        local ctrl = G3BoxStorage.__storageController
        if ctrl and input then
          local action = ctrl:handleInput(input)
          if action == "close" then
            G3BoxStorage.__storageController = nil
            if G3BoxStorage.close then
              G3BoxStorage.close()
            else
              local G3Stack = package and package.loaded and package.loaded["src.ui.game3.stack"]
              if G3Stack and G3Stack.has and G3Stack.has("box_storage") then
                G3Stack.pop("box_storage")
              end
            end
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

function ModernOverlay.drawMenu(game, state, vw, vh, theme, subState, viewport)
  if not state or not state.items then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local items = state.items or {}
  local numItems = #items
  if numItems == 0 then return end

  local curIdx = state.index or state.cursor or 1
  local title = state.title and tostring(state.title):upper()

  -- Viewport game canvas coordinates
  local gx = (type(viewport) == "table" and viewport.gameX) or math.max(0, math.floor((vw - 640) / 2))
  local gy = (type(viewport) == "table" and viewport.gameY) or math.max(0, math.floor((vh - 576) / 2))
  local gw = (type(viewport) == "table" and viewport.gameWidth) or (vw - gx * 2)
  local gh = (type(viewport) == "table" and viewport.gameHeight) or (vh - gy * 2)
  local scale = (type(viewport) == "table" and (viewport.scale or (viewport.gameWidth and viewport.gameWidth / 160))) or math.max(1, math.min(gw / 160, gh / 144))

  local tx = state.tx
  local ty = state.ty or 0

  -- Check if list has right-column tags (e.g. DexNav "GRASS 2-5", "SURF", "ROAM", "OWN", "SEEN")
  local hasBadges = false
  for _, it in ipairs(items) do
    if type(it) == "table" and it.right and tostring(it.right) ~= "" then
      hasBadges = true
      break
    end
  end
  local isDexNav = hasBadges or (title and title:find("DEXNAV") ~= nil)

  -- Pagination & Scrolling
  local maxVisible = state.rows or (ctx.isUltraCompact and 5 or (ctx.isCompact and 6 or 8))
  if numItems < maxVisible then maxVisible = numItems end
  if maxVisible < 1 then maxVisible = 1 end

  local scroll = state.scroll or 0
  if curIdx - 1 < scroll then
    scroll = curIdx - 1
  elseif curIdx - 1 >= scroll + maxVisible then
    scroll = curIdx - maxVisible
  end
  scroll = math.max(0, math.min(numItems - maxVisible, scroll))
  if state.scroll ~= nil then state.scroll = scroll end

  -- Dynamic responsive sizing adapting to content and device orientation
  local padX = ctx.isUltraCompact and 10 or (ctx.isCompact and 12 or 16)
  local itemH = ctx.isUltraCompact and 28 or (ctx.isCompact and 30 or 34)
  local itemGap = ctx.isUltraCompact and 3 or (ctx.isCompact and 4 or 6)
  local headerH = title and (ctx.isUltraCompact and 32 or 38) or 12
  local footerH = ctx.isUltraCompact and 18 or 24
  local footerExtra = (state.footer and tostring(state.footer) ~= "") and (ctx.isUltraCompact and 20 or 26) or 0

  local contentH = headerH + (maxVisible * itemH) + (math.max(0, maxVisible - 1) * itemGap) + footerH + footerExtra + 12
  local mh = contentH

  -- Measure text content width to auto-size card compactly
  local fontKind = ctx.isUltraCompact and "caption" or "button"
  local maxTextW = 0
  if title and #title > 0 then
    maxTextW = math.max(maxTextW, Layout.textWidth(title, ctx.isUltraCompact and "caption" or "headline"))
  end
  for _, it in ipairs(items) do
    local lbl = (type(it) == "table" and (it.label or it.name or it.text or it[1])) or tostring(it)
    local lblW = Layout.textWidth(tostring(lbl):upper(), fontKind)
    local rightVal = (type(it) == "table" and it.right and tostring(it.right) ~= "") and tostring(it.right) or nil
    if rightVal then
      local rightW = Layout.textWidth(tostring(rightVal):upper(), "tiny") + 16
      maxTextW = math.max(maxTextW, lblW + rightW + 24)
    else
      maxTextW = math.max(maxTextW, lblW)
    end
  end
  if state.footer and tostring(state.footer) ~= "" then
    maxTextW = math.max(maxTextW, Layout.textWidth(tostring(state.footer), "tiny"))
  end
  local hintW = Layout.textWidth((numItems > maxVisible) and "▲ ▼ Scroll    A Confirm    B Back" or "▲ ▼ Select    A Confirm", "tiny")
  maxTextW = math.max(maxTextW, hintW)

  local minW, maxW
  if isDexNav or hasBadges then
    minW = ctx.isUltraCompact and 240 or (ctx.isCompact and 280 or 320)
    maxW = ctx.isPortrait and math.min(vw - 24, 400) or math.min(vw - 48, 460)
  else
    minW = ctx.isUltraCompact and 150 or (ctx.isCompact and 170 or 190)
    maxW = ctx.isPortrait and math.min(vw - 32, 240) or math.min(vw - 48, 260)
  end
  local mw = math.max(minW, math.min(maxW, maxTextW + padX * 2 + 28))

  local mx, my
  local isLeftFlank = (tx ~= nil and tx <= 5)

  if ctx.isPortrait then
    if isLeftFlank then
      local dialogueY = math.min(vh - 160, math.floor(vh * 0.44))
      local safeTop = ctx.safeInsetTop or 48
      local leftDock = math.max(12, math.floor(gx + tx * 8 * scale + 4))
      local spriteLeftBound = math.floor(gx + (76 - 32) * scale)
      if spriteLeftBound > mw + 24 then
        mx = math.max(12, math.min(leftDock, spriteLeftBound - mw - 8))
      else
        mx = math.max(12, math.min(leftDock, vw - mw - 12))
      end
      local targetY = dialogueY - mh - 12
      my = math.max(safeTop + 8, math.min(vh - mh - 16, targetY))
    elseif tx ~= nil and tx > 5 then
      local dialogueY = math.min(vh - 160, math.floor(vh * 0.44))
      local safeTop = ctx.safeInsetTop or 48
      mx = math.min(vw - mw - 12, math.max(12, math.floor(gx + (tx + 1) * 8 * scale)))
      local targetY = dialogueY - mh - 12
      my = math.max(safeTop + 8, math.min(vh - mh - 16, targetY))
    else
      -- Centered modal (e.g. DexNav without tx)
      mx = math.floor((vw - mw) / 2)
      my = math.floor((vh - mh) / 2)
    end
  else
    -- On landscape:
    if isLeftFlank then
      local dConf = (theme.layout and theme.layout.dialogue) or { maxWidth = 740, height = 114, marginBottom = 24 }
      local dw = math.min(vw - (ctx.isCompact and 16 or 36), dConf.maxWidth or 740)
      local dh = (ctx.isUltraCompact) and 92 or (dConf.height or 114)
      local dx = math.floor((vw - dw) / 2)
      local marginBottom = (ctx.isUltraCompact) and 8 or (ctx.isCompact and 14 or (dConf.marginBottom or 24))
      local dialogueY = vh - dh - marginBottom
      mx = dx + 16
      local stageH = dialogueY
      local targetY = math.floor((stageH - mh) / 2)
      my = math.max(28, math.min(dialogueY - mh - 20, targetY))
    elseif tx ~= nil and tx > 5 then
      mx = math.min(vw - mw - 20, math.max(24, math.floor(gx + (tx + 1) * 8 * scale)))
      local targetY = math.floor(gy + ty * 8 * scale + 12)
      my = math.max(16, math.min(vh - mh - 16, targetY))
    else
      -- Centered modal (e.g. DexNav without tx)
      mx = math.floor((vw - mw) / 2)
      my = math.floor((vh - mh) / 2)
    end
  end

  -- Ensure within screen bounds
  if mx + mw > vw - 8 then mx = math.max(8, vw - mw - 8) end
  if my + mh > vh - 8 then my = math.max(8, vh - mh - 8) end
  if mx < 8 then mx = 8 end
  if my < 8 then my = 8 end

  -- Card container
  Layout.drawCard(mx, my, mw, mh, {
    color = theme.surface,
    borderColor = theme.borderStrong,
    borderWidth = 2,
    radius = theme.metrics and theme.metrics.radius.modal or 10,
  })

  -- Title Header
  local listStartY = my + headerH
  if title then
    Layout.drawText(title, mx + padX + 2, my + (ctx.isUltraCompact and 8 or 12), {
      font = ctx.isUltraCompact and "caption" or "headline",
      color = theme.heading,
      bold = true,
    })
    if numItems > maxVisible then
      local countStr = ("%d/%d"):format(curIdx, numItems)
      Layout.drawText(countStr, mx + mw - padX - 60, my + (ctx.isUltraCompact and 8 or 12), {
        font = "tiny",
        color = theme.textDim,
        align = "right",
        width = 56,
      })
    end
    Layout.drawSlot(mx + padX, my + headerH - 6, mw - padX * 2, 1.5, {
      color = theme.borderStrong or theme.border,
      borderColor = theme.accent,
      borderWidth = 0,
      radius = 1,
    })
  end

  -- Items List
  for vi = 1, maxVisible do
    local i = scroll + vi
    local it = items[i]
    if it then
      local lbl = (type(it) == "table" and (it.label or it.name or it.text or it[1])) or tostring(it)
      local rightVal = (type(it) == "table" and it.right and tostring(it.right) ~= "") and tostring(it.right) or nil
      local isSel = (i == curIdx)
      local iy = listStartY + (vi - 1) * (itemH + itemGap)
      local btnW = mw - padX * 2
      local alignMode = rightVal and "left" or "center"

      Layout.drawButton(mx + padX, iy, btnW, itemH, tostring(lbl):upper(), {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = fontKind,
        align = alignMode,
        padX = 14,
      })

      if rightVal then
        local badgeH = itemH >= 32 and 20 or 16
        local badgeY = iy + math.floor((itemH - badgeH) / 2)
        local badgeKind = isSel and "accent" or "ghost"
        if rightVal == "OWN" or rightVal:find("CAUGHT") then
          badgeKind = isSel and "good" or "accent"
        end
        local bw = Layout.textWidth(rightVal, "tiny") + 12
        Layout.drawBadge(mx + padX + btnW - bw - 8, badgeY, rightVal, {
          kind = badgeKind,
          font = "tiny",
          height = badgeH,
        })
      end
    end
  end

  -- Scroll indicators
  if scroll > 0 then
    Layout.drawText("▲", mx + mw - padX - 16, listStartY - 10, {
      font = "tiny",
      color = theme.accent or theme.heading,
    })
  end
  if scroll + maxVisible < numItems then
    Layout.drawText("▼", mx + mw - padX - 16, listStartY + maxVisible * (itemH + itemGap) - itemGap - 2, {
      font = "tiny",
      color = theme.accent or theme.heading,
    })
  end

  -- Optional footer note (e.g. "No Old/Good Rod.")
  if state.footer and tostring(state.footer) ~= "" then
    Layout.drawText(tostring(state.footer), mx + padX, my + mh - footerH - footerExtra + 4, {
      font = "tiny",
      color = theme.accent or theme.heading,
      align = "center",
      width = mw - padX * 2,
    })
  end

  -- Helper hint
  local hintText = (numItems > maxVisible) and "▲ ▼ Scroll    A Confirm    B Back" or "▲ ▼ Select    A Confirm"
  Layout.drawText(hintText, mx + padX, my + mh - footerH + 4, {
    font = "tiny",
    color = theme.textDim,
    align = "center",
    width = mw - padX * 2,
  })
end

-- Checks if a state is supported by the modern overlay
function ModernOverlay.isSupported(state)
  if not state or type(state) ~= "table" then return false end
  local id = state.screenId

  -- Explicit pass-through states (native engine rendering / video cutscenes / alert splashes)
  if id == "SlotMachine" or state.isSlotMachine
     or id == "CardFlip" or state.isCardFlip
     or id == "UnownPuzzle" or state.isUnownPuzzle
     or id == "QuestLog" or id == "Game3QuestLog" or state.isQuestLog
     or id == "IntroMovie" or id == "Game3IntroMovie" or state.isIntroMovie
     or id == "TitleScreen" or id == "Game3TitleScreen" or id == "TitleRse" or state.isTitleScreen
     or id == "ResetRtcScreen" or id == "BerryFixScreen" or id == "ClearSaveScreen"
     or id == "WirelessDirectScreen" or id == "MysteryEventScreen" or id == "RecordCornerScreen"
     or state.isRtcWarning or state.isBatteryWarning or state.isClearSaveScreen then
    return false
  end

  -- Custom mod-registered screens (via PublicApi.registerScreen)
  local PublicApi = package.loaded["mods.omni_ui.api.PublicApi"]
  if PublicApi and PublicApi.customScreens then
    for customKind, screenDef in pairs(PublicApi.customScreens) do
      if (screenDef.match and screenDef.match(state)) or (screenDef.screenId and screenDef.screenId == id) or (id == customKind) then
        return "custom_" .. customKind, screenDef
      end
    end
  end

  -- Legacy v1 match check first (KR UsefulBag / KantoSummary)
  for _, contract in pairs(LegacyV1Shim.registeredAdapters) do
    if contract.screens then
      for kind, screenDef in pairs(contract.screens) do
        if screenDef.match and screenDef.match(state) then
          return "legacy_" .. kind, screenDef
        end
      end
    end
  end

  if id == "PartyMenu" or id == "Gen2PartyMenu" or id == "Game3PartyMenu" or id == "party" or state.isPartyMenu
     or (state.party and state.partyMons)
     or (state._party ~= nil and (state.ACTIONS ~= nil or state.actionCursor ~= nil or state.switchFrom ~= nil))
     or state == package.loaded["src.ui.game3.party_menu"] then
    return "party"
  end
  if id == "SummaryMenu" or id == "Gen2SummaryMenu" or id == "Game3SummaryMenu" or id == "summary"
     or (state.mon ~= nil and (state.page ~= nil or state._expMaxPage ~= nil))
     or state.isSummaryMenu or state.PINK_PAGE or state.statPlacements
     or (state.PAGE_INFO ~= nil or (state._party ~= nil and state._page ~= nil))
     or state == package.loaded["src.ui.game3.summary_menu"] or state == package.loaded["src.ui.game3.rse.summary_menu"] then
    return "summary"
  end
  if id == "PlayerPC" or id == "ItemPcMenu" or id == "Gen2ItemPcMenu" or id == "player_pc" or id == "item_pc" or id == "rse_item_storage" or state.isPlayerPC or state.kind == "pc_item_deposit" or state.kind == "pc_item_withdraw" or state.kind == "pc_item_toss" or (state.pcItems and not state.pockets)
     or state == package.loaded["src.ui.game3.item_pc"]
     or state == package.loaded["src.ui.game3.rse.item_storage"] then
    return "player_pc"
  end
  if id == "BoxMenu" or id == "Gen2BoxMenu" or id == "Gen2PcMenu" or id == "box_storage" or id == "BoxStorageUI" or state.isBoxMenu or state.boxStorage or state.kind == "pc_box_withdraw" or state.kind == "pc_box_deposit" or state.kind == "pc_box_change" or (state.boxes and state.currentBox)
     or state == package.loaded["src.ui.game3.box_storage_ui"] then
    return "storage"
  end
  if id == "PcMenu" or id == "CenterPcMenu" or id == "Gen2CenterPcMenu" or id == "pc_menu" or id == "pc" or state.isPcMenu or state.isCenterPcMenu
     or (state.entries and type(state.entries) == "table" and #state.entries >= 2 and state.entries[1] and (
          tostring(state.entries[1].label or state.entries[1].id or ""):upper():find("BILL") ~= nil
          or tostring(state.entries[1].label or state.entries[1].id or ""):upper():find("PC") ~= nil
          or tostring(state.entries[1].label or state.entries[1].id or ""):upper():find("SOMEONE") ~= nil
          or tostring(state.entries[1].label or state.entries[1].id or ""):upper():find("WITHDRAW") ~= nil
        ))
     or (state.items and type(state.items) == "table" and #state.items >= 2 and (
          (type(state.items[1]) == "table" and type(state.items[1].label) == "string" and (
            state.items[1].label:upper():find("PC") ~= nil or state.items[1].label:upper():find("BILL") ~= nil or state.items[1].label:upper():find("SOMEONE") ~= nil or state.items[1].label:upper():find("LANETTE") ~= nil
          ))
          or (state.items[#state.items] and type(state.items[#state.items]) == "table" and type(state.items[#state.items].label) == "string" and (
            state.items[#state.items].label:upper():find("LOG OFF") ~= nil or state.items[#state.items].label:upper():find("TURN OFF") ~= nil
          ))
        ))
     or state == package.loaded["src.ui.game3.pc_menu"] then
    return "pc_hub"
  end
  if id == "ShopBuyMenu" or (state.items and state.dialogue and (state.price or (type(state.items) == "table" and type(state.items[1]) == "table" and state.items[1].price))) then
    return "shop"
  end
  if id == "BagMenu" or id == "Gen2PackMenu" or id == "Game3BagMenu" or id == "bag" or state.kind == "bag" or state.isBag or state.isPackMenu or state.location == "shop" or state.sellMode or state._sellMode or (state.mode == "sell") or (state.items and (state.__pocketIndex or state.isPackMenu or state.pocketIndex)) or (state.pocketIndex and state.pockets)
     or (state.POCKET_KEYS ~= nil or (state.pocketIdx ~= nil and state.currentPocket ~= nil))
     or state == package.loaded["src.ui.game3.bag_menu"] or state == package.loaded["src.ui.game3.rse.bag_menu"] then
    if state.mode == "buy" or (type(state.items) == "table" and type(state.items[1]) == "table" and state.items[1].price and not state.items[1].count) then
      return "shop"
    end
    return "bag"
  end
  if id == "ShopMenu" or id == "Gen2MartMenu" or id == "MartMenu" or id == "Game3ShopMenu" or id == "shop" or state.isShopMenu or state.isMartMenu or (state.items and state.dialogue and (state.price or state.money))
     or state == package.loaded["src.ui.game3.shop_menu"] or state == package.loaded["src.ui.game3.rse.shop_menu"] then
    if state.mode == "sell" or (type(state.items) == "table" and type(state.items[1]) == "table" and state.items[1].count and not state.items[1].price) then
      return "bag"
    end
    return "shop"
  end
  if id == "StartMenu" or id == "Gen2StartMenu" or id == "Game3StartMenu" or id == "StartMenuFRLG" or id == "start_menu" or id == "start"
     or state.startCloses or state.isStartMenu or (state.items and state.anchor == "topright") or (state.availability and state.contest ~= nil) or (state.ENTRIES and state.open ~= nil)
     or (state.items and state.showDescription ~= nil) or (state.items and state.unlocked and state.visibleItems)
     or (package.loaded["src.ui.gen2.StartMenu"] and getmetatable(state) == package.loaded["src.ui.gen2.StartMenu"])
     or state == package.loaded["src.ui.game3.start_menu"] or state == package.loaded["src.ui.game3.start_menu_frlg"] then
    return "start_menu"
  end
  if id == "Pokegear" or id == "Gen2Pokegear" or state.isPokegear or state.isGen2Pokegear or (state.cards and (state.drawRadio or state.drawPhone or state.drawClock or state.drawMap or state.tuningKnob ~= nil or state.phoneScroll ~= nil)) then
    return "pokegear"
  end
  if id == "TrainerCard" or id == "Gen2TrainerCard" or id == "Game3TrainerCard" or id == "trainer_card" or (state.badges and state.faces) or state._card ~= nil or state.isTrainerCard or state.johtoBadges
     or state == package.loaded["src.ui.game3.trainer_card"] then
    return "trainer_card"
  end
  if id == "PokedexMenu" or id == "Gen2PokedexMenu" or id == "Game3PokedexMenu" or id == "DexEntryMenu" or id == "pokedex" or id == "rse_pokedex" or id == "rs_pokedex" or state.isPokedexMenu or state._dex ~= nil or state.dex ~= nil or state.dexMode ~= nil or state.modeIndex ~= nil or (state.rowsAt and state.scroll ~= nil and state.index ~= nil and not state.mon) or (state.def and (state.species or state.pageCount)) or state.unownMode or (type(state.view) == "string" and (state.view == "list" or state.view == "entry" or state.view == "area" or state.view == "option" or state.view == "search" or state.view == "results" or state.view == "unown"))
     or state.currentCategory ~= nil or state.currentOrder ~= nil
     or state == package.loaded["src.ui.game3.pokedex"] or state == package.loaded["src.ui.game3.rse.pokedex"] or state == package.loaded["src.ui.game3.rs.pokedex"]
     or (package.loaded["src.ui.game3.rse.pokedex"] and (state == package.loaded["src.ui.game3.rse.pokedex"].Host or (package.loaded["src.ui.game3.rse.pokedex"].active and state == package.loaded["src.ui.game3.rse.pokedex"].active()))) then
    return "pokedex"
  end
  if id == "OptionsMenu" or id == "Gen2OptionsMenu" or id == "Game3OptionsMenu" or id == "option" or id == "options" or state.isOptionsMenu or (state.options ~= nil and (state.rows ~= nil or (type(state.options) == "table" and (state.options.textSpeed ~= nil or state.options.battleEffects ~= nil or state.options.frame ~= nil or state.options.menuAccount ~= nil or state.options.musicVol ~= nil)))) or (type(state.view) == "table" and state.scroll ~= nil and state.index ~= nil and not state.mon and not state.party and not state.items)
     or state == package.loaded["src.ui.game3.option_menu"] or state == package.loaded["src.ui.game3.rse.option_menu"] then
    return "options"
  end
  if id == "rse_pokenav" or id == "rs_pokenav" or id == "pokenav" or id == "Pokenav" or state.isPokenav
     or state.ID == "rse_pokenav" or state.ID == "rs_pokenav"
     or (state._matchCallList ~= nil or state.cardIndex ~= nil or state.condMonSel ~= nil)
     or (state.nav and state.shell and state.detail)
     or (state.leftMain and state.leftSub)
     or (package.loaded["src.ui.game3.rse.pokenav.init"] and (state == package.loaded["src.ui.game3.rse.pokenav.init"].Host or (package.loaded["src.ui.game3.rse.pokenav.init"].active and state == package.loaded["src.ui.game3.rse.pokenav.init"].active())))
     or (package.loaded["src.ui.game3.rs.pokenav.init"] and (state == package.loaded["src.ui.game3.rs.pokenav.init"].Host or (package.loaded["src.ui.game3.rs.pokenav.init"].active and state == package.loaded["src.ui.game3.rs.pokenav.init"].active()))) then
    return "pokenav"
  end
  if id == "TownMap" or id == "region_map" or id == "rse_region_map" or state.isTownMap or state.nestSpecies ~= nil or (state.locs and state.byMap and state.bg)
     or state == package.loaded["src.ui.game3.region_map"] or state == package.loaded["src.ui.game3.rse.region_map"] then
    return "town_map"
  end
  local isNamePick = (id == "Gen2NamePick" or id == "NamePick" or state.isNamePick)
     or (not (state.isMenu or id == "Menu") and state.items and (state.cursor ~= nil or state.index ~= nil) and (
          state.openNaming ~= nil
          or (state.picX ~= nil and state.gender ~= nil)
        ))
  if isNamePick then
    return "name_pick"
  end
  if id == "NamingScreen" or id == "Gen2NamingScreen" or id == "Game3NamingScreen" or id == "Game3Naming" or id == "Naming" or state.isNamingScreen or (state.glyphs and state.maxLen) or (type(state.text) == "string" and state.maxLength and state.deleteCharacter) or (state.buffer and state.template) or (type(state._state) == "table" and state._state.template) then
    if state.choosing then
      return nil
    end
    return "naming"
  end
  if id == "MoveLearnMenu" or id == "MoveSelectMenu" or state.isMoveLearnMenu or (type(state.mon) == "table" and state.mon.moves and (state.newMoveId or state.selecting ~= nil or state.askForget)) then
    return "move_learn"
  end
  if id == "PrizeCounter" or state.isPrizeCounter or (state.prizes and state.drawWindow) then
    return "prize_counter"
  end
  if id == "SaveMenu" or id == "Gen2SaveMenu" or id == "Game3SaveMenu" or id == "save" or state.isSaveMenu or (state.openPrompt ~= nil and state.holdsUIAnchors) or (state._phase and (state.save or state.saveData or state.saveStatus or state.flagStore ~= nil or state.countBadges ~= nil)) or (state.phase ~= nil and (state.writer ~= nil or state.writeNow ~= nil or state.yesNoVisible ~= nil or (state.choice ~= nil and state.existed ~= nil)))
     or state == package.loaded["src.ui.game3.save_menu"] then
    return "save"
  end
  if id == "ManagerState" or id == "ModManager" or id == "mod_manager" or state.isManagerState or (state._mgr and (state._mgr.status or state._mgr.screenId == "ManagerState")) or (state.status and state.tab and state.byId) or (state.status and state.screen and state.stagedList) then
    return "mod_manager"
  end
  if id == "TextBox" or id == "Game3Message" or id == "Message" or state.isTextBox or state.isGame3Message or (state.pages and state.shown) or state.shownSource or (state.line1Y and state.boxTy and not state.list) or (state._pages and state._revealed ~= nil) then
    return "dialogue"
  end
  if id == "ChoiceBox" or id == "Gen2ChoiceBox" or id == "Game3Choice" or id == "Choice" or state.isChoiceBox or state.isGame3Choice or (state.labels and (state.onChoose or state.firstItem or state.index or state.tx ~= nil or state.th ~= nil)) or (state.onChoose and state.labels) or (state.active and state.options and state.cursor and state.cols ~= nil) then
    return "choice"
  end
  if id == "QuantityBox" or state.isQuantityBox or (state.qty and state.max and state.onDone) then
    return "quantity"
  end
  if id == "PicBox" or state.isPicBox or (state.image and type(state.text) == "string" and state.update) then
    return "pic_box"
  end
  if id == "QuarantineReport" or state.isQuarantineReport or (state.report ~= nil and state.maxOffset ~= nil) or (state.lines and state.report) then
    return "load_report"
  end
  if id == "BattleState" or id == "Gen2BattleState" or id == "Game3BattleState" or state.isBattleState or state.isBattle or state.isGen2BattleState or (state.player and state.enemy and (state.shownHP ~= nil or state.actionIndex ~= nil or state.turnCount ~= nil or state.animActive ~= nil)) then
    return "battle"
  end
  if id == "EvolutionState" or id == "EvolutionAnim" or id == "Gen2Evolution" or state.isEvolution or (state.mon and state.newSpecies and state.via) then
    return "evolution"
  end
  if id == "HallOfFame" or state.isHallOfFame or state.showHofBanner ~= nil or (state.phase and (state.phase == "mons" or state.phase == "player_stats" or state.phase == "player_dex" or state.phase == "player_rating")) then
    return "hall_of_fame"
  end
  if state == package.loaded["src.ui.game3.hall_of_fame"] and state.open == true then
    return "hall_of_fame"
  end
  if state == package.loaded["src.ui.game3.hall_of_fame_pc"] and state.open == true then
    return "league_pc"
  end
  local frlgRelearner = package.loaded["src.ui.game3.move_relearner"]
  local rseRelearner = package.loaded["src.ui.game3.rse.move_relearner"]
  if state.open == true and (state == frlgRelearner or state == rseRelearner) then
    return "move_learn"
  end
  if id == "LeaguePC" or id == "league_pc" or state.isLeaguePC or (state.teams and state.teamIndex and state.monIndex) then
    return "league_pc"
  end
  if id == "Diploma" or state.isDiploma or (state.onDone and state.render and state.game and not state.items) then
    return "diploma"
  end
  if id == "FlyMenu" or state.isFlyMenu or (state.title and type(state.title) == "string" and state.title:upper():find("FLY") and state.items) then
    return "fly_menu"
  end
  if id == "MainMenu" or id == "Gen2MainMenu" or id == "Game3MainMenu" or id == "MainMenuRse" or state.isMainMenu or state.isTitleMenu
     or (state.list and (state.clockParts or state.drawSavePanel or state.drawClockBox or state.confirmDelay ~= nil or state.onContinue ~= nil))
     or (state.titleUiBox and state.items and state.onCancel)
     or (state.titleUiBox and state.save and state.title)
     or (state.phase == "menu" and state.menuIndex and (state.saveStatus ~= nil or state.menuFade ~= nil or state.hasContinue ~= nil))
     or (state.items and (state.menuType ~= nil or state.hasContinue ~= nil or state._fixScroll ~= nil))
     or (state.cycleSpecies and state.menuOpen)
     or (state.menuIndex ~= nil and (state.hasContinue ~= nil or state.continueInfo ~= nil))
     or (state.phase == "menu" and state.menuIndex ~= nil) then
    return "main_menu"
  end
  if id == "StatBox" or id == "Gen2StatBox" or state.isStatBox or (type(state.mon) == "table" and (state.keepOpen ~= nil or state.onDone) and state.mon.stats and not state.party and not state.items and not state.moves and not state.pockets) then
    return "stat_box"
  end
  if id == "BankOfMom" or id == "Gen2BankOfMom" or state.isBankOfMom or (state.saved ~= nil and state.held ~= nil and (state.kind == "deposit" or state.kind == "withdraw")) then
    return "bank_of_mom"
  end
  if id == "BuenaPassword" or id == "Gen2BuenaPassword" or state.isBuenaPassword or (state.words and (state.mode == "password" or state.mode == "prize")) or (state.prizes and state.balance ~= nil) then
    return "buena_password"
  end
  if id == "ElevatorMenu" or id == "Gen2ElevatorMenu" or state.isElevatorMenu or (state.floors and (state.origin ~= nil or state.floorNames ~= nil)) then
    return "elevator"
  end
  if id == "DecorationMenu" or id == "Gen2DecorationMenu" or state.isDecorationMenu or (state.categories and (state.mode == "category" or state.mode == "items" or state.mode == "side")) then
    return "decoration"
  end
  if id == "TradeMenu" or id == "Gen2TradeMenu" or state.isTradeMenu or (state.row and (state.say or state.ask or state.confirm or state.picking or state.animating)) then
    return "trade"
  end
  if id == "ContestMenu" or id == "Gen2ContestMenu" or state.isContestMenu or (state.stock and state.caught and (state.choice ~= nil or state.answer)) then
    return "contest"
  end
  if id == "HeldItemMenu" or id == "Gen2HeldItemMenu" or state.isHeldItemMenu or (state.slot and (state.giveItem or state.takeItem or (state.items and state.index and not state.pockets and not state.floors))) then
    return "held_item"
  end
  if id == "DayCareMenu" or id == "Gen2DayCareMenu" or state.isDayCareMenu or (state.side and (state.startWithdraw or state.takeMon or state.startOutside or state.startIntro or state.scriptVar ~= nil)) then
    return "daycare"
  end
  if id == "MoveDeleter" or id == "Gen2MoveDeleter" or state.isMoveDeleter or (state.list and state.row and state.moves and not state.pocketIndex and not state.boxes and not state.categories and not state.floors) then
    return "move_deleter"
  end
  if id == "MailRead" or id == "Gen2MailRead" or id == "MailMenu" or id == "Gen2MailMenu" or state.isMailRead or state.isMailMenu or (state.entry and (state.authorColumn or state.drawPanel)) then
    return "mail"
  end
  if id == "MailboxMenu" or id == "Gen2MailboxMenu" or state.isMailboxMenu or (state.box and state.readMail and state.putInPack) then
    return "mailbox"
  end
  if id == "MailCompose" or id == "Gen2MailCompose" or state.isMailCompose or (type(state.text) == "string" and state.MAIL_INPUT_UPPER and state.toggleCase) then
    return "mail_compose"
  end
  if id == "InitClock" or id == "Gen2InitClock" or id == "WallClock" or id == "Game3WallClock" or state.isInitClock or state.isWallClock
     or (state.hour ~= nil and state.minute ~= nil and state.phase)
     or (type(state.t) == "table" and state.t.minuteAngle ~= nil and (state.pm or state.am or state.frameType or state.confirm ~= nil))
     or (type(state._clock) == "table" and type(state._clock.t) == "table" and state._clock.t.minuteAngle ~= nil) then
    return "clock_setup"
  end
  if id == "StarterChoose" or id == "Game3StarterChoose" or state.isStarterChoose
     or (state.balls and state.hand and state.selection ~= nil)
     or (type(state._screen) == "table" and state._screen.balls and state._screen.hand) then
    return "starter_choose"
  end
  if id == "GenderSelect" or id == "Gen2GenderSelect" or state.isGenderSelect or (state.cursor and state.chosen ~= nil and state.menuOpen) or (type(state.text) == "string" and state.text:find("boy") and state.OPTIONS) then
    return "gender_select"
  end
  if id == "BattleTowerMenu" or id == "Gen2BattleTowerMenu" or state.isBattleTowerMenu or (state.rows and state.levelLabel and state.confirm) then
    return "battle_tower"
  end
  if id == "CallerBox" or id == "Gen2CallerBox" or state.isCallerBox or (state.name ~= nil and state.className ~= nil and not state.items) then
    return "caller_box"
  end
  -- Route DexNav / Encounter Radar / Route Monitor tools (Kanto-Reforged ExpDexNav, ExampleDexNav, etc.)
  if id == "ExpDexNav" or id == "ExampleDexNav"
     or (state.title and type(state.title) == "string" and state.title:upper():find("DEXNAV"))
     or (state.title and type(state.title) == "string" and state.title:upper():find("ROAMING RADAR"))
     or (state.kind and type(state.kind) == "string" and state.kind:upper():find("DEXNAV")) then
    return "dexnav"
  end

  -- Exclude ListMenu from generic Menu matching (e.g. FlyMenu, or custom list screens)
  local isListMenu = (state.scroll ~= nil and (state.onChoose ~= nil or state.rows ~= nil or state.pageJump ~= nil or state.listPrompt ~= nil or state.footer ~= nil or state.arrowBlink ~= nil or state.cursorBlank ~= nil or state.wrap ~= nil or state.hold ~= nil))
    or (package.loaded["src.ui.ListMenu"] and getmetatable(state) == package.loaded["src.ui.ListMenu"])
  if not isListMenu then
    if id == "Menu" or (state.isMenu and not state._mgr) or (state.items and (state.index ~= nil or state.tx ~= nil or state.title ~= nil or state.cancelable ~= nil or state.itemY ~= nil or state.onSelect ~= nil)) then
      return "menu"
    end
  end

  return false
end

function ModernOverlay.attachSaveControls(state, game)
  if not state or state.__omniUiSaveAttached then return end
  local isGen3Save = (state == (package and package.loaded and package.loaded["src.ui.game3.save_menu"]) or (state.open ~= nil and state.saveState ~= nil))
  if isGen3Save then return end
  state.__omniUiSaveAttached = true
  local baseUpdate = state.update
  state.update = function(self, dt)
    if type(self) ~= "table" then
      dt = self
      self = state
    end
    self = (type(self) == "table" and self) or state
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

function ModernOverlay.attachStartMenuControls(state, game)
  if not state or state.__omniUiStartAttached then return end
  local isGen3Start = (state == (package and package.loaded and (package.loaded["src.ui.game3.start_menu"] or package.loaded["src.ui.game3.start_menu_frlg"])) or state.ENTRIES ~= nil)
  if isGen3Start then return end
  state.__omniUiStartAttached = true
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

local function playMainMenuSelectSound(self, g)
  if self and self.playSfx then
    pcall(self.playSfx, self, "Sfx_ReadText2")
  elseif g and g.data then
    pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end)
  else
    local okKit, Kit = pcall(require, "src.ui.game3.rse.scene_kit")
    if okKit and Kit and Kit.playSe then
      pcall(Kit.playSe, "SE_SELECT")
    else
      local okAudio, Audio = pcall(require, "src.core.game3.audio")
      local okSE, SE = pcall(require, "src.core.game3.se_ids")
      if okAudio and Audio and Audio.playSe and okSE and SE and SE.SE_SELECT then
        pcall(Audio.playSe, SE.SE_SELECT)
      end
    end
  end
end

local function isContinueSelected(self)
  if not self then return false end
  -- 1. Gen 3 items table (e.g. {"CONTINUE", "NEW_GAME", "OPTION", "EXIT"})
  if self.items and type(self.items) == "table" then
    local idx = self.cursor or self.index or self.menuIndex or 1
    local sel = self.items[idx]
    if type(sel) == "string" and sel:upper():find("CONTINUE") then
      return true
    elseif type(sel) == "table" and sel.label and tostring(sel.label):upper():find("CONTINUE") then
      -- If item has its own onSelect handler (e.g. Gen 1 Menu opening ContinueInfo), let it run naturally
      if type(sel.onSelect) == "function" then
        return false
      end
      return true
    end
  end
  -- 2. Gen 3 FRLG boot state
  if self.menuIndex and (self.hasContinue or self.continueInfo) then
    if self.menuIndex == 1 then
      return true
    end
  end
  -- 3. Gen 2 list items
  if self.list and self.list.items then
    local idx = self.list.index or 1
    local item = self.list.items[idx]
    if item and (item.id == "continue" or (item.label and tostring(item.label):upper():find("CONTINUE"))) then
      return true
    end
  end
  -- 4. Gen 1 ContinueInfo substate
  if self.titleUiBox and self.save then
    return true
  end
  return false
end

function ModernOverlay.attachMainMenuControls(state, game)
  if not state or state.__omniUiMainMenuAttached then return end
  state.__omniUiMainMenuAttached = true
  if state.confirmChoice == nil then state.confirmChoice = 1 end
  local baseUpdate = state.update
  state.update = function(self, arg1, arg2, ...)
    local input = (type(arg1) == "table" and type(arg1.wasPressed) == "function" and arg1)
      or (type(arg2) == "table" and type(arg2.wasPressed) == "function" and arg2)
      or (self.game and self.game.input)
      or (game and game.input)
      or (package.loaded["src.core.Game3"] and package.loaded["src.core.Game3"].input)
      or (package.loaded["src.core.Game"] and package.loaded["src.core.Game"].input)

    local inConfirm = (self.phase == "confirm" or self.isConfirm == true or self._confirming == true)

    if input and inConfirm then
      if self.confirmChoice == nil then self.confirmChoice = 1 end
      if input:wasPressed("left") or input:wasPressed("right") or input:wasPressed("up") or input:wasPressed("down") then
        self.confirmChoice = (self.confirmChoice == 1) and 2 or 1
        playMainMenuSelectSound(self, self.game or game)
        return nil
      elseif input:wasPressed("b") then
        self.phase = "menu"
        self.isConfirm = false
        self._confirming = false
        playMainMenuSelectSound(self, self.game or game)
        return nil
      elseif input:wasPressed("a") then
        playMainMenuSelectSound(self, self.game or game)
        if (self.confirmChoice or 1) == 2 then
          self.phase = "menu"
          self.isConfirm = false
          self._confirming = false
          return nil
        else
          self.phase = "menu"
          self.isConfirm = false
          self._confirming = false
          -- Execute Continue based on engine version
          if self.onContinue then
            self.onContinue(self.save)
            return nil
          end
          if self.items and type(self.items) == "table" and self.items[self.index or 1] and type(self.items[self.index or 1].onSelect) == "function" then
            self.items[self.index or 1].onSelect()
            return nil
          end
          local title = self.title
          if not (title and title.onContinue) and self.game and self.game.stack and self.game.stack.states then
            for _, st in ipairs(self.game.stack.states) do
              if st and st.onContinue then
                title = st
                break
              end
            end
          end
          if title and title.onContinue then
            if self.game and self.game.stack then
              self.game.stack:pop()
              local okTrans, Transition = pcall(require, "src.render.Transition")
              if okTrans and Transition and Transition.whiteFlash then
                self.game.stack:push(Transition.whiteFlash(self.game, 33, function()
                  if title and title.onContinue then title.onContinue() end
                end))
              else
                title.onContinue()
              end
            else
              title.onContinue()
            end
            return nil
          elseif self.items and (self.cursor or self.state) then
            return { action = "continue" }
          elseif self.menuIndex and (self.hasContinue or self.continueInfo) then
            return { action = "continue" }
          else
            return { action = "continue" }
          end
        end
      end
      return nil
    elseif input and not inConfirm then
      if input:wasPressed("a") then
        if isContinueSelected(self) then
          local canOpenConfirm = true
          if self.state and self.state ~= "input" then
            canOpenConfirm = false
          end
          if self.pal and type(self.pal.fadeActive) == "function" and self.pal:fadeActive() then
            canOpenConfirm = false
          end
          if canOpenConfirm then
            self.phase = "confirm"
            self.isConfirm = true
            self._confirming = true
            self.confirmChoice = 1
            if self.step and type(self.step.pending) == "table" then
              self.step.pending["a"] = nil
            end
            playMainMenuSelectSound(self, self.game or game)
            return nil
          end
        end
      end
    end

    if baseUpdate then
      return baseUpdate(self, arg1, arg2, ...)
    end
  end

  local origChoose = state.choose
  if origChoose then
    state.choose = function(self, value)
      origChoose(self, value)
      if value == "continue" then
        self.phase = "confirm"
        self.isConfirm = true
        self._confirming = true
        self.confirmChoice = 1
      end
    end
  end
end

function ModernOverlay.attachControls(state, game)
  if not state then return end
  local kind = ModernOverlay.isSupported(state)
  if kind == "save" then
    if ModernOverlay.attachSaveControls then ModernOverlay.attachSaveControls(state, game) end
  elseif kind == "start_menu" then
    if ModernOverlay.attachStartMenuControls then ModernOverlay.attachStartMenuControls(state, game) end
  elseif kind == "main_menu" then
    if ModernOverlay.attachMainMenuControls then ModernOverlay.attachMainMenuControls(state, game) end
  elseif kind == "dialogue" then
    if ModernOverlay.attachDialogueControls then ModernOverlay.attachDialogueControls(state, game) end
  elseif kind == "load_report" then
    if ModernOverlay.attachLoadReportControls then ModernOverlay.attachLoadReportControls(state, game) end
  elseif kind == "pokegear" then
    if ModernOverlay.attachPokegearControls then ModernOverlay.attachPokegearControls(state, game) end
  elseif kind == "naming" then
    local okNR, NamingRenderer = pcall(require, "mods.omni_ui.renderers.NamingRenderer")
    if okNR and NamingRenderer and NamingRenderer.attachControls then
      NamingRenderer.attachControls(state, game)
    end
  end
end

-- Helper to find active underlying screen if top is a popup/choice box
function ModernOverlay.getActiveScreen(game)
  if game then ModernOverlay.currentGame = game end
  -- 1. Gen 1 / Gen 2 Game (game.stack)
  if game and game.stack and game.stack.top then
    local states = game.stack.states or {}

    -- Check if there is an active save screen on the stack
    for i = #states, 1, -1 do
      local s = states[i]
      if s and ModernOverlay.isSupported(s) == "save" then
        local topSub = (i < #states) and states[#states] or nil
        return "save", s, nil, topSub
      end
    end

    -- If top state on stack is an independent screen that is not supported by ModernOverlay,
    -- do NOT fall through to dormant underlying menus (e.g. StartMenu under ExpDexNav or FlyMenu).
    if #states > 1 then
      local topState = states[#states]
      local topKind = ModernOverlay.isSupported(topState)
      if not topKind then
        local isChildModal = (topState.isChoiceBox or topState.onChoose or topState.labels)
          or (topState.isTextBox or topState.shownSource or (topState.pages and topState.shown))
          or (topState.isQuantityBox or (topState.qty and topState.max))
          or (topState.isStatBox or (topState.baseStats and topState.deltas))
          or (topState.titleUiBox and topState.save)
          or (topState.isMenu and topState.tx and topState.th and topState.th < 14 and not topState.scroll)
        if not isChildModal then
          return nil
        end
      end
    end

    for i = #states, 1, -1 do
      local s = states[i]

      -- Handle ContinueInfo substate on top of MainMenu
      if s and s.titleUiBox and s.save and s.title and not s.items then
        local parentMenu = states[i - 1] or states[1]
        return "main_menu", parentMenu, nil, s
      end

      local kind, extra = ModernOverlay.isSupported(s)
      if kind then
        -- If kind is dialogue, choice, quantity, menu, or stat_box modal, check if there is an underlying parent menu or dialogue
        if (kind == "dialogue" or kind == "choice" or kind == "quantity" or kind == "menu" or kind == "stat_box") and i > 1 then
          for p = i - 1, 1, -1 do
            local pk, pe = ModernOverlay.isSupported(states[p])
            if pk and pk ~= "dialogue" and pk ~= "choice" and pk ~= "quantity" and pk ~= "menu" and pk ~= "stat_box" then
              return pk, states[p], pe, (states[#states] or s)
            elseif pk == "dialogue" then
              -- Underlying dialogue state (e.g. TextBox under a ChoiceBox)
              return "dialogue", states[p], pe, (states[#states] or s)
            end
          end
        end

        -- If kind is choice but no underlying supported screen, render as dialogue modal
        if kind == "choice" then
          return "dialogue", s, extra, (i < #states and states[#states] or nil)
        end

        -- If kind is main_menu and this state doesn't have items but an earlier state does
        if kind == "main_menu" and not s.items and not s.entries and i > 1 then
          for p = i - 1, 1, -1 do
            if states[p] and (states[p].items or states[p].entries) then
              return "main_menu", states[p], extra, s
            end
          end
        end
        return kind, s, extra, (i < #states and states[#states] or nil)
      end
    end
    if states[1] and states[1].cycleSpecies and states[1].menuOpen then
      return "main_menu", (states[2] or states[1]), nil, (states[3] or (states[2] ~= states[1] and states[2] or nil))
    end
    return nil
  end

  -- 2. Gen 3 Boot Phase (Game3 boot / Main Menu / Intro)
  if game and game.phase == "boot" and game.boot then
    local b = game.boot
    local bPhase = b.phase
    if bPhase == "menu" or bPhase == "main_menu" then
      if b.custom and b.custom.menu then
        local k, extra = ModernOverlay.isSupported(b.custom.menu)
        return k or "main_menu", b.custom.menu, extra, nil
      else
        local k, extra = ModernOverlay.isSupported(b)
        return k or "main_menu", b, extra, nil
      end
    elseif bPhase == "oak" or bPhase == "new_game" or (b.custom and b.custom.newGame) or b.newGame then
      local speech = (b.custom and b.custom.newGame) or b.newGame
      if speech then
        -- Check naming first
        local Naming = package.loaded["src.ui.game3.naming"]
        local isNamingOpen = (Naming and ((Naming.isOpen and Naming.isOpen() == true) or Naming.openFlag == true or (Naming._state and Naming._state.template)))
        local isBirchNamingActive = speech.naming and (speech.naming.stage ~= "return_hold" and speech.naming.stage ~= "fade_out")
        if (speech.naming and isBirchNamingActive) or isNamingOpen then
          local namingState = (Naming and Naming._state) or (speech.naming and speech.naming.data) or speech.naming
          return "naming", namingState, nil, nil
        end

        local isRse = (speech.sprites and speech.sprites.birch ~= nil) or (speech.showDialogue ~= nil)
        local isFrlg = (speech.win and (speech.win.dialog ~= nil or speech.win.menu ~= nil)) or (speech.assets and speech.assets.oakSprite ~= nil)

        if isRse then
          local choiceSubState = nil
          if speech.genderMenu then
            choiceSubState = {
              isChoiceBox = true,
              isGender = true,
              anchor = "left",
              tx = 3,
              options = { "BOY", "GIRL" },
              cursor = (speech.genderMenu.cursor or 0) + 1,
            }
          elseif speech.yesNo then
            choiceSubState = {
              isChoiceBox = true,
              anchor = "left",
              tx = 3,
              options = { "YES", "NO" },
              cursor = (speech.yesNo.cursor or 0) + 1,
            }
          end

          local hasDialogue = (speech.showDialogue == true) or (speech.printer ~= nil)
          if hasDialogue or choiceSubState then
            local lines = (speech.printer and speech.printer.lines)
            if lines and #lines > 0 and lines[1] ~= "" then
              speech._omniLastLines = lines
            elseif not lines or #lines == 0 or lines[1] == "" then
              if speech._omniLastLines and (choiceSubState or speech.showDialogue) then
                lines = speech._omniLastLines
              end
            end

            local isWaiting = false
            if speech.printer then
              local st = speech.printer.state
              isWaiting = (st == "clear" or st == "scroll_start" or st == "wait" or not speech.printer.active)
            end
            if choiceSubState then isWaiting = false end

            local dialogueState = {
              speaker = "PROF. BIRCH",
              lines = lines or { "" },
              printer = speech.printer,
              _waiting = isWaiting,
              speechRef = speech,
            }
            return "dialogue", dialogueState, nil, choiceSubState
          end
        elseif isFrlg then
          local choiceSubState = nil
          local m = speech.win and speech.win.menu
          if m and m.items then
            local opts = {}
            for _, it in ipairs(m.items) do
              table.insert(opts, it[1])
            end
            local isGender = (m.kind == "gender")
            choiceSubState = {
              isChoiceBox = true,
              isGender = isGender,
              anchor = (m.left and m.left <= 5) and "left" or "right",
              tx = m.left or 2,
              options = opts,
              cursor = (m.cursor or 0) + 1,
            }
          end

          local hasDialog = (speech.win and speech.win.dialog == true) or (speech.printer ~= nil)
          if hasDialog or choiceSubState then
            local isWaiting = false
            if speech.printer then
              isWaiting = (speech.printer.state == "clear" or not speech.printer.active)
            end
            if choiceSubState then isWaiting = false end

            local dialogueState = {
              speaker = "PROF. OAK",
              printer = speech.printer,
              pages = speech.printer and speech.printer.pages,
              page = speech.printer and speech.printer.page,
              revealed = speech.printer and speech.printer.revealed,
              _waiting = isWaiting,
              speechRef = speech,
            }
            return "dialogue", dialogueState, nil, choiceSubState
          end
        end

        local k, extra = ModernOverlay.isSupported(speech)
        if k then return k, speech, extra, nil end
      end
    elseif bPhase == "title_combo" and b.custom and b.custom.combo then
      local k, extra = ModernOverlay.isSupported(b.custom.combo)
      if k then return k, b.custom.combo, extra, nil end
    end
    -- During intro, copyright, title, title_cry, title_restart, pass-through so native opening video & title screen play seamlessly
    return nil
  end

  -- 3. Gen 3 Modal UI Stack (src.ui.game3.stack)
  if ModernOverlay.ensureGen3Hooks then ModernOverlay.ensureGen3Hooks() end
  local Stack = package.loaded["src.ui.game3.stack"]
  local layers = (Stack and Stack._layers) or {}
  local Choice = package.loaded["src.ui.game3.choice"]
  local isChoiceActive = Choice and ((Choice.isOpen and Choice.isOpen()) or Choice.active)
  local choiceState = (isChoiceActive and (Choice._state or Choice)) or nil

  if #layers > 0 then
    -- Check for save menu layer first
    for i = #layers, 1, -1 do
      local mod = layers[i].mod
      if mod then
        local target = (mod.Host and mod.Host._screen) or (mod._screen) or (mod._clock) or mod
        if ModernOverlay.isSupported(target) == "save" then
          local topSub = (i < #layers) and (layers[#layers].mod._screen or layers[#layers].mod) or choiceState
          return "save", target, nil, topSub
        end
      end
    end

    local LAYER_KIND_MAP = {
      party = "party",
      summary = "summary",
      bag = "bag",
      pokedex = "pokedex",
      rse_pokedex = "pokedex",
      rs_pokedex = "pokedex",
      rse_pokenav = "pokenav",
      rs_pokenav = "pokenav",
      pokenav = "pokenav",
      trainer_card = "trainer_card",
      save = "save",
      start_menu = "start_menu",
      option = "options",
      options = "options",
      mod_manager = "mod_manager",
      pc = "pc_hub",
      pc_menu = "pc_hub",
      item_pc = "player_pc",
      rse_item_storage = "player_pc",
      box_storage = "storage",
      hall_of_fame = "hall_of_fame",
      hall_of_fame_pc = "league_pc",
      move_relearner = "move_learn",
      shop = "shop",
      naming = "naming",
    }

    for i = #layers, 1, -1 do
      local layer = layers[i]
      local mod = layer and layer.mod
      if mod then
        local target = (mod.Host and (mod.Host._screen or mod.Host._s)) or (mod._screen) or (mod._clock) or (mod._state) or (mod._s) or (mod._mgr) or mod
        if layer.id == "region_map" or layer.id == "rse_region_map" then
          return "town_map", target, nil, nil
        end
        if target == mod and mod.isMenu and (layer.id == "rse_pokedex" or layer.id == "rs_pokedex") then
          local RsePokedex = package.loaded["src.ui.game3.rse.pokedex"] or package.loaded["src.ui.game3.rs.pokedex"]
          if RsePokedex and RsePokedex.active then
            target = RsePokedex.active() or target
          end
        elseif target == mod and mod.isMenu and (layer.id == "rse_pokenav" or layer.id == "rs_pokenav" or layer.id == "pokenav") then
          local RsePokenav = package.loaded["src.ui.game3.rse.pokenav.init"] or package.loaded["src.ui.game3.rs.pokenav.init"] or package.loaded["src.ui.game3.rse.pokenav"] or package.loaded["src.ui.game3.rs.pokenav"]
          if RsePokenav and RsePokenav.active then
            target = RsePokenav.active() or target
          end
        end
        local kind, extra = ModernOverlay.isSupported(target)
        if not kind and layer.id and LAYER_KIND_MAP[layer.id] then
          kind = LAYER_KIND_MAP[layer.id]
        end
        if kind == "mod_manager" and target and target._mgr then
          target = target._mgr
        end
        if kind then
          local subState = (i < #layers) and (layers[#layers].mod._screen or layers[#layers].mod._s or layers[#layers].mod) or choiceState
          return kind, target, extra, subState
        end
      end
    end
  end

  -- 4. Gen 3 Standalone Singletons
  local StartMenu = package.loaded["src.ui.game3.start_menu"]
  if StartMenu and ((StartMenu.isOpen and StartMenu.isOpen() == true) or StartMenu.open == true) then
    return "start_menu", StartMenu, nil, choiceState
  end

  local SaveMenu = package.loaded["src.ui.game3.save_menu"]
  if SaveMenu and ((SaveMenu.isOpen and SaveMenu.isOpen() == true) or SaveMenu.open == true) then
    return "save", SaveMenu, nil, choiceState
  end

  local SummaryMenu = package.loaded["src.ui.game3.summary_menu"] or package.loaded["src.ui.game3.rse.summary_menu"]
  if SummaryMenu and ((SummaryMenu.isOpen and SummaryMenu.isOpen() == true) or SummaryMenu.open == true) then
    return "summary", SummaryMenu, nil, nil
  end

  local PartyMenu = package.loaded["src.ui.game3.party_menu"]
  if PartyMenu and ((PartyMenu.isOpen and PartyMenu.isOpen() == true) or PartyMenu.open == true) then
    return "party", PartyMenu, nil, nil
  end

  local ItemPc = package.loaded["src.ui.game3.item_pc"]
  if ItemPc and ((ItemPc.isOpen and ItemPc.isOpen() == true) or ItemPc.open == true) then
    if ItemPc._fx then
      if ItemPc._fx.cb then
        local cb = ItemPc._fx.cb
        ItemPc._fx = nil
        cb()
        return ModernOverlay.getActiveScreen(game)
      else
        ItemPc._fx = nil
      end
    end
    return "player_pc", ItemPc, nil, nil
  end

  local BagMenu = package.loaded["src.ui.game3.bag_menu"] or package.loaded["src.ui.game3.rse.bag_menu"]
  if BagMenu and ((BagMenu.isOpen and BagMenu.isOpen() == true) or BagMenu.open == true) then
    return "bag", BagMenu, nil, nil
  end

  local Pokedex = package.loaded["src.ui.game3.pokedex"] or package.loaded["src.ui.game3.rse.pokedex"] or package.loaded["src.ui.game3.rs.pokedex"]
  if Pokedex and ((Pokedex.isOpen and Pokedex.isOpen() == true) or Pokedex.open == true or (Pokedex.active and Pokedex.active() ~= nil)) then
    local target = (Pokedex.active and Pokedex.active()) or Pokedex
    return "pokedex", target, nil, nil
  end

  local Pokenav = package.loaded["src.ui.game3.rse.pokenav.init"] or package.loaded["src.ui.game3.rs.pokenav.init"] or package.loaded["src.ui.game3.rse.pokenav"] or package.loaded["src.ui.game3.rs.pokenav"]
  if Pokenav and ((Pokenav.isOpen and Pokenav.isOpen() == true) or Pokenav.open == true or (Pokenav.active and Pokenav.active() ~= nil)) then
    local target = (Pokenav.active and Pokenav.active()) or (Pokenav.Host and Pokenav.Host._s) or Pokenav.Host or Pokenav
    return "pokenav", target, nil, nil
  end

  local TrainerCard = package.loaded["src.ui.game3.trainer_card"]
  if TrainerCard and ((TrainerCard.isOpen and TrainerCard.isOpen() == true) or TrainerCard.open == true) then
    return "trainer_card", TrainerCard, nil, nil
  end

  local OptionMenu = package.loaded["src.ui.game3.option_menu"] or package.loaded["src.ui.game3.rse.option_menu"]
  if OptionMenu and ((OptionMenu.isOpen and OptionMenu.isOpen() == true) or OptionMenu.open == true) then
    return "options", OptionMenu, nil, nil
  end

  local ShopMenu = package.loaded["src.ui.game3.shop_menu"] or package.loaded["src.ui.game3.rse.shop_menu"]
  if ShopMenu and ((ShopMenu.isOpen and ShopMenu.isOpen() == true) or ShopMenu.open == true) then
    return "shop", ShopMenu, nil, nil
  end

  local Naming = package.loaded["src.ui.game3.naming"]
  if Naming and ((Naming.isOpen and Naming.isOpen() == true) or Naming.openFlag == true or Naming._state ~= nil) then
    return "naming", (Naming._state or Naming), nil, nil
  end

  local HallOfFame = package.loaded["src.ui.game3.hall_of_fame"]
  if HallOfFame and HallOfFame.open == true then
    return "hall_of_fame", HallOfFame, nil, nil
  end

  local HofPc = package.loaded["src.ui.game3.hall_of_fame_pc"]
  if HofPc and HofPc.open == true then
    return "league_pc", HofPc, nil, nil
  end

  local MoveRelearner = package.loaded["src.ui.game3.move_relearner"] or package.loaded["src.ui.game3.rse.move_relearner"]
  if MoveRelearner and MoveRelearner.open == true then
    return "move_learn", MoveRelearner, nil, nil
  end

  local Message = package.loaded["src.ui.game3.message"]
  local Battle = package.loaded["src.core.game3.battle"]
  local battleOn = Battle and Battle.isActive and Battle.isActive() == true
  -- Battle lines ("Wild X appeared!") stay on the battle console. The field
  -- dialogue box is only for messages that are not part of the fight.
  if battleOn and Message and Message.isOpen and Message.isOpen()
      and Message.frameKind and Message.frameKind() == "battle" then
    return "battle", (Battle.getState and Battle.getState()) or Battle._st or Battle, nil, nil
  end
  if Message and ((Message.isOpen and Message.isOpen() == true) or Message.open == true) then
    return "dialogue", (Message._state or Message), nil, choiceState
  end

  if isChoiceActive and Choice then
    return "dialogue", (Choice._state or Choice), nil, nil
  end

  if battleOn then
    return "battle", (Battle.getState and Battle.getState()) or Battle._st or Battle, nil, nil
  end

  return nil
end

-- Transition & Animation State Manager
ModernOverlay.screenProgress = {}
ModernOverlay.lastActiveKind = nil
ModernOverlay.lastActiveState = nil
ModernOverlay.lastSubState = nil
ModernOverlay.closingModal = nil
ModernOverlay.transition = {
  progress = 1.0,
  lastTime = nil,
}

local function easeExpoOut(t)
  if t >= 1.0 then return 1.0 end
  return 1 - (2 ^ (-10 * t))
end

local function easeBackOut(t, s)
  s = s or 1.12 -- Subtle 1.2% breath overshoot
  local inv = t - 1
  return inv * inv * ((s + 1) * inv + s) + 1
end

local function easeSmooth(t)
  if t <= 0 then return 0.0 end
  if t >= 1 then return 1.0 end
  return t * t * (3 - 2 * t)
end

function ModernOverlay.updateProgress(kind, activeState, subState, isFullScreen)
  local now = (love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  local dt = 0.016
  if ModernOverlay.transition.lastTime then
    dt = math.min(0.05, math.max(0.001, now - ModernOverlay.transition.lastTime))
  end
  ModernOverlay.transition.lastTime = now

  -- Detect transition from save -> start_menu to trigger smooth shrink/fade exit
  if ModernOverlay.lastActiveKind == "save" and kind == "start_menu" and ModernOverlay.lastActiveState then
    ModernOverlay.closingModal = {
      kind = "save",
      state = ModernOverlay.lastActiveState,
      subState = ModernOverlay.lastSubState,
      progress = 1.0,
      duration = 0.22,
    }
  elseif kind == "save" then
    ModernOverlay.closingModal = nil
  end

  local prevActiveKind = ModernOverlay.lastActiveKind
  local prevActiveState = ModernOverlay.lastActiveState
  local prevActiveTime = ModernOverlay.lastActiveTime

  local isSameKind = (prevActiveKind == kind)
  local wasRecentDialogue = (kind == "dialogue" and ModernOverlay.lastDialogueTime and (now - ModernOverlay.lastDialogueTime < 1.5))
  if kind == "dialogue" then
    ModernOverlay.lastDialogueTime = now
  end

  local isPcFamily = (kind == "pc_hub" or kind == "storage" or kind == "player_pc" or kind == "league_pc")
  local wasPcFamily = (prevActiveKind == "pc_hub" or prevActiveKind == "storage" or prevActiveKind == "player_pc" or prevActiveKind == "league_pc")
  local wasRecentActive = prevActiveTime and (now - prevActiveTime < 0.60)

  ModernOverlay.lastActiveKind = kind
  ModernOverlay.lastActiveState = activeState
  ModernOverlay.lastSubState = subState
  ModernOverlay.lastActiveTime = now

  local key = kind .. "_" .. tostring(activeState)
  if not ModernOverlay.screenProgress[key] then
    -- Inherit full progress (1.0) when continuing across dialogue blurbs, within the same family (e.g. PC terminal / storage), or across active full screens to eliminate flickering
    local initialP = (isSameKind or wasRecentDialogue or (isPcFamily and wasPcFamily) or (isFullScreen and wasRecentActive and prevActiveKind ~= "start_menu")) and 1.0 or 0.0
    ModernOverlay.screenProgress[key] = { progress = initialP }
  end

  local sp = ModernOverlay.screenProgress[key]
  local duration = (kind == "save") and 0.16 or (isFullScreen and 0.30 or 0.15)
  if sp.progress < 1.0 then
    sp.progress = math.min(1.0, sp.progress + (dt / duration))
  end

  ModernOverlay.transition.progress = sp.progress
  return sp.progress, dt
end

-- GLSL Directional Wave Darkening Shader
local WAVE_SHADER_CODE = [[
  extern float u_menu_x;
  extern float u_wave_width;
  extern float u_max_alpha;
  extern float u_fill_amount;
  extern vec3 u_dim_color;

  vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    float left_edge = u_menu_x - u_wave_width;
    float factor = smoothstep(left_edge, u_menu_x, screen_coords.x);
    float final_factor = mix(factor, 1.0, clamp(u_fill_amount, 0.0, 1.0));
    float alpha = final_factor * u_max_alpha;
    return vec4(u_dim_color, alpha);
  }
]]

local waveShader = nil
local waveShaderFailed = false

function ModernOverlay.getWaveShader()
  if waveShaderFailed then return nil end
  if not waveShader and love and love.graphics and love.graphics.newShader then
    local ok, sh = pcall(love.graphics.newShader, WAVE_SHADER_CODE)
    if ok and sh then
      waveShader = sh
    else
      waveShaderFailed = true
    end
  end
  return waveShader
end

local saveCanvas = nil
local function getSaveCanvas(w, h)
  if not love or not love.graphics or not love.graphics.newCanvas then return nil end
  local cw = math.max(640, w)
  local ch = math.max(400, h)
  if not saveCanvas or saveCanvas:getWidth() < cw or saveCanvas:getHeight() < ch then
    local ok, cv = pcall(love.graphics.newCanvas, cw, ch)
    if ok and cv then saveCanvas = cv else saveCanvas = nil end
  end
  return saveCanvas
end

local function drawSaveModalWithTransform(game, state, vw, vh, theme, subState, hasStartMenu, scale, alpha)
  local ctx = Layout.getContext(vw, vh)
  local isSideBySide = hasStartMenu and not ctx.isPortrait
  local modalW = ctx.isPortrait and math.min(vw - 24, 380) or (isSideBySide and math.min(520, vw - 330) or math.min(vw - (ctx.isCompact and 16 or 32), 480))
  local modalH = ctx.isUltraCompact and 250 or 280
  local mx = isSideBySide and 24 or math.floor((vw - modalW) / 2)
  local my = ctx.isPortrait and math.max(ctx.safeInsetTop or 48, math.floor(vh * 0.12)) or math.floor((vh - modalH) / 2)
  local modalCenterX = mx + math.floor(modalW / 2)
  local modalCenterY = my + math.floor(modalH / 2)

  local clampedAlpha = math.max(0, math.min(1, alpha or 1.0))
  local cv = (clampedAlpha < 0.99) and getSaveCanvas(modalW + 32, modalH + 32) or nil

  local initDepth = love and love.graphics and love.graphics.getStackDepth and love.graphics.getStackDepth() or 0
  if cv then
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(-mx + 16, -my + 16)
    ModernOverlay.drawSaveMenu(game, state, vw, vh, theme, subState, hasStartMenu)
    love.graphics.pop()
    love.graphics.setCanvas(prevCanvas)

    love.graphics.push()
    love.graphics.translate(modalCenterX, modalCenterY)
    love.graphics.scale(scale, scale)
    love.graphics.setColor(1, 1, 1, clampedAlpha)
    love.graphics.draw(cv, -math.floor(modalW / 2) - 16, -math.floor(modalH / 2) - 16)
    love.graphics.pop()
  else
    love.graphics.push()
    love.graphics.translate(modalCenterX, modalCenterY)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-modalCenterX, -modalCenterY)
    ModernOverlay.drawSaveMenu(game, state, vw, vh, theme, subState, hasStartMenu)
    love.graphics.pop()
  end
  if love and love.graphics and love.graphics.getStackDepth then
    while love.graphics.getStackDepth() > initDepth do
      love.graphics.pop()
    end
  end
end

function ModernOverlay.draw(game, viewport)
  if game then ModernOverlay.currentGame = game end
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  local kind, activeState, extra, subState = ModernOverlay.getActiveScreen(game)

  if not kind or not activeState then
    ModernOverlay.lastActiveKind = nil
    ModernOverlay.lastActiveState = nil
    ModernOverlay.lastSubState = nil
    return
  end

  local vw = (type(viewport) == "table" and viewport.width) or (type(viewport) == "number" and viewport) or (love and love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 800
  local vh = (type(viewport) == "table" and viewport.height) or (love and love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 600
  local theme = Theme.get()

  local isOverlayOnly = (kind == "start_menu" or kind == "save" or kind == "dialogue" or kind == "battle" or kind == "clock_setup" or kind == "gender_select" or kind == "name_pick" or kind == "menu" or kind == "dexnav")
  local isFullScreen = not isOverlayOnly

  local rawP, dt = ModernOverlay.updateProgress(kind, activeState, subState, isFullScreen)
  local expoVal = easeExpoOut(rawP)
  local backVal = easeBackOut(rawP, 1.12)

  local hasExitDialog = false
  if activeState and (activeState.phase == "confirm" or activeState.phase == "confirmContest" or activeState._confirmExit) then
    hasExitDialog = true
  elseif subState and (subState.phase == "confirm" or (subState.isChoiceBox and subState.labels)) then
    hasExitDialog = true
  end

  local ctx = Layout.getContext(vw, vh, viewport)

  -- Translucent Overworld Darkening Backdrop:
  -- Overlay screens apply directional wave shader (start_menu / save) or uniform backdrop dimming,
  -- allowing the live overworld to remain visible behind all menus and modals.
  if kind == "start_menu" or kind == "save" then
    local dockConf = (theme.layout and theme.layout.dock) or { width = 290, marginX = 24 }
    local dockW = math.min(vw - 16, dockConf.width or 290)
    local marginX = ctx.isCompact and 8 or (dockConf.marginX or 24)
    local baseDockX = (dockConf.align == "left") and marginX
        or (dockConf.align == "center" or ctx.isPortrait) and math.floor((vw - dockW) / 2)
        or (vw - dockW - marginX)
    local slideX = (kind == "start_menu") and math.floor((1 - expoVal) * 32) or 0
    local currentMenuX = baseDockX + slideX

    local fillAmount = 0.0
    if kind == "save" then
      fillAmount = expoVal
    elseif kind == "start_menu" and ModernOverlay.closingModal and ModernOverlay.closingModal.kind == "save" then
      fillAmount = easeSmooth(math.max(0, math.min(1, ModernOverlay.closingModal.progress)))
    end

    if hasExitDialog then
      fillAmount = math.max(fillAmount, 0.95)
    end

    local baseDim = theme.overlayDim or 0.60
    -- A hair darker (0.72 vs 0.60) to distinctly emphasize exit to main menu dialog
    local maxAlpha = hasExitDialog and math.min(0.85, baseDim + 0.12) or baseDim

    local sh = ModernOverlay.getWaveShader()
    local drewShader = false
    if sh and pcall(function()
      local waveWidth = math.max(180, math.floor(vw * 0.45))
      sh:send("u_menu_x", currentMenuX)
      sh:send("u_wave_width", waveWidth)
      sh:send("u_max_alpha", maxAlpha)
      sh:send("u_fill_amount", fillAmount)
      sh:send("u_dim_color", { 0.0, 0.0, 0.0 })
      love.graphics.setShader(sh)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
      love.graphics.setShader()
    end) then
      drewShader = true
    end

    if not drewShader then
      if fillAmount > 0.5 or ctx.isPortrait or dockConf.align == "center" then
        local effectiveAlpha = maxAlpha * (expoVal * (1 - fillAmount) + fillAmount)
        love.graphics.setColor(0, 0, 0, effectiveAlpha)
        love.graphics.rectangle("fill", 0, 0, vw, vh)
      else
        -- Directional fallback without shader: darken only the dock area on the right
        local dimX = math.max(0, currentMenuX - 48)
        local dimW = vw - dimX
        local effectiveAlpha = maxAlpha * expoVal
        love.graphics.setColor(0, 0, 0, effectiveAlpha)
        love.graphics.rectangle("fill", dimX, 0, dimW, vh)
      end
    end
  elseif kind == "dialogue" or kind == "menu" or kind == "clock_setup" or kind == "name_pick" then
    -- Floating dialogue text boxes, menus, and intro cards render directly over the underlying scene with zero backdrop darkening
  elseif kind == "naming" then
    local bgCol = theme.bg or { 0.08, 0.09, 0.12, 1 }
    love.graphics.setColor(bgCol[1] or 0.08, bgCol[2] or 0.09, bgCol[3] or 0.12, 1.0)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
  elseif kind ~= "battle" then
    local targetDim = theme.overlayDim or 0.60
    love.graphics.setColor(0, 0, 0, targetDim * expoVal)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
  end

  -- Theme atmospheric background layer (holographic grids, scanlines, particle fields)
  -- Gated to full modal/browser screens so live overworld in start_menu/dialogue remains clean
  if theme.drawBackground and type(theme.drawBackground) == "function" and kind ~= "start_menu" and kind ~= "dialogue" and kind ~= "menu" and kind ~= "save" and kind ~= "battle" and kind ~= "clock_setup" and kind ~= "gender_select" and kind ~= "name_pick" and kind ~= "dexnav" then
    pcall(theme.drawBackground, theme, vw, vh, kind, expoVal)
  end

  -- Responsive Center Container Bounds
  local safeTop = ctx.safeInsetTop or (ctx.isPortrait and 48 or 0)
  local isFullHeightScreen = (kind == "naming" or kind == "mod_manager" or kind == "load_report")
  local portRatio = isFullHeightScreen and 1.0 or (ctx.portraitContainerRatio or (ctx.isUltraTallPortrait and 0.74 or (ctx.isTallPortrait and 0.70 or 0.64)))
  local maxContainerW = (theme.layout and theme.layout.container and theme.layout.container.maxWidth) or 860
  local maxContainerH = (theme.layout and theme.layout.container and theme.layout.container.maxHeight) or (ctx.isPortrait and (isFullHeightScreen and (vh - safeTop - 12) or math.floor((vh - safeTop) * portRatio)) or 540)
  local marginX = ctx.isUltraCompact and 4 or (ctx.isCompact and 6 or (ctx.isPortrait and 8 or 16))
  local marginY = ctx.isUltraCompact and 4 or (ctx.isCompact and 6 or (ctx.isPortrait and 8 or 16))
  local cw = math.min(vw - marginX * 2, maxContainerW)
  local ch = math.min(vh - safeTop - marginY * 2, maxContainerH)
  local cx = math.floor((vw - cw) / 2)
  local cy = ctx.isPortrait and safeTop or math.floor((vh - ch) / 2)

  local initialDepth = love and love.graphics and love.graphics.getStackDepth and love.graphics.getStackDepth() or 0

  local drawOk, drawErr = pcall(function()
    love.graphics.push()

    if kind == "start_menu" then
      -- Handle closing save modal shrink/fade exit if active
      if ModernOverlay.closingModal and ModernOverlay.closingModal.kind == "save" then
        local cm = ModernOverlay.closingModal
        cm.progress = cm.progress - (dt / cm.duration)
        if cm.progress <= 0 then
          ModernOverlay.closingModal = nil
        else
          local p = math.max(0, math.min(1, cm.progress))
          local exitEased = easeSmooth(p)
          -- Shrink & fade out the save modal smoothly
          local shrinkScale = 0.88 + 0.12 * exitEased
          drawSaveModalWithTransform(game, cm.state, vw, vh, theme, cm.subState, true, shrinkScale, exitEased)
        end
      end

      local slideX = ctx.isPortrait and 0 or math.floor((1 - expoVal) * 32)
      local slideY = ctx.isPortrait and math.floor((1 - expoVal) * 20) or 0
      love.graphics.translate(slideX, slideY)
      ModernOverlay.drawStartMenu(game, activeState, vw, vh, theme, subState, rawP)
    elseif kind == "battle" then
      if not activeState.blankForAskName and not activeState.fieldCleared then
        ModernOverlay.drawBattle(game, activeState, vw, vh, theme, subState, viewport)
      end
    elseif kind == "dialogue" then
      local slideY = (rawP < 0.99) and math.floor((1 - expoVal) * 14) or 0
      if slideY ~= 0 then love.graphics.translate(0, slideY) end
      ModernOverlay.drawDialogue(game, activeState, vw, vh, theme, subState, viewport)
    elseif kind == "stat_box" then
      if subState then
        local pk = ModernOverlay.isSupported(subState)
        if pk == "party" then
          ModernOverlay.drawParty(game, subState, cw, ch, theme, nil, 1.0)
        elseif pk == "bag" then
          ModernOverlay.drawBag(game, subState, cw, ch, theme, nil, 1.0)
        elseif pk == "battle" then
          ModernOverlay.drawBattle(game, subState, vw, vh, theme, nil, viewport)
        end
      end
      ModernOverlay.drawLevelUpStat(game, activeState, vw, vh, theme, subState, viewport)
    elseif kind == "menu" or kind == "dexnav" then
      ModernOverlay.drawMenu(game, activeState, vw, vh, theme, subState, viewport)
    elseif kind == "clock_setup" then
      ModernOverlay.drawClock(game, activeState, vw, vh, theme, subState, viewport)
    elseif kind == "gender_select" then
      ModernOverlay.drawGender(game, activeState, vw, vh, theme, subState, viewport)
    elseif kind == "name_pick" then
      ModernOverlay.drawNamePick(game, activeState, vw, vh, theme, subState, viewport)
    elseif kind == "save" then
      local startState = nil
      for _, st in ipairs((game and game.stack and game.stack.states) or {}) do
        if ModernOverlay.isSupported(st) == "start_menu" then
          startState = st
          break
        end
      end

      -- 1. Draw docked start menu stably in place (only in landscape mode)
      if startState and not ctx.isPortrait then
        ModernOverlay.drawStartMenu(game, startState, vw, vh, theme)
      end

      -- 2. Expand in the Save Modal smoothly centered on its own coordinates (Pop 0.80 -> 1.02 -> 1.00)
      local saveBack = easeBackOut(rawP, 1.35)
      local expandScale = 0.80 + 0.20 * saveBack
      drawSaveModalWithTransform(game, activeState, vw, vh, theme, subState, startState ~= nil and not ctx.isPortrait, expandScale, expoVal)
    else
      -- Full-page screens: Pop Overshoot (0.80 -> 1.02 -> 1.00 with physical breath) & native directional glide
      local popBack = easeBackOut(rawP, 1.35)
      local scale = 0.80 + 0.20 * popBack
      local slideX = ctx.isPortrait and 0 or math.floor((1 - expoVal) * 16)
      local slideY = ctx.isPortrait and math.floor((1 - expoVal) * 16) or 0
      love.graphics.translate(cx + cw / 2, cy + ch / 2)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-cw / 2 + slideX, -ch / 2 + slideY)
      if kind == "party" then
        ModernOverlay.drawParty(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "summary" then
        ModernOverlay.drawSummary(game, activeState, cw, ch, theme, rawP)
      elseif kind == "shop" then
        ModernOverlay.drawShopMenu(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "bag" then
        ModernOverlay.drawBag(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "trainer_card" then
        ModernOverlay.drawTrainerCard(game, activeState, cw, ch, theme, rawP)
      elseif kind == "options" then
        ModernOverlay.drawOptionsMenu(game, activeState, cw, ch, theme, rawP)
      elseif kind == "pokedex" then
        ModernOverlay.drawPokedexMenu(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "town_map" then
        ModernOverlay.drawTownMap(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "pokenav" then
        ModernOverlay.drawPokenav(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "pokegear" then
        ModernOverlay.drawPokegear(game, activeState, cw, ch, theme, subState, rawP, viewport)
      elseif kind == "naming" then
        ModernOverlay.drawNaming(game, activeState, cw, ch, theme, subState)
      elseif kind == "move_learn" then
        ModernOverlay.drawMoveLearn(game, activeState, cw, ch, theme, subState)
      elseif kind == "prize_counter" then
        ModernOverlay.drawPrizeCounter(game, activeState, cw, ch, theme, subState)
      elseif kind == "storage" then
        ModernOverlay.drawStorage(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "player_pc" then
        ModernOverlay.drawPlayerPc(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "pc_hub" then
        ModernOverlay.drawPcHub(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "mod_manager" then
        ModernOverlay.drawModManager(game, activeState, cw, ch, theme, subState)
      elseif kind == "load_report" then
        ModernOverlay.drawLoadReport(game, activeState, cw, ch, theme)
      elseif kind == "main_menu" then
        ModernOverlay.drawMainMenu(game, activeState, cw, ch, theme, subState)
      elseif kind == "evolution" then
        ModernOverlay.drawEvolution(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "hall_of_fame" then
        ModernOverlay.drawHallOfFame(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "league_pc" then
        ModernOverlay.drawLeaguePc(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "diploma" then
        ModernOverlay.drawDiploma(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "fly_menu" then
        ModernOverlay.drawFlyMenu(game, activeState, cw, ch, theme, subState, rawP)
      elseif kind == "stat_box" then
        ModernOverlay.drawLevelUpStat(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "bank_of_mom" then
        ModernOverlay.drawBankOfMom(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "buena_password" then
        ModernOverlay.drawBuenaPassword(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "elevator" then
        ModernOverlay.drawElevator(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "decoration" then
        ModernOverlay.drawDecoration(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "trade" then
        ModernOverlay.drawTrade(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "contest" then
        ModernOverlay.drawContest(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "held_item" then
        ModernOverlay.drawHeldItem(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "daycare" then
        ModernOverlay.drawDayCare(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "move_deleter" then
        ModernOverlay.drawMoveDeleter(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "mail" then
        ModernOverlay.drawMail(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "mailbox" then
        ModernOverlay.drawMailbox(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "mail_compose" then
        ModernOverlay.drawMailCompose(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "clock_setup" then
        ModernOverlay.drawClock(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "gender_select" then
        ModernOverlay.drawGender(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "battle_tower" then
        ModernOverlay.drawBattleTower(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "caller_box" then
        ModernOverlay.drawCallerBox(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind == "starter_choose" then
        ModernOverlay.drawStarterChoose(game, activeState, cw, ch, theme, subState, viewport)
      elseif kind:find("^custom_") and extra and extra.draw and type(extra.draw) == "function" then
        local HookBoundary = require("mods.omni_ui.core.HookBoundary")
        HookBoundary.safeRender(kind, extra.draw, game, activeState, cw, ch, theme, subState, rawP)
      elseif kind:find("^legacy_") then
        ModernOverlay.drawLegacy(game, activeState, extra, cw, ch, theme)
      end
    end

    love.graphics.pop()
  end)

  if not drawOk and drawErr then
    print("[OmniUI/ModernOverlay] render error: " .. tostring(drawErr))
  end

  if love and love.graphics and love.graphics.getStackDepth then
    while love.graphics.getStackDepth() > initialDepth do
      love.graphics.pop()
    end
  end
  love.graphics.setColor(1, 1, 1, 1)

  -- Post-Render Hook Execution (for custom HUD overlays, mod telemetry, etc.)
  local PublicApi = package.loaded["mods.omni_ui.api.PublicApi"]
  if PublicApi and PublicApi.postRenderHooks and PublicApi.postRenderHooks[kind] then
    local HookBoundary = require("mods.omni_ui.core.HookBoundary")
    for hookId, fn in pairs(PublicApi.postRenderHooks[kind]) do
      HookBoundary.safeRender("post_" .. tostring(hookId), fn, game, activeState, vw, vh, theme, subState)
    end
  end

  -- Draw floating dialogue / choice modal if stacked on top of an active full-page screen
  if kind ~= "dialogue" and kind ~= "save" then
    local states = (game and game.stack and game.stack.states) or {}
    local dialogState = nil
    local choiceState = nil
    for i = #states, 1, -1 do
      local s = states[i]
      if s == activeState then break end
      local k = ModernOverlay.isSupported(s)
      if k == "dialogue" or (s and (s.isTextBox or (s.pages and s.shown) or s.shownSource)) then
        dialogState = s
        if i < #states then choiceState = states[#states] end
        break
      end
    end
    local isPhoneCall = (kind == "pokegear") and (activeState and activeState.call ~= nil)
    if dialogState and not isPhoneCall then
      ModernOverlay.drawDialogue(game, dialogState, vw, vh, theme, choiceState)
    end

    local statBoxState = nil
    for i = #states, 1, -1 do
      local s = states[i]
      if s == activeState then break end
      local k = ModernOverlay.isSupported(s)
      if k == "stat_box" then
        statBoxState = s
        break
      end
    end
    if statBoxState then
      ModernOverlay.drawLevelUpStat(game, statBoxState, vw, vh, theme, nil, viewport)
    end
  end
end

return ModernOverlay
