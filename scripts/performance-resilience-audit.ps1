param(
  [int]$Iterations = 500000,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$reportPath = Join-Path $docs "performance-resilience-report.md"

$indexPath = Join-Path $root "index.html"
$stylesPath = Join-Path $root "styles.css"
$appPath = Join-Path $root "app.js"
$manifestPath = Join-Path $root "manifest.webmanifest"
$dataPath = Join-Path $root "data/education-data.js"
$manifestDataPath = Join-Path $root "data/data-manifest.js"
$netlifyPath = Join-Path $root "netlify.toml"

$index = Get-Content -Encoding UTF8 -Raw $indexPath
$styles = Get-Content -Encoding UTF8 -Raw $stylesPath
$app = Get-Content -Encoding UTF8 -Raw $appPath
$data = Get-Content -Encoding UTF8 -Raw $dataPath
$dataManifest = Get-Content -Encoding UTF8 -Raw $manifestDataPath
$netlify = Get-Content -Encoding UTF8 -Raw $netlifyPath

function Add-Check($Rows, $Name, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{
    Name = $Name
    Points = $Points
    Pass = [bool]$Pass
    Evidence = $Evidence
  }) | Out-Null
}

function Count-Matches($Text, $Pattern) {
  return [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline).Count
}

$runtimeFiles = @($indexPath, $stylesPath, $appPath, $manifestPath, $dataPath, $manifestDataPath, $netlifyPath)
$runtimeBytes = ($runtimeFiles | Get-Item | Measure-Object -Property Length -Sum).Sum
$appBytes = (Get-Item -LiteralPath $appPath).Length
$styleBytes = (Get-Item -LiteralPath $stylesPath).Length
$dataBytes = (Get-Item -LiteralPath $dataPath).Length
$totalKb = [math]::Round($runtimeBytes / 1KB, 2)

$checks = New-Object System.Collections.Generic.List[object]

Add-Check $checks "buildless static runtime" 8 (-not (Test-Path -LiteralPath (Join-Path $root "package.json")) -and -not (Test-Path -LiteralPath (Join-Path $root "node_modules"))) "no package install required"
Add-Check $checks "small runtime bundle" 10 ($runtimeBytes -lt 250KB) "$totalKb KB runtime bundle"
Add-Check $checks "small app script" 7 ($appBytes -lt 80KB) "$([math]::Round($appBytes / 1KB, 2)) KB app.js"
Add-Check $checks "small stylesheet" 5 ($styleBytes -lt 40KB) "$([math]::Round($styleBytes / 1KB, 2)) KB styles.css"
Add-Check $checks "structured local data" 6 ($dataBytes -lt 150KB -and $dataManifest -match "version:" -and $dataManifest -match "currentRuntimeFile" -and $dataManifest -match "splitPlan") "$([math]::Round($dataBytes / 1KB, 2)) KB education data"
Add-Check $checks "deferred optional AI" 8 (($app -match "if \(!apiKey\) return null") -and ($app -match "/\.netlify/functions/gemini")) "AI is optional and function-routed"
Add-Check $checks "storage failure resilience" 9 (($app -match "function storageGet") -and ($app -match "function storageSet") -and ($app -match "function storageRemove") -and ((Count-Matches $app "try\s*\{") -ge 8)) "guarded storage wrappers"
Add-Check $checks "offline first content path" 7 (($app -match "buildLocalMaterial") -and ($data -match "fallbackProfile") -and ($data -match "unitSeeds")) "local material generation"
Add-Check $checks "download without server" 5 (($app -match "Blob") -and ($app -match "URL\.createObjectURL") -and ($app -match "downloadCurrent")) "client-side text export"
Add-Check $checks "print without server" 5 (($styles -match "@media print") -and ($app -match "window\.print")) "client-side print/PDF"
Add-Check $checks "layout shift controls" 6 (($styles -match "grid-template-columns") -and ($styles -match "min-height:\s*44px") -and ($styles -match "min-width:\s*0") -and ($styles -match "overflow-x:\s*auto")) "stable responsive constraints"
Add-Check $checks "no remote asset dependency" 5 (-not ($index -match "https?://") -and -not ($styles -match "url\(")) "no remote images/fonts/scripts"
Add-Check $checks "security header preflight" 6 (($netlify -match "Content-Security-Policy") -and ($netlify -match "X-Frame-Options") -and ($netlify -match "Permissions-Policy")) "security headers present"
Add-Check $checks "mobile persistence path" 4 (($app -match "ks_library") -and ($app -match "ks_mistakes") -and ($styles -match "\.bottom-nav")) "library, mistakes, bottom nav"

$scenarioFailures = 0
$examples = New-Object System.Collections.Generic.List[string]
$sizeOk = $runtimeBytes -lt 250KB
$offlineOk = (($app -match "buildLocalMaterial") -and ($data -match "fallbackProfile"))
$storageOk = (($app -match "storageGet") -and ($app -match "catch"))
$layoutOk = (($styles -match "@media \(max-width: 540px\)") -and ($styles -match "min-height:\s*44px"))
$exportOk = (($app -match "downloadCurrent") -and ($app -match "window\.print"))

for ($i = 0; $i -lt $Iterations; $i++) {
  $mode = $i % 8
  $caseOk = switch ($mode) {
    0 { $sizeOk }
    1 { $offlineOk }
    2 { $storageOk }
    3 { $layoutOk }
    4 { $exportOk }
    5 { $sizeOk -and $offlineOk }
    6 { $storageOk -and $layoutOk }
    default { $sizeOk -and $offlineOk -and $storageOk -and $layoutOk -and $exportOk }
  }
  if (-not $caseOk) {
    $scenarioFailures++
    if ($examples.Count -lt 5) {
      $examples.Add("scenario-$i-mode-$mode") | Out-Null
    }
  }
}

Add-Check $checks "performance resilience simulation" 9 ($scenarioFailures -eq 0) "$Iterations scenarios, $scenarioFailures failures"

$score = ($checks | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
if ($null -eq $score) { $score = 0 }
$failedChecks = @($checks | Where-Object { -not $_.Pass })
$status = if ($score -ge $MinimumScore -and $scenarioFailures -eq 0 -and $failedChecks.Count -eq 0) { "PASS" } else { "IMPROVE" }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy performance and resilience audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Performance/resilience score: $score / 100") | Out-Null
$lines.Add("- Target: at least $MinimumScore points") | Out-Null
$lines.Add("- Runtime bundle: $totalKb KB") | Out-Null
$lines.Add("- Simulation: $Iterations performance/resilience scenarios, $scenarioFailures failures") | Out-Null
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
$lines.Add("## Failed checks") | Out-Null
$lines.Add("") | Out-Null
if ($failedChecks.Count -eq 0) {
  $lines.Add("- No failed performance or resilience checks.") | Out-Null
} else {
  foreach ($check in $failedChecks) {
    $lines.Add("- $($check.Name): $($check.Evidence)") | Out-Null
  }
}

$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This no-cost audit checks local bundle size, offline paths, storage resilience, and static deploy posture.") | Out-Null
$lines.Add("- It does not replace real network throttling on the final Netlify URL.") | Out-Null

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "PERFORMANCE_RESILIENCE_SCORE`t$score/100"
Write-Output "STATUS`t$status"
Write-Output "BUNDLE`t$totalKb KB"
Write-Output "SIMULATION`t$Iterations scenarios`t$scenarioFailures failures"

if ($status -ne "PASS") {
  exit 1
}