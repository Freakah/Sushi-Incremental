# Sushi Incremental — UI approval plan

Status: approved by the user and implemented in the supplied source pack. Studio Play-mode and place-only UI verification remain pending. Read UI-Audit.md for the original source inventory and Install-and-Test.md for delivery checks.

## Direction: Lucky Neko Sushi Shop

Bright salmon accents, rice-cream interiors, nori outlines and soy-brown signboard headers. Buttons resemble chunky toys with a solid offset shadow, rounded edges and a small glossy upper highlight. FredokaOne throughout; large outlined titles, clean high-contrast body text. Decorative lanterns, rice dots, chopstick dividers, wave arcs, sakura and a peeking neko are sparse accents, built from UI primitives with no required uploaded art.

### What I am taking from the 16 references

- Strong silhouette, thick outline and clear large-title hierarchy.
- Large item icon, short benefit text, obvious price/action, ownership and gift affordances.
- Featured offers mixed with compact individual product cards.
- Colour and icon identity for currency, rarity and boost type.
- Category navigation with details, readable destination cards, grouped settings and code entry feedback.
- Boost duration/count, progression milestones and limited/unavailable offer states.

The new pack uses an original sushi-shop composition and motif system. No copied icon art, pixel typeface, stud texture, bundle promise or reference pricing.

## Theme tokens

| Semantic palette | Base | Light/hover | Dark/pressed/shadow | Outline |
|---|---|---|---|---|
| Salmon primary | #F56842 | #FF8C63 | #AE3D28 | #50271E |
| Nori secondary | #205540 | #34755A | #12382B | #14261D |
| Tamago accent | #FFC83D | #FFDE70 | #B77C19 | #593C16 |
| Wasabi buy/success | #69CB39 | #8BE45B | #3B8424 | #244619 |
| Soy header | #805033 | #A36C43 | #533322 | #30221B |
| Rice panel | #FFF0CE | #FFF8E6 | #DBC49C | #202D26 |
| Danger/close | #E54146 | #FA686A | #A72631 | #571F27 |
| Disabled | #858B90 | #A3A9AD | #5D646A | #343C42 |

Currency base tokens: Cash #31B85C; KG #F28A32; Prestiges #8968E8; Rebirth milestone #20B6D2; AP/Ascension #B91D39; Runes #A747E5; Neko #F4BD27; Robux #25C9AD; Fish #3499EB; Slices #E9539D. Each has light/dark/outline variants. Text on light chips uses dark ink; light text on darker surfaces. Currency names/icons remain visible so meaning never depends on colour alone. Cosmetic title colours remain content-driven.

Rarity tokens read sushi colours from RarityConfig. Rune rarity gets an explicit adapter for Mythical and Divine without renaming or changing gameplay configs. Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic pink-red and Secret rainbow retain their configured identities.

- Spacing: 4, 8, 12, 16, 24; corner radii: 8, 12, 18, 24 and pill.
- Outline: 3 px controls, 4 px main panels; solid button shadow approximately 5 px, shortened on press.
- Starting desktop text: Title 36, Header 26, Body 20, Caption 16. Phone wraps/reflows with readable minima; console increases reading size.
- At least 44 actual screen pixels for interactive targets; main actions preferably 52–56. World SurfaceGui canvas pixels do not satisfy this alone.
- All UI colour/size/motion/sound constants live in UIKit.Theme. Existing shared configs remain authoritative for content, costs, rarity, title identity and gameplay values. World geometry and character animation constants are outside the UI theme.

## Component contract

| Family | Required components |
|---|---|
| Buttons | Primary, Secondary, Buy with price/currency, Danger, round icon, Close X, Tab, gift action |
| Controls | Toggle, Slider, Quantity x1/x10/MAX, text input, category selector, search/filter/sort |
| HUD | Labelled square tile, currency pill, active boost chip/timer, contextual action prompt |
| Panels | Wood/noren header with icon/title/close, scrollable body, optional footer; compact and full-screen variants; world-board panel |
| Cards | Upgrade, Index, shop offer, bundle, title, rune, area, boost/potion, skill node, inventory detail |
| Progress | Progress with shine, XP/level, Rebirth requirement, cooldown/status and timing-meter preview |
| Feedback | Confirm Yes/No, reward, toast, tooltip, NEW/MAX, count badge, lock overlay, success/error flash, celebration |
| Utility | Spinning sushi plate, loading/error/retry where relevant, empty state, nametag preview, world text/sign styling |

