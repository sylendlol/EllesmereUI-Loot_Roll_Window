if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUILootRoll.lua
--  Loot Roll Window (Dworak > Loot Roll Window): on the group loot roll popups
--  (GroupLootFrame1..4) every Need / Greed / Pass button shows how many group
--  members chose it, and its tooltip lists them in class color (in a raid:
--  only the numbers). A standalone addon, so an EllesmereUI update never
--  overwrites it. No EllesmereUI file is changed; the Blizzard Skin's loot
--  roll skin keeps working, we only add our own child frames on top.
--
--  Where the choices come from:
--   1. C_LootHistory (GetSortedInfoForDrop): every player of the drop with
--      the state Need / Greed / Transmog / Pass / NoRoll ("waiting"), live,
--      LOOT_HISTORY_UPDATE_DROP on every change. A roll popup is paired with
--      its drop by item.
--   2. Chat fallback (CHAT_MSG_LOOT "X has selected Greed for: [item]"),
--      matched with the client's own localized LOOT_ROLL_* strings, for when
--      the loot history has no entry for the roll (yet).
--
--  Settings are account-wide in EllesmereUILootRollDB.
--  /lootroll opens the settings, /lootroll dump prints what the client gives.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

EllesmereUILootRoll = EllesmereUILootRoll or {}
ns.API = EllesmereUILootRoll

local SV_NAME = "EllesmereUILootRollDB"
local NUM_FRAMES = 4

local DEFAULTS = {
    enabled     = true,
    counts      = true,        -- the choice counts
    countLayout = "OUTSIDE",   -- OUTSIDE (free side of each button) / INSIDE (on the icon,
                               -- bottom right) / CORNER (countPos) / SUMMARY (one line)
    countColor  = true,        -- number (and badge frame) in the button's own color
    hideZero    = true,
    countStyle  = "BADGE",     -- BADGE (framed box) / TEXT (outlined number)
    countSize   = 12,
    countPos    = "BOTTOMRIGHT", -- CORNER layout only
    countX      = 0,
    countY      = 0,
    summaryPos  = "FRAME_BOTTOM", -- SUMMARY layout: where the line sits
    summaryX    = 0,
    summaryY    = 0,
    rolled      = true,        -- "3/5": chosen / group
    rolledSize  = 10,
    rolledPos   = "PASS_BELOW",
    rolledX     = 0,
    rolledY     = 0,
    tooltip     = true,        -- names in the button tooltip
    waiting     = true,        -- "Waiting:" list in the tooltip
    raidNames   = false,       -- names in a raid too (default: numbers only)
    -- Colors that follow the UI Accent Color unless set to CUSTOM:
    badgeMode   = "ACCENT", badgeR = 1, badgeG = 1, badgeB = 1,          -- badge frames (Color by Button off)
    rolledMode  = "ACCENT", rolledR = 1, rolledG = 0.82, rolledB = 0,    -- the "3" of "3/5"
    tipMode     = "ACCENT", tipR = 1, tipG = 0.82, tipB = 0,             -- tooltip header line
}
ns.DEFAULTS = DEFAULTS

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local function Root(create)
    local root = _G[SV_NAME]
    if type(root) ~= "table" then
        if not create then return nil end
        root = {}
        _G[SV_NAME] = root
    end
    return root
end

