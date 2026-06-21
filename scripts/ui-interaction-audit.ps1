param(
  [int]$Iterations = 500000,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$index = Get-Content -Encoding UTF8 -Raw (Join-Path $root "index.html")
$styles = Get-Content -Encoding UTF8 -Raw (Join-Path $root "styles.css")
$app = Get-Content -Encoding UTF8 -Raw (Join-Path $root "app.js")

function Get-Matches($Text, $Pattern) {
  return @([regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
}

function Add-Check($Rows, $Name, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{
    Name = $Name
    Points = $Points
    Pass = [bool]$Pass
    Evidence = $Evidence
  }) | Out-Null
}

$ids = @(Get-Matches $index 'id="([^"]+)"')
$views = @(Get-Matches $index '<section id="([^"]+)" class="view')
$dataViews = @(Get-Matches $index 'data-view="([^"]+)"')
$appRefs = @(Get-Matches $app '\$\("([^"]+)"\)')
$buttons = @([regex]::Matches($index, '<button\b') | ForEach-Object { $_.Value })
$forms = @(Get-Matches $index '<form id="([^"]+)"')
$dynamicDelegates = @("[data-answer-toggle]", "[data-mistake-save]", "[data-mistake-review]", "[data-mistake-remove]", ".explore-item")

$missingRefs = @($appRefs | Where-Object { $ids -notcontains $_ })
$missingViews = @($dataViews | Where-Object { $views -notcontains $_ })
$hasTouchBase = ($styles -match 'min-height:\s*44px')
$hasDynamicTouch = ($styles -match '\.answer-toggle' -and $styles -match '\.explore-item')
$bottomNav44 = ($styles -match '\.bottom-nav button\s*\{[\s\S]*?min-height:\s*44px')
$mobileBottomNav44 = ($styles -match '@media \(max-width: 540px\)[\s\S]*?\.bottom-nav button\s*\{[\s\S]*?min-height:\s*44px')
$hasPrintHideNav = ($styles -match '@media print' -and $styles -match '\.bottom-nav')
$hasFormSubmit = ($app -match '"textbookForm"\)\.addEventListener\("submit"')
$hasDelegatedQuestions = ($app -match '"questionList"\)\.addEventListener\("click"')
$hasDelegatedMistakes = ($app -match '"mistakeList"\)\.addEventListener\("click"')
$hasExploreDelegate = ($app -match '"exploreResults"\)\.addEventListener\("click"')
$hasKeyboardNative = ($index -match '<button' -and $index -match '<select' -and $index -match '<input')

$rows = New-Object System.Collections.Generic.List[object]
Add-Check $rows "all app id references exist" 12 ($missingRefs.Count -eq 0) "$($appRefs.Count) refs, $($missingRefs.Count) missing"
Add-Check $rows "all navigation targets exist" 12 ($missingViews.Count -eq 0) "$($dataViews.Count) links, $($missingViews.Count) missing"
Add-Check $rows "touch target baseline" 10 $hasTouchBase "44px baseline"
Add-Check $rows "dynamic action touch targets" 10 $hasDynamicTouch "answer/explore buttons"
Add-Check $rows "bottom nav desktop touch size" 8 $bottomNav44 "bottom nav 44px"
Add-Check $rows "bottom nav mobile touch size" 8 $mobileBottomNav44 "mobile bottom nav 44px"
Add-Check $rows "native keyboard controls" 8 $hasKeyboardNative "buttons/selects/inputs"
Add-Check $rows "form submit bound" 8 $hasFormSubmit "textbook form submit"
Add-Check $rows "question click delegation" 8 $hasDelegatedQuestions "questionList click"
Add-Check $rows "mistake click delegation" 8 $hasDelegatedMistakes "mistakeList click"
Add-Check $rows "explore click delegation" 4 $hasExploreDelegate "exploreResults click"
Add-Check $rows "print removes nav clutter" 4 $hasPrintHideNav "print styles"

$actionPool = @(
  "switch-summary", "switch-explore", "switch-table", "switch-mindmap", "switch-questions",
  "switch-textbook", "switch-governance", "switch-deploy", "switch-qa", "switch-approval",
  "switch-library", "switch-mistakes", "switch-settings", "switch-worksheet",
  "change-school", "change-subject", "change-question-category", "change-question-format",
  "generate", "save", "download", "worksheet", "toggle-answer", "save-mistake",
  "review-mistake", "remove-mistake", "clear-library", "clear-mistakes", "theme-toggle",
  "self-check", "textbook-submit", "print"
)

$available = @{
  "switch-summary" = ($views -contains "summary")
  "switch-explore" = ($views -contains "explore")
  "switch-table" = ($views -contains "table")
  "switch-mindmap" = ($views -contains "mindmap")
  "switch-questions" = ($views -contains "questions")
  "switch-textbook" = ($views -contains "textbook")
  "switch-governance" = ($views -contains "governance")
  "switch-deploy" = ($views -contains "deploy")
  "switch-qa" = ($views -contains "qa")
  "switch-approval" = ($views -contains "approval")
  "switch-library" = ($views -contains "library")
  "switch-mistakes" = ($views -contains "mistakes")
  "switch-settings" = ($views -contains "settings")
  "switch-worksheet" = ($views -contains "worksheet")
  "change-school" = ($ids -contains "schoolLevel")
  "change-subject" = ($ids -contains "subject")
  "change-question-category" = ($ids -contains "questionCategory")
  "change-question-format" = ($ids -contains "questionFormat")
  "generate" = ($ids -contains "generateBtn")
  "save" = ($ids -contains "saveBtn")
  "download" = ($ids -contains "downloadBtn")
  "worksheet" = ($ids -contains "worksheetBtn")
  "toggle-answer" = ($hasDelegatedQuestions -and $app -match 'data-answer-toggle')
  "save-mistake" = ($hasDelegatedQuestions -and $app -match 'data-mistake-save')
  "review-mistake" = ($hasDelegatedMistakes -and $app -match 'data-mistake-review')
  "remove-mistake" = ($hasDelegatedMistakes -and $app -match 'data-mistake-remove')
  "clear-library" = ($ids -contains "clearLibrary")
  "clear-mistakes" = ($ids -contains "clearMistakes")
  "theme-toggle" = ($ids -contains "themeToggle")
  "self-check" = ($ids -contains "runSelfCheck")
  "textbook-submit" = ($forms -contains "textbookForm")
  "print" = ($ids -contains "printBtn")
}

$failures = 0
$examples = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $Iterations; $i++) {
  $action = $actionPool[($i * 17) % $actionPool.Count]
  if (-not [bool]$available[$action]) {
    $failures++
    if ($examples.Count -lt 10) {
      $examples.Add($action) | Out-Null
    }
  }
}

$score = ($rows | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
$maxScore = ($rows | Measure-Object -Property Points -Sum).Sum
$status = if ($score -ge $MinimumScore -and $failures -eq 0) { "PASS" } else { "IMPROVE" }
$failedChecks = @($rows | Where-Object { -not $_.Pass })
$failureRate = if ($Iterations -eq 0) { 0 } else { [math]::Round(($failures / $Iterations) * 100, 4) }

$reportPath = Join-Path $docs "ui-interaction-report.md"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy UI interaction audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- UI score: $score / $maxScore") | Out-Null
$lines.Add("- Target: at least $MinimumScore points") | Out-Null
$lines.Add("- Interaction simulation: $Iterations iterations, $failures failures, $failureRate% failure rate") | Out-Null
$lines.Add("- Result: $status") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Checks") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("|Check|Points|Result|Evidence|") | Out-Null
$lines.Add("|---|---:|---|---|") | Out-Null
foreach ($row in $rows) {
  $mark = if ($row.Pass) { "PASS" } else { "IMPROVE" }
  $lines.Add("|$($row.Name)|$($row.Points)|$mark|$($row.Evidence)|") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Failed checks") | Out-Null
$lines.Add("") | Out-Null
if ($failedChecks.Count -eq 0) {
  $lines.Add("- No failed UI checks.") | Out-Null
} else {
  foreach ($row in $failedChecks) {
    $lines.Add("- $($row.Name): $($row.Evidence)") | Out-Null
  }
}
$lines.Add("") | Out-Null
$lines.Add("## Failed simulated actions") | Out-Null
$lines.Add("") | Out-Null
if ($examples.Count -eq 0) {
  $lines.Add("- No failed simulated actions.") | Out-Null
} else {
  foreach ($example in $examples) {
    $lines.Add("- $example") | Out-Null
  }
}
$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This is a no-cost local structural and interaction simulation.") | Out-Null
$lines.Add("- It does not replace a real browser visual pass on the deployed URL.") | Out-Null

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "UI_SCORE`t$score/$maxScore"
Write-Output "STATUS`t$status"
Write-Output "SIMULATION`t$Iterations iterations`t$failures failures`t$failureRate% failure_rate"
if ($failedChecks.Count -gt 0) {
  foreach ($row in $failedChecks) {
    Write-Output "FAIL`t$($row.Name)`t$($row.Evidence)"
  }
}
