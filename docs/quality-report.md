# koreastudy quality score report

- Generated at: 2026-06-22 09:09:47
- Total score: 100 / 100
- Target: at least 85 points, 10 consecutive passes
- Consecutive scores: 100, 100, 100, 100, 100, 100, 100, 100, 100, 100
- Simulation: 500000 iterations, 0 failures, 0% failure rate
- Result: PASS

## Score model

Common market apps are treated as 50 points and stable large apps as 70 points. koreastudy must reach 85+ through code safety, deployment readiness, content coverage, UX, free operation, and risk control.

## Item results

|Category|Item|Points|Result|Evidence|
|---|---:|---:|---|---|
|reliability|required files|4|PASS|24/24 files|
|reliability|safe storage wrappers|4|PASS|storage wrappers|
|reliability|escaped HTML output|4|PASS|80 uses|
|reliability|AI no-key fallback|4|PASS|Gemini optional|
|reliability|self-check screen|3|PASS|self-check|
|reliability|stored JSON guarded|3|PASS|guarded parse|
|reliability|static check script|3|PASS|static-check|
|content|school levels|4|PASS|3 levels|
|content|subject breadth|4|PASS|49 subjects|
|content|subject profiles|4|PASS|43 profiles|
|content|curriculum versions|3|PASS|2015/2022|
|content|question categories|3|PASS|4 categories|
|content|unit seeds|2|PASS|unit seeds|
|ux|responsive layout|3|PASS|breakpoints|
|ux|touch targets|3|PASS|44px minimum|
|ux|dark mode|3|PASS|theme|
|ux|print support|3|PASS|print|
|ux|worksheet download|2|PASS|worksheet/download|
|ux|bottom navigation|2|PASS|nav|
|ux|accessibility visual audit|2|PASS|500000 accessibility scenarios|
|ux|UI interaction audit|1|PASS|500000 UI interactions|
|ux|browser runtime audit|1|PASS|100000 real browser clicks|
|deployment|Netlify config|3|PASS|netlify.toml|
|deployment|buildless static deploy|3|PASS|publish root|
|deployment|function path|3|PASS|function|
|deployment|security headers|2|PASS|headers|
|deployment|manifest linked|2|PASS|manifest|
|deployment|deployment preflight audit|2|PASS|500000 deployment scenarios|
|risk|copyright policy|3|PASS|policy|
|risk|deferred approvals|3|PASS|approvals doc|
|risk|free-first principle|2|PASS|free docs|
|risk|no obvious secret key|2|PASS|no Gemini key|
|growth|free roadmap|2|PASS|roadmap|
|growth|premium candidates|2|PASS|future paid roadmap|
|growth|retention features|2|PASS|library/mistakes|
|growth|solo student friendly|2|PASS|no build/deps|
|growth|operations risk audit|2|PASS|500000 free-operation scenarios|

## Failed items

- No failed automated score items.

## Limits

- This is a free local static audit plus data-combination simulation.
- Real 500,000-user load testing against Netlify is not run on a free personal account.
- Real revenue needs deployed traffic, retention, and conversion data.