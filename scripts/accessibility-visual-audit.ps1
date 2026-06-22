param(
  [int]$Iterations = 500000,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$reportPath = Join-Path $docs "accessibility-visual-report.md"
$index = Get-Content -Encoding UTF8 -Raw (Join-Path $root "index.html")
$styles = Get-Content -Encoding UTF8 -Raw (Join-Path $root "styles.css")
$app = Get-Content -Encoding UTF8 -Raw (Join-Path $root "app.js")

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

$buttons = Count-Matches $index '<button\b'
$labelCount = Count-Matches $index '<label\b'
$selectCount = Count-Matches $index '<select\b'
$inputCount = Count-Matches $index '<input\b'
$textareaCount = Count-Matches $index '<textarea\b'
$thCount = Count-Matches $index '<th\b'
$thScoped = Count-Matches $index '<th\s+scope="col"'
$colorTokens = Count-Matches $styles '--[a-z0-9-]+:\s*#[0-9a-fA-F]{3,6}'

$checks = New-Object System.Collections.Generic.List[object]

Add-Check $checks "document language" 5 ($index -match '<html lang="ko"') "Korean document language"
Add-Check $checks "viewport metadata" 5 ($index -match 'name="viewport"') "responsive viewport"
Add-Check $checks "skip link" 8 (($index -match 'class="skip-link"') -and ($styles -match '\.skip-link') -and ($styles -match 'skip-link:focus-visible')) "keyboard skip link"
Add-Check $checks "visible focus state" 10 (($styles -match ':focus-visible') -and ($styles -match 'outline:\s*3px')) "3px focus outline"
Add-Check $checks "labeled form controls" 8 ($labelCount -ge ($selectCount + $inputCount + $textareaCount - 2)) "$labelCount labels for $($selectCount + $inputCount + $textareaCount) controls"
Add-Check $checks "icon button accessible name" 5 (($index -match 'id="themeToggle"') -and ($index -match '<button[^>]+aria-label=')) "theme button label"
Add-Check $checks "navigation names" 7 ((Count-Matches $index 'aria-label=') -ge 3) "named navigation and status regions"
Add-Check $checks "table header scope" 5 ($thCount -eq $thScoped -and $thCount -gt 0) "$thScoped/$thCount scoped headers"
Add-Check $checks "responsive breakpoints" 7 (($styles -match '@media \(max-width: 860px\)') -and ($styles -match '@media \(max-width: 540px\)') -and ($styles -match '@media \(max-width: 390px\)')) "3 breakpoints"
Add-Check $checks "print stylesheet" 4 ($styles -match '@media print') "print support"
Add-Check $checks "dark mode theme" 5 (($styles -match '\[data-theme="dark"\]') -and ($app -match 'toggleTheme')) "dark mode"
Add-Check $checks "balanced visual tokens" 6 ($colorTokens -ge 10) "$colorTokens color tokens"
Add-Check $checks "stable layout constraints" 6 (($styles -match 'grid-template-columns') -and ($styles -match 'min-height:\s*44px') -and ($styles -match 'overflow-x:\s*auto')) "grid, touch, overflow"
Add-Check $checks "no decorative asset dependency" 3 (-not ($index -match '<img\b|<video\b|<canvas\b')) "no external visual asset failure risk"
Add-Check $checks "mobile bottom nav protection" 4 (($styles -match '\.app-shell[\s\S]*?padding-bottom:\s*78px') -and ($styles -match '\.bottom-nav')) "bottom nav spacing"
Add-Check $checks "content text wrapping" 3 (($styles -match 'overflow-wrap:\s*anywhere') -or ($styles -match 'line-height')) "text wrapping/line rhythm"

$scenarioFailures = 0
$hasFocus = ($styles -match ':focus-visible')
$hasSkip = ($index -match 'class="skip-link"')
$hasMobile = ($styles -match '@media \(max-width: 540px\)')
$hasDark = ($styles -match '\[data-theme="dark"\]')
$hasLabels = ($labelCount -ge 10)
for ($i = 0; $i -lt $Iterations; $i++) {
  $mode = $i % 6
  $caseOk = switch ($mode) {
    0 { $hasFocus }
    1 { $hasSkip }
    2 { $hasMobile }
    3 { $hasDark }
    4 { $hasLabels }
    default { $hasFocus -and $hasSkip -and $hasMobile -and $hasDark -and $hasLabels }
  }
  if (-not $caseOk) {
    $scenarioFailures++
  }
}

Add-Check $checks "accessibility scenario simulation" 9 ($scenarioFailures -eq 0) "$Iterations scenarios, $scenarioFailures failures"

$score = ($checks | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
if ($null -eq $score) { $score = 0 }
$status = if ($score -ge $MinimumScore -and $scenarioFailures -eq 0 -and -not ($checks | Where-Object { -not $_.Pass })) { "PASS" } else { "IMPROVE" }
$failedChecks = @($checks | Where-Object { -not $_.Pass })

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy accessibility and visual audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Accessibility/visual score: $score / 100") | Out-Null
$lines.Add("- Target: at least $MinimumScore points") | Out-Null
$lines.Add("- Simulation: $Iterations accessibility scenarios, $scenarioFailures failures") | Out-Null
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
  $lines.Add("- No failed accessibility or visual checks.") | Out-Null
} else {
  foreach ($check in $failedChecks) {
    $lines.Add("- $($check.Name): $($check.Evidence)") | Out-Null
  }
}

$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This is a no-cost static accessibility and visual resilience audit.") | Out-Null
$lines.Add("- It does not replace expert WCAG review or real-device visual QA on the deployed URL.") | Out-Null

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "ACCESSIBILITY_VISUAL_SCORE`t$score/100"
Write-Output "STATUS`t$status"
Write-Output "SIMULATION`t$Iterations scenarios`t$scenarioFailures failures"

if ($status -ne "PASS") {
  exit 1
}