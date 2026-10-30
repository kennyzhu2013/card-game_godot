param(
    [switch]$SkipExport,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$GodotExe = "",
    [string]$Preset = "Web",
    [int]$Port = 8765
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $godotCommand) {
        $godotCommand = Get-Command godot4 -ErrorAction SilentlyContinue
    }
    if ($godotCommand) {
        $GodotExe = $godotCommand.Source
    }
}


function Write-Utf8File {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function ConvertTo-JsonCompact {
    param([Parameter(Mandatory=$true)]$Value)
    return ($Value | ConvertTo-Json -Depth 12)
}

function Read-TrimmedText {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) {
        return ""
    }
    $text = Get-Content -Path $Path -Encoding UTF8 -Raw
    if ($null -eq $text) {
        return ""
    }
    return $text.Trim()
}

function Find-PlaywrightNodeModules {
    param([Parameter(Mandatory=$true)][string]$NpmCachePath)
    $npxRoot = Join-Path $NpmCachePath "_npx"
    if (-not (Test-Path $npxRoot)) {
        return ""
    }
    $indexFile = Get-ChildItem -Path $npxRoot -Recurse -Filter "index.js" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "*node_modules\@playwright\test\index.js" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $indexFile) {
        return ""
    }
    $testDir = Split-Path -Parent $indexFile.FullName
    $scopeDir = Split-Path -Parent $testDir
    return Split-Path -Parent $scopeDir
}

function Finish-WebQA {
    param(
        [Parameter(Mandatory=$true)][string]$Status,
        [Parameter(Mandatory=$true)][string]$Reason,
        [Parameter(Mandatory=$true)][bool]$Ok,
        [hashtable]$Extra = @{}
    )
    $result = @{
        gate = "webqa_regression"
        ok = $Ok
        status = $Status
        reason = $Reason
        project_root = $ProjectRoot
        web_dir = $WebDir
        screenshot = $ScreenshotPath
        console_log = $ConsoleJsonPath
        command_log = $CommandLogPath
    }
    foreach ($key in $Extra.Keys) {
        $result[$key] = $Extra[$key]
    }
    Write-Utf8File -Path $ResultJsonPath -Content (ConvertTo-JsonCompact $result)

    $summary = @(
        "status: $Status",
        "reason: $Reason",
        "ok: $Ok",
        "web_dir: $WebDir",
        "screenshot: $ScreenshotPath",
        "console_log: $ConsoleJsonPath",
        "command_log: $CommandLogPath"
    ) -join [Environment]::NewLine
    Write-Utf8File -Path $SummaryPath -Content ($summary + [Environment]::NewLine)
    if ($Ok) {
        exit 0
    }
    exit 1
}

$ClientDir = Join-Path $ProjectRoot "client"
$ArtifactsDir = Join-Path $ProjectRoot "output\webqa\artifacts"
$WebDir = Join-Path $ClientDir "output\web"
$ExportPresetPath = Join-Path $ClientDir "export_presets.cfg"
$ExportHtmlPath = Join-Path $WebDir "index.html"
$SummaryPath = Join-Path $ArtifactsDir "webqa-summary.md"
$ResultJsonPath = Join-Path $ArtifactsDir "webqa-regression-result.json"
$ConsoleJsonPath = Join-Path $ArtifactsDir "webqa-console.json"
$ScreenshotPath = Join-Path $ArtifactsDir "webqa-screenshot.png"
$CommandLogPath = Join-Path $ArtifactsDir "webqa-command.log"
$PlaywrightSpecPath = Join-Path $ProjectRoot "output\webqa\webqa_playwright.spec.js"
$PlaywrightResultsDir = Join-Path $ArtifactsDir "test-results"

New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null
Write-Utf8File -Path $CommandLogPath -Content "WebQA started $(Get-Date -Format o)`nSkipExport=$SkipExport`n"

if (-not (Test-Path $ClientDir)) {
    Finish-WebQA -Status "blocked" -Reason "client directory missing: $ClientDir" -Ok $false
}
if (-not (Test-Path (Join-Path $ClientDir "project.godot"))) {
    Finish-WebQA -Status "blocked" -Reason "Godot project missing: client/project.godot" -Ok $false
}

