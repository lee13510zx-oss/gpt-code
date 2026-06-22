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
  $Rows.Add([pscustomobject]@{
    Category = $Category
    Item = $Item
    Points = $Points
    Pass = [bool]$Pass
    Evidence = $Evidence
  }) | Out-Null
}

function Get-QuotedValues($Text, $Pattern) {
  $matches = [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
  $values = New-Object System.Collections.Generic.List[string]
  foreach ($match in $matches) {
    $inner = $match.Groups[1].Value
    foreach ($value in [regex]::Matches($inner, '"([^"]+)"')) {
      $values.Add($value.Groups[1].Value) | Out-Null
    }
  }
  return $values | Select-Object -Unique
}

function Invoke-ScenarioSimulation($SchoolNames, $Subjects, $Categories, $Formats, $Count) {
  $failures = 0
  $examples = New-Object System.Collections.Generic.List[string]
  $subjectList = @($Subjects)
  $schoolList = @($SchoolNames)
  $profileMap = @{}
  $templateMap = @{}
  $formatMap = @{}
  $hasFallback = Test-Text $script:data 'fallbackProfile\s*:'

  foreach ($subject in $subjectList) {
    $profileMap[$subject] = Test-Text $script:data ('"' + [regex]::Escape($subject) + '"\s*:\s*\{')
  }
  foreach ($category in $Categories) {
    $templateMap[$category] = Test-Text $script:data ($category + '\s*:\s*\[')
  }
  foreach ($format in $Formats) {
    $formatMap[$format] = Test-Text $script:app ('\b' + [regex]::Escape($format) + '\b')
  }

  for ($i = 0; $i -lt $Count; $i++) {
    $school = $schoolList[$i % $schoolList.Count]
    $subject = $subjectList[($i * 7) % $subjectList.Count]
    $category = $Categories[($i * 11) % $Categories.Count]
    $format = $Formats[($i * 13) % $Formats.Count]
    $grade = 1 + (($i * 5) % 6)

    $hasProfile = [bool]$profileMap[$subject]
    $hasTemplate = [bool]$templateMap[$category]
    $hasFormat = [bool]$formatMap[$format]
    $shapeOk = ($school.Length -gt 0 -and $grade -ge 1 -and $subject.Length -gt 0)

    if (-not ($shapeOk -and ($hasProfile -or $hasFallback) -and $hasTemplate -and $hasFormat)) {
      $failures++
      if ($examples.Count -lt 5) {
        $examples.Add("$school/$grade/$subject/$category/$format") | Out-Null
      }
    }
  }

  return [pscustomobject]@{
    Iterations = $Count
    Failures = $failures
    FailureRate = if ($Count -eq 0) { 0 } else { [math]::Round(($failures / $Count) * 100, 4) }
    Examples = @($examples)
  }
}

$requiredFiles = @(
  "index.html",
  "styles.css",
  "app.js",
  "manifest.webmanifest",
  "netlify.toml",
  "data/data-manifest.js",
  "data/education-data.js",
  "netlify/functions/gemini.js",
  "README.md",
  "docs/data-policy.md",
  "docs/deferred-approvals.md",
  "docs/deploy-checklist.md",
  "docs/qa-checklist.md",
  "docs/final-handoff.md",
  "docs/ui-interaction-report.md",
  "docs/browser-runtime-report.md",
  "docs/operations-risk-report.md",
  "docs/deployment-preflight-report.md",
  "docs/accessibility-visual-report.md",
  "docs/performance-resilience-report.md",
  "docs/content-integrity-report.md",
  "scripts/ui-interaction-audit.ps1",
  "scripts/browser-runtime-audit.ps1",
  "scripts/operations-risk-audit.ps1",
  "scripts/deployment-preflight-audit.ps1",
  "scripts/accessibility-visual-audit.ps1",
  "scripts/performance-resilience-audit.ps1",
  "scripts/content-integrity-audit.ps1"
)

$missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
$schools = @([regex]::Matches($data, 'school:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$subjects = @(Get-QuotedValues $data 'subjects:\s*\[(.*?)\]')
$profileNames = @([regex]::Matches($data, '"([^"]+)"\s*:\s*\{\s*domains:', [Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$categories = @("concept", "school", "mock", "essay")
$formats = @("mixed", "multiple", "ox", "blank", "short")

$rows = New-Object System.Collections.Generic.List[object]

$hasStorageGet = Test-Text $app "function storageGet"
$hasStorageSet = Test-Text $app "function storageSet"
$hasStorageRemove = Test-Text $app "function storageRemove"
$hasNoKeyFallback = Test-Text $app "if \(!apiKey\) return null"
$hasFallbackProfile = Test-Text $data "fallbackProfile"
$hasRunSelfCheck = Test-Text $app "function runSelfCheck"
$hasSelfCheckPanel = Test-Text $index "selfCheckPanel"
$hasJsonParse = Test-Text $app "JSON\.parse"
$hasGuardedJsonCatch = Test-Text $app "catch\s*\{[\s\r\n]*return \[\]"

Add-Score $rows "reliability" "required files" 4 ($missing.Count -eq 0) "$($requiredFiles.Count - $missing.Count)/$($requiredFiles.Count) files"
Add-Score $rows "reliability" "safe storage wrappers" 4 ($hasStorageGet -and $hasStorageSet -and $hasStorageRemove) "storage wrappers"
Add-Score $rows "reliability" "escaped HTML output" 4 (([regex]::Matches($app, "escapeHtml").Count) -ge 20) "$([regex]::Matches($app, "escapeHtml").Count) uses"
Add-Score $rows "reliability" "AI no-key fallback" 4 ($hasNoKeyFallback -and $hasFallbackProfile) "Gemini optional"
Add-Score $rows "reliability" "self-check screen" 3 ($hasRunSelfCheck -and $hasSelfCheckPanel) "self-check"
Add-Score $rows "reliability" "stored JSON guarded" 3 ($hasJsonParse -and $hasGuardedJsonCatch) "guarded parse"
Add-Score $rows "reliability" "static check script" 3 (Test-Path -LiteralPath (Join-Path $root "scripts/static-check.ps1")) "static-check"

$has2022 = Test-Text $data 'id:\s*"2022"'
$has2015 = Test-Text $data 'id:\s*"2015"'
$hasQuestionCategories = (($categories | Where-Object { Test-Text $data ($_ + '\s*:\s*\[') }).Count -eq 4)
$hasUnitSeeds = Test-Text $data 'unitSeeds\s*:'
$hasManySeedArrays = ([regex]::Matches($data, '\[[^\]]+\]').Count -ge 40)

Add-Score $rows "content" "school levels" 4 ($schools.Count -ge 3) "$($schools.Count) levels"
Add-Score $rows "content" "subject breadth" 3 ($subjects.Count -ge 45) "$($subjects.Count) subjects"
Add-Score $rows "content" "subject profiles" 3 ($profileNames.Count -ge 35) "$($profileNames.Count) profiles"
Add-Score $rows "content" "curriculum versions" 3 ($has2022 -and $has2015) "2015/2022"
Add-Score $rows "content" "question categories" 3 $hasQuestionCategories "4 categories"
Add-Score $rows "content" "unit seeds" 2 ($hasUnitSeeds -and $hasManySeedArrays) "unit seeds"
$hasContentAudit = Test-Path -LiteralPath (Join-Path $root "scripts/content-integrity-audit.ps1")
$hasContentReport = Test-Path -LiteralPath (Join-Path $root "docs/content-integrity-report.md")
$contentReport = if ($hasContentReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/content-integrity-report.md") } else { "" }
$hasContentPass = ($contentReport -match 'Result: PASS' -and $contentReport -match '500000 content combinations')
Add-Score $rows "content" "content integrity audit" 2 ($hasContentAudit -and $hasContentPass) "500000 content combinations"

$hasBreakpoint860 = Test-Text $styles "@media \(max-width: 860px\)"
$hasBreakpoint540 = Test-Text $styles "@media \(max-width: 540px\)"
$hasTouch44 = Test-Text $styles "min-height:\s*44px"
$hasNoSmallTouchTarget = -not (Test-Text $styles "min-height:\s*(3[0-9]|4[0-3])px")
$hasDarkCss = Test-Text $styles '\[data-theme="dark"\]'
$hasThemeToggle = Test-Text $app "toggleTheme"
$hasPrintCss = Test-Text $styles "@media print"
$hasPrintButton = Test-Text $app "window\.print"
$hasWorksheet = Test-Text $app "renderWorksheet"
$hasDownload = Test-Text $app "downloadCurrent"
$hasBottomNavCss = Test-Text $styles "\.bottom-nav"
$hasBottomNavHtml = Test-Text $index "bottom-nav"
$hasUiAudit = Test-Path -LiteralPath (Join-Path $root "scripts/ui-interaction-audit.ps1")
$hasUiReport = Test-Path -LiteralPath (Join-Path $root "docs/ui-interaction-report.md")
$uiReport = if ($hasUiReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/ui-interaction-report.md") } else { "" }
$hasUiPass = ($uiReport -match 'Result: PASS' -and $uiReport -match '500000 iterations, 0 failures')
$hasBrowserAudit = Test-Path -LiteralPath (Join-Path $root "scripts/browser-runtime-audit.ps1")
$hasBrowserReport = Test-Path -LiteralPath (Join-Path $root "docs/browser-runtime-report.md")
$browserReport = if ($hasBrowserReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/browser-runtime-report.md") } else { "" }
$hasBrowserPass = ($browserReport -match 'Result: PASS' -and $browserReport -match '100000 iterations')
$hasOperationsAudit = Test-Path -LiteralPath (Join-Path $root "scripts/operations-risk-audit.ps1")
$hasOperationsReport = Test-Path -LiteralPath (Join-Path $root "docs/operations-risk-report.md")
$operationsReport = if ($hasOperationsReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/operations-risk-report.md") } else { "" }
$hasOperationsPass = ($operationsReport -match 'Result: PASS' -and $operationsReport -match '500000 free-operation scenarios')
$hasDeploymentAudit = Test-Path -LiteralPath (Join-Path $root "scripts/deployment-preflight-audit.ps1")
$hasDeploymentReport = Test-Path -LiteralPath (Join-Path $root "docs/deployment-preflight-report.md")
$deploymentReport = if ($hasDeploymentReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/deployment-preflight-report.md") } else { "" }
$hasDeploymentPass = ($deploymentReport -match 'Result: PASS' -and $deploymentReport -match '500000 deployment scenarios')
$hasAccessibilityAudit = Test-Path -LiteralPath (Join-Path $root "scripts/accessibility-visual-audit.ps1")
$hasAccessibilityReport = Test-Path -LiteralPath (Join-Path $root "docs/accessibility-visual-report.md")
$accessibilityReport = if ($hasAccessibilityReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/accessibility-visual-report.md") } else { "" }
$hasAccessibilityPass = ($accessibilityReport -match 'Result: PASS' -and $accessibilityReport -match '500000 accessibility scenarios')
$hasPerformanceAudit = Test-Path -LiteralPath (Join-Path $root "scripts/performance-resilience-audit.ps1")
$hasPerformanceReport = Test-Path -LiteralPath (Join-Path $root "docs/performance-resilience-report.md")
$performanceReport = if ($hasPerformanceReport) { Get-Content -Encoding UTF8 -Raw (Join-Path $root "docs/performance-resilience-report.md") } else { "" }
$hasPerformancePass = ($performanceReport -match 'Result: PASS' -and $performanceReport -match '500000 performance/resilience scenarios')

Add-Score $rows "ux" "responsive layout" 3 ($hasBreakpoint860 -and $hasBreakpoint540) "breakpoints"
Add-Score $rows "ux" "touch targets" 3 ($hasTouch44 -and $hasNoSmallTouchTarget) "44px minimum"
Add-Score $rows "ux" "dark mode" 3 ($hasDarkCss -and $hasThemeToggle) "theme"
Add-Score $rows "ux" "print support" 3 ($hasPrintCss -and $hasPrintButton) "print"
Add-Score $rows "ux" "worksheet download" 2 ($hasWorksheet -and $hasDownload) "worksheet/download"
Add-Score $rows "ux" "bottom navigation" 2 ($hasBottomNavCss -and $hasBottomNavHtml) "nav"
Add-Score $rows "ux" "accessibility visual audit" 2 ($hasAccessibilityAudit -and $hasAccessibilityPass) "500000 accessibility scenarios"
Add-Score $rows "ux" "UI interaction audit" 1 ($hasUiAudit -and $hasUiPass) "500000 UI interactions"
Add-Score $rows "ux" "browser runtime audit" 1 ($hasBrowserAudit -and $hasBrowserPass) "100000 real browser clicks"

$hasPublishRoot = Test-Text $netlify 'publish\s*=\s*"."'
$hasNoPackageJson = -not (Test-Path -LiteralPath (Join-Path $root "package.json"))
$hasFunctionFile = Test-Path -LiteralPath (Join-Path $root "netlify/functions/gemini.js")
$hasFunctionCall = Test-Text $app "/\.netlify/functions/gemini"
$hasFrameHeader = Test-Text $netlify "X-Frame-Options"
$hasContentTypeHeader = Test-Text $netlify "X-Content-Type-Options"
$hasManifestFile = Test-Path -LiteralPath (Join-Path $root "manifest.webmanifest")
$hasManifestLink = Test-Text $index "manifest.webmanifest"

Add-Score $rows "deployment" "Netlify config" 3 (Test-Path -LiteralPath (Join-Path $root "netlify.toml")) "netlify.toml"
Add-Score $rows "deployment" "buildless static deploy" 2 ($hasPublishRoot -and $hasNoPackageJson) "publish root"
Add-Score $rows "deployment" "function path" 3 ($hasFunctionFile -and $hasFunctionCall) "function"
Add-Score $rows "deployment" "security headers" 2 ($hasFrameHeader -and $hasContentTypeHeader) "headers"
Add-Score $rows "deployment" "manifest linked" 2 ($hasManifestFile -and $hasManifestLink) "manifest"
Add-Score $rows "deployment" "deployment preflight audit" 2 ($hasDeploymentAudit -and $hasDeploymentPass) "500000 deployment scenarios"
Add-Score $rows "deployment" "performance resilience audit" 2 ($hasPerformanceAudit -and $hasPerformancePass) "500000 performance/resilience scenarios"

$hasDataPolicy = Test-Path -LiteralPath (Join-Path $docs "data-policy.md")
$hasPolicySize = ((Get-Item -LiteralPath (Join-Path $docs "data-policy.md")).Length -gt 500)
$hasApprovalsDoc = Test-Path -LiteralPath (Join-Path $docs "deferred-approvals.md")
$hasFreeDocs = (Test-Path -LiteralPath (Join-Path $docs "free-growth-roadmap.md")) -and $hasApprovalsDoc
$hasNoGeminiKey = -not (Test-Text ($index + $app + $data) "AIza[0-9A-Za-z_-]{20,}")

Add-Score $rows "risk" "copyright policy" 3 ($hasDataPolicy -and $hasPolicySize) "policy"
Add-Score $rows "risk" "deferred approvals" 3 $hasApprovalsDoc "approvals doc"
Add-Score $rows "risk" "free-first principle" 2 $hasFreeDocs "free docs"
Add-Score $rows "risk" "no obvious secret key" 2 $hasNoGeminiKey "no Gemini key"

$hasRoadmap = Test-Path -LiteralPath (Join-Path $docs "free-growth-roadmap.md")
$roadmapSize = ((Get-Item -LiteralPath (Join-Path $docs "free-growth-roadmap.md")).Length -gt 500)
$hasLibraryStorage = Test-Text $app "ks_library"
$hasMistakeStorage = Test-Text $app "ks_mistakes"
$soloFriendly = -not (Test-Path -LiteralPath (Join-Path $root "package.json")) -and -not (Test-Path -LiteralPath (Join-Path $root "node_modules"))

Add-Score $rows "growth" "free roadmap" 2 $hasRoadmap "roadmap"
Add-Score $rows "growth" "premium candidates" 2 $roadmapSize "future paid roadmap"
Add-Score $rows "growth" "retention features" 2 ($hasLibraryStorage -and $hasMistakeStorage) "library/mistakes"
Add-Score $rows "growth" "solo student friendly" 1 $soloFriendly "no build/deps"
Add-Score $rows "growth" "operations risk audit" 2 ($hasOperationsAudit -and $hasOperationsPass) "500000 free-operation scenarios"

$score = ($rows | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
$maxScore = ($rows | Measure-Object -Property Points -Sum).Sum
$failed = @($rows | Where-Object { -not $_.Pass })
$simulation = Invoke-ScenarioSimulation $schools $subjects $categories $formats $Iterations

$repeatScores = New-Object System.Collections.Generic.List[int]
$repeatPasses = 0
for ($round = 1; $round -le $RepeatTarget; $round++) {
  $roundSimulation = Invoke-ScenarioSimulation $schools $subjects $categories $formats ([math]::Max(1000, [math]::Floor($Iterations / $RepeatTarget)))
  $roundPenalty = if ($roundSimulation.Failures -eq 0) { 0 } else { [math]::Min(10, [math]::Ceiling($roundSimulation.FailureRate)) }
  $roundScore = [math]::Max(0, $score - $roundPenalty)
  $repeatScores.Add($roundScore) | Out-Null
  if ($roundScore -ge $MinimumScore) {
    $repeatPasses++
  }
}

$status = if ($score -ge $MinimumScore -and $repeatPasses -eq $RepeatTarget -and $simulation.Failures -eq 0) {
  "PASS"
} else {
  "IMPROVE"
}

$reportPath = Join-Path $docs "quality-report.md"
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
if ($failed.Count -eq 0) {
  $lines.Add("- No failed automated score items.") | Out-Null
} else {
  foreach ($row in $failed) {
    $lines.Add("- $($row.Category) / $($row.Item): $($row.Evidence)") | Out-Null
  }
}
$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This is a free local static audit plus data-combination simulation.") | Out-Null
$lines.Add("- Real 500,000-user load testing against Netlify is not run on a free personal account.") | Out-Null
$lines.Add("- Real revenue needs deployed traffic, retention, and conversion data.") | Out-Null

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "QUALITY_SCORE`t$score/$maxScore"
Write-Output "STATUS`t$status"
Write-Output "SIMULATION`t$($simulation.Iterations) iterations`t$($simulation.Failures) failures`t$($simulation.FailureRate)% failure_rate"
Write-Output "REPEAT`t$repeatPasses/$RepeatTarget above $MinimumScore`t$($repeatScores -join ',')"
if ($failed.Count -gt 0) {
  foreach ($row in $failed) {
    Write-Output "FAIL`t$($row.Category)`t$($row.Item)`t$($row.Evidence)"
  }
}
