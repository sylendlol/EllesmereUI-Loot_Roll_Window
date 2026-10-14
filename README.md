# EllesmereUI Loot Roll Window
<img width="1296" height="942" alt="{12CF21F9-EE17-45EF-92A5-08D197137BCB}" src="https://github.com/user-attachments/assets/9048d51d-0659-4311-84c5-f91afb3d329a" />
<img width="454" height="209" alt="{FC0C7ACA-CC7D-4DD1-8767-77A1F750EF8A}" src="https://github.com/user-attachments/assets/ca48260d-f32d-4ef3-bb92-8a5ffc47f0aa" />
<img width="467" height="176" alt="{65093CE4-E549-4450-B039-9AC743EB9870}" src="https://github.com/user-attachments/assets/f62b524a-06c3-4444-802b-975f9c3afcf1" />



Shows on the group loot roll popup how many of your group chose **Need**, **Greed** and **Pass**,
and who chose what, in class color. Built for **WoW Forever** as a plugin for EllesmereUI v9.5.4. It lives
in the **Dworak** section of the EllesmereUI settings panel and matches the look of the rest of
the suite: it follows your **UI Accent Color** out of the box, and every accent-colored part can be
given its own color.

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

How the numbers look:

- **Style:** a dark badge with a 1px frame, or a plain outlined number.
- **Color by Button** (on by default): each number and its badge frame take the button's own color
  (Need white, Greed gold, Transmog purple, Pass red), so it is clear at a glance which button a
  number belongs to. This also colors the numbers of the Summary Line.
- With Color by Button off, the numbers are white and the badge frames use the **Badge Frame
  Color** (see [Colors](#colors)).
- Text size, X/Y offsets, and **Hide Zero** (no number on a button nobody chose).
- The numbers stay readable on disabled buttons (for example Need on an item you cannot use).

### Rolled counter
A `4/5` counter shows how many have chosen out of the whole group. You can place it under or beside
the Pass button, above, below, left or right of the window, or inside the window's top right or
bottom right corner, then fine-tune it with X/Y offsets and text size. The chosen number is drawn
in the **Counter Color** (see [Colors](#colors)), the total in light grey.

### Who chose what
Hover a button and its tooltip lists the players who chose it:

- **Header line:** `Need 2 / 5`, in the **Tooltip Header Color** (see [Colors](#colors)).
- **In a party:** names in class color, with a "(you)" tag on yourself and a "(Transmog)" tag where
  it applies.
- **Waiting:** who has not chosen yet (can be turned off).
- **In a raid:** only the numbers by default (`Need 6 / 25`, `Waiting 7`, plus a Need · Greed · Pass
  summary line), so the tooltip stays short. **Names in Raid** lists the names there too.
- Class colors follow EllesmereUI's class color settings.

### Colors
Three parts use EllesmereUI's **UI Accent Color** by default. Each has its own setting in the
**Colors** section, with two choices:

- **UI Accent Color:** follows Global Settings > UI Accent Color, and repaints live when you change it.
- **Custom:** any color, from the color picker next to the setting.

| Setting | Colors | Default |
|---|---|---|
| **Badge Frame Color** | The 1px frame of the count badges, while Color by Button is off and the style is Badge | UI Accent Color |
| **Counter Color** | The chosen number of the `4/5` counter | UI Accent Color |
| **Tooltip Header Color** | The `Need 2 / 5` line in the button tooltip | UI Accent Color |

Colors that are not tied to the accent:

- **Button colors** (Color by Button): Need white, Greed gold, Transmog purple, Pass red.
- **Player names:** class colors from EllesmereUI.
- **Waiting list and labels:** grey.

A color setting that has no effect with your other choices (for example Badge Frame Color while
Color by Button is on) is greyed out, and its tooltip says which setting it depends on.

### Live preview
The top of the settings page shows a roll popup with sample choices. Every setting, colors
included, shows up there as you change it, and hovering its buttons shows the real tooltip. Switch
the preview between a **party** and a **raid** sample.

## Settings overview

| Section | Settings |
|---|---|
| **Loot Roll Window** | Enable, Preview Group (party / raid sample) |
| **Counts** | Show Counts, Count Layout, Color by Button, Hide Zero, Count Style, Count Text Size, Button Corner, Count X / Y Offset, Summary Position, Summary X / Y Offset |
| **Rolled Counter** | Show Rolled Counter, Counter Text Size, Counter Position, Counter X / Y Offset |
| **Tooltip** | Show Choices in Tooltip, Show Waiting Players, Names in Raid |
| **Colors** | Badge Frame Color, Counter Color, Tooltip Header Color (each: UI Accent Color or Custom) |

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

Settings, custom colors included, are account-wide and saved in `EllesmereUILootRollDB`
(`WTF\Account\<account>\SavedVariables\EllesmereUILootRoll.lua`). The **Reset** button at the bottom
of the settings page restores the defaults.

## Files

| File | Contents |
|---|---|
| `EllesmereUILootRoll.toc` | Addon manifest |
| `EllesmereUILootRoll.lua` | Roll tracking (loot history and chat), counts, rolled counter, colors, tooltip lines, `/lootroll dump` |
| `EllesmereUILootRoll_Options.lua` | Settings page with the live preview |
| `README.md` | This file |

## Credits

- Built on EllesmereUI by Ellesmere.
- Author: Dworak
