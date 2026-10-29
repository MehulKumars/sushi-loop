# Services and backend

These games do not need a server of their own. Google and a few free services act as the backend,
and the template hides each one behind an interface in `core/services/`.

## What you use, and what the template has

| Need | Service | Cost | In the template |
|---|---|---|---|
| Ads | Google AdMob | free (pays out once earnings pass US$100) | `AdsService` interface + mock |
| In-app purchases | Google Play Billing | Google takes 15% on your first US$1M a year | `IAPService` interface + mock (add the real one only after a game passes Keep) |
| Leaderboards, achievements, cloud saves | Google Play Games Services | free | `LeaderboardService` interface + mock |
| Analytics and crash reports | Firebase (free Spark plan) or Sentry | free tiers | `AnalyticsService` interface + mock |
| Review prompt | Google Play in-app review | free | `ReviewService` interface + mock |
| Progress and settings | on the phone | free | `SaveStore` (real, done) and `Settings` (`user://settings.cfg`) |
| Cross-device leaderboards (only if needed later) | Talo | free up to 10,000 players | not included |

Avoid: SilentWolf (shut down around 1 Nov 2025), Supabase free projects (pause after a week idle),
LootLocker (jumps from free to US$500/month), and anything without a free tier.

## The interfaces

```gdscript
# Services.ads (AdsService)
signal rewarded_finished(placement: String, granted: bool)
signal interstitial_closed(placement: String)
func is_rewarded_ready(placement: String) -> bool
func show_rewarded(placement: String) -> void
func is_interstitial_ready(placement: String) -> bool
func show_interstitial(placement: String) -> void

# Services.iap (IAPService)
signal purchase_finished(product_id: String, success: bool)
func is_owned(product_id: String) -> bool
func purchase(product_id: String) -> void

# Services.analytics (AnalyticsService)
func log_event(event_name: String, params: Dictionary = {}) -> void

# Services.leaderboard (LeaderboardService)
func submit_score(board_id: String, score: int) -> void
func show_board(board_id: String) -> void
func get_local_best(board_id: String) -> int

# Services.review (ReviewService)
func request_review() -> void
```

Every service also has `initialize()`, called once by `Services._ready()`.

**Usage rules:** give every ad call a `placement` name ("revive", "hint", "results") so analytics
can tell placements apart; reward the player only in `rewarded_finished` when `granted` is true;
ask for interstitials only through `AdPolicy` on a results screen; ask for a review only after a
clear win.

## How the mocks behave

| Mock | Debug builds (editor, PC, debug APK) | Release builds |
|---|---|---|
| `MockAdsService` | Ads are "ready"; after 0.5 s reports the result; `ads_grant false` in the console tests the no-reward path | Nothing is ready and no reward is ever granted; `Services` logs a warning |
| `MockIAPService` | Every purchase succeeds for the session, answering after 0.3 s like a real store (results never arrive inside `purchase()`, so screens can call and then `await purchase_finished`) | Same (wire real billing before selling anything) |
| `MockAnalyticsService` | Prints events to the Output panel | Prints only |
| `MockLeaderboardService` | Keeps best scores in memory | Same |
| `MockReviewService` | Prints | Prints |

The release behaviour of the ad mock is deliberate: a game shipped before real ads are wired
cannot hand out free rewards.

## Adding a real service (pattern)

Do this once, with the first game that needs it, then copy the implementation into the template.

1. **Install the plugin** into `addons/` at a pinned version and enable it. Plugins confirmed
   maintained in October 2026:
   - Ads: `poingstudios/godot-admob-plugin` v5.1.0 (includes consent/UMP and editor mock ads).
     The old separate Android/iOS repos are archived.
   - Purchases: `godot-sdk-integrations/godot-google-play-billing` 3.3.0+ (Billing Library 9.1.0,
     meets Google's "Billing Library 8 or later" rule).
   - Leaderboards: `godot-sdk-integrations/godot-play-game-services` v3.4.0.
   - Crash reporting: `getsentry/sentry-godot` 2.3.0, or Firebase Crashlytics.
   Android plugins need the **Android Release AAB** preset's Gradle build (already on) and usually
   the same for the debug preset; follow each plugin's README.
2. **Write an implementation** that extends the interface and translates calls to the plugin:
   ```gdscript
   class_name AdMobAdsService
   extends AdsService
   ## Real ads through the AdMob plugin. Only this file talks to the plugin.

   func initialize() -> void:
   	pass  # initialise the plugin and load the first ads, as its README shows

   func show_rewarded(placement: String) -> void:
   	pass  # show the plugin's rewarded ad; on its "earned reward" callback emit
   	      # rewarded_finished.emit(placement, true), on close without reward emit false
   ```
   Use AdMob **test ad unit IDs** during development and real IDs only in release builds.
3. **Select it in `core/services/services.gd`**, keeping the mock for the editor and PC:
   ```gdscript
   ads = _add(AdMobAdsService.new() if OS.get_name() == "Android" else MockAdsService.new(), "Ads") as AdsService
   ```
4. **Test on a phone** (`adb logcat -s godot`), then fill in the Play Console declarations: the ads
   declaration and the Data safety form must include what the SDK collects.

The plugin steps above are not yet exercised in this template; expect to adapt them to each
plugin's current README.

## Privacy and money notes

- Google shows your full address on the store page "if you decide to monetize on Google Play";
  whether ads-only counts is unconfirmed. Check Play Console before launch.
- In-app purchases need BillDesk KYC for India-based merchants and raise GST questions; add them
  only after a game passes Keep, and talk to a chartered accountant first. Not legal or tax advice.
