.pragma library

var MINUTE = 60 * 1000
var DAY = 24 * 60 * MINUTE
var DEFAULT_ALERTS = [43200, 10080, 1440, 60, 0]
var ALLOWED_ALERTS = [43200, 10080, 1440, 60, 0]

function pad(value) {
  return value < 10 ? "0" + value : String(value)
}

function boolSetting(value, fallback) {
  if (value === undefined || value === null) return fallback
  if (typeof value === "string") {
    var text = value.toLowerCase().trim()
    if (text === "true" || text === "1" || text === "yes" || text === "on") return true
    if (text === "false" || text === "0" || text === "no" || text === "off") return false
  }
  return !!value
}

function dateInput(date) {
  var value = date || new Date()
  return value.getFullYear() + "-" + pad(value.getMonth() + 1) + "-" + pad(value.getDate())
}

function defaultDate(nowMs) {
  return dateInput(new Date((nowMs || Date.now()) + 30 * DAY))
}

function trimText(value, limit) {
  var text = String(value || "").trim()
  return text.length > limit ? text.slice(0, limit) : text
}

function validDateParts(text) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(text || "").trim())
  if (!match) return null
  var year = parseInt(match[1], 10)
  var month = parseInt(match[2], 10)
  var day = parseInt(match[3], 10)
  var value = new Date(year, month - 1, day, 12, 0, 0, 0)
  if (value.getFullYear() !== year || value.getMonth() !== month - 1 || value.getDate() !== day) return null
  return { year: year, month: month, day: day }
}

function validTimeParts(text) {
  var match = /^(\d{1,2}):(\d{2})$/.exec(String(text || "").trim())
  if (!match) return null
  var hour = parseInt(match[1], 10)
  var minute = parseInt(match[2], 10)
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null
  return { hour: hour, minute: minute }
}

function normalizedAlerts(value) {
  var source = Array.isArray(value) ? value : DEFAULT_ALERTS
  var result = []
  for (var i = 0; i < ALLOWED_ALERTS.length; i++) {
    var candidate = ALLOWED_ALERTS[i]
    for (var j = 0; j < source.length; j++) {
      if (parseInt(source[j], 10) === candidate) {
        result.push(candidate)
        break
      }
    }
  }
  return result
}

function normalizeEvent(input, nowMs) {
  var source = input || {}
  var now = Number(nowMs) || Date.now()
  var title = trimText(source.title, 80)
  var date = String(source.date || "").trim()
  var allDay = boolSetting(source.allDay, true)
  var time = allDay ? "09:00" : String(source.time || "").trim()

  if (!title) return { ok: false, error: "Give the countdown a name." }
  if (!validDateParts(date)) return { ok: false, error: "Use a valid date in YYYY-MM-DD format." }
  if (!validTimeParts(time)) return { ok: false, error: "Use a valid 24-hour time in HH:MM format." }

  var event = {
    id: trimText(source.id, 120),
    title: title,
    date: date,
    time: time,
    allDay: allDay,
    yearly: boolSetting(source.yearly, false),
    icon: trimText(source.icon, 12) || "󰔛",
    alerts: normalizedAlerts(source.alerts),
    createdAt: Number(source.createdAt) > 0 ? Number(source.createdAt) : now,
    armedAt: Number(source.armedAt) > 0 ? Number(source.armedAt) : now
  }
  return { ok: true, event: event, error: "" }
}

function hydrateEvents(raw, nowMs) {
  var parsed = []
  try {
    var candidate = JSON.parse(String(raw || "[]"))
    if (Array.isArray(candidate)) parsed = candidate
  } catch (e) {}

  var result = []
  for (var i = 0; i < parsed.length; i++) {
    var normalized = normalizeEvent(parsed[i], nowMs)
    if (normalized.ok && normalized.event.id) result.push(normalized.event)
  }
  return result
}

function targetForYear(event, year) {
  var date = validDateParts(event.date)
  var time = validTimeParts(event.allDay ? "09:00" : event.time)
  if (!date || !time) return null
  var actualYear = year === undefined || year === null ? date.year : year
  var target = new Date(actualYear, date.month - 1, date.day, time.hour, time.minute, 0, 0)
  if (target.getFullYear() !== actualYear || target.getMonth() !== date.month - 1 || target.getDate() !== date.day) return null
  return target
}

function occurrenceCandidates(event, nowMs) {
  if (!event.yearly) {
    var fixed = targetForYear(event, null)
    return fixed ? [fixed] : []
  }

  var now = new Date(nowMs)
  var candidates = []
  for (var year = now.getFullYear() - 1; year <= now.getFullYear() + 5; year++) {
    var target = targetForYear(event, year)
    if (target) candidates.push(target)
  }
  return candidates
}

function displayTarget(event, nowMs) {
  var candidates = occurrenceCandidates(event, nowMs)
  if (!candidates.length) return null
  if (!event.yearly) return candidates[0]
  for (var i = 0; i < candidates.length; i++) {
    if (candidates[i].getTime() >= nowMs) return candidates[i]
  }
  return candidates[candidates.length - 1]
}

