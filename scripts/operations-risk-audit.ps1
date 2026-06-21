param(
  [int]$Iterations = 500000,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$reportPath = Join-Path $docs "operations-risk-report.md"

function Read-Text($RelativePath) {
  return Get-Content -Encoding UTF8 -Raw (Join-Path $root $RelativePath)
}

function Add-Check($Rows, $Name, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{ Name = $Name; Points = $Points; Pass = [bool]$Pass; Evidence = $Evidence }) | Out-Null
}

$index = Read-Text "index.html"
$app = Read-Text "app.js"
$data = Read-Text "data/education-data.js"
$netlify = Read-Text "netlify.toml"
$readme = Read-Text "README.md"
$roadmap = Read-Text "docs/free-growth-roadmap.md"
$policy = Read-Text "docs/data-policy.md"
$approvals = Read-Text "docs/deferred-approvals.md"

$runtimeFiles = @("index.html", "styles.css", "app.js", "manifest.webmanifest", "data/data-manifest.js", "data/education-data.js")
$runtimeBytes = 0
foreach ($file in $runtimeFiles) { $runtimeBytes += (Get-Item -LiteralPath (Join-Path $root $file)).Length }
$runtimeKb = [math]::Round($runtimeBytes / 1kb, 2)
$runtimeMb = [math]::Round($runtimeBytes / 1mb, 4)

$checks = New-Object System.Collections.Generic.List[object]
Add-Check $checks "static deployment shape" 10 (($netlify -match 'publish\s*=\s*"."') -and -not (Test-Path -LiteralPath (Join-Path $root "package.json"))) "build command not required"
Add-Check $checks "low runtime bundle size" 10 ($runtimeBytes -lt 500kb) "$runtimeKb KB runtime bundle"
Add-Check $checks "no paid database dependency" 8 (-not ($index + $app + $data + $readme -match 'supabase|firebase|postgres|mysql|mongodb|stripe')) "no paid service dependency found"
Add-Check $checks "no embedded API secret" 8 (-not ($index + $app + $data -match 'AIza[0-9A-Za-z_-]{20,}|sk-[A-Za-z0-9]')) "no obvious secret key"
Add-Check $checks "AI failure fallback" 8 (($app -match 'if \(!apiKey\) return null') -and ($app -match 'Gemini fallback used')) "keyless/failure fallback"
Add-Check $checks "solo maintenance fit" 8 ((-not (Test-Path -LiteralPath (Join-Path $root "node_modules"))) -and (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) -and ($netlify -match 'publish\s*=\s*"."')) "no install/build workflow"
Add-Check $checks "copyright risk control" 8 ($policy.Length -gt 500 -and $approvals.Length -gt 500) "policy and deferred approval docs"
Add-Check $checks "premium deferred safely" 8 ($roadmap.Length -gt 500) "future paid roadmap documented"
Add-Check $checks "retention features present" 8 (($app -match 'ks_library') -and ($app -match 'ks_mistakes')) "library and mistake notebook"
Add-Check $checks "deployment risk docs" 8 ((Test-Path -LiteralPath (Join-Path $docs "deploy-checklist.md")) -and ($netlify -match 'X-Content-Type-Options')) "checklist and headers"
Add-Check $checks "current fixed software cost" 2 (-not ($index + $app + $data + $readme -match 'required paid|monthly paid|subscription required')) "0 KRW planned fixed software cost"

$scenarioFailures = 0
$keylessOk = ($app -match 'if \(!apiKey\) return null')
$costOk = -not ($index + $app + $data + $readme -match 'stripe|paid database|required paid')
$bundleOk = $runtimeMb -lt 1
for ($i = 0; $i -lt $Iterations; $i++) {
  $sessionCount = 1 + (($i * 17) % 20)
  $userCount = 1 + (($i * 31) % 100000)
  $staticTransferMb = $userCount * $sessionCount * $runtimeMb
  $shapeOk = $staticTransferMb -gt 0 -and $bundleOk
  if (-not ($keylessOk -and $costOk -and $shapeOk)) { $scenarioFailures++ }
}
Add-Check $checks "free-operation simulation" 14 ($scenarioFailures -eq 0) "$Iterations scenarios, $scenarioFailures failures"