Every interactive component supports normal, hover/gamepad focus, pressed, disabled/locked and selected. Count notification and affordability are independent decorators, not mutually exclusive states. Disabled actions do not fire gameplay requests. Touch exposes tooltip content through selection/details rather than hover. Async actions have pending/success/error handling and guard against repeat activation.

## Motion and sound

- Hover: scale 1→1.06, 0.12 s Back, light colour, restrained ±2° tilt/icon wiggle.
- Press: 0.92 scale and shorter shadow in 0.06 s, then 0.2 s spring return.
- Open: 0.8→1 scale with fade, dim and locally owned blur, 0.25 s Back Out. Close: shrink/fade 0.15 s.
- Affordability glow, periodic badge bounce, tile float and buy-button shine share a scheduler and stop while hidden/destroyed.
- Purchase success uses confirmed events/attributes; rejection uses red feedback/error sound. Currency displays always follow authoritative attributes.
- Big celebrations cover reset, new discovery, rare catch/rune and level-up presentations. Queue/coalesce simultaneous messages to avoid overlap.
- Normal transition segments stay at or below 0.35 s; celebration sequences may run longer. Periodic idle effects use small short transitions separated by delays.
- Reduce Motion stops decorative loops, shake, tilt and large movement; uses immediate state/colour feedback and short fades. Essential timing-meter information remains readable.
- AudioController owns hover/click/open/close/success/error cues using the existing SFX group and volume settings. UIKit must not double-play AudioController's existing global click hook. No new uploaded sound is required for a functional pack; existing IDs can be mapped until dedicated cues are supplied.

## Screens to build/restyle

| Screen/group | Final design and integration |
|---|---|
| UI Showcase | Studio-only launcher; component/state gallery, motion/sound toggles, theme swatches and screen previews; simulated affordability/purchase results; no real remotes |
| HUD | Context-aware Cash/KG/Prestige/Fish/Slices pills plus Rebirth/AP status; eight main tiles including Areas; compact phone navigation; sell prompt; boost tray; notifications/tutorial reserved lanes |
| Shop | Upgrades, Passes and Products tabs; featured offer areas, compact cards, ribbons, price/currency clarity, owned/coming-soon/pending states. Preserve six configured offers and marketplace flows |
| Market | Restyled contextual Sell All and converter/rate displays, authoritative gain feedback |
| Boards | All nine board types, upgrade/automation cards, scrolling arrows, balance pills, locks, MAX and confirms; accessible screen-panel companion for mobile/controller |
| Index | Rarity-grouped collection, 18 previews, progress/bonus, details, silhouettes and discovery popup; phone details stack or open as a sheet |
| Skills | Preserve current graph topology/pan/zoom/input; themed nodes, connections, prices, tooltip, focus and Exit; cheaper-skill recommendation remains |
| Runes | Area tabs, eight passive-rune cards, odds/count/boost/max states, altar status/results; equip/manual-roll preview available in showcase |
| Titles/Profile | All 18 equip rows, requirement bars, nametag preview and 11 profile stats; live world nametag restyle |
| Areas | Five configured destinations plus More areas soon; requirements, current/locked status, portal guidance and proximity-valid Teleport; unrestricted teleport only in preview |
| Prestige/Rebirth/Ascension | Clear lose/keep/gain comparison, requirement progress, Confirm and Cancel; keep existing server requests and proximity requirements |
| Fishing/Slashing | Live status and confirmed result feedback for current mechanics; separate future catch/timing challenge previews |
| Restaurant/Dropper | Complete future Neko HUD, upgrade menu/board and buy-pad prompt previews; no pretend live income or purchases |
| Automation | Existing two purchase/toggle features, requirements and balance; screen access shares existing board requests |
| Hall of Fame | Nine server-generated boards styled locally, including 12-row rank/avatar/value layouts; keep server data updates |
| Tutorial/Announcements | Five steps, compact/expanded bubble, mascot, guide/highlight, completion; unified toast/banner/discovery queue |
| Settings/Admin | All current controls; add Reduce Motion via SettingsConfig; gamepad sliders/focus; preserve admin gating and actions |
| World labels | Sushi name/KG, Chef speech, sell rates, portal signs, FISHING AREA sign, nametags and any additional place UI discovered during Studio audit |