function calendarDayDifference(target, nowMs) {
  var now = new Date(nowMs)
  var todayUtc = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
  var targetUtc = Date.UTC(target.getFullYear(), target.getMonth(), target.getDate())
  return Math.round((targetUtc - todayUtc) / DAY)
}

function relativeLabel(event, target, nowMs) {
  if (!target) return "Invalid date"

  if (event.allDay) {
    var days = calendarDayDifference(target, nowMs)
    if (days === 0) return "Today"
    if (days === 1) return "Tomorrow"
    if (days > 1) return days + "d"
    if (days === -1) return "Yesterday"
    return Math.abs(days) + "d ago"
  }

  var remaining = target.getTime() - nowMs
  var absolute = Math.abs(remaining)
  var suffix = remaining < 0 ? " ago" : ""
  if (absolute < MINUTE) return remaining < 0 ? "Just now" : "<1m"
  if (absolute < 60 * MINUTE) return Math.floor(absolute / MINUTE) + "m" + suffix
  if (absolute < DAY) {
    var hours = Math.floor(absolute / (60 * MINUTE))
    var minutes = Math.floor((absolute % (60 * MINUTE)) / MINUTE)
    return hours + "h" + (minutes ? " " + minutes + "m" : "") + suffix
  }
  var daysLeft = Math.floor(absolute / DAY)
  var hoursLeft = Math.floor((absolute % DAY) / (60 * MINUTE))
  return daysLeft + "d" + (daysLeft < 7 && hoursLeft ? " " + hoursLeft + "h" : "") + suffix
}

function longDate(target, allDay) {
  if (!target) return ""
  var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
  var result = weekdays[target.getDay()] + ", " + target.getDate() + " " + months[target.getMonth()] + " " + target.getFullYear()
  if (!allDay) result += " at " + pad(target.getHours()) + ":" + pad(target.getMinutes())
  return result
}

function eventView(event, nowMs) {
  var target = displayTarget(event, nowMs)
  return {
    event: event,
    id: event.id,
    title: event.title,
    icon: event.icon,
    yearly: event.yearly,
    allDay: event.allDay,
    targetMs: target ? target.getTime() : 0,
    relative: relativeLabel(event, target, nowMs),
    detail: longDate(target, event.allDay),
    past: target ? target.getTime() < nowMs : false
  }
}

function sortedEventViews(events, nowMs) {
  var result = []
  for (var i = 0; i < events.length; i++) result.push(eventView(events[i], nowMs))
  result.sort(function(a, b) {
    if (a.past !== b.past) return a.past ? 1 : -1
    if (a.past) return b.targetMs - a.targetMs
    return a.targetMs - b.targetMs
  })
  return result
}

function featuredEventView(events, pinnedId, nowMs) {
  var views = sortedEventViews(events, nowMs)
  if (pinnedId) {
    for (var i = 0; i < views.length; i++) if (views[i].id === pinnedId) return views[i]
  }
  return views.length ? views[0] : null
}

function compactTitle(title, limit) {
  var text = String(title || "")
  var max = limit || 22
  return text.length > max ? text.slice(0, Math.max(1, max - 1)) + "…" : text
}

function milestoneLabel(minutes) {
  var value = parseInt(minutes, 10)
  if (value === 43200) return "30 days"
  if (value === 10080) return "7 days"
  if (value === 1440) return "1 day"
  if (value === 60) return "1 hour"
  return "At time"
}

function occurrenceKey(event, target) {
  return event.id + "|" + dateInput(target) + "T" + pad(target.getHours()) + ":" + pad(target.getMinutes())
}

function dueNotifications(events, firedInput, nowMs) {
  var fired = {}
  var key
  if (firedInput && typeof firedInput === "object") {
    for (key in firedInput) fired[key] = firedInput[key]
  }

  var notifications = []
  for (var i = 0; i < events.length; i++) {
    var event = events[i]
    var candidates = occurrenceCandidates(event, nowMs)
    var due = []

    for (var c = 0; c < candidates.length; c++) {
      var target = candidates[c]
      var targetMs = target.getTime()
      if (targetMs < nowMs - 2 * DAY) continue
      if (targetMs > nowMs + 367 * DAY) continue

      var baseKey = occurrenceKey(event, target)
      for (var a = 0; a < event.alerts.length; a++) {
        var threshold = event.alerts[a]
        var dueAt = targetMs - threshold * MINUTE
        var alertKey = baseKey + "|" + threshold
        if (dueAt >= event.armedAt && dueAt <= nowMs && !fired[alertKey]) {
          due.push({ event: event, target: target, threshold: threshold, dueAt: dueAt, key: alertKey })
        }
      }
    }

    if (!due.length) continue
    due.sort(function(a, b) { return a.dueAt - b.dueAt })
    for (var d = 0; d < due.length; d++) fired[due[d].key] = nowMs
    var latest = due[due.length - 1]
    notifications.push({
      title: latest.event.title,
      icon: latest.event.icon,
      threshold: latest.threshold,
      milestone: milestoneLabel(latest.threshold),
      detail: longDate(latest.target, latest.event.allDay),
      reached: latest.threshold === 0
    })
  }
  return { notifications: notifications, fired: fired }
}
