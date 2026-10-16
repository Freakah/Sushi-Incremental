# Sushi Incremental — source UI inventory

Audit date: 16 October 2026. Source: supplied Sushi-Incremental.zip, extracted into work/Sushi-Incremental. No implementation changes made.

## Coverage and limits

Read the archive's CLAUDE.md, UIKit, MenuManager, HudController, MenuButtonsController and all remaining modules in Controllers (29 modules total). Checked ClientMain, the content/settings/shop/rarity/zone configs, and additional UI builders outside Controllers. This inventories source-defined elements and source references to saved UI. The ZIP does not contain the Roblox place, so unreferenced saved ScreenGuis, SurfaceGuis, signs and prompts cannot be enumerated yet. A Studio Explorer audit remains a completion requirement; this document does not claim to inventory unseen place-only instances.

Repeated config-generated cards are listed by family and content below. Their decorative children belong to that component; controls, readouts, status variants and feedback are explicitly listed.

## Shared infrastructure

| Source | Existing elements and behaviour | Migration |
|---|---|---|
| UIKit | Label, rounded corner, stroke, gradient button; Button returns Button/Label/Gradient and SetText/SetColors; hover/press animation | Preserve callers while introducing theme tokens and semantic variants |
| UIKit.Window | ScreenGui, clickable dim backdrop, input sink, framed header icon/title, Close button, body; open/close/toggle and callbacks; responsive uniform scale | Shared responsive window, close X, focus handling, dim/blur and fade; retain API compatibility |
| UIKit.List/Row | Vertical scroll list, scrollbar, padded icon/text/control rows | Shared scroll/row components |
| UIKit.Toggle/Slider | On/Off button; draggable volume track/fill/knob/percentage | Toggle and slider with touch/gamepad support |
| UIKit.Tile | Image or drawn HUD tile, caption/icon, red exclamation badge | Labelled tile, count badge and affordability state |
| MenuManager | Registry of close callbacks; opening a registered menu closes others | Add current-menu tracking, common dismiss and focus restoration; avoid reopening proximity dialogs immediately |
| AudioController | Global PlayerGui button hover/click hooks; music playlist; master/music/SFX settings | One sound owner per interaction; add six semantic UI sound cues without duplicate clicks |
| SettingsState | Local values, config validation, SetSetting requests, mirrored attribute updates | Preserve save flow; support Reduce Motion through shared settings config |

## HUD and contextual UI

| Source | Every current element/control | Purpose/state |
|---|---|---|
| HudController | KG pill; Cash pill; Prestiges pill; Fish pill; Slices pill | Icon, caption, formatted animated amount and accumulated +gain for each |
| HudController | Contextual pill arrangement | Starter/default: KG and Cash, then Prestige once progressed; Fishing: Fish/Cash; Slashing: Slices/Cash |
| HudController | Combo text | xN COMBO, GREAT, AMAZING, INSANE; punch/fade feedback |
| MenuButtonsController | Index, Skills, Titles, Runes, Profile, Shop, Settings | Seven menu-opening tiles; badges for unseen Index/Titles/Runes and affordable Skills |
| MarketController | Bottom-centre Sell All pill | Sell button; expected KG-to-Cash return; empty-state instruction; E/X key chip, hidden on touch |
| MarketController | Sell feedback | Empty-sale shake; normal/2x-deal world reward text; Cash notes flying to HUD; gain effects |
| MarketController | Existing RateGui.Rate labels on sell stalls | Live rate, 1 kg = cash; saved place UI referenced by source |
| MarketController | Beginner guide trail | World chevrons toward nearest sell zone after tutorial |
| ZoneController | AreaBanner | Entering label, area name/icon and subtitle/bonus line |
| ZoneController | Travel Fade and lock Toast | Travel transition; unmet area requirement feedback |
| ZoneController | PortalSign billboards | Walk-in instruction or unlock requirement on each tagged portal |
| AmbientController | Chef.Head.Speech.Text | Rotates seven welcome/gameplay hints; saved place speech bubble |

Missing from current HUD: dedicated Rebirth/AP/Neko counters, Areas button, boost tray, XP/level display. Rebirth is a milestone count, not spendable currency. AP is spendable; Ascensions is a separate lifetime count.

## World boards — BoardsController

All nine supported BoardType values are included. Boards use custom pointer/touch raycasts, not ordinary Activated handlers; their migration must preserve hit testing and add an accessible screen-panel route for controller and small-screen interaction. Existing world canvas pixels are not equivalent to 44 screen pixels.

