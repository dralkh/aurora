// Local wall-clock estimates; a cycle is an approximation, not a prediction.
function wrap(minutes) { return ((minutes % 1440) + 1440) % 1440; }
function result(anchor, cycles, latency, mode) {
    return anchor + (mode === 0 ? -1 : 1) * (cycles * 90 + latency);
}
function time(minutes, use24) {
    var value = wrap(minutes), h = Math.floor(value / 60), m = value % 60;
    return (use24 ? String(h).padStart(2, "0") : String(h % 12 || 12)) + ":" + String(m).padStart(2, "0");
}
function period(minutes) { return wrap(minutes) < 720 ? "AM" : "PM"; }
function dayOffset(minutes) { return Math.floor(minutes / 1440); }
function parse(text, use24, pm) {
    var match = /^(\d{1,2}):(\d{2})$/.exec(text.trim());
    if (!match) return -1;
    var h = Number(match[1]), m = Number(match[2]);
    if (m > 59 || h > (use24 ? 23 : 12) || (!use24 && h < 1)) return -1;
    return (use24 ? h : h % 12 + (pm ? 12 : 0)) * 60 + m;
}
