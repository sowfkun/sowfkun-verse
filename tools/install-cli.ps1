$ErrorActionPreference = "Stop"

$toolsPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$profilePath = $PROFILE

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Updating PowerShell Profile & Smart Tab-Completion..." -ForegroundColor Green
Write-Host "Tools Path:   $toolsPath" -ForegroundColor White
Write-Host "Profile Path: $profilePath" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan

$lines = @(
    "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8",
    "`$OutputEncoding = [System.Text.Encoding]::UTF8",
    "",
    "`$toolsPath = `"$toolsPath`"",
    "",
    "if (`$env:Path -notlike `"*`$toolsPath*`") {",
    "    `$env:Path = `"`$toolsPath;`$env:Path`"",
    "}",
    "",
    "function sowfkun {",
    "    & `"`$toolsPath\sowfkun.ps1`" @args",
    "}",
    "",
    "Register-ArgumentCompleter -Native -CommandName sowfkun, sowfkun.cmd, sowfkun.ps1, sowfkun.exe -ScriptBlock {",
    "    param(`$wordToComplete, `$commandAst, `$cursorPosition)",
    "    ",
    "    `$text = `$commandAst.ToString()",
    "    `$parts = `$text.TrimStart().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)",
    "    `$isNewArg = `$text.EndsWith(' ') -or [string]::IsNullOrEmpty(`$wordToComplete)",
    "    `$argIndex = if (`$isNewArg) { `$parts.Count } else { [Math]::Max(0, `$parts.Count - 1) }",
    "",
    "    if (`$argIndex -le 1) {",
    "        `$topCommands = @('infra', 'deploy', 'deploy-gateway', 'verse-deploy', 'verse-deploy-gateway', 'download', 'sync-audio', 'help')",
    "        `$topCommands | Where-Object { `$_ -like `"`$wordToComplete*`" } | ForEach-Object {",
    "            [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)",
    "        }",
    "        return",
    "    }",
    "",
    "    `$subCmd = `$parts[1].ToLower()",
    "",
    "    if (`$subCmd -in @('infra', 'infra-tunnel', 'tunnel')) {",
    "        if (`$argIndex -eq 2) {",
    "            `$infraActions = @('open', 'close', 'switch', 'status')",
    "            `$infraActions | Where-Object { `$_ -like `"`$wordToComplete*`" } | ForEach-Object {",
    "                [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)",
    "            }",
    "            return",
    "        }",
    "        if (`$argIndex -ge 3) {",
    "            `$profiles = @('tailscale-dev', 'hybrid-dev', 'gcp-direct-dev', 'netcup-mongo-dev', 'all', 'mongo', 'cache', 'redis', 'kafka', 'app', 'gateway')",
    "            `$jsonPath = Join-Path (Split-Path -Parent `$toolsPath) '.servers\servers.json'",
    "            if (Test-Path `$jsonPath) {",
    "                try {",
    "                    `$json = Get-Content `$jsonPath -Raw | ConvertFrom-Json",
    "                    if (`$json.profiles) {",
    "                        `$profiles = @(`$json.profiles.PSObject.Properties.Name) + @('all', 'mongo', 'cache', 'redis', 'kafka', 'app', 'gateway')",
    "                    }",
    "                } catch {}",
    "            }",
    "            `$profiles | Where-Object { `$_ -like `"`$wordToComplete*`" } | ForEach-Object {",
    "                [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)",
    "            }",
    "            return",
    "        }",
    "    }",
    "",
    "    if (`$subCmd -in @('verse-deploy', 'verse-deploy-gateway', 'verse-deploy-gw', 'deploy', 'deploy-api', 'deploy-gw')) {",
    "        if (`$argIndex -eq 2) {",
    "            `$profiles = @('tailscale-dev', 'hybrid-dev', 'gcp-direct-dev', 'tailscale-prod')",
    "            `$jsonPath = Join-Path (Split-Path -Parent `$toolsPath) '.servers\servers.json'",
    "            if (Test-Path `$jsonPath) {",
    "                try {",
    "                    `$json = Get-Content `$jsonPath -Raw | ConvertFrom-Json",
    "                    if (`$json.profiles) {",
    "                        `$profiles = @(`$json.profiles.PSObject.Properties.Name)",
    "                    }",
    "                } catch {}",
    "            }",
    "            `$profiles | Where-Object { `$_ -like `"`$wordToComplete*`" } | ForEach-Object {",
    "                [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)",
    "            }",
    "            return",
    "        }",
    "        if (`$argIndex -ge 3) {",
    "            `$envs = @('dev', 'staging', 'prod')",
    "            `$envs | Where-Object { `$_ -like `"`$wordToComplete*`" } | ForEach-Object {",
    "                [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)",
    "            }",
    "            return",
    "        }",
    "    }",
    "}"
)

$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$lines | Out-File -FilePath $profilePath -Encoding UTF8 -Force

Write-Host "INSTALLATION SUCCESSFUL!" -ForegroundColor Green
Write-Host "Tab-Completion is now fully active for sowfkun, infra, verse-deploy!" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
