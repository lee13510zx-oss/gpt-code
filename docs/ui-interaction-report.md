# koreastudy UI interaction audit

- Generated at: 2026-06-22 00:52:16
- UI score: 100 / 100
- Target: at least 85 points
- Interaction simulation: 500000 iterations, 0 failures, 0% failure rate
- Result: PASS

## Checks

|Check|Points|Result|Evidence|
|---|---:|---|---|
|all app id references exist|12|PASS|44 refs, 0 missing|
|all navigation targets exist|12|PASS|14 links, 0 missing|
|touch target baseline|10|PASS|44px baseline|
|dynamic action touch targets|10|PASS|answer/explore buttons|
|bottom nav desktop touch size|8|PASS|bottom nav 44px|
|bottom nav mobile touch size|8|PASS|mobile bottom nav 44px|
|native keyboard controls|8|PASS|buttons/selects/inputs|
|form submit bound|8|PASS|textbook form submit|
|question click delegation|8|PASS|questionList click|
|mistake click delegation|8|PASS|mistakeList click|
|explore click delegation|4|PASS|exploreResults click|
|print removes nav clutter|4|PASS|print styles|

## Failed checks

- No failed UI checks.

## Failed simulated actions

- No failed simulated actions.

## Limits

- This is a no-cost local structural and interaction simulation.
- It does not replace a real browser visual pass on the deployed URL.