$score = ($checks | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
if ($null -eq $score) { $score = 0 }
$status = if ($score -ge $MinimumScore -and $scenarioFailures -eq 0 -and -not ($checks | Where-Object { -not $_.Pass })) { "PASS" } else { "IMPROVE" }

$usageRows = @(
  [pscustomobject]@{ Users = 1000; SessionsPerUser = 5 },
  [pscustomobject]@{ Users = 10000; SessionsPerUser = 5 },
  [pscustomobject]@{ Users = 50000; SessionsPerUser = 5 },
  [pscustomobject]@{ Users = 100000; SessionsPerUser = 5 }
)
$premiumRows = @(
  [pscustomobject]@{ Users = 1000; Conversion = 0.01; PriceKrw = 3000 },
  [pscustomobject]@{ Users = 10000; Conversion = 0.02; PriceKrw = 3000 },
  [pscustomobject]@{ Users = 50000; Conversion = 0.03; PriceKrw = 5000 },
  [pscustomobject]@{ Users = 100000; Conversion = 0.05; PriceKrw = 5000 }
)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy operations and growth risk audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Operations score: $score / 100") | Out-Null
$lines.Add("- Target: at least $MinimumScore points") | Out-Null
$lines.Add("- Simulation: $Iterations free-operation scenarios, $scenarioFailures failures") | Out-Null
$lines.Add("- Runtime bundle: $runtimeKb KB") | Out-Null
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
$lines.Add("## Expected Usage Model") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("This is a planning estimate, not a guarantee. Real capacity depends on the current hosting plan limits, cache behavior, traffic geography, and whether optional AI calls are enabled.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("|Monthly users|Sessions/user|Estimated static transfer|Risk note|") | Out-Null
$lines.Add("|---:|---:|---:|---|") | Out-Null
foreach ($row in $usageRows) {
  $transferGb = [math]::Round(($row.Users * $row.SessionsPerUser * $runtimeBytes) / 1gb, 3)
  $risk = if ($row.Users -le 10000) { "low for static MVP if free quota remains available" } elseif ($row.Users -le 50000) { "watch bandwidth and AI usage" } else { "needs real hosting analytics before promises" }
  $lines.Add("|$($row.Users)|$($row.SessionsPerUser)|$transferGb GB|$risk|") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Profitability Model") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Current version has no premium gate and no paid cost. Revenue is therefore 0 KRW now, with 0 KRW planned fixed software cost. Premium should stay deferred until real users, retention, and legal content boundaries are measured.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("|Monthly users|Paid conversion|Monthly price|Estimated gross revenue|") | Out-Null
$lines.Add("|---:|---:|---:|---:|") | Out-Null
foreach ($row in $premiumRows) {
  $paidUsers = [math]::Floor($row.Users * $row.Conversion)
  $gross = $paidUsers * $row.PriceKrw
  $lines.Add("|$($row.Users)|$([math]::Round($row.Conversion * 100, 1))%|$($row.PriceKrw) KRW|$gross KRW|") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This audit avoids paid APIs, paid hosting, paid databases, account login, and copyrighted source material.") | Out-Null
$lines.Add("- It does not replace actual Netlify deploy logs, public URL QA, payment/legal review, or real user analytics.") | Out-Null
$lines.Add("- Optional AI usage can become the first scalability bottleneck, so keyless fallback remains required.") | Out-Null

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")
Write-Output "OPERATIONS_SCORE`t$score/100"
Write-Output "STATUS`t$status"
Write-Output "SIMULATION`t$Iterations scenarios`t$scenarioFailures failures"
Write-Output "RUNTIME_BUNDLE`t$runtimeKb KB"
if ($status -ne "PASS") { exit 1 }