Mobile: fewer columns, vertically stacked content and scrollable navigation, no shrinking an entire wide menu below usable sizes. Desktop: side-by-side detail layouts. Console: strong focus outline, predictable navigation, A activation/B dismiss and focus restoration. Escape dismisses custom menus where Roblox input handling permits; platform menu behaviour remains intact.

## Future reference-feature pack

All of the following get usable visual previews, state examples and integration callbacks with demo data isolated from live state. Missing gameplay is labelled Preview/Coming soon. No mock action grants real currency or prompts a purchase.

- VIP bundle, starter bundle, lucky bundle, individual multipliers and gifting recipient/confirm/result UI. Do not promise all future passes or copy reference offers into live entitlements.
- Mastery bundles: rune, minion, mining, sword, card, luck, prism and character/collectible categories adapted with sushi-shop naming/art placeholders.
- Potion cards/inventory/active boost tray: rune luck/bulk/speed, expedition luck, capsule luck, drop luck, mastery XP and aura luck; duration, count and use/quantity states.
- Codes and community rewards: entry, Claim/Redeem/Activate, empty/invalid/expired/already-used/success/inactive/active states. No external community destination invented.
- Collection categories: Traits, Relics, Dice/rollables, Auras, Rings, Potions and Mounts; selection, rarity sort, detail, equip/unequip, lock and empty states.
- Roll action, auto-roll status/toggle, increased bulk, luck and speed offers, cooldown, roll result and rare result celebration.
- Mining speed/auto-mining, resource multipliers (gold/silver/iron/crystals/wood), fish multiplier, extra rollables and cosmetic skin offer variants. These are future templates, not new game currencies.
- Limited-time, ended, out-of-stock, event progress/milestones and mastery/XP widgets.
- Three game-specific multiplier cards: 2x Cash and 2x Sushi Value use the existing definitions; 2x Neko is a future preview. No duplicate passes or invented live prices.

## Implementation phases and Play-mode checks

The ZIP has no Git history: establish an unchanged local baseline after approval, then commit each phase. All game edits remain under src/; preserve ignoreUnknownInstances and SushiController-last boot order.

| Phase | Work | Exactly what to test in Play |
|---|---|---|
| 1 | Theme, primitives, component/state API, animation helper, sound ownership, menu focus/dismiss; Reduce Motion config; harmless replacement for the existing lone `w` client script | Join/respawn without initialization errors; existing windows still open; hover/click once; volume respected; Reduce Motion saves and disables loops; rapid open/close leaves no blur/focus behind |
| 2 | Studio UI Showcase and all future templates | Open launcher; inspect every state; exercise sliders/toggles/quantities/inputs; simulate success/error; switch phone/tablet/1080p layouts; navigate with controller; demo actions do not affect balance |
| 3 | HUD/navigation/sell/tutorial notification lanes | Gain/spend each actual currency; enter Fishing/Slashing; test large values; open each tile; sell with mouse/touch/E/X; check thumbstick/jump/topbar clearance; check simultaneous notices |
| 4a | Shop, Market and upgrade board migration | All six existing shop offers remain Coming soon with zero IDs; live IDs prompt correct products later; Buy/Max respects balance/max; world arrows/wheel and controller companion work; sales/automation preserve behaviour |
| 4b | Index, one menu commit | Select all rarity groups; undiscovered silhouette, details and NEW badges; new discovery and KG bonus; phone scroll/details and gamepad focus |
| 4c | Skills, one menu commit | Pan/zoom/drag/pinch; locked/affordable/owned nodes; successful and rejected buys; gamepad D-pad/A/B/zoom; no purchases from drags; Reduce Motion |
| 4d | Runes/altar, one menu commit | Fish costs and server auto-roll still work; all eight cards, count/MAX/NEW; passive bonuses; no false equip/manual-roll claims |
| 4e | Titles then Profile, separate commits | Equip unlocked title; locked titles blocked; world nametag and preview sync; all 11 stats and long names fit |
| 4f | Areas, one menu commit | Five destinations and real locks; distant player gets portal instruction; nearby travel works; failure/timeout clears transition; new menu closes previous one |
| 4g | Prestige then Rebirth then Ascension, separate commits | Verify lose/keep/gain text; Cancel changes nothing; Confirm sends once; authoritative results; close/B behaviour; altar dismissal does not reopen over another menu |
| 4h | Fishing/Slashing, Automation, Hall of Fame, Settings, Admin and remaining world UI, individual commits | Existing rewards and inputs remain; leaderboard refresh preserves styling; settings persist; non-admin sees no admin controls; world labels and controller access remain readable |
| 5 | Coverage sweep, icon manifest, packaging | Fresh join/respawn; all menus at 390×844 and 844×390 phone, 768×1024 tablet, 1920×1080 PC and controller; long text/huge values; Output errors/warnings reviewed; compare place UI against inventory |