if (-not $SkipExport) {
    if (-not (Test-Path $GodotExe)) {
        Finish-WebQA -Status "blocked" -Reason "Godot executable missing: $GodotExe" -Ok $false
    }
    if (-not (Test-Path $ExportPresetPath)) {
        Finish-WebQA -Status "blocked" -Reason "Godot Web export preset missing: $ExportPresetPath" -Ok $false
    }
    $presetText = Get-Content -Path $ExportPresetPath -Encoding UTF8 -Raw
    if ($presetText -notmatch 'platform="Web"') {
        Finish-WebQA -Status "blocked" -Reason "Godot export preset file exists but has no Web platform preset: $ExportPresetPath" -Ok $false
    }
    New-Item -ItemType Directory -Path $WebDir -Force | Out-Null
    $exportStdout = Join-Path $ArtifactsDir "godot-web-export-stdout.log"
    $exportStderr = Join-Path $ArtifactsDir "godot-web-export-stderr.log"
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Running Godot Web export..."
    $proc = Start-Process -FilePath $GodotExe -ArgumentList @("--headless", "--path", $ClientDir, "--export-release", $Preset, $ExportHtmlPath) -WorkingDirectory $ClientDir -NoNewWindow -Wait -PassThru -RedirectStandardOutput $exportStdout -RedirectStandardError $exportStderr
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Godot export exit code: $($proc.ExitCode)"
    if ($proc.ExitCode -ne 0 -or -not (Test-Path $ExportHtmlPath)) {
        $stderrText = ""
        $stderrText = Read-TrimmedText -Path $exportStderr
        if ($stderrText.Length -gt 500) {
            $stderrText = $stderrText.Substring(0, 500)
        }
        Finish-WebQA -Status "blocked" -Reason "Godot Web export failed or did not create index.html. Exit=$($proc.ExitCode). $stderrText" -Ok $false -Extra @{ godot_export_stdout = $exportStdout; godot_export_stderr = $exportStderr }
    }
}

if (-not (Test-Path $ExportHtmlPath)) {
    Finish-WebQA -Status "blocked" -Reason "Web export missing: $ExportHtmlPath. Run without -SkipExport after restoring export presets/templates." -Ok $false
}

$npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
if (-not $npx) {
    $npx = Get-Command npx -ErrorAction SilentlyContinue
}
if (-not $npx) {
    Finish-WebQA -Status "blocked" -Reason "npx is missing; Node/npm tooling is required for Playwright" -Ok $false
}

