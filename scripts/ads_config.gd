extends RefCounted
## AdMob settings. EVERYTHING is on Google's TEST ads right now - safe to tap, earns nothing.
##
## To go live:
##   1. Create an app + 3 ad units (banner, interstitial, rewarded) in https://admob.google.com
##   2. Put the real IDs below and set IS_REAL = true
##   3. Put the real *application id* (ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy) into
##      addons/AdmobPlugin/android_export.cfg  ([Release] app_id, and [General] is_real=true)
##   4. Rebuild the APK/AAB.

const ENABLED := true
const IS_REAL := false

# Real ad unit IDs (only used when IS_REAL = true)
const REAL_BANNER_ID := ""
const REAL_INTERSTITIAL_ID := ""
const REAL_REWARDED_ID := ""

## Show a full-screen ad after every N cleared levels (0 = never). Rewarded ads are always opt-in.
const INTERSTITIAL_EVERY := 3
## ...but never more often than this many seconds.
const INTERSTITIAL_MIN_SECONDS := 90

## Is the game directed at children? Google's Families policy then limits which ads may be served.
## -1 = unspecified, 0 = no, 1 = yes (child-directed treatment).
const CHILD_DIRECTED := -1

## On desktop / in the editor, fake ads are shown so the whole reward flow can be tested.
const SIMULATE_ON_DESKTOP := true
const SIM_REWARDED_SECONDS := 3.0
