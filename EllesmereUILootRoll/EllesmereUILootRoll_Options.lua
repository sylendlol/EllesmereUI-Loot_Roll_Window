if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUILootRoll_Options.lua
--  The "Loot Roll Window" row of the Dworak section, one page with a live
--  preview in the content header: a roll popup with sample choices from a
--  party or a raid, using the same badges and tooltip code as the real ones.
-------------------------------------------------------------------------------
local _, ns = ...

local PAGE = "Loot Roll Window"

-------------------------------------------------------------------------------
--  Sample choices
-------------------------------------------------------------------------------
ns.previewMode = "PARTY"

local PARTY = {
    { "Thraxor", "WARRIOR", "need" }, { "Lunessa", "PRIEST", "need" },
    { "Pyrelle", "MAGE", "greed" }, { "Kragg", "HUNTER", "pass" },
}
local RAID_CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local RAID_NAMES = { "Aldric", "Brenna", "Corvin", "Dalia", "Eamon", "Fenra", "Garrick", "Hesta", "Ivor", "Jorna",
    "Kael", "Lyra", "Morden", "Nyssa", "Orrin", "Perrin", "Quilla", "Roderic", "Sylva", "Torvald",
    "Ulla", "Varik", "Wren", "Yorick" }
-- 24 others: 6 need, 8 greed, 4 pass, 6 waiting (you wait too).
local RAID_SPLIT = { need = 6, greed = 8, pass = 4 }

