# Issue Tracker User Stories

This list is aligned to the features currently present in the app codebase so issues can be created and prioritized without drifting from reality.

## Current App Baseline

- Bottom navigation with 3 tabs: Home, Masjid, Settings.
- Prayer times are calculated locally from user location.
- Next prayer countdown is shown on Home.
- Daily prayer completion tracker is available and persisted.
- Masjid finder fetches nearby results and supports save/remove.
- Settings include permission review and Athan tone preferences (stored).

## Now (Aligned To Existing Features)

### US-001 - Detect location and show local prayer times
As a Muslim user, I want the app to detect my location and display accurate prayer times so I can pray on time where I am.

Acceptance criteria:
- On Home, user can tap Refresh Location to fetch location.
- App handles location disabled, denied, and denied forever states with clear messages.
- App displays Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha.
- Times update after successful location refresh.

Suggested labels: `feature`, `home`, `prayer-times`, `mvp`
Priority: P1

### US-002 - See next prayer and live countdown
As a Muslim user, I want to see the next prayer and a live countdown so I can prepare before Athan.

Acceptance criteria:
- Home displays next prayer name.
- Home displays a countdown that updates continuously.
- Countdown rolls over correctly after Isha to next day's Fajr.

Suggested labels: `feature`, `home`, `countdown`, `mvp`
Priority: P1

### US-003 - Track daily obligatory prayers
As a Muslim user, I want to mark prayers complete each day so I can track consistency.

Acceptance criteria:
- Home shows checklist for Fajr, Dhuhr, Asr, Maghrib, Isha.
- Toggling any prayer persists immediately.
- Daily progress summary shows completed count out of 5.
- A new day starts with a fresh checklist.

Suggested labels: `feature`, `home`, `tracker`, `mvp`
Priority: P1

### US-004 - Browse nearby masjids
As a user, I want to find nearby masjids so I can quickly identify places to pray.

Acceptance criteria:
- Masjid tab loads nearby results using current or last known location.
- Loading, empty state, and error state are shown.
- Pull-to-refresh updates nearby results.

Suggested labels: `feature`, `masjid`, `location`, `mvp`
Priority: P1

### US-005 - Save and remove favorite masjids
As a user, I want to save masjids and remove them later so I can keep a personal list.

Acceptance criteria:
- User can bookmark a nearby masjid.
- Saved tab lists persisted favorites.
- User can remove a saved masjid.
- Duplicate saves are prevented by id.

Suggested labels: `feature`, `masjid`, `favorites`, `mvp`
Priority: P1

### US-006 - Manage core permissions from settings
As a user, I want to review and request permissions from Settings so I can keep app features working.

Acceptance criteria:
- Settings shows current location and notification permission state.
- User can trigger permission request flows from Settings.
- User can open OS app settings from Settings page.

Suggested labels: `feature`, `settings`, `permissions`, `mvp`
Priority: P1

### US-007 - Store Athan tone preferences per prayer
As a user, I want to pick a sound per prayer so reminders match my preference.

Acceptance criteria:
- Settings shows tone selector for each obligatory prayer.
- Selections persist between app launches.
- Saved values are loaded and shown correctly.

Suggested labels: `feature`, `settings`, `preferences`, `mvp`
Priority: P2

## Next (Build On Current App)

### US-008 - Schedule local prayer notifications
As a user, I want automatic notifications for each prayer so I receive reminders without opening the app.

Acceptance criteria:
- App schedules notifications for all daily obligatory prayers.
- Notifications are refreshed daily for upcoming days.
- Notification title/body clearly identifies prayer name and time.
- Notification scheduling respects permission state.

Suggested labels: `enhancement`, `notifications`, `scheduler`
Priority: P1
Dependency: US-006, US-007

### US-009 - Use selected tone in actual notifications
As a user, I want my chosen tone to be used in prayer alerts so notifications feel personalized.

Acceptance criteria:
- Each prayer notification uses its mapped tone where supported.
- Fallback behavior is defined and used when custom tone is unavailable.
- Tone mapping is documented in settings/help text.

Suggested labels: `enhancement`, `notifications`, `audio`
Priority: P2
Dependency: US-007, US-008

### US-010 - Add Qibla direction feature
As a user, I want a Qibla indicator so I can orient correctly for prayer.

Acceptance criteria:
- App shows Qibla direction view based on location and compass.
- User sees guidance when sensor or permission data is unavailable.
- Direction updates smoothly while device orientation changes.

Suggested labels: `feature`, `qibla`, `location`
Priority: P2

## Later (Roadmap)

### US-011 - Monthly prayer calendar view
As a user, I want a monthly calendar of prayer times so I can plan ahead.

Acceptance criteria:
- User can open a month view for location-based prayer times.
- User can move between months.
- Days show key prayer times and selected-day detail.

Suggested labels: `roadmap`, `calendar`, `planning`
Priority: P3

### US-012 - Cloud sync for settings and saved masjids
As a returning user, I want my preferences and saved masjids synced so I can switch devices without losing data.

Acceptance criteria:
- User can sign in and sync selected data.
- Conflict handling is defined for merges.
- Offline mode preserves local behavior until sync resumes.

Suggested labels: `roadmap`, `sync`, `account`
Priority: P3

## Suggested Issue Creation Order

1. US-001
2. US-002
3. US-003
4. US-004
5. US-005
6. US-006
7. US-007
8. US-008
9. US-009
10. US-010
11. US-011
12. US-012
