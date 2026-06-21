# koreastudy deployment preflight audit

- Generated at: 2026-06-22 08:56:50
- Deployment score: 100 / 100
- Target: at least 85 points
- Simulation: 500000 deployment scenarios, 0 failures
- Result: PASS

## Checks

|Check|Points|Result|Evidence|
|---|---:|---|---|
|publish root configured|7|PASS|Netlify publish root|
|functions directory configured|7|PASS|Netlify functions path|
|no build dependency|7|PASS|buildless static deploy|
|security headers present|8|PASS|baseline headers|
|content security policy present|8|PASS|CSP and frame policy|
|permissions policy present|5|PASS|browser permissions locked down|
|function method guard|7|PASS|POST-only function|
|function JSON guard|7|PASS|invalid JSON handling|
|function key isolation|7|PASS|environment key only|
|function upstream failure handling|7|PASS|upstream error path|
|app function path matches|7|PASS|client calls deployed function path|
|keyless app fallback|7|PASS|no-key deploy still works|
|manifest deploy ready|4|PASS|manifest linked|
|relative asset paths|4|PASS|static asset paths|
|deployment scenario simulation|8|PASS|500000 scenarios, 0 failures|

## Limits

- This is a no-cost local preflight audit for files that will be deployed.
- It does not replace Netlify deploy logs, production function logs, DNS checks, or public URL browser QA.
- External account actions remain documented separately when a connector or login is unavailable.