Use actual Studio Play checks for runtime claims. Static inspection alone cannot certify no overlap, working controller input, or clean Output. No Studio connector is currently exposed in this chat; user Play-mode verification or a connected Studio tool is required for that sign-off.

## Initial icon production brief

Transparent PNG, strong silhouette, thick dark outline, upper-left highlight, no baked label/price/button frame. UI placeholders remain clear without uploaded assets. Preserve existing useful previews and allow icon IDs to be replaced through one registry.

| Names | Size each | Shows |
|---|---|---|
| Cash, KG, Prestige, Rebirth, AscensionAP, Runes, Neko, Robux, Fish, Slices | 256×256 | Banknote; nigiri on scale; star stamp; circular renewal arrows; blood-red altar gem; violet rune; gold neko coin; Robux symbol; koi; sliced maki |
| Shop, Index, Skills, Titles, Profile, Areas, Settings, Automation, HallOfFame, Codes, Boosts | 256×256 | Shop bag; sushi book; branching bamboo; title tag; chef portrait; torii/map; gear; chef robot; trophy; coupon; bottle |
| AreaStarter, AreaPond, AreaSlashing, AreaBloodRift, AreaRestaurant | 512×512 | Sushi stall; koi pond; katana/maki; red torii altar; lantern restaurant |
| VIPBundle, StarterBundle, LuckyBundle, DoubleCash, DoubleKG, DoubleNeko | 512×512 | Crown/neko seal; bento gift; lucky cat; paired notes; paired nigiri; paired neko coins |
| RuneMinnow, RuneGoldfish, RuneKoi, RunePuffer, RuneThunderfin, RuneGoldenKoi, RuneAbyssal, RuneLeviathan | 256×256 | Eight distinct fish-shaped rune stones, matching rarity |
| Traits, Relics, Rollables, Auras, Rings, Potions, Mounts | 256×256 | Chef crest; ancient sushi charm; sushi die; aura halo; ring; potion; riding koi |
| MasteryRune, MasteryMinion, MasteryMining, MasterySword, MasteryCard, MasteryLuck, MasteryPrism, MasteryCollectible | 256×256 | Distinct discipline emblem for each future bundle |
| BoostLuck, BoostBulk, BoostSpeed, BoostXP, BoostDrops, BoostExpedition, BoostCapsule, BoostAura | 256×256 | Reusable bottle silhouettes with clear effect symbols |
| ResourceGold, ResourceSilver, ResourceIron, ResourceCrystal, ResourceWood, AutoRoll, AutoMine, SkinFlame | 256×256 | Future offer placeholders with distinct resource/action silhouettes |
| MascotNeko | 512×512 | Friendly beckoning cat peeking over a panel |
| GenericUpgrade, Capacity, SpawnSpeed, Crit, AutoPickup, AutoBuy, Gift, Lock, EmptyPlate | 256×256 | Upgrade arrow; stacked plates; clock; impact; magnet; robot; gift; lock; empty sushi plate |

Close/check/arrows/selection rings, shadows, highlights, rays, simple sparkles and loading plate can remain procedural. Existing sushi models supply Index portraits. Skill-specific art can reuse the existing sheet behind the registry, with consistent placeholders where replacements are needed.

## Approval requested

Approve this style and phased scope, including functional restyling of existing features, complete preview UI for unsupported future features, portal-valid live travel, and preservation of all server logic/remotes. Implementation begins only after your OK.
