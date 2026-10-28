# Countdown for Omarchy

A local Omarchy bar plugin for holidays, deadlines, launches, birthdays, and any other date worth counting down to.

## Features

- Multiple one-off or yearly countdowns
- A pinned countdown in the bar, with automatic nearest-event fallback
- All-day dates and exact local times
- Per-event milestone alerts at 30 days, 7 days, 1 day, 1 hour, and the event time
- Persistent event and notification state across shell restarts
- No accounts, API keys, network access, or external services
- Theme-aware Omarchy interface

## Install

Once published:

```bash
omarchy plugin add https://github.com/LiamBateman/omarchy-countdown.git --enable
```

For local development:

```bash
omarchy plugin validate /path/to/omarchy-countdown
omarchy plugin add /path/to/omarchy-countdown --enable
```

Click **Countdown** in the bar and choose **+ New**. Dates use `YYYY-MM-DD`; exact times use the 24-hour `HH:MM` format.

## Remove

```bash
omarchy plugin remove io.github.liambateman.countdown --yes
```

Removing the plugin does not intentionally remove Quickshell's persisted event state, so reinstalling can restore existing countdowns.

## Requirements and dependencies

- Omarchy 4 with the Quickshell-based Omarchy Shell
- `notify-send` for milestone alerts (included with the standard Omarchy desktop)

There are no additional packages, accounts, API keys, network services, install hooks, or elevated privileges.

## Controls

- Left click: open or close the countdown panel
- Middle click: pause or resume milestone notifications
- Pin: keep an event in the bar instead of automatically showing the nearest event
- Repeat yearly: reuse the month, day, and time each year

All-day events are counted as calendar dates and their alerts fire at 09:00 local time. Editing an event rearms its future milestones without replaying milestones that are already in the past. If the computer is asleep when a milestone passes, the most recent missed milestone is delivered after the shell resumes; older missed milestones are silently marked handled.

## Privacy and storage

Countdown is offline-only. Event data and alert deduplication state are held by Quickshell's persistent-properties store. No countdown information leaves the machine.

## Development

```bash
omarchy plugin validate .
```

The plugin targets Omarchy 4 and consists of a persistent service plus a bar widget:

- `Service.qml` owns countdown state, recurrence, and notifications.
- `BarWidget.qml` renders the nearest or pinned event.
- `Panel.qml` provides event creation and management.
- `Model.js` contains deterministic date, sorting, and milestone logic.

## License

MIT