function ns.Get(key)
    local root = Root(false)
    local v = root and root[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

function ns.Cfg()
    return Root(true)
end

function ns.Reset()
    _G[SV_NAME] = {}
end

function ns.Print(msg)
    local brand = (EllesmereUI.COLOR_CODES and EllesmereUI.COLOR_CODES.BRAND) or "|cff0cd29d"
    EllesmereUI.Print(brand .. "Loot Roll Window:|r " .. msg)
end

function ns.Accent()
    local c = EllesmereUI.ELLESMERE_GREEN
    if c then return c.r, c.g, c.b end
    return 0.05, 0.82, 0.62
end

-- The UI Accent Color, or the custom color of an element (prefix "badge",
-- "rolled", "tip") when its mode is CUSTOM.
function ns.ColorOf(prefix)
    if ns.Get(prefix .. "Mode") == "CUSTOM" then
        return ns.Get(prefix .. "R"), ns.Get(prefix .. "G"), ns.Get(prefix .. "B")
    end
    return ns.Accent()
end

function ns.ClassColor(class)
    if class and EllesmereUI.GetClassColor then
        local c = EllesmereUI.GetClassColor(class)
        if c then return c.r, c.g, c.b end
    end
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-------------------------------------------------------------------------------
--  Roll states -> the four buckets the buttons show
-------------------------------------------------------------------------------
local S = Enum and Enum.EncounterLootDropRollState or {}
local ST_NEED, ST_NEED_OS = S.NeedMainSpec or 0, S.NeedOffSpec or 1
local ST_TMOG, ST_GREED   = S.Transmog or 2, S.Greed or 3
local ST_NOROLL, ST_PASS  = S.NoRoll or 4, S.Pass or 5

local function Bucket(state)
    if state == ST_NEED or state == ST_NEED_OS then return "need" end
    if state == ST_GREED or state == ST_TMOG then return "greed" end
    if state == ST_PASS then return "pass" end
    return "wait"
end

local function ItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-------------------------------------------------------------------------------
--  Group roster: name -> class (party / raid members and you)
-------------------------------------------------------------------------------
local roster = {}

local function AddUnit(unit)
    if not UnitExists(unit) then return end
    local name, realm = UnitName(unit)
    if not name then return end
    local _, class = UnitClass(unit)
    local e = { name = name, class = class, isSelf = UnitIsUnit(unit, "player") }
    roster[name] = e
    if realm and realm ~= "" then roster[name .. "-" .. realm] = e end
end

local function BuildRoster()
    wipe(roster)
    AddUnit("player")
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do AddUnit("raid" .. i) end
    else
        for i = 1, GetNumSubgroupMembers() do AddUnit("party" .. i) end
    end
end

-- Unique members (roster has a name and a name-realm key for some).
local function RosterMembers()
    local list, seen = {}, {}
    for _, e in pairs(roster) do
        if not seen[e] then
            seen[e] = true
            list[#list + 1] = e
        end
    end
    return list
end

local function ShortName(name)
    return name and (name:match("^([^%-]+)") or name)
end

-------------------------------------------------------------------------------
--  Active rolls
--    rolls[rollID] = { rollID, link, itemID, started, duration,
--                      drop = { enc, key } (loot history match),
--                      chat = { [shortName] = { bucket, transmog } } }
-------------------------------------------------------------------------------
local rolls, claimed = {}, {}   -- claimed["enc:key"] = rollID

local function DropKey(enc, key)
    return tostring(enc) .. ":" .. tostring(key)
end

local function NewRoll(rollID, duration)
    if not rollID then return end
    local r = rolls[rollID]
    if r then return r end
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
    r = { rollID = rollID, link = link, itemID = ItemID(link), started = GetTime(),
          duration = (duration or 60000) / 1000, chat = {} }
    rolls[rollID] = r
    return r
end

local function DropRoll(rollID)
    local r = rolls[rollID]
    if not r then return end
    if r.drop then claimed[DropKey(r.drop.enc, r.drop.key)] = nil end
    rolls[rollID] = nil
end

-- Rolls whose popup is long gone (missed CANCEL_LOOT_ROLL) are forgotten.
local function Prune()
    local now = GetTime()
    local active
    if GetActiveLootRollIDs then
        active = {}
        for _, id in ipairs(GetActiveLootRollIDs() or {}) do active[id] = true end
    end
    for id, r in pairs(rolls) do
        if not r.preview and now - r.started > r.duration + 30 and not (active and active[id]) then
            DropRoll(id)
        end
    end
end

-------------------------------------------------------------------------------
--  Source 1: the loot history
-------------------------------------------------------------------------------
local LH = C_LootHistory

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, ...)
    if ok then return res end
end

local function DropListKey(drop)
    return drop.lootListKey or drop.lootListID
end

-- An unfinished drop of the same item, not paired with another roll yet.
-- Exact link first, then the newest.
local function MatchDrop(r)
    if r.drop or not r.itemID or not LH then return end
    local best, bestScore
    for _, enc in ipairs(SafeCall(LH.GetAllEncounterInfos) or {}) do
        for _, drop in ipairs(SafeCall(LH.GetSortedDropsForEncounter, enc.encounterID) or {}) do
            local key = DropListKey(drop)
            if key and not claimed[DropKey(enc.encounterID, key)] and not drop.winner and not drop.allPassed
               and ItemID(drop.itemHyperlink) == r.itemID then
                local score = (drop.startTime or 0) + (drop.itemHyperlink == r.link and 1e9 or 0)
                if not bestScore or score > bestScore then
                    best, bestScore = { enc = enc.encounterID, key = key }, score
                end
            end
        end
    end
    if best then
        r.drop = best
        claimed[DropKey(best.enc, best.key)] = r.rollID
    end
end

-- LOOT_HISTORY_UPDATE_DROP for a drop nobody has: hand it to the oldest
-- unpaired roll of that item.
local function OfferDrop(enc, key)
    if not (LH and enc and key) or claimed[DropKey(enc, key)] then return end
    local drop = SafeCall(LH.GetSortedInfoForDrop, enc, key)
    if not drop or drop.winner or drop.allPassed then return end
    local itemID, pick = ItemID(drop.itemHyperlink), nil
    for _, r in pairs(rolls) do
        if not r.drop and not r.preview and r.itemID == itemID and (not pick or r.started < pick.started) then
            pick = r
        end
    end
    if pick then
        pick.drop = { enc = enc, key = key }
        claimed[DropKey(enc, key)] = pick.rollID
    end
end

local function HistoryInfo(r)
    if not LH then return nil end
    MatchDrop(r)
    if not r.drop then return nil end
    local info = SafeCall(LH.GetSortedInfoForDrop, r.drop.enc, r.drop.key)
    if info and type(info.rollInfos) == "table" and #info.rollInfos > 0 then return info end
end

-------------------------------------------------------------------------------
--  Source 2: chat ("X has selected Need for: [item]")
-------------------------------------------------------------------------------
-- Turns a format string into a pattern; order[k] = which argument capture k is.
local function ToPattern(fmt)
    local order, n = {}, 0
    local out = fmt:gsub("%%(%d)%$s", "\1%1\2")
    out = out:gsub("%%s", "\1\2")
    out = out:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    out = out:gsub("\1(%d?)\2", function(d)
        n = n + 1
        order[n] = tonumber(d) or n
        return "(.+)"
    end)
    return "^" .. out .. "$", order
end

-- Most specific first: the SELF lines and the AUTO passes before the plain
-- ones, which would match them too.
local CHAT_FORMATS = {
    { "LOOT_ROLL_NEED_SELF", "need", true },
    { "LOOT_ROLL_GREED_SELF", "greed", true },
    { "LOOT_ROLL_TRANSMOG_SELF", "greed", true, true },
    { "LOOT_ROLL_DISENCHANT_SELF", "greed", true },
    { "LOOT_ROLL_PASSED_SELF_AUTO", "pass", true },
    { "LOOT_ROLL_PASSED_SELF", "pass", true },
    { "LOOT_ROLL_PASSED_AUTO", "pass" },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", "pass" },
    { "LOOT_ROLL_NEED", "need" },
    { "LOOT_ROLL_GREED", "greed" },
    { "LOOT_ROLL_TRANSMOG", "greed", false, true },
    { "LOOT_ROLL_DISENCHANT", "greed" },
    { "LOOT_ROLL_PASSED", "pass" },
}
local chatPatterns

local function BuildChatPatterns()
    chatPatterns = {}
    for _, f in ipairs(CHAT_FORMATS) do
        local fmt = _G[f[1]]
        if type(fmt) == "string" and fmt ~= "" then
            local pat, order = ToPattern(fmt)
            chatPatterns[#chatPatterns + 1] = { pat = pat, order = order, bucket = f[2], self = f[3], tmog = f[4] }
        end
    end
end

local function ParseChat(msg)
    if not chatPatterns then BuildChatPatterns() end
    for _, p in ipairs(chatPatterns) do
        local caps = { msg:match(p.pat) }
        if caps[1] then
            local args = {}
            for k, v in ipairs(caps) do args[p.order[k] or k] = v end
            if p.self then return UnitName("player"), args[1], p.bucket, p.tmog end
            return args[1], args[2], p.bucket, p.tmog
        end
    end
end

local function OnChatLoot(msg)
    if type(msg) ~= "string" then return false end
    local name, item, bucket, tmog = ParseChat(msg)
    if not name then return false end
    local itemID = ItemID(item)
    if not itemID then return false end
    name = ShortName(name)
    -- The oldest roll of that item this player has not chosen on yet.
    local pick
    for _, r in pairs(rolls) do
        if not r.preview and r.itemID == itemID and not r.chat[name] and (not pick or r.started < pick.started) then
            pick = r
        end
    end
    if not pick then return false end
    pick.chat[name] = { bucket = bucket, tmog = tmog }
    return true
end

-------------------------------------------------------------------------------
--  Collect: the four lists for one roll
--    { need = {...}, greed = {...}, pass = {...}, wait = {...}, total, source }
--    entry = { name, class, isSelf, tmog }
-------------------------------------------------------------------------------
local function SortEntries(a, b)
    if a.isSelf ~= b.isSelf then return a.isSelf end
    return a.name < b.name
end

function ns.Collect(r)
    if r.preview then return r.data end
    local res = { need = {}, greed = {}, pass = {}, wait = {}, total = 0 }
    local seen = {}
    local info = HistoryInfo(r)
    if info then
        res.source = "history"
        for _, ri in ipairs(info.rollInfos) do
            local name = ShortName(ri.playerName) or "?"
            local bucket, tmog = Bucket(ri.state), ri.state == ST_TMOG
            -- The chat can be a step ahead of the history.
            local c = r.chat[name]
            if bucket == "wait" and c then bucket, tmog = c.bucket, c.tmog end
            local e = { name = name, class = ri.playerClass, isSelf = ri.isSelf, tmog = tmog }
            table.insert(res[bucket], e)
            seen[name] = true
        end
    else
        res.source = "chat"
        for name, c in pairs(r.chat) do
            local m = roster[name]
            table.insert(res[c.bucket], { name = name, class = m and m.class, isSelf = m and m.isSelf, tmog = c.tmog })
            seen[name] = true
        end
        for _, m in ipairs(RosterMembers()) do
            if not seen[m.name] then
                table.insert(res.wait, { name = m.name, class = m.class, isSelf = m.isSelf })
                seen[m.name] = true
            end
        end
    end
    for _, k in ipairs({ "need", "greed", "pass", "wait" }) do
        table.sort(res[k], SortEntries)
        res.total = res.total + #res[k]
    end
    return res
end

-------------------------------------------------------------------------------
--  Count badges (shared by the real popups and the settings preview)
-------------------------------------------------------------------------------
local FLAT = "Interface\\Buttons\\WHITE8X8"
local badges = {}   -- every badge, for accent / style repaints

local function NewBadge(button, key)
    local b = CreateFrame("Frame", nil, button)
    b:SetFrameLevel(button:GetFrameLevel() + 6)
    if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(true) end -- disabled buttons sit at 35%
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(FLAT)
    b.edges = {}
    for i = 1, 4 do
        local t = b:CreateTexture(nil, "BORDER")
        t:SetTexture(FLAT)
        b.edges[i] = t
    end
    b.edges[1]:SetPoint("TOPLEFT");     b.edges[1]:SetPoint("TOPRIGHT");    b.edges[1]:SetHeight(1)
    b.edges[2]:SetPoint("BOTTOMLEFT");  b.edges[2]:SetPoint("BOTTOMRIGHT"); b.edges[2]:SetHeight(1)
    b.edges[3]:SetPoint("TOPLEFT");     b.edges[3]:SetPoint("BOTTOMLEFT");  b.edges[3]:SetWidth(1)
    b.edges[4]:SetPoint("TOPRIGHT");    b.edges[4]:SetPoint("BOTTOMRIGHT"); b.edges[4]:SetWidth(1)
    b.text = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.text:SetPoint("CENTER", 0, 0)
    b.button, b.key = button, key
    b:Hide()
    badges[#badges + 1] = b
    return b
end

-- The buttons' own colors (Color by Button): dice, coin, pass sign.
local BUTTON_COLOR = {
    need  = { 0.92, 0.92, 0.92 },
    greed = { 1.00, 0.78, 0.25 },
    tmog  = { 0.80, 0.55, 1.00 },
    pass  = { 1.00, 0.38, 0.38 },
}
ns.BUTTON_COLOR = BUTTON_COLOR

-- Number color and badge frame color for a button key.
local function KeyColors(key)
    if ns.Get("countColor") and BUTTON_COLOR[key] then
        local c = BUTTON_COLOR[key]
        return c[1], c[2], c[3], c[1], c[2], c[3]
    end
    local r, g, b = ns.ColorOf("badge")
    return 1, 1, 1, r, g, b
end

-- OUTSIDE: the side that is free in Blizzard's layout (Need / Greed sit on
-- the left of the button group, Pass on the right).
local OUTSIDE = {
    need  = { "RIGHT", "LEFT", -2, 0 },
    greed = { "RIGHT", "LEFT", -2, 0 },
    tmog  = { "RIGHT", "LEFT", -2, 0 },
    pass  = { "LEFT", "RIGHT", 2, 0 },
}

local function PlaceBadge(b)
    local layout, x, y = ns.Get("countLayout"), ns.Get("countX"), ns.Get("countY")
    b:ClearAllPoints()
    if layout == "INSIDE" then
        b:SetPoint("BOTTOMRIGHT", b.button, "BOTTOMRIGHT", -1 + x, 1 + y)
    elseif layout == "CORNER" then
        b:SetPoint("CENTER", b.button, ns.Get("countPos"), x, y)
    else
        local o = OUTSIDE[b.key] or OUTSIDE.need
        b:SetPoint(o[1], b.button, o[2], o[3] + x, o[4] + y)
    end
end

local function StyleBadge(b)
    local size = ns.Get("countSize")
    local badge = ns.Get("countStyle") == "BADGE"
    EllesmereUI.ApplyModuleFont(b.text, nil, size, nil, badge and nil or "OUTLINE")
    local tr, tg, tb, er, eg, eb = KeyColors(b.key)
    b.text:SetTextColor(tr, tg, tb)
    b.bg:SetVertexColor(0.04, 0.04, 0.04, 0.85)
    b.bg:SetShown(badge)
    for _, e in ipairs(b.edges) do
        e:SetVertexColor(er, eg, eb, 1)
        e:SetShown(badge)
    end
    PlaceBadge(b)
end

local function SetBadge(b, n)
    if not ns.Get("counts") or ns.Get("countLayout") == "SUMMARY" or (n == 0 and ns.Get("hideZero")) then
        b:Hide()
        return
    end
    StyleBadge(b)
    b.text:SetText(n)
    local h = ns.Get("countSize") + 4
    b:SetSize(math.max(h, math.ceil(b.text:GetStringWidth()) + 6), h)
    b:Show()
end

-- Where a text line (summary, "3/5") sits: point on the line, the anchor
-- ("frame" or "pass") and its point, base offset.
local TEXT_POS = {
    PASS_BELOW        = { "TOP", "pass", "BOTTOM", 0, -1 },
    PASS_RIGHT        = { "LEFT", "pass", "RIGHT", 3, 0 },
    FRAME_TOP         = { "BOTTOM", "frame", "TOP", 0, 3 },
    FRAME_BOTTOM      = { "TOP", "frame", "BOTTOM", 0, -3 },
    FRAME_RIGHT       = { "LEFT", "frame", "RIGHT", 4, 0 },
    FRAME_LEFT        = { "RIGHT", "frame", "LEFT", -4, 0 },
    INSIDE_TOPRIGHT   = { "TOPRIGHT", "frame", "TOPRIGHT", -5, -4 },
    INSIDE_BOTTOMRIGHT= { "BOTTOMRIGHT", "frame", "BOTTOMRIGHT", -5, 4 },
}
ns.TEXT_POS = TEXT_POS

local function PlaceText(fs, d, posKey, x, y)
    local p = TEXT_POS[posKey] or TEXT_POS.PASS_BELOW
    local anchor = p[2] == "pass" and d.btn.pass or d.frame
    fs:ClearAllPoints()
    fs:SetPoint(p[1], anchor, p[3], p[4] + x, p[5] + y)
end

-- First letter of a localized word (UTF-8 safe).
local function Initial(word)
    return (word or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
end

-------------------------------------------------------------------------------
--  Tooltip lines
-------------------------------------------------------------------------------
local BUCKET_LABEL = {
    need  = function() return NEED or "Need" end,
    greed = function() return GREED or "Greed" end,
    pass  = function() return PASS or "Pass" end,
}

local function NameText(e)
    local txt = Hex(ns.ClassColor(e.class)) .. e.name .. "|r"
    if e.tmog then txt = txt .. " |cff9d9d9d(Transmog)|r" end
    if e.isSelf then txt = txt .. " |cff9d9d9d(you)|r" end
    return txt
end

-- isRaid: numbers only (unless Names in Raid is on).
function ns.AddTooltipLines(tt, data, bucket, isRaid)
    if not (data and ns.Get("tooltip")) then return end
    local list = data[bucket] or {}
    local names = not isRaid or ns.Get("raidNames")
    local ar, ag, ab = ns.ColorOf("tip")
    tt:AddLine(" ")
    tt:AddDoubleLine(BUCKET_LABEL[bucket](), #list .. " / " .. data.total, ar, ag, ab, 1, 1, 1)
    if names then
        if #list == 0 then
            tt:AddLine("Nobody yet", 0.6, 0.6, 0.6)
        else
            for _, e in ipairs(list) do tt:AddLine("  " .. NameText(e)) end
        end
    end
    if ns.Get("waiting") and #data.wait > 0 then
        if names then
            local parts = {}
            for _, e in ipairs(data.wait) do parts[#parts + 1] = NameText(e) end
            tt:AddLine("Waiting: " .. table.concat(parts, "|cff9d9d9d, |r"), 0.6, 0.6, 0.6, true)
        else
            tt:AddDoubleLine("Waiting", #data.wait, 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
        end
    end
    if not names then
        local n, g, p = #data.need, #data.greed, #data.pass
        tt:AddLine(string.format("%s %d  |cff9d9d9d·|r  %s %d  |cff9d9d9d·|r  %s %d",
            BUCKET_LABEL.need(), n, BUCKET_LABEL.greed(), g, BUCKET_LABEL.pass(), p), 0.8, 0.8, 0.8)
    end
end

-------------------------------------------------------------------------------
--  Decorating a roll popup (real or preview)
--    deco = { frame, btn = { need = Button, greed = Button, tmog = Button,
--             pass = Button }, badge = { [key] = badge }, rolled = FontString,
--             getRoll = function() -> r }
-------------------------------------------------------------------------------
local BUTTON_BUCKET = { need = "need", greed = "greed", tmog = "greed", pass = "pass" }
local decos = {}

function ns.Decorate(frame, buttons, getRoll, isRaidFn)
    local d = { frame = frame, btn = buttons, badge = {}, getRoll = getRoll, isRaid = isRaidFn }
    for key, button in pairs(buttons) do
        d.badge[key] = NewBadge(button, key)
        local bucket = BUTTON_BUCKET[key]
        button:HookScript("OnEnter", function(self)
            if not ns.Get("enabled") then return end
            local r = d.getRoll()
            if not r or GameTooltip:GetOwner() ~= self then return end
            ns.AddTooltipLines(GameTooltip, ns.Collect(r), bucket, d.isRaid())
            GameTooltip:Show()
        end)
    end
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameLevel(frame:GetFrameLevel() + 8)
    d.rolled = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.summary = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.holder = holder
    decos[#decos + 1] = d
    return d
end

local function CountText(key, n)
    if not ns.Get("countColor") then return tostring(n) end
    local c = BUTTON_COLOR[key]
    return Hex(c[1], c[2], c[3]) .. n .. "|r"
end

function ns.Paint(d)
    local r = ns.Get("enabled") and d.frame:IsShown() and d.getRoll()
    if not r then
        for _, b in pairs(d.badge) do b:Hide() end
        d.rolled:Hide()
        d.summary:Hide()
        return
    end
    local data = ns.Collect(r)
    for key, b in pairs(d.badge) do
        local button = d.btn[key]
        if button:IsShown() then
            SetBadge(b, #data[BUTTON_BUCKET[key]])
        else
            b:Hide()
        end
    end

    -- SUMMARY: "N 2 · G 1 · P 1" in one line.
    if ns.Get("counts") and ns.Get("countLayout") == "SUMMARY" then
        EllesmereUI.ApplyModuleFont(d.summary, nil, ns.Get("countSize"), nil, "OUTLINE")
        local greedKey = (d.btn.tmog and d.btn.tmog:IsShown() and not (d.btn.greed and d.btn.greed:IsShown())) and "tmog" or "greed"
        local dot = "  |cff808080·|r  "
        d.summary:SetText(
            "|cffd0d0d0" .. Initial(NEED or "Need") .. "|r " .. CountText("need", #data.need) .. dot ..
            "|cffd0d0d0" .. Initial(GREED or "Greed") .. "|r " .. CountText(greedKey, #data.greed) .. dot ..
            "|cffd0d0d0" .. Initial(PASS or "Pass") .. "|r " .. CountText("pass", #data.pass))
        d.summary:SetTextColor(1, 1, 1)
        PlaceText(d.summary, d, ns.Get("summaryPos"), ns.Get("summaryX"), ns.Get("summaryY"))
        d.summary:Show()
    else
        d.summary:Hide()
    end

    if ns.Get("rolled") and data.total > 0 then
        EllesmereUI.ApplyModuleFont(d.rolled, nil, ns.Get("rolledSize"), nil, "OUTLINE")
        local done = data.total - #data.wait
        local ar, ag, ab = ns.ColorOf("rolled")
        d.rolled:SetText(Hex(ar, ag, ab) .. done .. "|r/" .. data.total)
        d.rolled:SetTextColor(0.85, 0.85, 0.85)
        PlaceText(d.rolled, d, ns.Get("rolledPos"), ns.Get("rolledX"), ns.Get("rolledY"))
        d.rolled:Show()
    else
        d.rolled:Hide()
    end
end

-------------------------------------------------------------------------------
--  The real popups
-------------------------------------------------------------------------------
local function RealRoll(frame)
    local id = frame.rollID
    if not id then return nil end
    return rolls[id] or NewRoll(id, frame.rollTime)
end

local function InRaid()
    return IsInRaid()
end

local realDecos = {}

local function SetupFrames()
    for i = 1, NUM_FRAMES do
        local f = _G["GroupLootFrame" .. i]
        local c = f and (f.LootButtonContainer or f)
        if c and c.NeedButton and c.PassButton then
            local buttons = { need = c.NeedButton, pass = c.PassButton }
            if c.GreedButton then buttons.greed = c.GreedButton end
            if c.TransmogButton then buttons.tmog = c.TransmogButton end
            realDecos[#realDecos + 1] = ns.Decorate(f, buttons, function() return RealRoll(f) end, InRaid)
        end
    end
end

-- Every refresh lands on the next frame, outside Blizzard's own calls.
local pending = false
local function RefreshNow()
    pending = false
    for _, d in ipairs(realDecos) do ns.Paint(d) end
end

function ns.Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0, RefreshNow)
end

-- Accent / style change: the preview and the popups repaint.
function ns.RefreshAll()
    ns.Refresh()
    if ns.RefreshPreview then ns.RefreshPreview() end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SetupFrames()
        BuildRoster()
        for _, id in ipairs(GetActiveLootRollIDs and GetActiveLootRollIDs() or {}) do
            NewRoll(id, C_Loot and C_Loot.GetLootRollDuration and C_Loot.GetLootRollDuration(id))
        end
        self:RegisterEvent("START_LOOT_ROLL")
        self:RegisterEvent("CANCEL_LOOT_ROLL")
        self:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
        self:RegisterEvent("CHAT_MSG_LOOT")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        if LH then
            self:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
            self:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER")
        end
        if type(_G.GroupLootContainer_AddFrame) == "function" then
            hooksecurefunc("GroupLootContainer_AddFrame", ns.Refresh)
        end
        if type(_G.GroupLootContainer_RemoveFrame) == "function" then
            hooksecurefunc("GroupLootContainer_RemoveFrame", ns.Refresh)
        end
        if EllesmereUI.RegAccent then
            EllesmereUI.RegAccent({ type = "callback", fn = function() ns.RefreshAll() end })
        end
        C_Timer.NewTicker(30, Prune)
        ns.Refresh()
    elseif event == "START_LOOT_ROLL" then
        local rollID, rollTime = ...
        NewRoll(rollID, rollTime)
        ns.Refresh()
    elseif event == "CANCEL_LOOT_ROLL" then
        DropRoll((...))
        ns.Refresh()
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        for id in pairs(rolls) do DropRoll(id) end
        ns.Refresh()
    elseif event == "CHAT_MSG_LOOT" then
        if next(rolls) and OnChatLoot((...)) then ns.Refresh() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        BuildRoster()
        ns.Refresh()
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then
        if next(rolls) then
            OfferDrop(...)
            ns.Refresh()
        end
    elseif event == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
        if next(rolls) then ns.Refresh() end
    end
end)

-------------------------------------------------------------------------------
--  /lootroll dump: what the client gives for the open rolls
-------------------------------------------------------------------------------
local STATE_NAME = { [ST_NEED] = "Need", [ST_NEED_OS] = "NeedOS", [ST_TMOG] = "Transmog",
                     [ST_GREED] = "Greed", [ST_NOROLL] = "NoRoll", [ST_PASS] = "Pass" }

function ns.Dump()
    ns.Print("C_LootHistory: " .. (LH and "yes" or "|cffff5555no|r")
        .. ", group: " .. (IsInRaid() and "raid" or IsInGroup() and "party" or "solo")
        .. ", roster: " .. #RosterMembers())
    local any = false
    for id, r in pairs(rolls) do
        if not r.preview then
            any = true
            local data = ns.Collect(r)
            ns.Print(string.format("roll %s %s  drop=%s  source=%s  need %d greed %d pass %d wait %d",
                tostring(id), r.link or "?", r.drop and DropKey(r.drop.enc, r.drop.key) or "none",
                data.source or "?", #data.need, #data.greed, #data.pass, #data.wait))
            local info = HistoryInfo(r)
            if info then
                for _, ri in ipairs(info.rollInfos) do
                    print("   ", ri.playerName, ri.playerClass, STATE_NAME[ri.state] or tostring(ri.state), ri.roll or "")
                end
            end
            for name, c in pairs(r.chat) do print("    chat:", name, c.bucket) end
        end
    end
    if not any then ns.Print("no open roll right now.") end
    if LH then
        for _, enc in ipairs(SafeCall(LH.GetAllEncounterInfos) or {}) do
            local drops = SafeCall(LH.GetSortedDropsForEncounter, enc.encounterID) or {}
            print("   encounter", enc.encounterID, enc.encounterName, #drops .. " drops")
        end
    end
end
