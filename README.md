# OmniUI

A modern UI overhaul framework for Pokémon Gen 1-3 recompilations (Mod API v2).

## Theme Directory & Custom Themes

OmniUI features a dedicated themes directory at [`mods/omni_ui/themes/`](file:///home/autumn/src/gen1recomp/mods/omni_ui/themes/). Developers can add new themes simply by creating a `.lua` file in `themes/` or extending an existing theme via `Theme.extend()`.

### Built-in Themes
- [`dark.lua`](file:///home/autumn/src/gen1recomp/mods/omni_ui/themes/dark.lua) - Graphite surfaces, crisp contrast, sapphire accents (Default).
- [`kanto.lua`](file:///home/autumn/src/gen1recomp/mods/omni_ui/themes/kanto.lua) - Fiery crimson accents with warm dark surfaces.
- [`emerald.lua`](file:///home/autumn/src/gen1recomp/mods/omni_ui/themes/emerald.lua) - Jade and emerald forest tones with mint highlights.
- [`cyber.lua`](file:///home/autumn/src/gen1recomp/mods/omni_ui/themes/cyber.lua) - Cyberpunk neon cyan/magenta with left-docked pause menu.
- [`classic.lua`](file:///home/autumn/src/gen1recomp/mods/omni_ui/themes/classic.lua) - Monochrome Game Boy Pocket retro slate styling.

### Creating a Declarative Theme (Zero Math / Zero Render Code)
```lua
return {
  id = "synthwave",
  label = "Synthwave 80s",
  colors = {
    bg      = "#1B0B2B",
    surface = "#26143D",
    accent  = "#FF007F",
    text    = "#FFE3F1",
    hpGreen = "#00F0FF",
  },
  metrics = {
    radius = { card = 8, button = 6 },
  },
  layout = {
    dock = { align = "left", width = 300 },
  }
}
```

### Built-in UI Primitives
Developers can use or override high-level primitives without manual geometry math:
- `Layout.drawCard(x, y, w, h, opts)` - Surface container with border and radius tokens.
- `Layout.drawSlot(x, y, w, h, opts)` - Inset row slot inside cards.
- `Layout.drawButton(x, y, w, h, label, opts)` - Primary, accent, danger, and ghost buttons with left/right padding support.
- `Layout.drawBadge(x, y, text, opts)` - Status badges and notification tags.
- `Layout.drawPedestal(x, y, rx, ry, opts)` - Monster pedestal platform.
- `Layout.drawHealthBar(x, y, w, h, current, max, opts)` - Dynamic HP/Stat meters.
- `Layout.drawProgressBar(x, y, w, h, current, max, opts)` - Experience and progress bars.
- `Layout.drawDivider(x, y, w, opts)` - Subtle horizontal divider lines.
- `Layout.drawButtonHint(x, y, keyText, labelText, opts)` - Gamepad/keyboard prompt pill.
- `Layout.drawHintBar(x, y, w, h, hints, opts)` - Locked-spacing footer action bar.
- `Layout.drawText(text, x, y, opts)` / `Layout.drawTextWrapped(text, x, y, wrapLimit, opts)` - Vector typography.

---

## Mod Developer Public API (`PublicApi`)

Other mods can integrate seamlessly into OmniUI via `require("mods.omni_ui.api.PublicApi")`:

### 1. Menu & Screen Extension
- **Start / Pause Menu**:
  ```lua
  local PublicApi = require("mods.omni_ui.api.PublicApi")
  PublicApi.registerStartMenuItem({
    id = "quest_log",
    label = "QUESTS",
    badge = "3",          -- Optional notification tag
    kind = "primary",     -- "primary" | "accent" | "good" | "danger" | "ghost"
    insertAfter = "ITEM", -- Anchor placement
    onSelect = function(game) ... end,
  })
  ```
- **Game Settings / Options Menu**:
  ```lua
  PublicApi.registerOptionRow({
    id = "text_speed_turbo",
    label = "TURBO DIALOGUE",
    choices = { "OFF", "ON" },
    get = function() return ... end,
    set = function(val) ... end,
  })
  ```
- **Pokémon Summary Page Tabs**:
  ```lua
  PublicApi.registerSummaryTab({
    id = "ev_iv_inspector",
    label = "EV / IV",
    draw = function(game, mon, rx, ry, rw, rh, theme)
      -- Render custom summary panel with full theme access
    end,
  })
  ```
- **Bag / Inventory Pockets**:
  ```lua
  PublicApi.registerBagPocket({
    id = "held_items",
    label = "HELD ITEMS",
    filter = function(itemId, itemDef) return itemDef.isHoldable end,
  })
  ```
- **Party Context Submenu**:
  ```lua
  PublicApi.registerPartyAction({
    id = "pet_mon",
    label = "PET POKÉMON",
    onSelect = function(game, mon, partyIndex) ... end,
  })
  ```
- **Completely Custom UI Screens**:
  ```lua
  PublicApi.registerScreen("my_mod_screen", {
    match = function(state) return state.isMyModScreen == true end,
    draw = function(game, state, w, h, theme, subState, animProgress)
      -- Draw custom UI with modern cards, slots, buttons, and theme colors
    end,
  })
  ```

### 2. Lifecycle Render Hooks
```lua
-- Intercept before or after screen rendering for overlays, telemetry, or custom HUDs
PublicApi.onPreRender("battle", "my_hud_pre", function(game, state, w, h, theme) ... end)
PublicApi.onPostRender("battle", "my_hud_post", function(game, state, w, h, theme) ... end)
```

### 3. Sandboxed Execution (`HookBoundary`)
External mod renderers and callbacks are protected by `HookBoundary`, preventing third-party Lua crashes or unpopped graphics matrix states from disrupting the core game.

