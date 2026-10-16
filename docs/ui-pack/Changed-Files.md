# Changed files

35 source files changed: 28 modified and 7 added. All game edits are under src/. The server scripts and Rojo project configuration are unchanged.

## Outside Controllers

| File | Change |
|---|---|
| src/ReplicatedFirst/LocalScript.client.luau | Replaced the pre-existing invalid lone w statement with a harmless comment. |
| src/ReplicatedStorage/Shared/Config/SettingsConfig.luau | Added ReduceMotion using the existing generic setting validation/save path. |
| src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau | Registered Areas, WorldUI, MinigameHUD and Studio showcase; SushiController remains last. |

## Modified controller modules

All names below are in src/StarterPlayer/StarterPlayerScripts/Controllers/.

| File | Change |
|---|---|
| UIKit.luau | Theme, semantic colours/currency/rarity tokens, shared dimensions, responsive window, controls, card families, icons, mascot, motion, feedback and lifecycle helpers. |
| MenuManager.luau | Menu exclusivity, current menu, common dismiss and unregister handling. |
| AudioController.luau | Semantic UI sounds, settings support and silent/disabled button gating. |
| HudController.luau | Context-aware animated counters, Rebirth/AP status, combo and active boosts. |
| MenuButtonsController.luau | Eight labelled menu tiles and compact phone drawer. |
| ShopController.luau | Pass/Product/Upgrade tabs and existing marketplace offer states. |
| BoardsController.luau | World-board theme, button states, existing purchase handlers and explicit reset dialogs. |
| MarketController.luau | Themed Sell All button, sale preview and reduced-motion feedback. |
| IndexController.luau | Collection cards, phone detail navigation, rarity state and queued discovery celebration. |
| SkillTreeUIController.luau | Procedural themed graph, shared motion, reduced-motion mode and initial controller selection fix. |
| RunesMenuController.luau | Responsive passive-rune inventory, rarity state and icon slots. |
| TitlesController.luau | Themed title rows, phone equip layout and reduced-motion rainbow handling. |
| ProfileController.luau | Responsive avatar/title preview and 11 lifetime statistics. |
| AscensionController.luau | Exclusive Blood Altar window, scrollable comparison, safe request failure handling and reduced motion. |
| AdminController.luau | Responsive admin window and all existing authorized currency/teleport actions. |
| SettingsController.luau | Shared theme/layout use; all original settings retained. |
| TutorialController.luau | Theme, compact/expanded bubble, shared motion and menu visibility handling. |
| AnnouncementController.luau | Shared notification queue and themed announcements. |
| EffectsController.luau | Themed floating labels and shared UI motion; Reduce Motion suppresses camera kick. |
| ZoneController.luau | Theme, queued entering notice, travel API for Areas and timeout feedback. |
| RuneController.luau | Theme for altar feedback and reduced-motion pulse. |
| FishingController.luau | Theme for real catch feedback. |
| SlashController.luau | Theme for real critical/slice feedback; gameplay input retained. |
| SushiController.luau | Theme for pickup feedback; original collection requests retained. |
| NametagController.luau | Shared theme and reduced-motion title animation. |

## Added controller modules

| File | Purpose |
|---|---|
| AreasController.luau | Five destinations with requirements, current-area state and proximity-valid travel. |
| BoardMenuController.luau | Touch/controller screen companion for upgrade and automation boards. |
| ResetMenuController.luau | Lose/keep/gain comparison and guarded Prestige/Rebirth confirmations. |
| FutureUIController.luau | Bundles, gifts, boosts, codes, inventory categories, rolling, restaurant, timing, event and mastery previews. |
| UIShowcaseController.luau | Studio-only UI Lab and component/state gallery. |
| MinigameHUDController.luau | Actual Fishing/Slashing status and confirmed result display. |
| WorldUIController.luau | Local adapter for replicated leaderboards, nametags, speech, rates, signs and sushi labels. |

## Verification

79 source files compile with zero syntax errors. Component service-double checks and all 210 geometry-reference checks pass. Actual Studio rendering, touch/controller behaviour, Output and place-only UI coverage remain pending; use Install-and-Test.md.
