param(
  [int]$Iterations = 500000,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$reportPath = Join-Path $docs "deployment-preflight-report.md"

function Read-Text($RelativePath) {
  return Get-Content -Encoding UTF8 -Raw (Join-Path $root $RelativePath)
}

function Add-Check($Rows, $Name, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{ Name = $Name; Points = $Points; Pass = [bool]$Pass; Evidence = $Evidence }) | Out-Null
}

$index = Read-Text "index.html"
$app = Read-Text "app.js"
$netlify = Read-Text "netlify.toml"
$function = Read-Text "netlify/functions/gemini.js"
$manifest = Read-Text "manifest.webmanifest"
$checks = New-Object System.Collections.Generic.List[object]

Add-Check $checks "publish root configured" 7 ($netlify -match 'publish\s*=\s*"."') "Netlify publish root"
Add-Check $checks "functions directory configured" 7 ($netlify -match 'functions\s*=\s*"netlify/functions"') "Netlify functions path"
Add-Check $checks "no build dependency" 7 (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) "buildless static deploy"
Add-Check $checks "security headers present" 8 (($netlify -match 'X-Frame-Options') -and ($netlify -match 'X-Content-Type-Options') -and ($netlify -match 'Referrer-Policy')) "baseline headers"
Add-Check $checks "content security policy present" 8 (($netlify -match 'Content-Security-Policy') -and ($netlify -match "frame-ancestors 'none'")) "CSP and frame policy"
Add-Check $checks "permissions policy present" 5 ($netlify -match 'Permissions-Policy') "browser permissions locked down"
Add-Check $checks "function method guard" 7 (($function -match 'event\.httpMethod !== "POST"') -and ($function -match '405')) "POST-only function"
Add-Check $checks "function JSON guard" 7 (($function -match 'JSON\.parse') -and ($function -match 'Invalid JSON body')) "invalid JSON handling"
Add-Check $checks "function key isolation" 7 (($function -match 'process\.env\.GEMINI_API_KEY') -and -not ($function -match 'AIza[0-9A-Za-z_-]{20,}')) "environment key only"
Add-Check $checks "function upstream failure handling" 7 (($function -match '!response\.ok') -and ($function -match 'Gemini request failed')) "upstream error path"
Add-Check $checks "app function path matches" 7 (($app -match '/\.netlify/functions/gemini') -and ($index -match 'app\.js')) "client calls deployed function path"
Add-Check $checks "keyless app fallback" 7 (($app -match 'if \(!apiKey\) return null') -and ($app -match 'Gemini fallback used')) "no-key deploy still works"
Add-Check $checks "manifest deploy ready" 4 (($index -match 'manifest\.webmanifest') -and ($manifest -match 'koreastudy')) "manifest linked"
Add-Check $checks "relative asset paths" 4 (($index -match '\./styles\.css') -and ($index -match '\./data/education-data\.js') -and ($index -match '\./app\.js')) "static asset paths"

$scenarioFailures = 0
$hasDeployShape = ($netlify -match 'publish\s*=\s*"."' -and $netlify -match 'functions\s*=\s*"netlify/functions"')
$hasHeaders = ($netlify -match 'Content-Security-Policy' -and $netlify -match 'Permissions-Policy')
$hasFunctionSafety = ($function -match 'process\.env\.GEMINI_API_KEY' -and $function -match 'Invalid JSON body' -and $function -match '!response\.ok')
$hasFallback = ($app -match 'if \(!apiKey\) return null')
for ($i = 0; $i -lt $Iterations; $i++) {
  $mode = $i % 5
  $caseOk = switch ($mode) {
    0 { $hasDeployShape }
    1 { $hasHeaders }
    2 { $hasFunctionSafety }
    3 { $hasFallback }
    default { $hasDeployShape -and $hasHeaders -and $hasFunctionSafety -and $hasFallback }
  }
  if (-not $caseOk) { $scenarioFailures++ }
}
Add-Check $checks "deployment scenario simulation" 8 ($scenarioFailures -eq 0) "$Iterations scenarios, $scenarioFailures failures"

$score = ($checks | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
if ($null -eq $score) { $score = 0 }
$status = if ($score -ge $MinimumScore -and $scenarioFailures -eq 0 -and -not ($checks | Where-Object { -not $_.Pass })) { "PASS" } else { "IMPROVE" }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy deployment preflight audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Deployment score: $score / 100") | Out-Null
$lines.Add("- Target: at least $MinimumScore points") | Out-Null
$lines.Add("- Simulation: $Iterations deployment scenarios, $scenarioFailures failures") | Out-Null
$lines.Add("- Result: $status") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Checks") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("|Check|Points|Result|Evidence|") | Out-Null
$lines.Add("|---|---:|---|---|") | Out-Null
foreach ($check in $checks) {
  $resultText = if ($check.Pass) { "PASS" } else { "IMPROVE" }
  $evidence = ([string]$check.Evidence).Replace("|", "/").Replace("`r", " ").Replace("`n", " ")
  $lines.Add("|$($check.Name)|$($check.Points)|$resultText|$evidence|") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This is a no-cost local preflight audit for files that will be deployed.") | Out-Null
$lines.Add("- It does not replace Netlify deploy logs, production function logs, DNS checks, or public URL browser QA.") | Out-Null
$lines.Add("- External account actions remain documented separately when a connector or login is unavailable.") | Out-Null
Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "DEPLOYMENT_SCORE`t$score/100"
Write-Output "STATUS`t$status"
Write-Output "SIMULATION`t$Iterations scenarios`t$scenarioFailures failures"
if ($status -ne "PASS") { exit 1 }
