# Icon production manifest

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


## Upload registry

Set uploaded IDs in UIKit.Theme.Icons. For example:

```luau
UIKit.Theme.Icons.Money = "rbxassetid://YOUR_CASH_ICON_ID"
UIKit.Theme.Icons.KG = "rbxassetid://YOUR_SUSHI_ICON_ID"
UIKit.Theme.Icons.Shop = "rbxassetid://YOUR_SHOP_ICON_ID"
UIKit.Theme.Icons.VIPBundle = "rbxassetid://YOUR_BUNDLE_ICON_ID"
```

Currency keys are Money, KG, Prestiges, TotalRebirths, AscensionPoints, Runes, Neko, Robux, Fish and Slices. HUD keys are Shop, Index, Skills, Runes, Titles, Profile, Areas and Settings. Current shop keys are DoubleCash, DoubleSushi, Lucky, VIP, CashBoost and LuckBoost. Rune slots use Minnow, Goldfish, Koi, Puffer, Thunderfin, GoldenKoi, Abyssal and Leviathan. Featured preview offers use VIPBundle, StarterBundle, LuckyBundle, DoubleCash, DoubleSushi and DoubleNeko. Other generic cards use their Name or Title as the slot key.

The base pack, mascot, headers, buttons, shadows and focus rings work without uploaded assets. Existing Index models and skill icon art remain available.
