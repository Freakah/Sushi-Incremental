# Sushi Incremental — Lucky Neko UI Pack

The source implementation is ready for Studio Play testing. It includes the shared UI pack, existing-menu migrations, accessible upgrade counter, Areas menu, Studio showcase and future-feature previews. It has not been rendered or run in Roblox Studio in this session.

## Install

1. Extract Sushi-Incremental-UI-Pack.zip into a separate project folder, or merge its src/ into a copy of your current Rojo project.
2. Use your existing Sushi Incremental place. The ZIP contains scripts; it does not contain Map, saved GUI instances, Remotes or Assets from the place.
3. Run the supplied start-rojo.bat (or rojo serve default.project.json) and connect the Roblox Studio Rojo plugin.
4. Press Play. Open **UI Lab** at the top right to inspect the pack. This launcher appears only in Studio.
5. Open **Shop → Upgrades → Open boards** for the accessible upgrade/automation counter. Open **Shop → Upgrades → Preview pack** for future screens.

All new modules are under the existing Controllers folder. Its ignoreUnknownInstances metadata and default.project.json are preserved. SushiController remains last in client boot. No server script, existing gameplay remote, cost or entitlement definition was changed. Reduce Motion was added to SettingsConfig and uses the existing generic save endpoint.

## What is live versus preview

Live rendering uses existing attributes/remotes for Cash/KG/Prestige/Fish/Slices/Rebirth/AP, upgrades, automation, Index, Skills, passive Runes, Titles, Profile, sell/travel and reset requests. Existing shop IDs remain zero, so those offers show Coming soon.

Future preview screens include bundles/gifting, potions and active timers, codes/community reward states, traits/relics/rollables/auras/rings/mounts, roll/auto-roll, mining/resource/mastery offers, limited/ended/out-of-stock event cards, progression widgets, Neko restaurant/dropper and timing challenges. Preview actions affect demo state only. They do not grant rewards or prompt real purchases. The three sushi multiplier cards are 2x Cash, 2x Sushi Value and the future 2x Neko.

Areas respects the existing server proximity requirement: a distant player receives a portal instruction; nearby unlocked portals allow the existing travel request. Fishing remains automatic on its pad; current Runes remain passive and auto-roll at the altar. Timing challenges are preview UI.

## Play-mode checklist by phase

### 1 — Theme, components and motion

- Join and respawn; inspect Output for initialization errors.
- Open/close menus rapidly and switch between menus; check that old close callbacks do not hide a reopened menu and blur clears.
- Hover/press with a mouse, tap on touch and select/activate with a controller. Verify one hover/click sound and visible focus.
- Set SFX off and Volume to zero; UI sounds should follow both settings.
- Toggle Reduce Motion while a menu is open. Verify pulses/shine/tilt stop; rejoin to check the setting persists.

### 2 — Showcase

- Open UI Lab. Scroll through button states, card states, toggles/sliders/quantity, progress bars, currencies and feedback.
- Test disabled controls, selected controls, notification counts, affordable glow, confirm/cancel, reward and celebration.
- Inspect future screens through Preview pack. Try code SUSHI, then USED, EXPIRED, an empty field and an unknown code. Test gift recipient validation and different selected offers.
- Use a potion and check its count and timer. Toggle auto-roll and test collection search/sort/equip.
- Confirm all preview actions leave real player balances unchanged.

### 3 — HUD

- Gain/spend Cash and KG; enter Fishing and Slashing; unlock Prestige, Rebirth and AP displays.
- Test all eight menu tiles, notifications, combo labels and active boost timers.
- On a phone, expand/collapse Menus. Verify controls do not cover thumbstick/jump, Roblox topbar or sell prompts.
- Test Sell All with E, controller X and touch; verify the displayed sale preview matches the configured rate.

### 4 — Menus and world boards

- Shop: check the six configured offers, Coming soon/owned/timer states and product price behaviour when you later configure real IDs.
- Boards: test Cash, Prestige, Rebirth, Automation, Converter, Fish, Slices, Ascension info and Ascension upgrades. Test Buy, MAX, locks, maxed upgrades, On/Off, arrows and wheel scrolling.
- Accessible counter: use Shop → Upgrades → Open boards with touch/controller. Verify purchases match the same world boards.
- Index: select found/unfound entries, rarity sections, details and NEW. On a phone, use Back to collection. Trigger a discovery and verify the KG bonus and celebration.
- Skills: click versus drag, pinch/scroll zoom, purchase/insufficient/maxed/locked states, D-pad selection, A buy, B exit and shoulder zoom.
- Runes: altar auto-roll, all eight cards, odds, passive boosts, counts, NEW/MAX and area tabs.
- Titles/Profile: locked versus unlocked equip, world nametag sync, avatar, all 11 stats and long names.
- Areas: all five zones, unlock requirements, current area, far/near portal travel and travel timeout feedback.
- Prestige/Rebirth: compare lose/keep/gain copy, Cancel (no changes), Confirm (one request), rewards and resulting balances.
- Blood Altar: proximity opening, unmet requirement, Confirm/Not yet/B, server return home and reduced-motion celebration.
- Fishing/Slashing: original catching and slash inputs/rewards, status strip, golden/critical results.
- Tutorial/announcements: five steps, expand/collapse, objective arrows/trail, completion and simultaneous notices.
- Settings: every original control, slider mouse/touch/controller input, persistence and Reduce Motion.
- Admin: allowed account only, amount parsing, give/subtract, set Rebirths and destination travel.
- Hall of Fame: all nine categories, rank/avatar/value rows and refreshed data. Check nametags, Chef speech, sale rates, portal and ground signs, sushi labels.

### 5 — Final visual sign-off (still required)

Test 390×844 and 844×390 phone, 768×1024 tablet, 1920×1080 desktop and a controller. Use very large balances, long names, empty inventories, locked/maxed progression, rapid actions, respawn and simultaneous rewards. Inspect Output after each feature.

The source ZIP cannot reveal unreferenced saved UI in your place. Inspect StarterGui, PlayerGui, Workspace SurfaceGuis/BillboardGuis and ProximityPrompts for any additional place-only controls; add them to the adapter/migration before declaring full coverage. Pixel-level overlap, clipping, controller feel and a clean Output window are not yet certified.

## Validation completed here

- All 79 Luau source files compile with Luau 0.742: zero syntax errors.
- Executable service-double checks passed for disabled action gating, notification counts, selected state, gradient propagation, locked controller-action gating, quantity selection, progress clamping, toggles, menu exclusivity, rapid reopen, reduced-motion duration and card APIs.
- Window bounds checked at phone portrait/landscape, tablet and 1080p dimensions in the service double. These are bounds checks, not rendering tests.
- All 210 centralized dimension references resolve.
- git diff --check passed. Working tree clean after commits.
- Server scripts and default.project.json match the supplied baseline.

## Phase history

The companion Git bundle preserves the unchanged source baseline and phase commits. To inspect it in a new folder, use git clone Sushi-Incremental-UI-History.bundle Sushi-Incremental-UI-History.

See Changed-Files.md for the file summary and Icon-Manifest.md for upload slots.
