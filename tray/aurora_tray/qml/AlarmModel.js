// Shared alarm-form behavior. The standalone bundle carries an identical copy.
function defaults() {
    return {selectedId: "", alarmName: "Sleep schedule", repeatDays: [],
            bedEnabled: true, wakeEnabled: true, bedSound: true, wakeSound: true,
            bedLead: 15, snooze: 10, volume: 70};
}

function validationError(draft) {
    if (!draft.alarmName.trim()) return "Enter an alarm name in Configure.";
    if (!draft.bedEnabled && !draft.wakeEnabled)
        return "Enable a bedtime or wake-up alarm in Configure.";
    return "";
}

function dateString(date) {
    return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0")
           + "-" + String(date.getDate()).padStart(2, "0");
}

function makeSchedule(draft, bedMinutes, wakeMinutes, now) {
    var day = new Date(now.getTime());
    day.setHours(Math.floor(wakeMinutes / 60), wakeMinutes % 60, 0, 0);
    if (day.getTime() <= now.getTime()) day.setDate(day.getDate() + 1);
    var schedule = {name: draft.alarmName.trim(), bedMinutes: bedMinutes, wakeMinutes: wakeMinutes,
                    wakeDate: dateString(day), days: draft.repeatDays.slice(), enabled: true,
                    bedEnabled: draft.bedEnabled, wakeEnabled: draft.wakeEnabled,
                    bedLead: draft.bedLead, bedSound: draft.bedSound, wakeSound: draft.wakeSound,
                    snooze: draft.snooze, volume: draft.volume};
    if (draft.selectedId) schedule.id = draft.selectedId;
    return schedule;
}

function restore(schedule) {
    var draft = defaults();
    if (!schedule) return {draft: draft, calculator: null};
    draft.selectedId = schedule.id;
    draft.alarmName = schedule.name;
    draft.repeatDays = schedule.days.slice();
    for (var key of ["bedEnabled", "wakeEnabled", "bedSound", "wakeSound", "bedLead", "snooze", "volume"])
        draft[key] = schedule[key];
    var duration = (schedule.wakeMinutes - schedule.bedMinutes + 1440) % 1440;
    var cycles = Math.max(1, Math.min(6, Math.floor(duration / 90)));
    return {draft: draft, calculator: {
        mode: 0, wakeMinutes: schedule.wakeMinutes, cycles: cycles,
        latency: Math.max(0, Math.min(120, duration - cycles * 90))
    }};
}

function applyDraft(owner, draft) {
    for (var key in draft) owner[key] = draft[key];
}
