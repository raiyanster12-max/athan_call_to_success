# Issue Tracker User Stories

This list is aligned to the features currently present in the app codebase so issues can be created and prioritized without drifting from reality.

## Current App Baseline

- Bottom navigation with 4 tabs: Home, Quran, Tracker, More.
- Prayer times are calculated locally from user location.
- Next prayer countdown is shown on Home.
- Home shows live Gregorian date/time and Hijri date.
- Quran tab provides all 114 surahs and an interactive Arabic reader with English translation toggle, ayah jump, last-read ayah, and copy ayah action.
- Tracker page includes daily prayer completion tracking and an interactive Ramadan day calendar (done, missed, pending).
- More tab includes an interactive Gregorian calendar with Hijri conversion for selected dates.
- Masjid finder supports nearby and saved views, 15-mile search radius, Overpass multi-mirror lookup, and Nominatim fallback to reduce timeout failures.
- Settings include location, notifications, battery optimization review, and Athan tone preferences (stored).

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

### US-002 - See next prayer and live countdown with date context
As a Muslim user, I want to see the next prayer, live countdown, and current date context so I can prepare before Athan.

Acceptance criteria:
- Home displays next prayer name.
- Home displays a countdown that updates continuously.
- Home displays live Gregorian date/time and Hijri date.
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

### US-004 - Browse nearby masjids reliably
As a user, I want to find nearby masjids without frequent timeout failures so I can quickly identify places to pray.

Acceptance criteria:
- Masjid finder loads nearby results using current or last known location.
- Loading, empty state, and error state are shown.
- Pull-to-refresh updates nearby results.
- Service uses fallback source(s) when primary provider times out.

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
- Settings shows current location, notification, and battery optimization permission state.
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

### US-008 - Read full Quran in interactive mode
As a user, I want a rich Quran reading experience with full Arabic text and translation controls so I can read comfortably.

Acceptance criteria:
- Quran tab lists all 114 surahs.
- Surah details show full Arabic ayahs, not placeholders.
- User can toggle English translation visibility.
- User can jump to a specific ayah from a dropdown.
- Last-read ayah for each surah is saved and restored.

Suggested labels: `feature`, `quran`, `reader`, `mvp`
Priority: P1

### US-009 - Track Ramadan day outcomes
As a user, I want to mark Ramadan days as done or missed in a calendar so I can review my consistency over the month.

Acceptance criteria:
- Tracker page includes Ramadan calendar for the current Gregorian year.
- Each Ramadan day cycles through pending, done, missed on tap.
- Status is persisted locally and restored between launches.
- Summary chips show done, missed, and pending counts.

Suggested labels: `feature`, `tracker`, `ramadan`, `calendar`
Priority: P1

### US-010 - Use calendar utilities in More tab
As a user, I want a selectable calendar with Hijri conversion in More so I can quickly map dates.

Acceptance criteria:
- More tab shows selectable Gregorian calendar.
- Selected date shows matching Hijri date.
- Today action jumps back to the current date.

Suggested labels: `feature`, `more`, `calendar`, `hijri`
Priority: P2

## Next (Build On Current App)

### US-011 - Schedule local prayer notifications
As a user, I want automatic notifications for each prayer so I receive reminders without opening the app.

Acceptance criteria:
- App schedules notifications for all daily obligatory prayers.
- Notifications are refreshed daily for upcoming days.
- Notification title/body clearly identifies prayer name and time.
- Notification scheduling respects permission state.

Suggested labels: `enhancement`, `notifications`, `scheduler`
Priority: P1
Dependency: US-006, US-007

### US-012 - Use selected tone in actual notifications
As a user, I want my chosen tone to be used in prayer alerts so notifications feel personalized.

Acceptance criteria:
- Each prayer notification uses its mapped tone where supported.
- Fallback behavior is defined and used when custom tone is unavailable.
- Tone mapping is documented in settings/help text.

Suggested labels: `enhancement`, `notifications`, `audio`
Priority: P2
Dependency: US-007, US-011

### US-013 - Add Qibla direction feature
As a user, I want a Qibla indicator so I can orient correctly for prayer.

Acceptance criteria:
- App shows Qibla direction view based on location and compass.
- User sees guidance when sensor or permission data is unavailable.
- Direction updates smoothly while device orientation changes.

Suggested labels: `feature`, `qibla`, `location`
Priority: P2

## Later (Roadmap)

### US-014 - Monthly prayer calendar view
As a user, I want a monthly calendar of prayer times so I can plan ahead.

Acceptance criteria:
- User can open a month view for location-based prayer times.
- User can move between months.
- Days show key prayer times and selected-day detail.

Suggested labels: `roadmap`, `calendar`, `planning`
Priority: P3

### US-015 - Cloud sync for settings and saved masjids
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
13. US-013
14. US-014
15. US-015
