# koreastudy browser runtime audit

- Generated at: 2026-06-22 01:33:38
- Browser: C:\Program Files\Google\Chrome\Application\chrome.exe
- Runtime score: 100 / 100
- Target: at least 85 points
- Real browser click simulation: 100000 iterations
- Result: PASS
- Page title: koreastudy
- Body text length: 1184
- Active view after audit: qa

## Checks

|Check|Points|Result|Evidence|
|---|---:|---|---|
|required runtime ids|10|PASS|34 ids|
|education data available|8|PASS|catalog and profiles|
|summary generation|10|PASS|511 chars|
|table render|7|PASS|4 rows|
|mindmap render|7|PASS|4 nodes|
|question render|8|PASS|4 cards|
|answer toggle click|6|PASS|answer opened|
|mistake save click|5|PASS|1 stored|
|worksheet navigation|5|PASS|1355 chars|
|navigation target integrity|6|PASS|19 links|
|repeated click simulation|10|PASS|100000 iterations|
|self check runtime|6|PASS|6 pass rows|
|runtime touch target scan|6|PASS|27 visible controls|
|runtime error listener|6|PASS|0 errors|

## Failed runtime checks

- No failed runtime checks.

## Limits

- This runs a real local Chrome or Edge headless browser against the static app.
- It validates runtime rendering, navigation, clicks, localStorage-backed actions, touch-target dimensions, and browser error listeners.
- It does not prove Netlify public URL availability or real 500,000-user traffic capacity.