local function SampleData(mode)
    local d = { need = {}, greed = {}, pass = {}, wait = {}, total = 0 }
    local _, myClass = UnitClass("player")
    table.insert(d.wait, { name = UnitName("player") or "You", class = myClass, isSelf = true })
    if mode == "RAID" then
        local i = 0
        for _, bucket in ipairs({ "need", "greed", "pass" }) do
            for _ = 1, RAID_SPLIT[bucket] do
                i = i + 1
                table.insert(d[bucket], { name = RAID_NAMES[i], class = RAID_CLASSES[(i - 1) % #RAID_CLASSES + 1] })
            end
        end
        for j = i + 1, #RAID_NAMES do
            table.insert(d.wait, { name = RAID_NAMES[j], class = RAID_CLASSES[(j - 1) % #RAID_CLASSES + 1] })
        end
    else
        for _, p in ipairs(PARTY) do table.insert(d[p[3]], { name = p[1], class = p[2] }) end
    end
    for _, k in ipairs({ "need", "greed", "pass", "wait" }) do d.total = d.total + #d[k] end
    return d
end

-------------------------------------------------------------------------------
--  Preview popup (same layout as GroupLootFrameBaseTemplate: 277 x 67)
-------------------------------------------------------------------------------
local FLAT = "Interface\\Buttons\\WHITE8X8"
local FW, FH = 277, 67
local BUTTONS = {
    need  = { atlas = "lootroll-toast-icon-need",  file = "Interface\\Buttons\\UI-GroupLoot-Dice",  tip = "NEED",  fb = "Need" },
    greed = { atlas = "lootroll-toast-icon-greed", file = "Interface\\Buttons\\UI-GroupLoot-Coin",  tip = "GREED", fb = "Greed" },
    pass  = { atlas = "lootroll-toast-icon-pass",  file = "Interface\\Buttons\\UI-GroupLoot-Pass",  tip = "PASS",  fb = "Pass" },
}

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function RollButton(parent, key)
    local spec = BUTTONS[key]
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(32, 32)
    if HasAtlas(spec.atlas .. "-up") then
        b:SetNormalAtlas(spec.atlas .. "-up")
        b:SetPushedAtlas(spec.atlas .. "-down")
        b:SetHighlightAtlas(spec.atlas .. "-highlight", "ADD")
    else
        b:SetNormalTexture(spec.file .. "-Up")
        b:SetPushedTexture(spec.file .. "-Down")
        b:SetHighlightTexture(spec.file .. "-Highlight", "ADD")
    end
    b.tooltipText = _G[spec.tip] or spec.fb
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local preview, hookedParents = nil, {}

local function BuildPreviewFrame(view)
    local f = CreateFrame("Frame", nil, view)
    f:SetSize(FW, FH)
    f:SetPoint("TOP", 0, -28)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.06, 0.06, 0.07, 0.94)
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                           { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0, 0, 0, 1)
        t:SetPoint(pts[1]); t:SetPoint(pts[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
    end

    -- Item: icon with a 1px quality frame, quality colored name.
    local q = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3]
    local qr, qg, qb = q and q.r or 0, q and q.g or 0.44, q and q.b or 0.87
    f.iconBorder = f:CreateTexture(nil, "ARTWORK")
    f.iconBorder:SetSize(36, 36)
    f.iconBorder:SetPoint("TOPLEFT", 9, -10)
    f.iconBorder:SetColorTexture(qr, qg, qb, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.icon:SetSize(34, 34)
    f.icon:SetPoint("TOPLEFT", 10, -11)
    f.icon:SetTexture("Interface\\Icons\\INV_Sword_39")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetSize(125, 30)
    f.name:SetPoint("TOPLEFT", 60, -15)
    f.name:SetJustifyH("LEFT")
    f.name:SetJustifyV("MIDDLE")
    f.name:SetText("Ironbark Greatblade")
    f.name:SetTextColor(qr, qg, qb)

    -- Timer bar.
    f.timer = CreateFrame("StatusBar", nil, f)
    f.timer:SetSize(190, 8)
    f.timer:SetPoint("BOTTOMLEFT", 3, 4)
    f.timer:SetStatusBarTexture(FLAT)
    f.timer:SetMinMaxValues(0, 1)
    f.timer:SetValue(0.62)
    f.timer.bg = f.timer:CreateTexture(nil, "BACKGROUND")
    f.timer.bg:SetAllPoints()
    f.timer.bg:SetColorTexture(0, 0, 0, 0.55)

    -- Buttons where Blizzard puts them (container starts at the name's right).
    local left = 60 + 125 + 3
    f.need = RollButton(f, "need")
    f.need:SetPoint("TOPLEFT", left + 14, -7)
    f.pass = RollButton(f, "pass")
    f.pass:SetPoint("LEFT", f.need, "RIGHT", 6, 2)
    f.greed = RollButton(f, "greed")
    f.greed:SetPoint("TOP", f.need, "BOTTOM", 0, 5)
    return f
end

local function Style(v)
    local f = v.frame
    EllesmereUI.ApplyModuleFont(f.name, nil, 12)
    EllesmereUI.ApplyModuleFont(v.hint, nil, 10)
    f.timer:SetStatusBarColor(ns.Accent())
end

ns.RefreshPreview = function(force)
    local v = preview
    if not (v and (force or v.view:IsVisible())) then return end
    v.roll.data = SampleData(ns.previewMode)
    Style(v)
    ns.Paint(v.deco)
    local pw = v.view:GetParent():GetWidth()
    local available = (pw > 0 and pw) or v.availableWidth or FW + 40
    local scale = math.min(1.25, math.max(100, available - 200) / FW)
    v.frame:SetScale(scale)
    v.hint:SetText(ns.Get("enabled")
        and "|cff9d9d9dHover Need, Greed or Pass to see the tooltip.|r"
        or "|cff9d9d9dLoot Roll Window is off.|r")
    v.previewHeight = math.floor((FH + 28 + 34) * scale + 30)
    v.view:SetHeight(v.previewHeight)
    if v.onHeightChanged then v.onHeightChanged(v.previewHeight) end
end

local function CreatePreview(parent, availableWidth, onHeightChanged)
    local v = preview
    if not v then
        v = {}
        v.view = CreateFrame("Frame", nil, parent)
        v.frame = BuildPreviewFrame(v.view)
        v.hint = v.view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        v.hint:SetPoint("BOTTOM", 0, 8)
        v.roll = { preview = true }
        v.deco = ns.Decorate(v.frame, { need = v.frame.need, greed = v.frame.greed, pass = v.frame.pass },
            function() return v.roll end,
            function() return ns.previewMode == "RAID" end)
        v.view:SetScript("OnShow", function() ns.RefreshPreview() end)
        preview = v
    end
    v.availableWidth, v.onHeightChanged = availableWidth, onHeightChanged
    v.view:SetParent(parent)
    v.view:ClearAllPoints()
    v.view:SetPoint("TOPLEFT")
    v.view:SetPoint("TOPRIGHT")
    if not hookedParents[parent] then
        hookedParents[parent] = true
        local lastWidth
        parent:HookScript("OnSizeChanged", function(_, width)
            if width == lastWidth then return end
            lastWidth = width
            if v.view:GetParent() == parent then ns.RefreshPreview() end
        end)
    end
    v.view:Show()
    ns.RefreshPreview(true)
    return v
end

local function HeaderBuilder(header, width)
    local building = true
    local v = CreatePreview(header, width, function(height)
        if not building and header:IsVisible() and math.abs(header:GetHeight() - height) > 1 then
            EllesmereUI:SetContentHeaderHeightSilent(height)
        end
    end)
    building = false
    return v.previewHeight
end

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local POSITIONS = {
    BOTTOMRIGHT = "Bottom Right", TOPRIGHT = "Top Right",
    BOTTOMLEFT = "Bottom Left", TOPLEFT = "Top Left", CENTER = "Center",
}
local POSITION_ORDER = { "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMLEFT", "TOPLEFT", "CENTER" }

local LAYOUTS = {
    OUTSIDE = "Beside the Button (free side)",
    INSIDE  = "On the Icon (bottom right)",
    CORNER  = "Button Corner (choose)",
    SUMMARY = "Summary Line (N · G · P)",
}
local LAYOUT_ORDER = { "OUTSIDE", "INSIDE", "CORNER", "SUMMARY" }

local TEXT_POSITIONS = {
    PASS_BELOW = "Under the Pass Button", PASS_RIGHT = "Right of the Pass Button",
    FRAME_TOP = "Above the Window", FRAME_BOTTOM = "Below the Window",
    FRAME_RIGHT = "Right of the Window", FRAME_LEFT = "Left of the Window",
    INSIDE_TOPRIGHT = "Inside, Top Right", INSIDE_BOTTOMRIGHT = "Inside, Bottom Right",
}
local TEXT_POSITION_ORDER = { "PASS_BELOW", "PASS_RIGHT", "FRAME_TOP", "FRAME_BOTTOM",
    "FRAME_RIGHT", "FRAME_LEFT", "INSIDE_TOPRIGHT", "INSIDE_BOTTOMRIGHT" }

local function BuildPage(pageName, parent, yOffset)
    local W = EllesmereUI.Widgets
    local BLANK = EllesmereUI.BlankRowCfg
    local y = yOffset
    local _, h
    parent._showRowDivider = true

    local prebuilding = EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild()
    if not prebuilding then EllesmereUI:SetContentHeader(HeaderBuilder) end

    local function off() return not ns.Get("enabled") end
    local function countsOff() return off() or not ns.Get("counts") end
    local function tipOff() return off() or not ns.Get("tooltip") end

    local function Changed()
        ns.RefreshAll()
    end
    local function Bind(cfg, key, disabled, why)
        cfg.disabled = disabled or off
        cfg.disabledTooltip = why or "Loot Roll Window"
        cfg.getValue = cfg.getValue or function() return ns.Get(key) end
        cfg.setValue = cfg.setValue or function(v)
            ns.Cfg()[key] = v
            Changed()
        end
        return cfg
    end
    local function Toggle(key, text, tooltip, disabled, why)
        return Bind({ type = "toggle", text = text, tooltip = tooltip }, key, disabled, why)
    end
    local function Slider(key, text, min, max, disabled, why, tooltip)
        return Bind({ type = "slider", text = text, min = min, max = max, step = 1, tooltip = tooltip },
            key, disabled, why)
    end

    ---------------------------------------------------------------------------
    --  GENERAL
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "LOOT ROLL WINDOW", y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enable",
          tooltip = "Shows on the Need, Greed and Pass buttons of the loot roll popup how many group members chose each.",
          getValue = function() return ns.Get("enabled") end,
          setValue = function(v)
              ns.Cfg().enabled = v
              Changed()
              EllesmereUI:RefreshPage()
          end },
        { type = "dropdown", text = "Preview Group",
          values = { PARTY = "Party (names)", RAID = "Raid (numbers)" }, order = { "PARTY", "RAID" },
          tooltip = "Sample choices for the preview above. Nothing changes in the game.",
          getValue = function() return ns.previewMode end,
          setValue = function(v)
              ns.previewMode = v
              ns.RefreshPreview()
          end }
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  COUNTS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "COUNTS", y);  y = y - h

    local function layout() return ns.Get("countLayout") end
    local function noBadges() return countsOff() or layout() == "SUMMARY" end
    local function notCorner() return countsOff() or layout() ~= "CORNER" end
    local function notSummary() return countsOff() or layout() ~= "SUMMARY" end
    local function why(want)
        return function()
            if off() then return "Loot Roll Window" end
            if not ns.Get("counts") then return "Show Counts" end
            return "Count Layout: " .. want
        end
    end
    -- Layout changes grey other rows in or out.
    local function Relayout(cfg)
        local set = cfg.setValue
        cfg.setValue = function(v)
            set(v)
            EllesmereUI:RefreshPage()
        end
        return cfg
    end

    _, h = W:DualRow(parent, y,
        Relayout(Toggle("counts", "Show Counts", "How many chose Need, Greed and Pass.")),
        Relayout(Bind({ type = "dropdown", text = "Count Layout", values = LAYOUTS, order = LAYOUT_ORDER,
               tooltip = "Beside the Button: Need and Greed numbers on the left, Pass on the right, so none sits "
                   .. "next to another button. On the Icon: like a stack count. Button Corner: the corner you pick "
                   .. "below. Summary Line: no numbers on the buttons, one \"N 2 · G 1 · P 1\" line instead." },
            "countLayout", countsOff, "Show Counts"))
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("countColor", "Color by Button",
            "Each number (and badge frame) takes its button's color: Need white, Greed gold, Pass red. "
                .. "Off: white numbers in UI Accent Color frames.", countsOff, "Show Counts"),
        Toggle("hideZero", "Hide Zero", "No number on a button nobody chose.", noBadges, why("not Summary Line"))
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Bind({ type = "dropdown", text = "Count Style",
               values = { BADGE = "Badge (framed box)", TEXT = "Text (outlined)" }, order = { "BADGE", "TEXT" },
               tooltip = "Badge: a dark box with a 1px frame." },
            "countStyle", noBadges, why("not Summary Line")),
        Slider("countSize", "Count Text Size", 8, 20, countsOff, "Show Counts")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Bind({ type = "dropdown", text = "Button Corner", values = POSITIONS, order = POSITION_ORDER,
               tooltip = "Which corner of the button the number sits on (Button Corner layout)." },
            "countPos", notCorner, why("Button Corner")),
        BLANK()
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Slider("countX", "Count X Offset", -20, 20, noBadges, why("not Summary Line"),
            "Moves every number. Separate Positions adds a per-button offset on top."),
        Slider("countY", "Count Y Offset", -20, 20, noBadges, why("not Summary Line"),
            "Moves every number. Separate Positions adds a per-button offset on top.")
    );  y = y - h

    local function sepOff() return noBadges() or not ns.Get("countSeparate") end
    local function sepWhy()
        if noBadges() then return why("not Summary Line")() end
        return "Separate Positions"
    end

    _, h = W:DualRow(parent, y,
        Relayout(Toggle("countSeparate", "Separate Positions",
            "Each button's number gets its own X / Y offset, added to the Count X / Y Offset above.",
            noBadges, why("not Summary Line"))),
        BLANK()
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Slider("needX", "Need X Offset", -30, 30, sepOff, sepWhy),
        Slider("needY", "Need Y Offset", -30, 30, sepOff, sepWhy)
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Slider("greedX", "Greed X Offset", -30, 30, sepOff, sepWhy, "Also moves the Transmog number."),
        Slider("greedY", "Greed Y Offset", -30, 30, sepOff, sepWhy, "Also moves the Transmog number.")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Slider("passX", "Pass X Offset", -30, 30, sepOff, sepWhy),
        Slider("passY", "Pass Y Offset", -30, 30, sepOff, sepWhy)
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Bind({ type = "dropdown", text = "Summary Position", values = TEXT_POSITIONS, order = TEXT_POSITION_ORDER },
            "summaryPos", notSummary, why("Summary Line")),
        BLANK()
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Slider("summaryX", "Summary X Offset", -100, 100, notSummary, why("Summary Line")),
        Slider("summaryY", "Summary Y Offset", -60, 60, notSummary, why("Summary Line"))
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  ROLLED COUNTER
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "ROLLED COUNTER", y);  y = y - h

    local function rolledOff() return off() or not ns.Get("rolled") end

    _, h = W:DualRow(parent, y,
        Relayout(Toggle("rolled", "Show Rolled Counter",
            "\"3/5\": how many have chosen out of the whole group.")),
        Slider("rolledSize", "Counter Text Size", 8, 16, rolledOff, "Show Rolled Counter")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Bind({ type = "dropdown", text = "Counter Position", values = TEXT_POSITIONS, order = TEXT_POSITION_ORDER },
            "rolledPos", rolledOff, "Show Rolled Counter"),
        BLANK()
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Slider("rolledX", "Counter X Offset", -100, 100, rolledOff, "Show Rolled Counter"),
        Slider("rolledY", "Counter Y Offset", -60, 60, rolledOff, "Show Rolled Counter")
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  TOOLTIP
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "TOOLTIP", y);  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("tooltip", "Show Choices in Tooltip",
            "Hovering a button lists who chose it, in class color. In a raid only the numbers."),
        Toggle("waiting", "Show Waiting Players", "Also lists who has not chosen yet.", tipOff,
            "Show Choices in Tooltip")
    );  y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("raidNames", "Names in Raid", "Lists the names in a raid too, not only the numbers.", tipOff,
            "Show Choices in Tooltip"),
        BLANK()
    );  y = y - h

    _, h = W:Spacer(parent, y, 20);  y = y - h

    ---------------------------------------------------------------------------
    --  COLORS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "COLORS", y);  y = y - h

    local MODES = { ACCENT = "UI Accent Color", CUSTOM = "Custom" }
    local MODE_ORDER = { "ACCENT", "CUSTOM" }
    local function ModeRow(prefix, text, tooltip, disabled, why)
        return Bind({ type = "dropdown", text = text, values = MODES, order = MODE_ORDER, tooltip = tooltip,
                      setValue = function(v)
                          ns.Cfg()[prefix .. "Mode"] = v
                          Changed()
                          EllesmereUI:RefreshPage()
                      end }, prefix .. "Mode", disabled, why)
    end
    -- The inline swatch picks the custom color; greyed out while the mode is the accent.
    local function Swatch(region, prefix, tooltip, disabled, why)
        if prebuilding or not (region and EllesmereUI.BuildInlineSwatches) then return end
        local function swOff() return disabled() or ns.Get(prefix .. "Mode") ~= "CUSTOM" end
        EllesmereUI.BuildInlineSwatches(region, { {
            tooltip = tooltip, disabled = swOff,
            disabledTooltip = function()
                if disabled() then return type(why) == "function" and why() or why end
                return "Custom"
            end,
            getValue = function() return ns.Get(prefix .. "R"), ns.Get(prefix .. "G"), ns.Get(prefix .. "B"), 1 end,
            setValue = function(r, g, b)
                local c = ns.Cfg()
                c[prefix .. "R"], c[prefix .. "G"], c[prefix .. "B"] = r, g, b
                Changed()
            end,
        } }, { disabled = off, disabledTooltip = "Loot Roll Window" })
    end

    local function badgeOff()
        return noBadges() or ns.Get("countColor") or ns.Get("countStyle") ~= "BADGE"
    end
    local function badgeWhy()
        if off() then return "Loot Roll Window" end
        if not ns.Get("counts") then return "Show Counts" end
        if ns.Get("countLayout") == "SUMMARY" then return "Count Layout: not Summary Line" end
        if ns.Get("countColor") then return "Color by Button off" end
        return "Count Style: Badge"
    end
    local function tipColorOff() return tipOff() end

    local colorRow
    colorRow, h = W:DualRow(parent, y,
        ModeRow("badge", "Badge Frame Color",
            "Frame of the count badges while Color by Button is off.", badgeOff, badgeWhy),
        ModeRow("rolled", "Counter Color", "The chosen number of the \"3/5\" counter.",
            rolledOff, "Show Rolled Counter")
    );  y = y - h
    Swatch(colorRow and colorRow._leftRegion, "badge", "Badge Frame Color", badgeOff, badgeWhy)
    Swatch(colorRow and colorRow._rightRegion, "rolled", "Counter Color", rolledOff, "Show Rolled Counter")

    local tipRow
    tipRow, h = W:DualRow(parent, y,
        ModeRow("tip", "Tooltip Header Color", "The \"Need 1 / 5\" line in the button tooltip.",
            tipColorOff, "Show Choices in Tooltip"),
        BLANK()
    );  y = y - h
    Swatch(tipRow and tipRow._leftRegion, "tip", "Tooltip Header Color", tipColorOff, "Show Choices in Tooltip")

    _, h = W:Spacer(parent, y, 20);  y = y - h

    return math.abs(y)
end

-------------------------------------------------------------------------------
--  Registration: the "Loot Roll Window" row of the "Dworak" section.
-------------------------------------------------------------------------------
local DW = EllesmereUIDworak
if not DW then
    ns.Print("EllesmereUI Dworak is not enabled, so the Loot Roll Window settings cannot be shown.")
    return
end

DW.AddModule({
    key         = "LootRoll",
    title       = "Loot Roll Window",
    order       = 45,
    description = "Need / Greed / Pass counts on the loot roll popup, with who chose what in class color.",
    pages       = { PAGE },
    buildPage   = BuildPage,
    getHeaderBuilder = function() return HeaderBuilder end,
    onPageCacheRestore = function() ns.RefreshPreview() end,
    onReset = function()
        ns.Reset()
        ns.RefreshAll()
        EllesmereUI:RefreshPage(true)
    end,
})

-- /lootroll opens the settings, /lootroll dump prints the open rolls.
SLASH_EUILOOTROLL1 = "/lootroll"
SlashCmdList.EUILOOTROLL = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "dump" then
        ns.Dump()
    else
        DW.Open("LootRoll", PAGE)
    end
end
