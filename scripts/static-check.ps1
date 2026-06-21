$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
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
  "docs/deferred-approvals.md",
  "docs/deploy-checklist.md",
  "docs/qa-checklist.md",
  "docs/final-handoff.md",
  "docs/quality-report.md",
  "docs/ui-interaction-report.md",
  "docs/browser-runtime-report.md",
  "docs/operations-risk-report.md",
  "scripts/quality-audit.ps1",
  "scripts/ui-interaction-audit.ps1",
  "scripts/browser-runtime-audit.ps1",
  "scripts/operations-risk-audit.ps1"
)

$missing = @()
foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) {
    $missing += $file
  }
}

$index = Get-Content -Encoding UTF8 -Raw (Join-Path $root "index.html")
$app = Get-Content -Encoding UTF8 -Raw (Join-Path $root "app.js")
$data = Get-Content -Encoding UTF8 -Raw (Join-Path $root "data/education-data.js")
$hasQualityAudit = Test-Path -LiteralPath (Join-Path $root "scripts/quality-audit.ps1")
$hasQualityReport = Test-Path -LiteralPath (Join-Path $root "docs/quality-report.md")
$hasUiAudit = Test-Path -LiteralPath (Join-Path $root "scripts/ui-interaction-audit.ps1")
$hasUiReport = Test-Path -LiteralPath (Join-Path $root "docs/ui-interaction-report.md")
$hasBrowserAudit = Test-Path -LiteralPath (Join-Path $root "scripts/browser-runtime-audit.ps1")
$hasBrowserReport = Test-Path -LiteralPath (Join-Path $root "docs/browser-runtime-report.md")
$hasOperationsAudit = Test-Path -LiteralPath (Join-Path $root "scripts/operations-risk-audit.ps1")
$hasOperationsReport = Test-Path -LiteralPath (Join-Path $root "docs/operations-risk-report.md")

$checks = @(
  @{ Name = "Required files"; Pass = ($missing.Count -eq 0); Detail = if ($missing.Count) { "Missing: $($missing -join ', ')" } else { "All present" } },
  @{ Name = "Data loaded before app"; Pass = ($index.IndexOf("data/education-data.js") -lt $index.IndexOf("app.js")); Detail = "Script order" },
  @{ Name = "Gemini function path"; Pass = ($app.Contains("/.netlify/functions/gemini")); Detail = "Function fallback" },
  @{ Name = "Self-check feature"; Pass = ($app.Contains("runSelfCheck") -and $index.Contains("selfCheckPanel")); Detail = "QA self-check" },
  @{ Name = "Approval dashboard"; Pass = ($data.Contains("finalApprovals") -and $index.Contains("approvalPanel")); Detail = "Final approvals" },
  @{ Name = "Mistake note"; Pass = ($app.Contains("ks_mistakes") -and $index.Contains("mistakeList")); Detail = "Mistake note storage" },
  @{ Name = "Quality audit"; Pass = ($hasQualityAudit -and $hasQualityReport); Detail = "Quality score and simulation" },
  @{ Name = "UI interaction audit"; Pass = ($hasUiAudit -and $hasUiReport); Detail = "Touch and navigation simulation" },
  @{ Name = "Browser runtime audit"; Pass = ($hasBrowserAudit -and $hasBrowserReport); Detail = "Real browser runtime simulation" },
  @{ Name = "Operations risk audit"; Pass = ($hasOperationsAudit -and $hasOperationsReport); Detail = "Users, revenue, free-operation risk" }
)

foreach ($check in $checks) {
  $status = if ($check.Pass) { "PASS" } else { "FAIL" }
  Write-Output "$status`t$($check.Name)`t$($check.Detail)"
}

if ($checks | Where-Object { -not $_.Pass }) {
  exit 1
}