| BoardType | Readouts and controls | What it does |
|---|---|---|
| CashBoard | Cash pill; Sushi Value, Sushi Capacity, Spawn Speed cards | Each card: name, level, icon, level progress, current→next effect, price/currency, Buy and Max xN; maxed state. Calls RequestUpgrade |
| PrestigeWall | Prestige balance; fixed exchange card; upgrade strip; left/right arrows; wheel scrolling | Exchange shows resets, gain, Cash amount/minimum; Prestige→CONFIRM? button within 5 seconds; waiting/insufficient states. Calls RequestPrestige |
| PrestigeWall | Cash Multi, More Prestiges, Sushi Multi, Fish Multi cards; Next World teaser | Each upgrade has Buy/Max, cost, level, effect, progress/maxed; Fish Multi has Rebirth lock. Calls RequestPrestigeUpgrade |
| RebirthBoard | Rebirth count; current→next Cash boost; unlock line; Prestige requirement progress; reset warning | Rebirth→CONFIRM? button within 5 seconds; insufficient/waiting states. Calls RequestRebirth |
| AutomationWall | Prestige balance; left/right scrolling; Auto Fish Upgrades, Auto Slice Upgrades; Next World teaser | Ownership 0/1; requirement/area lock; price; Buy then On/Off. Calls BuyAutomation/ToggleAutomation |
| Converter | KG balance; Sushi Market title; conversion rate; sale preview; Sell button | Calls MarketController.Sell, with empty-state feedback |
| FishUpgradesBoard | Fish balance; More Fish, Faster Fish, Fish Luck, Auto Fish cards | Buy/Max, levels/effects/prices/progress/maxed. Calls RequestFishUpgrade |
| SliceUpgradesBoard | Slices balance; More Slices, Faster Slashes, Critical Slices, Auto Slash cards | Buy/Max, levels/effects/prices/progress/maxed. Calls RequestSliceUpgrade |
| AscensionBoard | AP balance, explanation, Ascension count, SUSHI EMPIRE requirement, altar hint | Informational board, no purchase button |
| AscensionUpgradesBoard | AP balance; Auto Pickup, Auto Buy, More Prestiges, More Cash cards | Buy/Max and normal upgrade states; owned Auto Buy becomes On/Off via SetSetting; purchases use RequestAscensionUpgrade |

Cross-board feedback: purchased-card flash/pop; LEVEL UP or +N LEVELS world text; purchase streak sound; insufficient shake; Prestige title/gain celebration; Rebirth title/Cash boost/area-unlock celebration. All belong in the shared feedback pack.

## Centre menus

Every UIKit window below also includes its title/icon, Close button and backdrop dismissal.

| Source | Existing elements and actions |
|---|---|
| ShopController | Game Passes and Boosts & Packs section headers; six item cards with icon/name/description/Buy, owned state, Coming soon state, active boost timer; purchase confirmation banner/effects. Uses MarketplaceService prompts only for nonzero IDs |
| IndexController | Discovered count, total progress bar, permanent KG bonus; rarity section counts; 18 clickable sushi cards with live viewport/name/count, silhouette/???/lock, NEW and selection ring; detail viewport/name/rarity chip/weight range/zone/collected count. Clicking selects and marks seen; closing clears unseen badges |
| IndexController | Separate queued NewSushiPopup: sushi portrait/name, Index-added text, rarity/weight, +3% KG badge, NEW SUSHI tag and sparkles |
| SkillTreeUIController | Full-screen backdrop; pan/zoom tree; START; six branches of nodes and connection lines; locked/hidden/available/owned states; price tags; level data; affordability glow and cheapest-affordable recommendation arrow; tooltip title/description/cost or requirement; Exit button; drag/pinch/scroll hints; purchase/unlocked/maxed feedback; decorative petals |
| SkillTreeUIController | Mouse click buys, first touch selects/second buys; D-pad selection, A buy, B exit, shoulders zoom, right stick pan; Escape close. Node input is mathematical hit testing rather than one GuiButton per node. Header frame exists but currently has no title |
| RunesMenuController | Areas sidebar with Fish Pond tab and More areas soon text; area header, 50 Fish per roll instruction, Rune Luck and total rolls; eight passive rune cards with rarity, chance, current stat multipliers, count/max progress, ???/not-found/MAX states; new-rune HUD badge |
| TitlesController | 18 title rows; title colour/gold/rainbow treatment, requirement, progress/count, Equip/Equipped/locked-percent button; unseen-title HUD badge. Calls EquipTitle |
| ProfileController | Username, avatar portrait, equipped title, hint to change title; 11 lifetime stat rows: Cash, Playtime, Fish, Rebirths, Prestiges, Sushi, Weight, Index, Upgrades, Titles, Robux |
| SettingsController | Music toggle; SFX toggle; Volume slider; Pickup Popups; Hide Other Players; Night Mode; Particles; Camera Shake; Save Last Position; Auto Buy (Ascension). Nine toggles and one slider, saved through SettingsState |
| AscensionController | Proximity-open AscendPanel: title, lose/keep/reward text, missing-SUSHI-EMPIRE requirement, ASCEND and Not yet; controller A/B. Currently outside MenuManager |
| AscensionController | Ascension overlay: red/black transition, ASCENDED title, count and +1 AP; waits for server return home |
| AdminController | Admin-only HUD toggle; draggable panel; X; amount TextBox and validation feedback; Give and subtract for Cash/KG/Prestiges/Fish/Slices/AP; Set Rebirths to amount; five destination teleport buttons. Uses AdminAction; preserve allow-list and server checks |

