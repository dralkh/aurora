const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const math = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../package/contents/ui/SleepMath.js`, "utf8"), math);
assert.equal(math.result(360, 5, 14, 0), -104);
assert.equal(math.time(-104, false), "10:16");
assert.equal(math.period(-104), "PM");
assert.equal(math.dayOffset(-104), -1);
assert.equal(math.time(math.result(1320, 5, 14, 1), true), "05:44");
assert.equal(math.dayOffset(math.result(1320, 5, 14, 1)), 1);
assert.equal(math.result(720, 1, 0, 2), 810);
assert.equal(math.parse("12:00", false, false), 0);
assert.equal(math.parse("12:00", false, true), 720);
assert.equal(math.parse("23:59", true, false), 1439);
for (const invalid of ["24:00", "12:60", "x", "-1:00"]) assert.equal(math.parse(invalid, true, false), -1);
assert.equal(math.parse("00:00", false, false), -1);
for (let anchor = 0; anchor < 1440; anchor += 15) {
    for (let cycles = 1; cycles <= 6; cycles++) {
        for (const latency of [0, 14, 120]) {
            for (const mode of [0, 1, 2]) {
                const result = math.result(anchor, cycles, latency, mode);
                assert.equal(Math.abs(result - anchor), cycles * 90 + latency);
                assert.ok(math.wrap(result) >= 0 && math.wrap(result) < 1440);
                assert.equal(math.parse(math.time(result, true), true, false), math.wrap(result));
                assert.equal(math.parse(math.time(result, false), false, math.period(result) === "PM"), math.wrap(result));
            }
        }
    }
}
console.log("Sleep calculations passed: midnight, AM/PM, day rollover, validation, all modes and cycle counts.");