$server = $null
try {
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Starting static server on port $Port..."
    $serverArgs = @("-m", "http.server", "$Port", "--bind", "127.0.0.1", "--directory", $WebDir)
    $server = Start-Process -FilePath "python" -ArgumentList $serverArgs -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $ArtifactsDir "web-server-stdout.log") -RedirectStandardError (Join-Path $ArtifactsDir "web-server-stderr.log")
    Start-Sleep -Seconds 2
    if ($server.HasExited) {
        Finish-WebQA -Status "blocked" -Reason "local Web server exited before browser test could run" -Ok $false
    }

    $env:WEBQA_URL = "http://127.0.0.1:$Port/index.html"
    $env:WEBQA_SCREENSHOT = $ScreenshotPath
    $env:WEBQA_CONSOLE_JSON = $ConsoleJsonPath
    $env:WEBQA_RESULT_JSON = $ResultJsonPath
    $env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $ProjectRoot "output\webqa\browsers"
    $env:npm_config_cache = Join-Path $ProjectRoot "output\webqa\npm-cache"
    if (-not (Test-Path $PlaywrightSpecPath)) {
        Finish-WebQA -Status "blocked" -Reason "Playwright spec missing: $PlaywrightSpecPath" -Ok $false
    }

    $pwPrefetchStdout = Join-Path $ArtifactsDir "playwright-prefetch-stdout.log"
    $pwPrefetchStderr = Join-Path $ArtifactsDir "playwright-prefetch-stderr.log"
    $playwrightNodePath = Find-PlaywrightNodeModules -NpmCachePath $env:npm_config_cache
    if ($playwrightNodePath.Length -eq 0) {
        Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Preparing Playwright package cache..."
        $prefetchArgs = @("--yes", "--package", "@playwright/test", "playwright", "--version")
        $prefetch = Start-Process -FilePath $npx.Source -ArgumentList $prefetchArgs -WorkingDirectory $ProjectRoot -NoNewWindow -Wait -PassThru -RedirectStandardOutput $pwPrefetchStdout -RedirectStandardError $pwPrefetchStderr
        Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Playwright prefetch exit code: $($prefetch.ExitCode)"
        if ($prefetch.ExitCode -ne 0) {
            $prefetchFailure = Read-TrimmedText -Path $pwPrefetchStderr
            if ($prefetchFailure.Length -eq 0) {
                $prefetchFailure = Read-TrimmedText -Path $pwPrefetchStdout
            }
            Finish-WebQA -Status "blocked" -Reason "Playwright package preparation failed. Exit=$($prefetch.ExitCode). $prefetchFailure" -Ok $false -Extra @{ playwright_prefetch_stdout = $pwPrefetchStdout; playwright_prefetch_stderr = $pwPrefetchStderr }
        }
        $playwrightNodePath = Find-PlaywrightNodeModules -NpmCachePath $env:npm_config_cache
    }
    if ($playwrightNodePath.Length -gt 0) {
        if ($env:NODE_PATH) {
            $env:NODE_PATH = "$playwrightNodePath$([IO.Path]::PathSeparator)$env:NODE_PATH"
        } else {
            $env:NODE_PATH = $playwrightNodePath
        }
        Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "NODE_PATH includes Playwright package cache: $playwrightNodePath"
    }

    $browserInstallStdout = Join-Path $ArtifactsDir "playwright-browser-install-stdout.log"
    $browserInstallStderr = Join-Path $ArtifactsDir "playwright-browser-install-stderr.log"
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Ensuring Playwright Chromium is installed..."
    $browserInstallArgs = @("--yes", "--package", "@playwright/test", "playwright", "install", "chromium")
    $browserInstall = Start-Process -FilePath $npx.Source -ArgumentList $browserInstallArgs -WorkingDirectory $ProjectRoot -NoNewWindow -Wait -PassThru -RedirectStandardOutput $browserInstallStdout -RedirectStandardError $browserInstallStderr
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Playwright Chromium install exit code: $($browserInstall.ExitCode)"
    if ($browserInstall.ExitCode -ne 0) {
        $browserInstallFailure = Read-TrimmedText -Path $browserInstallStderr
        if ($browserInstallFailure.Length -eq 0) {
            $browserInstallFailure = Read-TrimmedText -Path $browserInstallStdout
        }
        Finish-WebQA -Status "blocked" -Reason "Playwright Chromium installation failed. Exit=$($browserInstall.ExitCode). $browserInstallFailure" -Ok $false -Extra @{ playwright_browser_install_stdout = $browserInstallStdout; playwright_browser_install_stderr = $browserInstallStderr }
    }

    $pwStdout = Join-Path $ArtifactsDir "playwright-stdout.log"
    $pwStderr = Join-Path $ArtifactsDir "playwright-stderr.log"
    $playwrightSpecArg = "output/webqa/webqa_playwright.spec.js"
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Running Playwright..."
    $pwArgs = @("--yes", "--package", "@playwright/test", "playwright", "test", $playwrightSpecArg, "--workers=1", "--reporter=line", "--output", $PlaywrightResultsDir)
    $pw = Start-Process -FilePath $npx.Source -ArgumentList $pwArgs -WorkingDirectory $ProjectRoot -NoNewWindow -Wait -PassThru -RedirectStandardOutput $pwStdout -RedirectStandardError $pwStderr
    Add-Content -Path $CommandLogPath -Encoding UTF8 -Value "Playwright exit code: $($pw.ExitCode)"

    if ($pw.ExitCode -ne 0) {
        $failureText = Read-TrimmedText -Path $pwStderr
        if ($failureText.Length -eq 0) {
            $failureText = Read-TrimmedText -Path $pwStdout
        }
        if ($failureText.Length -gt 700) {
            $failureText = $failureText.Substring(0, 700)
        }
        Finish-WebQA -Status "blocked" -Reason "Playwright browser regression failed or browser dependency is unavailable. Exit=$($pw.ExitCode). $failureText" -Ok $false -Extra @{ playwright_stdout = $pwStdout; playwright_stderr = $pwStderr }
    }

    if (-not (Test-Path $ResultJsonPath)) {
        Finish-WebQA -Status "blocked" -Reason "Playwright completed but did not write result JSON" -Ok $false -Extra @{ playwright_stdout = $pwStdout; playwright_stderr = $pwStderr }
    }
    $resultText = Get-Content -Path $ResultJsonPath -Encoding UTF8 -Raw
    if ($resultText -notmatch '"ok"\s*:\s*true') {
        Finish-WebQA -Status "failed" -Reason "Playwright completed but WebQA result was not ok" -Ok $false -Extra @{ playwright_stdout = $pwStdout; playwright_stderr = $pwStderr }
    }
    Finish-WebQA -Status "passed" -Reason "Godot Web export/browser smoke path passed" -Ok $true -Extra @{ playwright_stdout = $pwStdout; playwright_stderr = $pwStderr }
}
finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
}