### Current content behind repeated cards

Shop passes: 2x Cash, 2x Sushi Value, Lucky Chef (x1.5 sushi luck), VIP (x1.25 Cash/KG, title, gold name). Products: Cash Rush (x2 Cash, 15 minutes), Lucky Hour (x2 Luck, 15 minutes). All six IDs are zero, so none currently initiates a real purchase.

Index:

- Common: Salmon Nigiri, Tamago Nigiri, Cucumber Maki.
- Uncommon: Tuna Nigiri, Ebi Nigiri, Salmon Maki.
- Rare: Ikura Gunkan, Unagi Nigiri, Avocado Maki.
- Epic: Otoro Nigiri, Uni Gunkan, Dragon Maki.
- Legendary: Golden Salmon, Golden Maki.
- Mythic: Sakura Nigiri, Cosmic Gunkan.
- Secret: Rainbow Roll, Diamond Nigiri.

Runes: Minnow, Goldfish, Koi, Puffer, Thunderfin, Golden Koi, Abyssal, Celestial Leviathan. Bonuses are passive; there is no equip action. Rune rarity has Mythical and Divine, unlike sushi rarity's Mythic; theme adapters must preserve these distinct config names and support Divine.

Titles: Novice, Sushi Rookie, Sushi Chef, Master Chef, Sushi Legend, Reborn, Rebirth Addict, Rebirth Lord, Eternal Chef, Millionaire, Billionaire, Trillionaire, Collector, Completionist, Tree Climber, Legendary, Dedicated, VIP. Every row receives the same complete title component and state treatment.

Skills (each ID is an individual node with its own selection, tooltip and purchase interaction; generated from SkillTreeConfig, not duplicated manually):

- Value: V1–V6 (value multipliers), CHEF (Head Chef), EMPIRE (Ascension unlock), FRESH/FRESH2 (minimum sushi weight), VX1/VX2 (value), RARE (Rare+ value), SECRET (Secret value).
- Cash: C1–C6 (Cash multipliers), MOGUL (Sushi Mogul), DEAL/DEAL2 (sale bonus), CX1/CX2 (Cash), TIP (Tip Jar), VET (lifetime Prestige-based Cash bonus).
- Spawning: S1–S6 (spawn speed), STORM (Sushi Storm), DOUBLE/DOUBLE2 (bonus sushi chance), SX1/SX2/SX3 (spawn speed).
- Speed: SWIFT, SWIFT2, SWIFT3 (walk speed).
- Luck: L1–L6, LUCKY (Lucky Cat), ORDR/ORDE/LEGEND (rare-order tiers), GOLD (Golden Sushi), JACKPOT/JACKPOT2 (bonus value).
- Prestige: R1–R6, REBORN (Prestige Master), HEAD/HEAD2/HEAD3 (Cash head start), TYCOON (lifetime Prestige-based sushi value).

## Minigames, onboarding and feedback

| Source | Current UI/feedback and behaviour |
|---|---|
| FishingController | Aggregated +Fish floating reward; GOLDEN variant; pad pulse. Fishing is server-timed while standing on the pad, not a timing-bar minigame |
| FishingAnimController | Rod/IK/bobber/fish visual loop; SurfaceGui ripple rings are world VFX. No screen menu, catch button or catch meter |
| SlashController | Click/touch/R2 hold-to-slash input; +Slices and CRIT floating results; boss hit flash/face reaction. No timing meter or health bar; boss has infinite HP |
| RuneController | Altar ground ring, inside/outside glow, rolled-rune world label, NEW/MAX variants, rare-rune announcement. Server auto-rolls while nearby; no manual roll/equip request |
| TutorialController | Expand/collapse hit area over compact/expanded bubble; title, step counter, instructions, tip icon/text, goal/progress, chevron, procedural sushi mascot; Done and final tutorial-complete states; world objective arrow and ground trail |
| TutorialController | Five steps: collect 5 sushi, sell at Market, buy Cash upgrade, unlock a skill, Prestige. Instructions adapt to device; progress comes from server |
| AnnouncementController | Queued top banner, normal/rainbow variants, rare-spawn message, generic reward message; formatted rare-found Roblox system-chat message |
| EffectsController | Shared world FloatingText billboards with outlined label and scale; sound templates, bursts and camera kick used by menus/purchases/collecting |
| SushiController | Sushi model labels supplied by SushiModels; +KG/batched pickup, combo, GOLDEN x5, Tip +Cash, CRIT +KG, Auto Chef +KG feedback; rare-spawn announcements |
| NametagController | Existing server-created @username/title billboard; rainbow title gradient and Hide Others visibility |
| PropAnimationController | No menus/buttons/readouts; world prop and lantern animation only |
| AmbientController | Chef speech above; remaining petals/conveyor/rings are world ambience, not menus |

