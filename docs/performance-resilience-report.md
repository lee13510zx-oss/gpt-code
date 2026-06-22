# koreastudy performance and resilience audit

- Generated at: 2026-06-22 09:28:47
- Performance/resilience score: 100 / 100
- Target: at least 85 points
- Runtime bundle: 94.24 KB
- Simulation: 500000 performance/resilience scenarios, 0 failures
- Result: PASS

## Checks

|Check|Points|Result|Evidence|
|---|---:|---|---|
|buildless static runtime|8|PASS|no package install required|
|small runtime bundle|10|PASS|94.24 KB runtime bundle|
|small app script|7|PASS|36.69 KB app.js|
|small stylesheet|5|PASS|12.28 KB styles.css|
|structured local data|6|PASS|30.55 KB education data|
|deferred optional AI|8|PASS|AI is optional and function-routed|
|storage failure resilience|9|PASS|guarded storage wrappers|
|offline first content path|7|PASS|local material generation|
|download without server|5|PASS|client-side text export|
|print without server|5|PASS|client-side print/PDF|
|layout shift controls|6|PASS|stable responsive constraints|
|no remote asset dependency|5|PASS|no remote images/fonts/scripts|
|security header preflight|6|PASS|security headers present|
|mobile persistence path|4|PASS|library, mistakes, bottom nav|
|performance resilience simulation|9|PASS|500000 scenarios, 0 failures|

## Failed checks

- No failed performance or resilience checks.

## Limits

- This no-cost audit checks local bundle size, offline paths, storage resilience, and static deploy posture.
- It does not replace real network throttling on the final Netlify URL.