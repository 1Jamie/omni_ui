-- OmniUI Modern PC Mailbox System Renderer
-- Dual-pane 10-slot PC mailbox catalog with live postcard preview and mail action dispatcher.
-- Reconstructs side-by-side catalog & preview to stacked vertical cards on portrait viewports with dynamic scrollbars.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Mail = require("src.core.gen2.Mail")

local MailboxRenderer = {}

local SUB_ENTRIES = {
  { id = "read", label = "READ MAIL" },
  { id = "pack", label = "PUT IN PACK" },
  { id = "attach", label = "ATTACH MAIL" },
  { id = "cancel", label = "CANCEL" },
}

function MailboxRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local save = state.save or (game and game.save) or {}
  local box = (state.box and state:box()) or (state.box) or Mail.mailbox(save) or {}
  local total = (state.count and state:count()) or #box
  local selectedIdx = state.index or 1
  local scroll = state.scroll or 0
  local selMail = box[selectedIdx] or {}

  -- 1. Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Frame Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(760, vw - pad * 2)
  local cardH = math.min(520, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Card
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 22 or 26
  Layout.drawBadge(cardX + pad, topY, "PC MAILBOX STORAGE", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local countStr = ("%d / 10 STORED"):format(total)
  local countW = Layout.textWidth(countStr, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - countW, topY, countStr, {
    kind = total > 0 and "good" or "ghost",
    font = "tiny",
    height = headerH,
    width = countW,
    radius = 4,
  })

  -- 4. Content Area Layout
  local contentY = topY + headerH + (isCompact and 6 or 10)
  local footerH = (state.message or state.confirm) and (isCompact and (isPortrait and 80 or 70) or 100) or (isCompact and 26 or 34)
  local contentH = cardH - (contentY - cardY) - footerH - pad

  -- Helper to render preview of letter
  local function drawLetterPreview(px, py, pw, ph)
    Layout.drawCard(px, py, pw, ph, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.borderStrong,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText("LETTER PREVIEW", px + 10, py + 6, {
      font = "tiny",
      color = theme.colors.heading,
      bold = true,
    })

    if selMail and (selMail.author or selMail.message or selMail.type) then
      local top, bottom = Mail.lines(selMail)
      local slotH = ph - 30
      local slotY = py + 24

      Layout.drawSlot(px + 8, slotY, pw - 16, slotH, {
        color = theme.colors.surface,
        borderColor = theme.colors.border,
        borderWidth = 1,
        radius = 6,
      })

      Layout.drawBadge(px + pw - 90, slotY + 6, tostring(selMail.type or "MAIL"):upper(), {
        kind = "primary",
        font = "tiny",
        height = 16,
        width = 80,
        radius = 3,
      })

      Layout.drawText(top or "", px + 14, slotY + (isCompact and 14 or 20), {
        font = isCompact and "caption" or "body",
        color = theme.colors.heading,
        bold = true,
      })

      if bottom and #bottom > 0 and slotH >= 46 then
        Layout.drawText(bottom, px + 14, slotY + (isCompact and 30 or 40), {
          font = isCompact and "caption" or "body",
          color = theme.colors.heading,
          bold = true,
        })
      end

      local authorStr = ("From: %s"):format(tostring(selMail.author or "TRAINER"):upper())
      Layout.drawText(authorStr, px + 14, slotY + slotH - 18, {
        font = "tiny",
        color = theme.colors.accent,
        bold = true,
      })
    else
      Layout.drawText("- SELECT A LETTER TO PREVIEW -", px + 14, py + math.floor(ph / 2) - 6, {
        font = "tiny",
        color = theme.colors.textDim,
      })
    end
  end

  -- Helper to render catalog list
  local function drawCatalogList(lx, ly, lw, lh)
    Layout.drawCard(lx, ly, lw, lh, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText("STORED LETTERS", lx + 10, ly + 6, {
      font = "tiny",
      color = theme.colors.accent,
      bold = true,
    })

    local listStartY = ly + 24
    local listAvailableH = lh - 28
    local itemH = isCompact and 30 or 38
    local itemGap = 4
    local visibleRows = math.max(2, math.min(5, math.floor(listAvailableH / (itemH + itemGap))))

    if total == 0 then
      Layout.drawText("- MAILBOX IS EMPTY -", lx + 14, ly + math.floor(lh / 2) - 6, {
        font = "tiny",
        color = theme.colors.textDim,
      })
    else
      for row = 1, visibleRows do
        local i = scroll + row
        local entry = box[i]
        local iy = listStartY + (row - 1) * (itemH + itemGap)

        if entry then
          local isSel = (i == selectedIdx)
          local authorName = entry.author and (entry.author ~= "" and entry.author or "TRAINER") or "TRAINER"
          local mailType = entry.type or "MAIL"

          Layout.drawCard(lx + 6, iy, lw - 12, itemH, {
            color = isSel and theme.colors.raised or theme.colors.surface,
            borderColor = isSel and (theme.colors.accent or theme.colors.borderStrong) or theme.colors.border,
            borderWidth = isSel and 2 or 1,
            radius = 5,
          })

          Layout.drawText(authorName:upper(), lx + 12, iy + (itemH > 32 and 4 or 6), {
            font = itemH > 32 and "button" or "caption",
            color = isSel and theme.colors.heading or theme.colors.text,
            bold = true,
          })

          if itemH > 32 then
            Layout.drawText(tostring(mailType):upper():gsub("_", " "), lx + 12, iy + 18, {
              font = "tiny",
              color = theme.colors.textDim,
            })
          end

          if isSel then
            Layout.drawBadge(lx + lw - 28, iy + math.floor((itemH - 16) / 2), "►", {
              kind = "accent",
              font = "tiny",
              width = 16,
              height = 16,
              radius = 3,
            })
          end
        end
      end

      if total > visibleRows then
        Layout.drawScrollBar(lx + lw - 6, listStartY, 3, visibleRows * (itemH + itemGap) - itemGap, total, visibleRows, scroll + 1, {
          is1Indexed = true,
          radius = 2,
        })
      end
    end
  end

  if isPortrait then
    -- =========================================================================
    -- PORTRAIT STACKED LAYOUT (Top: Catalog List, Bottom: Postcard Preview)
    -- =========================================================================
    local slotGap = 6
    local topPaneH = math.floor(contentH * 0.52)
    local botPaneH = contentH - topPaneH - slotGap
    local paneW = cardW - pad * 2

    drawCatalogList(cardX + pad, contentY, paneW, topPaneH)
    drawLetterPreview(cardX + pad, contentY + topPaneH + slotGap, paneW, botPaneH)
  else
    -- =========================================================================
    -- LANDSCAPE SIDE-BY-SIDE DUAL PANE
    -- =========================================================================
    local leftW = math.floor((cardW - pad * 2 - (isCompact and 10 or 16)) * 0.44)
    local rightW = cardW - pad * 2 - leftW - (isCompact and 10 or 16)
    local leftX = cardX + pad
    local rightX = leftX + leftW + (isCompact and 10 or 16)

    drawCatalogList(leftX, contentY, leftW, contentH)
    drawLetterPreview(rightX, contentY, rightW, contentH)
  end

  -- 5. Floating Submenu Modal
  if state.submenu then
    local subW = isCompact and 150 or 180
    local subH = isCompact and 130 or 150
    local subX = math.floor((vw - subW) / 2)
    local subY = math.floor((vh - subH) / 2)

    Layout.drawCard(subX, subY, subW, subH, {
      color = theme.colors.surface,
      borderColor = theme.colors.accent,
      borderWidth = 2,
      radius = 8,
    })

    local subSel = state.submenu.index or 1
    local subBtnH = isCompact and 24 or 28
    for row, entry in ipairs(SUB_ENTRIES) do
      local isSel = (row == subSel)
      local by = subY + 8 + (row - 1) * (subBtnH + 4)
      Layout.drawButton(subX + 8, by, subW - 16, subBtnH, entry.label, {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = "tiny",
      })
    end
  end

  -- 6. Footer / Confirmation Box
  local footerY = cardY + cardH - footerH - pad
  local footerW = cardW - pad * 2

  if state.message or state.confirm then
    local activeMsg = state.message or state.confirm
    local pageIdx = activeMsg.page or 1
    local pages = activeMsg.pages or {}
    local curLines = pages[pageIdx] or {}
    local line1 = curLines[1] or ""
    local line2 = curLines[2] or ""

    Layout.drawCard(cardX + pad, footerY, footerW, footerH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.accent,
      borderWidth = 1.5,
      radius = 8,
    })

    Layout.drawText(line1, cardX + pad + 12, footerY + (isCompact and 6 or 10), {
      font = isCompact and "caption" or "body",
      color = theme.colors.heading,
      bold = true,
    })
    if line2 and #line2 > 0 and footerH >= 50 then
      Layout.drawText(line2, cardX + pad + 12, footerY + (isCompact and 22 or 28), {
        font = isCompact and "caption" or "body",
        color = theme.colors.heading,
        bold = true,
      })
    end

    if state.confirm and pageIdx >= #pages then
      local choice = state.confirm.choice or 1
      local btnW = isCompact and 70 or 86
      local btnH = isCompact and 24 or 28
      local btnY = footerY + footerH - btnH - (isCompact and 4 or 8)

      Layout.drawButton(cardX + cardW - pad - btnW * 2 - 14, btnY, btnW, btnH, "YES", {
        kind = choice == 1 and "primary" or "ghost",
        selected = choice == 1,
        font = "tiny",
      })
      Layout.drawButton(cardX + cardW - pad - btnW - 6, btnY, btnW, btnH, "NO", {
        kind = choice == 2 and "primary" or "ghost",
        selected = choice == 2,
        font = "tiny",
      })
    end
  else
    Layout.drawText("▲ ▼ Select Letter   A Options   B Close Mailbox", cardX + pad, footerY + (isCompact and 6 or 8), {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = footerW,
    })
  end
end

return MailboxRenderer
