extends RefCounted
## Settings for the Play Store review prompt and in-app updates.

const PACKAGE_ID := "com.arrowescapehard.game"

# ---- Review prompt (Google Play In-App Review) ----------------------------------------------
# Asked right after the player clears a level, only when ALL of these are true:
const REVIEW_ENABLED := true
const REVIEW_MIN_LEVELS := 5          # has cleared at least this many levels
const REVIEW_MIN_DAYS := 2            # and has had the game installed for this many days
const REVIEW_COOLDOWN_DAYS := 90      # and we did not ask in the last N days
const REVIEW_MAX_PROMPTS := 3         # and we asked fewer than this many times in total
# Google also rate-limits the dialog itself, so it may silently not appear. That is normal.

# ---- In-app updates (Google Play In-App Updates) --------------------------------------------
const UPDATE_ENABLED := true
const UPDATE_CHECK_DELAY := 4.0       # seconds after launch before checking
const UPDATE_PROMPT_COOLDOWN_HOURS := 24   # don't offer an optional update more often than this
const UPDATE_IMMEDIATE_PRIORITY := 4  # updates with priority >= this (set in Play Console / API)
                                      # are installed with the full-screen "immediate" flow
