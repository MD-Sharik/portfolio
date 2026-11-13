# Google Play listing - Arrow Escape

Copy/paste into Play Console > Grow > Store presence > Main store listing.
(Character limits are Google's: title 30, short description 80, full description 4000.)

## App name (max 30)
Arrow Escape: Hardest Puzzle

## Short description (max 80)
1000 giant arrow mazes. Tap, slide, escape. How far can you get?

## Full description (max 4000)
HARDEST ARROW GAME - and it only gets deeper.

Every arrow is a snake of lines with a pointed head. Tap an arrow and it slides out along
its own path - but only if nothing is in its way! Pick the wrong one and it crashes into a
neighbour and you lose a drop. Clear every arrow from the board to win.

Sounds simple? Your boards are up to 128 x 128 squares with well over a thousand arrows
locked together in chains more than a hundred moves deep. One careless tap can block
everything behind it.

WHAT YOU GET
- 1000 handcrafted-by-algorithm levels, every one solvable and every one a monster
- Huge boards: pinch to zoom and drag to look around
- 4 drops per level - run out and watch a short ad for an extra one
- Free hints that point at a safe arrow (earn more by clearing levels)
- Bright candy colours, Night, Meadow, Bubblegum, Parchment... or go pure Black & White
- Satisfying haptic feedback, sound effects and confetti when you clear a board
- Play offline, any time. No account needed.

PERFECT FOR
Fans of maze, logic and "unblock it" puzzles who like a real challenge and want one more
level before bed.

Can you reach level 1000?

## Category / tags
- App type: Game
- Category: Puzzle
- Tags: Puzzle, Logic, Casual, Single player, Offline

## Graphics (this folder)
- App icon (512x512): `icon_512.png`
- Feature graphic (1024x500): `feature_graphic_1024x500.png`
- Phone screenshots (1080x1920, upload all six, in this order): `screenshots/01 ... 06`

## Things Play Console will ask you
- **Privacy policy URL**: required because the app shows ads (AD_ID permission). Host a short policy
  page and paste its URL. (It should say: no account, no personal data collected by the developer;
  Google AdMob may collect device identifiers for ads.)
- **Data safety form**: Data collected -> "Device or other IDs" (advertising ID), purpose: Advertising;
  not sold; Google AdMob is the third party.
- **Ads**: yes, the app contains ads.
- **Content rating questionnaire**: puzzle, no violence/gambling/user-generated content -> expect "Everyone".
- **Target audience**: if you pick an audience that includes children (under 13), the Families policy
  applies: set `CHILD_DIRECTED` in `scripts/ads_config.gd` and use only Families-certified ad setups.
  Safest for a first release: target 13+ / "not designed for children".
- **Account**: use *Play App Signing* (default). The AAB is signed with the UPLOAD key in
  your local keystore folder (kept outside the repo) - back it up.

## BEFORE you publish: replace the test ads
The build uses Google's TEST ad units. Live apps must use their own:
1. Create the app + 3 ad units (banner, interstitial, rewarded) in AdMob.
2. Put the IDs in `scripts/ads_config.gd` (IS_REAL = true) and the app ID in
   `addons/AdmobPlugin/android_export.cfg` ([General] is_real=true, [Release] app_id=...).
3. Rebuild the AAB (see README).

## Release notes (what's new)
First release! 1000 levels, huge boards, hints, themes and rewarded extra drops.
