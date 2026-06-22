param(
  [int]$Iterations = 500000,
  [int]$MinimumScore = 85
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$reportPath = Join-Path $docs "content-integrity-report.md"

$index = Get-Content -Encoding UTF8 -Raw (Join-Path $root "index.html")
$app = Get-Content -Encoding UTF8 -Raw (Join-Path $root "app.js")
$data = Get-Content -Encoding UTF8 -Raw (Join-Path $root "data/education-data.js")
$policy = Get-Content -Encoding UTF8 -Raw (Join-Path $docs "data-policy.md")

function Add-Check($Rows, $Name, $Points, $Pass, $Evidence) {
  $Rows.Add([pscustomobject]@{
    Name = $Name
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
  return @($values | Select-Object -Unique)
}

function Count-Matches($Text, $Pattern) {
  return [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline).Count
}

$schools = @([regex]::Matches($data, 'school:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$subjects = @(Get-QuotedValues $data 'subjects:\s*\[(.*?)\]')
$profileNames = @([regex]::Matches($data, '"([^"]+)"\s*:\s*\{\s*domains:', [Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$curricula = @([regex]::Matches($data, 'id:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$categories = @("concept", "school", "mock", "essay")
$formats = @("mixed", "multiple", "ox", "blank", "short")
$templateCount = Count-Matches $data 'difficulty:\s*"[^"]+"\s*,\s*prompt:\s*"[^"]+"\s*,\s*answer:\s*"[^"]+"'
$unitArrayCount = Count-Matches $data '"[^"]+"\s*:\s*\[[^\]]+\]'
$domainArrayCount = Count-Matches $data 'domains:\s*\[[^\]]+\]'
$focusArrayCount = Count-Matches $data 'focus:\s*\[[^\]]+\]'
$summaryCount = Count-Matches $data 'summary:\s*"[^"]+"'
$formulaCount = Count-Matches $data 'formula:\s*"[^"]+"'
$categoryTemplateCoverage = @($categories | Where-Object { $data -match ($_ + '\s*:\s*\[\s*\{') })
$formatCoverage = @($formats | Where-Object { $app -match ('\b' + [regex]::Escape($_) + '\b') })
$directProfileCoverage = @($subjects | Where-Object {
  $subject = $_
  $normalized = $subject -replace '[\u2160\u2161\u2162]', ''
  ($profileNames -contains $subject) -or ($profileNames -contains $normalized)
})
$profileMap = @{}
$unitMap = @{}
$categoryMap = @{}
$formatMap = @{}
foreach ($subject in $subjects) {
  $normalized = $subject -replace '[\u2160\u2161\u2162]', ''
  $profileMap[$subject] = (($profileNames -contains $subject) -or ($profileNames -contains $normalized))
  $unitMap[$subject] = (($data -match [regex]::Escape($subject)) -or ($data -match [regex]::Escape($normalized)))
}
foreach ($category in $categories) {
  $categoryMap[$category] = $data -match ($category + '\s*:\s*\[')
}
foreach ($format in $formats) {
  $formatMap[$format] = $app -match ('\b' + [regex]::Escape($format) + '\b')
}

$checks = New-Object System.Collections.Generic.List[object]

Add-Check $checks "school catalog breadth" 8 ($schools.Count -ge 3 -and $subjects.Count -ge 45) "$($schools.Count) school levels, $($subjects.Count) subjects"
Add-Check $checks "curriculum coverage" 6 (($curricula -contains "2022") -and ($curricula -contains "2015")) "$($curricula -join ', ')"
Add-Check $checks "direct subject profile coverage" 8 ($directProfileCoverage.Count -ge 40) "$($directProfileCoverage.Count)/$($subjects.Count) subjects with direct profiles"
Add-Check $checks "fallback profile safety" 7 (($data -match "fallbackProfile") -and ($data -match "domains:\s*\[") -and ($data -match "focus:\s*\[")) "fallback profile fields"
Add-Check $checks "profile field completeness" 8 ($domainArrayCount -ge 40 -and $focusArrayCount -ge 40 -and $summaryCount -ge 40 -and $formulaCount -ge 40) "$domainArrayCount domains, $focusArrayCount focus, $summaryCount summaries, $formulaCount formulas"
Add-Check $checks "unit seed breadth" 8 ($unitArrayCount -ge 40 -and $data -match "unitSeeds") "$unitArrayCount unit/array seeds"
Add-Check $checks "question category coverage" 8 ($categoryTemplateCoverage.Count -eq 4) "$($categoryTemplateCoverage.Count)/4 categories"
Add-Check $checks "question template richness" 7 ($templateCount -ge 12) "$templateCount templates with difficulty/prompt/answer"
Add-Check $checks "question format coverage" 5 ($formatCoverage.Count -eq 5) "$($formatCoverage.Count)/5 formats"
Add-Check $checks "generated material sections" 7 (($app -match "goal") -and ($app -match "table") -and ($app -match "mindmap") -and ($app -match "questions")) "goal, table, mindmap, questions"
Add-Check $checks "copyright-safe data posture" 6 (($policy -match "GEMINI_API_KEY") -and ($policy -match "data/education-data.js") -and ($data -match "dataGovernance") -and ($data -match "finalApprovals")) "policy and governance warnings"
Add-Check $checks "user input guarded into output" 5 ((Count-Matches $app "escapeHtml") -ge 20 -and ($app -match "userText")) "$(Count-Matches $app "escapeHtml") escapeHtml references"
Add-Check $checks "self-check content checks" 4 (($app -match "questionTemplates") -and ($app -match "subjectProfiles") -and ($app -match "unitSeeds")) "runtime self-check data keys"

$scenarioFailures = 0
$examples = New-Object System.Collections.Generic.List[string]
$hasFallback = $data -match "fallbackProfile"
$hasUnits = $data -match "unitSeeds"
$hasTemplates = $categoryTemplateCoverage.Count -eq 4
$hasFormats = $formatCoverage.Count -eq 5
$hasEscaping = (Count-Matches $app "escapeHtml") -ge 20

for ($i = 0; $i -lt $Iterations; $i++) {
  $school = $schools[$i % $schools.Count]
  $subject = $subjects[($i * 7) % $subjects.Count]
  $category = $categories[($i * 11) % $categories.Count]
  $format = $formats[($i * 13) % $formats.Count]
  $grade = 1 + (($i * 5) % 6)
  $hasProfile = [bool]$profileMap[$subject] -or $hasFallback
  $shapeOk = $school.Length -gt 0 -and $subject.Length -gt 0 -and $grade -ge 1
  $categoryOk = [bool]$categoryMap[$category]
  $formatOk = [bool]$formatMap[$format]
  $unitOk = $hasUnits -and ([bool]$unitMap[$subject] -or $hasFallback)

  if (-not ($shapeOk -and $hasProfile -and $unitOk -and $categoryOk -and $formatOk -and $hasTemplates -and $hasFormats -and $hasEscaping)) {
    $scenarioFailures++
    if ($examples.Count -lt 5) {
      $examples.Add("$school/$grade/$subject/$category/$format") | Out-Null
    }
  }
}

Add-Check $checks "content combination simulation" 13 ($scenarioFailures -eq 0) "$Iterations scenarios, $scenarioFailures failures"

$score = ($checks | Where-Object { $_.Pass } | Measure-Object -Property Points -Sum).Sum
if ($null -eq $score) { $score = 0 }
$failedChecks = @($checks | Where-Object { -not $_.Pass })
$status = if ($score -ge $MinimumScore -and $scenarioFailures -eq 0 -and $failedChecks.Count -eq 0) { "PASS" } else { "IMPROVE" }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# koreastudy content integrity audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Content integrity score: $score / 100") | Out-Null
$lines.Add("- Target: at least $MinimumScore points") | Out-Null
$lines.Add("- Catalog: $($schools.Count) school levels, $($subjects.Count) subjects, $($profileNames.Count) profiles") | Out-Null
$lines.Add("- Simulation: $Iterations content combinations, $scenarioFailures failures") | Out-Null
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
  $lines.Add("- No failed content integrity checks.") | Out-Null
} else {
  foreach ($check in $failedChecks) {
    $lines.Add("- $($check.Name): $($check.Evidence)") | Out-Null
  }
}

$lines.Add("") | Out-Null
$lines.Add("## Limits") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This no-cost audit checks internal data breadth and generation consistency, not official textbook correctness.") | Out-Null
$lines.Add("- Copyright-restricted textbooks, commercial worksheets, and full mock exam originals are still deferred until rights are approved.") | Out-Null

Set-Content -LiteralPath $reportPath -Encoding UTF8 -Value ($lines -join "`n")

Write-Output "CONTENT_INTEGRITY_SCORE`t$score/100"
Write-Output "STATUS`t$status"
Write-Output "CATALOG`t$($schools.Count) schools`t$($subjects.Count) subjects`t$($profileNames.Count) profiles"
Write-Output "SIMULATION`t$Iterations combinations`t$scenarioFailures failures"

if ($status -ne "PASS") {
  exit 1
}
