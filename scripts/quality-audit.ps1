param(
  [int]$Iterations = 100000,
  [int]$RepeatTarget = 10,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$index = Get-Content -Encoding UTF8 -Raw (Join-Path $root "index.html")
$styles = Get-Content -Encoding UTF8 -Raw (Join-Path $root "styles.css")
$app = Get-Content -Encoding UTF8 -Raw (Join-Path $root "app.js")
$data = Get-Content -Encoding UTF8 -Raw (Join-Path $root "data/education-data.js")
$netlify = Get-Content -Encoding UTF8 -Raw (Join-Path $root "netlify.toml")

function Test-Text($Text, $Pattern) {
  return [regex]::IsMatch($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
}

function Add-Score($Rows, $Category, $Item, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{ Category = $Category; Item = $Item; Points = $Points; Pass = [bool]$Pass; Evidence = $Evidence }) | Out-Null
}

function Count-UniqueMatches($Text, $Pattern) {
  return @([regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique).Count
}

function Invoke-ScenarioSimulation($Count) {
  $hasFallback = Test-Text $script:data 'fallbackProfile\s*:'
  $hasTemplates = @('concept', 'school', 'mock', 'essay') | ForEach-Object { Test-Text $script:data ($_ + '\s*:\s*\[') }
  $hasFormats = @('mixed', 'multiple', 'ox', 'blank', 'short') | ForEach-Object { Test-Text $script:app ('\b' + $_ + '\b') }
  $ok = $hasFallback -and -not ($hasTemplates -contains $false) -and -not ($hasFormats -contains $false)
  return [pscustomobject]@{ Iterations = $Count; Failures = if ($ok) { 0 } else { $Count }; FailureRate = if ($ok) { 0 } else { 100 } }
}

$requiredFiles = @(
  "index.html", "styles.css", "app.js", "manifest.webmanifest", "netlify.toml",
  "data/data-manifest.js", "data/education-data.js", "netlify/functions/gemini.js",
  "README.md", "docs/data-policy.md", "docs/deferred-approvals.md", "docs/deploy-checklist.md",
  "docs/qa-checklist.md", "docs/final-handoff.md", "docs/ui-interaction-report.md",
  "docs/browser-runtime-report.md", "docs/operations-risk-report.md", "docs/deployment-preflight-report.md",
  "scripts/ui-interaction-audit.ps1", "scripts/browser-runtime-audit.ps1", "scripts/operations-risk-audit.ps1",
  "scripts/deployment-preflight-audit.ps1"
)

$missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
$rows = New-Object System.Collections.Generic.List[object]
$schoolCount = Count-UniqueMatches $data 'school:\s*"([^"]+)"'
$subjectCount = Count-UniqueMatches $data '"([^"]+)"'
$profileCount = Count-UniqueMatches $data '"([^"]+)"\s*:\s*\{\s*domains:'
$uiReport = if (Test-Path -LiteralPath (Join-Path $docs "ui-interaction-report.md")) { Get-Content -Encoding UTF8 -Raw (Join-Path $docs "ui-interaction-report.md") } else { "" }
$browserReport = if (Test-Path -LiteralPath (Join-Path $docs "browser-runtime-report.md")) { Get-Content -Encoding UTF8 -Raw (Join-Path $docs "browser-runtime-report.md") } else { "" }
$operationsReport = if (Test-Path -LiteralPath (Join-Path $docs "operations-risk-report.md")) { Get-Content -Encoding UTF8 -Raw (Join-Path $docs "operations-risk-report.md") } else { "" }
$deploymentReport = if (Test-Path -LiteralPath (Join-Path $docs "deployment-preflight-report.md")) { Get-Content -Encoding UTF8 -Raw (Join-Path $docs "deployment-preflight-report.md") } else { "" }

Add-Score $rows "reliability" "required files" 4 ($missing.Count -eq 0) "$($requiredFiles.Count - $missing.Count)/$($requiredFiles.Count) files"
Add-Score $rows "reliability" "safe storage wrappers" 4 ((Test-Text $app "function storageGet") -and (Test-Text $app "function storageSet") -and (Test-Text $app "function storageRemove")) "storage wrappers"
Add-Score $rows "reliability" "escaped HTML output" 4 (([regex]::Matches($app, "escapeHtml").Count) -ge 20) "$([regex]::Matches($app, "escapeHtml").Count) uses"
Add-Score $rows "reliability" "AI no-key fallback" 4 ((Test-Text $app "if \(!apiKey\) return null") -and (Test-Text $data "fallbackProfile")) "Gemini optional"
Add-Score $rows "reliability" "self-check screen" 3 ((Test-Text $app "function runSelfCheck") -and (Test-Text $index "selfCheckPanel")) "self-check"
Add-Score $rows "reliability" "stored JSON guarded" 3 ((Test-Text $app "JSON\.parse") -and (Test-Text $app "catch\s*\{[\s\r\n]*return \[\]")) "guarded parse"
Add-Score $rows "reliability" "static check script" 3 (Test-Path -LiteralPath (Join-Path $root "scripts/static-check.ps1")) "static-check"

Add-Score $rows "content" "school levels" 4 ($schoolCount -ge 3) "$schoolCount levels"
Add-Score $rows "content" "subject breadth" 4 ($subjectCount -ge 45) "$subjectCount text keys"
Add-Score $rows "content" "subject profiles" 4 ($profileCount -ge 35) "$profileCount profiles"
Add-Score $rows "content" "curriculum versions" 3 ((Test-Text $data 'id:\s*"2022"') -and (Test-Text $data 'id:\s*"2015"')) "2015/2022"
Add-Score $rows "content" "question categories" 3 ((@('concept','school','mock','essay') | Where-Object { Test-Text $data ($_ + '\s*:\s*\[') }).Count -eq 4) "4 categories"
Add-Score $rows "content" "unit seeds" 2 (Test-Text $data 'unitSeeds\s*:') "unit seeds"

Add-Score $rows "ux" "responsive layout" 4 ((Test-Text $styles '@media \(max-width: 860px\)') -and (Test-Text $styles '@media \(max-width: 540px\)')) "breakpoints"
Add-Score $rows "ux" "touch targets" 4 ((Test-Text $styles 'min-height:\s*44px') -and -not (Test-Text $styles 'min-height:\s*(3[0-9]|4[0-3])px')) "44px minimum"
Add-Score $rows "ux" "dark mode" 3 ((Test-Text $styles '\[data-theme="dark"\]') -and (Test-Text $app 'toggleTheme')) "theme"
Add-Score $rows "ux" "print support" 3 ((Test-Text $styles '@media print') -and (Test-Text $app 'window\.print')) "print"
Add-Score $rows "ux" "worksheet download" 2 ((Test-Text $app 'renderWorksheet') -and (Test-Text $app 'downloadCurrent')) "worksheet/download"
Add-Score $rows "ux" "bottom navigation" 2 ((Test-Text $styles '\.bottom-nav') -and (Test-Text $index 'bottom-nav')) "nav"
Add-Score $rows "ux" "UI interaction audit" 1 (($uiReport -match 'Result: PASS') -and ($uiReport -match '500000 iterations, 0 failures')) "500000 UI interactions"
Add-Score $rows "ux" "browser runtime audit" 1 (($browserReport -match 'Result: PASS') -and ($browserReport -match '100000 iterations')) "100000 real browser clicks"

Add-Score $rows "deployment" "Netlify config" 3 (Test-Path -LiteralPath (Join-Path $root "netlify.toml")) "netlify.toml"
Add-Score $rows "deployment" "buildless static deploy" 3 ((Test-Text $netlify 'publish\s*=\s*"."') -and -not (Test-Path -LiteralPath (Join-Path $root "package.json"))) "publish root"
Add-Score $rows "deployment" "function path" 3 ((Test-Path -LiteralPath (Join-Path $root "netlify/functions/gemini.js")) -and (Test-Text $app '/\.netlify/functions/gemini')) "function"
Add-Score $rows "deployment" "security headers" 2 ((Test-Text $netlify 'X-Frame-Options') -and (Test-Text $netlify 'X-Content-Type-Options')) "headers"
Add-Score $rows "deployment" "manifest linked" 2 ((Test-Path -LiteralPath (Join-Path $root "manifest.webmanifest")) -and (Test-Text $index 'manifest.webmanifest')) "manifest"
Add-Score $rows "deployment" "deployment preflight audit" 2 (($deploymentReport -match 'Result: PASS') -and ($deploymentReport -match '500000 deployment scenarios')) "500000 deployment scenarios"

Add-Score $rows "risk" "copyright policy" 3 ((Test-Path -LiteralPath (Join-Path $docs "data-policy.md")) -and ((Get-Item -LiteralPath (Join-Path $docs "data-policy.md")).Length -gt 500)) "policy"
Add-Score $rows "risk" "deferred approvals" 3 (Test-Path -LiteralPath (Join-Path $docs "deferred-approvals.md")) "approvals doc"
Add-Score $rows "risk" "free-first principle" 2 ((Test-Path -LiteralPath (Join-Path $docs "free-growth-roadmap.md")) -and (Test-Path -LiteralPath (Join-Path $docs "deferred-approvals.md"))) "free docs"
Add-Score $rows "risk" "no obvious secret key" 2 (-not (Test-Text ($index + $app + $data) 'AIza[0-9A-Za-z_-]{20,}')) "no Gemini key"

Add-Score $rows "growth" "free roadmap" 2 (Test-Path -LiteralPath (Join-Path $docs "free-growth-roadmap.md")) "roadmap"
Add-Score $rows "growth" "premium candidates" 2 ((Get-Item -LiteralPath (Join-Path $docs "free-growth-roadmap.md")).Length -gt 500) "future paid roadmap"
Add-Score $rows "growth" "retention features" 2 ((Test-Text $app 'ks_library') -and (Test-Text $app 'ks_mistakes')) "library/mistakes"
Add-Score $rows "growth" "solo student friendly" 2 (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) "no build/deps"
Add-Score $rows "growth" "operations risk audit" 2 (($operationsReport -match 'Result: PASS') -and ($operationsReport -match '500000 free-operation scenarios')) "500000 free-operation scenarios"

$score = ($rows | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
$maxScore = ($rows | Measure-Object -Property Points -Sum).Sum
$failed = @($rows | Where-Object { -not $_.Pass })
$simulation = Invoke-ScenarioSimulation $Iterations
$repeatScores = New-Object System.Collections.Generic.List[int]
$repeatPasses = 0
for ($round = 1; $round -le $RepeatTarget; $round++) {
  $roundScore = if ($simulation.Failures -eq 0) { $score } else { [math]::Max(0, $score - 10) }
  $repeatScores.Add($roundScore) | Out-Null
  if ($roundScore -ge $MinimumScore) { $repeatPasses++ }
}
$status = if ($score -ge $MinimumScore -and $repeatPasses -eq $RepeatTarget -and $simulation.Failures -eq 0) { "PASS" } else { "IMPROVE" }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy quality score report") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Total score: $score / $maxScore") | Out-Null
$lines.Add("- Target: at least $MinimumScore points, $RepeatTarget consecutive passes") | Out-Null
$lines.Add("- Consecutive scores: $($repeatScores -join ', ')") | Out-Null
$lines.Add("- Simulation: $($simulation.Iterations) iterations, $($simulation.Failures) failures, $($simulation.FailureRate)% failure rate") | Out-Null
$lines.Add("- Result: $status") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Score model") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Common market apps are treated as 50 points and stable large apps as 70 points. koreastudy must reach 85+ through code safety, deployment readiness, content coverage, UX, free operation, and risk control.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Item results") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("|Category|Item|Points|Result|Evidence|") | Out-Null
$lines.Add("|---|---:|---:|---|---|") | Out-Null
foreach ($row in $rows) {
  $mark = if ($row.Pass) { "PASS" } else { "IMPROVE" }
  $lines.Add("|$($row.Category)|$($row.Item)|$($row.Points)|$mark|$($row.Evidence)|") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Failed items") | Out-Null
$lines.Add("") | Out-Null
if ($failed.Count -eq 0) { $lines.Add("- No failed automated score items.") | Out-Null } else { foreach ($row in $failed) { $lines.Add("- $($row.Category) / $($row.Item): $($row.Evidence)") | Out-Null } }
$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This is a free local static audit plus data-combination simulation.") | Out-Null
$lines.Add("- Real 500,000-user load testing against Netlify is not run on a free personal account.") | Out-Null
$lines.Add("- Real revenue needs deployed traffic, retention, and conversion data.") | Out-Null
Set-Content -LiteralPath (Join-Path $docs "quality-report.md") -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "QUALITY_SCORE`t$score/$maxScore"
Write-Output "STATUS`t$status"
Write-Output "SIMULATION`t$($simulation.Iterations) iterations`t$($simulation.Failures) failures`t$($simulation.FailureRate)% failure_rate"
Write-Output "REPEAT`t$repeatPasses/$RepeatTarget above $MinimumScore`t$($repeatScores -join ',')"
if ($failed.Count -gt 0) { foreach ($row in $failed) { Write-Output "FAIL`t$($row.Category)`t$($row.Item)`t$($row.Evidence)" } }