## Additional UI outside Controllers

- LeaderboardService builds nine Hall of Fame board categories, each with a title and 12 rank/avatar/name/value rows: Total Cash, Total Rebirths, Time Played, Sushi Collected, Heaviest Sushi, Sushi Sold, Robux Spent, Total Prestiges, Total Ascensions. Top three get medal styling; empty rows are blank. DataStore and live-server data flow must stay unchanged. Use a client styling adapter that handles late replication and refreshed text.
- ProfileShopService builds Nametag.PlayerName and Nametag.Title, including VIP gold name and title colour changes. NametagController can style these locally and preserve updates.
- Shared/SushiModels builds each sushi's Label billboard with SushiName and KG. Apply UIKit styling to client-created label instances without requiring a StarterPlayer module from shared/server code.
- GroundSignBuilder creates GroundSign.SignBoard.SurfaceGui with FISHING AREA text. Style its UI locally; leave geometry/server builder intact.
- Saved place dependencies: stall RateGui, Chef speech, altar sign model, portal signs/models, map boards, Assets (including sushi meshes and katana), any other saved UI. The actual place is needed to identify remaining instances.
- Native Roblox topbar, chat shell, player list, movement controls and purchase dialogs are platform UI; preserve their supported behaviour and safe areas. Game-written chat content and leaderstats still need readable formatting.

## Confirmed scope differences and constraints

1. Areas has no player menu/HUD tile today. Five destinations exist: Sushi Bar (Starter), Blood Rift, Sushi Pond (Rebirth 1), Sushi Slashing (Rebirth 2), Sushi Restaurant (Rebirth 3). Restaurant is explicitly a gameplay placeholder. No Neko attribute, dropper service, upgrade board or buy-pad flow is in this archive.
2. RequestTravel checks that the player is near a portal to the destination. An anywhere-Teleport menu cannot work under the unchanged server contract. Live cards should explain portal proximity and use existing valid travel; unrestricted teleport remains a showcase preview.
3. Runes auto-roll at the altar and work passively. Manual roll/equip must be preview UI unless gameplay is added later.
4. Fishing and Slashing have no timing-score mechanics. Add status/result presentation for actual events and preview timing widgets separately; never imply the demo meter decides rewards.
5. Codes, gifting, consumable potion inventory, traits/relics/dice/auras/rings/mount inventories, mastery systems, XP, VIP bundles and most reference offers have no supporting service in this archive.
6. Buy/Max remotes generally accept a boolean buyMax, not a quantity. x10 is required in the component pack, but cannot be silently sent as an unsupported quantity or implemented by ten uncontrolled requests.
7. Reduce Motion can be added to SettingsConfig and use the existing generic validation/storage pathway. No new remote or server implementation is needed.
8. Existing MenuManager has no common Escape/B or focus management; Ascension/Admin do not register with it. World boards need explicit gamepad access.
9. ReplicatedFirst/LocalScript.client.luau contains only `w`, an invalid standalone Luau statement. It is a pre-existing Output error source; proposed phase 1 housekeeping is to replace it with a harmless comment.
10. This archive has no .git history. After approval, create a local baseline and phase commits in the extracted project; the original ZIP stays unchanged.

## Verified reset copy for new confirmation screens

- Prestige: exchanges Cash for Prestiges; resets KG and Cash upgrades; Cash returns to the configured skill head-start amount. Skills and other progression remain.
- Rebirth: resets current Prestiges and Prestige upgrades, Cash/KG/Cash upgrades, Fish/Fish upgrades, Slices/Slice upgrades; retains skills, Index, runes, automation, Ascension progression and lifetime stats. Cash can receive skill head-start. Reward is the new permanent Cash multiplier and configured area unlocks.
- Ascension: resets Cash, KG, Cash upgrades and skill tree; keeps other progression; adds one Ascension and one AP. Blood Altar proximity and eligibility remain server-validated.

Implementation acceptance requires the source inventory above plus a place-only UI inspection, Play-mode Output review, phone/tablet/desktop layout checks and controller testing. No runtime validation has been performed during this planning audit.
