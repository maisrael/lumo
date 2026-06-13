# Lumo

A Noctalia-inspired drop-down panel for macOS: **one translucent, rounded window with everything on tabs**. A menu-bar item (or any sketchybar click) summons the panel pre-switched to a tab — calendar, now-playing, system — the same window every time.

No Xcode required. Pure `swiftc` + a Makefile. Runs as an `LSUIElement` agent (no dock icon).

## Build & run

```sh
make run                 # build, (re)launch
open "lumo://tab/music"  # summon the panel on a tab
```

URL forms accepted: `lumo://tab/<name>` or `lumo://<name>` where `<name>` is `calendar`, `music`, or `system`. Re-firing the same tab toggles the panel closed.

`make install` copies the bundle to `/Applications`.

## Dismiss

Click anywhere outside the panel, or press `Esc`.

## sketchybar integration

Give any bar item a click script that opens the matching tab:

```sh
sketchybar --set cal_item   click_script="open 'lumo://tab/calendar'"
sketchybar --set music_item click_script="open 'lumo://tab/music'"
sketchybar --set sys_item   click_script="open 'lumo://tab/system'"
```

## Status

v0.1 — working shell: panel, tab rail, URL summoning, click/Esc dismiss. Tab contents are placeholders; real calendar / now-playing / system-toggle data is the next milestone.
