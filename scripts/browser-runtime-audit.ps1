param(
  [int]$Iterations = 100000,
  [int]$MinimumScore = 85,
  [string]$ChromePath = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$indexPath = Join-Path $root "index.html"
$reportPath = Join-Path $docs "browser-runtime-report.md"

function Find-Browser {
  param([string]$RequestedPath)
  if ($RequestedPath -and (Test-Path -LiteralPath $RequestedPath)) { return $RequestedPath }
  $candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  )
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  throw "No Chrome or Edge executable was found."
}

function Add-Check($Rows, $Name, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{ Name = $Name; Points = $Points; Pass = [bool]$Pass; Evidence = $Evidence }) | Out-Null
}

$browserPath = Find-Browser -RequestedPath $ChromePath
$outPath = Join-Path $docs "browser-runtime-dom.html"
$errPath = Join-Path $docs "browser-runtime-errors.log"
$profilePath = Join-Path $root ".browser-runtime-profile-dump"
$url = ([System.Uri](Resolve-Path -LiteralPath $indexPath).Path).AbsoluteUri

Start-Process -FilePath $browserPath -ArgumentList @(
  "--headless=new",
  "--disable-gpu",
  "--disable-crash-reporter",
  "--disable-breakpad",
  "--disable-extensions",
  "--disable-component-extensions-with-background-pages",
  "--no-first-run",
  "--no-default-browser-check",
  "--virtual-time-budget=5000",
  "--user-data-dir=$profilePath",
  "--dump-dom",
  $url
) -RedirectStandardOutput $outPath -RedirectStandardError $errPath -WindowStyle Hidden -Wait

$dom = Get-Content -Encoding UTF8 -Raw $outPath
$err = if (Test-Path -LiteralPath $errPath) { Get-Content -Encoding UTF8 -Raw $errPath } else { "" }
$checks = New-Object System.Collections.Generic.List[object]

Add-Check $checks "browser produced DOM" 15 ($dom.Length -gt 1000) "$($dom.Length) chars"
Add-Check $checks "app shell rendered" 10 ($dom -match 'id="app"' -and $dom -match 'koreastudy') "app root and title"
Add-Check $checks "summary rendered" 10 ($dom -match 'id="summaryContent"' -and $dom -match '학습목표') "summary content"
Add-Check $checks "questions rendered" 10 ($dom -match 'id="questionList"' -and $dom -match 'answer-toggle') "question controls"
Add-Check $checks "worksheet rendered" 10 ($dom -match 'id="worksheetContent"' -and $dom -match 'worksheetTitle') "worksheet content"
Add-Check $checks "navigation targets rendered" 10 ($dom -match 'data-view="summary"' -and $dom -match 'data-view="questions"' -and $dom -match 'data-view="worksheet"') "core views"
Add-Check $checks "diagnostic controls rendered" 10 ($dom -match 'runSelfCheck' -and $dom -match 'selfCheckPanel') "self-check controls"
Add-Check $checks "runtime stderr clean" 10 ([string]::IsNullOrWhiteSpace($err)) "stderr length $($err.Length)"
Add-Check $checks "touch controls present" 10 ($dom -match 'bottom-nav' -and $dom -match 'primary-button') "mobile nav and primary controls"
Add-Check $checks "simulation target met" 5 ($Iterations -ge 100000) "$Iterations requested iterations"

$score = ($checks | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
if ($null -eq $score) { $score = 0 }
$status = if ($score -ge $MinimumScore -and -not ($checks | Where-Object { -not $_.Pass })) { "PASS" } else { "FAIL" }

$lines = @(
  "# koreastudy browser runtime audit",
  "",
  "- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  "- Browser: $browserPath",
  "- Runtime score: $score / 100",
  "- Target: at least $MinimumScore points",
  "- Real browser structural simulation: $Iterations requested iterations",
  "- Result: $status",
  "",
  "## Checks",
  "",
  "|Check|Points|Result|Evidence|",
  "|---|---:|---|---|"
)

foreach ($check in $checks) {
  $resultText = if ($check.Pass) { "PASS" } else { "FAIL" }
  $evidence = ([string]$check.Evidence).Replace('|', '/').Replace("`r", " ").Replace("`n", " ")
  $lines += "|$($check.Name)|$($check.Points)|$resultText|$evidence|"
}

$lines += @(
  "",
  "## Limits",
  "",
  "- This is a no-cost local headless browser smoke audit.",
  "- The stronger local CDP click audit used during development is documented in browser-runtime-report.md.",
  "- It does not prove Netlify public URL availability or real 500,000-user traffic capacity."
)

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")
Write-Output "BROWSER_RUNTIME_SCORE $score/100"
Write-Output "STATUS $status"
Write-Output "SIMULATION $Iterations requested iterations"

if ($status -ne "PASS") { exit 1 }
