function dayKey(day) {
    return day.getFullYear() + "-" + String(day.getMonth() + 1).padStart(2, "0")
           + "-" + String(day.getDate()).padStart(2, "0");
}

function monthKey(day) { return dayKey(day).slice(0, 7); }

function calendar(month) {
    var first = new Date(month.getFullYear(), month.getMonth(), 1, 12);
    var start = new Date(first.getTime());
    start.setDate(1 - (first.getDay() + 6) % 7);
    var cells = [];
    for (var i = 0; i < 42; i++) {
        var day = new Date(start.getTime());
        day.setDate(start.getDate() + i);
        cells.push({key: dayKey(day), number: day.getDate(), date: day,
                    currentMonth: day.getMonth() === month.getMonth()});
    }
    return cells;
}

function shiftMonth(month, delta) {
    return new Date(month.getFullYear(), month.getMonth() + delta, 1, 12);
}
