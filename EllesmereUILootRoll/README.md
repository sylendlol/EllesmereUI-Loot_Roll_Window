# EllesmereUI Loot Roll Window

Shows on the group loot roll popup how many of your group chose **Need**, **Greed** and **Pass**,
and who chose what, in class color. Built for **WoW Forever** as a plugin for EllesmereUI. It lives
in the **Dworak** section of the EllesmereUI settings panel and matches the look of the rest of
the suite.

It is a standalone addon: no EllesmereUI file is changed, so EllesmereUI updates never overwrite it.
It does not replace Blizzard's roll popup either. Rolling, the timer and the Need roll animation
are still Blizzard's own, and EllesmereUI's loot roll skin keeps working. The addon only adds its
numbers and tooltip lines on top.

## Features

### Choice counts on the buttons
Every Need, Greed (or Transmog) and Pass button shows how many group members picked it. The counts
update live as people choose. Pick one of four layouts:

- **Beside the Button** (default): the Need and Greed numbers sit on the left of their buttons and
  the Pass number on the right, so no number ends up next to another button.
- **On the Icon:** in the bottom right corner of the button, like a stack count in your bags.
- **Button Corner:** any corner of the button you choose.
- **Summary Line:** no numbers on the buttons. One `N 2 · G 1 · P 1` line instead, which you can
  place above, below or beside the window, under the Pass button, or inside the window.

Other count settings:

- **Color by Button** (on by default): each number and its frame take the button's color (Need
  white, Greed gold, Pass red). When it is off, numbers are white in UI Accent Color (or custom color) frames.
- **Style:** a dark badge with a 1px frame, or a plain outlined number.
- Text size, X/Y offsets, and **Hide Zero** (no number on a button nobody chose).
- The numbers stay readable on disabled buttons (for example Need on an item you cannot use).

### Rolled counter
A `3/5` counter shows how many have chosen out of the whole group. You can place it under or beside
the Pass button, above, below, left or right of the window, or inside the window's top right or
bottom right corner, then fine-tune it with X/Y offsets and text size.

### Who chose what
Hover a button and its tooltip lists the players who chose it:

- **In a party:** names in class color, with a "(you)" tag on yourself and a "(Transmog)" tag where
  it applies.
- **Waiting:** who has not chosen yet (can be turned off).
- **In a raid:** only the numbers by default (`Need 6 / 25`, `Waiting 7`, plus a Need · Greed · Pass
  summary line), so the tooltip stays short. **Names in Raid** lists the names there too.
- Class colors follow EllesmereUI's class color settings.

### Colors
Everything that uses EllesmereUI's **UI Accent Color** can be given its own color instead:

- **Badge Frame Color:** the frame of the count badges (while Color by Button is off).
- **Counter Color:** the chosen number of the `3/5` counter.
- **Tooltip Header Color:** the `Need 1 / 5` line in the button tooltip.

Each one is either **UI Accent Color** (follows it live) or **Custom** with its own color picker.

### Live preview
The top of the settings page shows a roll popup with sample choices. Every setting shows up there
as you change it, and hovering its buttons shows the real tooltip. Switch the preview between a
**party** and a **raid** sample.

## Where the data comes from

1. **The loot history** (`C_LootHistory`): the client tracks every player's choice for a drop while
   the roll is open, and the addon pairs each roll popup with its drop by item.
2. **Chat, as a fallback:** if the loot history has no entry for a roll yet, the addon reads the
   "X has selected Greed for: [item]" lines. They are matched against the client's own localized
   strings, so this works in every client language.

`/lootroll dump` prints what the client gives for the open rolls (which source is used, each
player's state). Use it if a count looks wrong.

## Requirements

- WoW Forever (Interface 16001)
- EllesmereUI (built against 9.5.4)
- **EllesmereUI Dworak** (`EllesmereUIDworak`), which provides the "Dworak" section of the
  EllesmereUI panel

## Installation

1. Download the latest release.
2. Copy the `EllesmereUILootRoll` folder into
   `World of Warcraft\_classic_beta_\Interface\AddOns\`
   (the same place as your other EllesmereUI folders).
3. Make sure `EllesmereUIDworak` is installed as well.
4. Log in, or type `/reload`.
5. Open the settings with `/lootroll`, or in the EllesmereUI panel under **Dworak > Loot Roll Window**.

The folder must be named exactly `EllesmereUILootRoll`.

## Slash commands

| Command | Action |
|---|---|
| `/lootroll` | Open the settings |
| `/lootroll dump` | Print the open rolls: matched loot history drop, data source, counts and each player's state |

## Settings and saved data

Settings are account-wide and saved in `EllesmereUILootRollDB`
(`WTF\Account\<account>\SavedVariables\EllesmereUILootRoll.lua`). The **Reset** button at the bottom
of the settings page restores the defaults.

## Files

| File | Contents |
|---|---|
| `EllesmereUILootRoll.toc` | Addon manifest |
| `EllesmereUILootRoll.lua` | Roll tracking (loot history and chat), counts, rolled counter, tooltip lines, `/lootroll dump` |
| `EllesmereUILootRoll_Options.lua` | Settings page with the live preview |

## Credits

- Built on EllesmereUI by Ellesmere.
- Author: Dworak
