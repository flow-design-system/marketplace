<#
.SYNOPSIS
  Bootstraps a personal Windows machine for working with Flow DS.

.DESCRIPTION
  Installs: mise, Node.js (via mise), npm, Claude Code, and
  Flow Builder skills.
  Supports: Windows 10+ with winget.

.EXAMPLE
  # Run directly (may require: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned)
  .\setup-personal.ps1

  # Or via remote URL:
  irm <url>/setup-personal.ps1 | iex
#>

#Requires -Version 5.1

# -- Config ----------------------------------------------------------

$NodeVersion = if ($env:NODE_VERSION) { $env:NODE_VERSION } else { 'lts' }

# -- Helpers ----------------------------------------------------------

function Write-Bold { param([string]$Message) Write-Host $Message -ForegroundColor White }
function Write-Info { param([string]$Message) Write-Host '==>' -ForegroundColor Cyan -NoNewline; Write-Host " $Message" }
function Write-Warn { param([string]$Message) Write-Host '!!' -ForegroundColor Yellow -NoNewline; Write-Host " $Message" }
function Write-Ok   { param([string]$Message) Write-Host 'ok' -ForegroundColor Green -NoNewline; Write-Host " $Message" }

function Stop-Setup {
  param([string]$Message)
  Write-Host "xx $Message" -ForegroundColor Red
  exit 1
}

function Test-Command {
  param([string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
  Refreshes the session PATH from the registry so newly-installed
  tools are discoverable without opening a new terminal.
#>
function Update-SessionPath {
  $machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
  $userPath    = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
  $env:PATH    = "$machinePath;$userPath"
}

# -- Steps ------------------------------------------------------------

function Install-Prerequisites {
  if (-not (Test-Command 'winget')) {
    Stop-Setup 'winget is not available. Install "App Installer" from the Microsoft Store or update Windows to 10 1709+.'
  }

  if (-not (Test-Command 'git')) {
    Write-Info 'Installing Git'
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    Update-SessionPath
  }
  else {
    Write-Ok 'Git already installed'
  }
}

function Install-Mise {
  if (Test-Command 'mise') {
    $version = (mise --version 2>$null) -replace '\s.*', ''
    Write-Ok "mise already installed ($version)"
  }
  else {
    Write-Info 'Installing mise'

    if (Test-Command 'winget') {
      winget install --id jdx.mise -e --accept-package-agreements --accept-source-agreements
    }
    elseif (Test-Command 'scoop') {
      scoop install mise
    }
    else {
      Stop-Setup 'Neither winget nor scoop found. Install mise manually: https://mise.jdx.dev/getting-started.html'
    }

    Update-SessionPath

    # mise's bin dir may not yet be on the registry PATH — add it
    # for this session so subsequent commands work immediately.
    $miseBin = Join-Path $env:LOCALAPPDATA 'mise\bin'
    if ((Test-Path $miseBin) -and ($env:PATH -notlike "*$miseBin*")) {
      $env:PATH = "$miseBin;$env:PATH"
    }
  }

  # Put shims on PATH for this session
  $miseShims = Join-Path $env:LOCALAPPDATA 'mise\shims'
  if ($env:PATH -notlike "*$miseShims*") {
    $env:PATH = "$miseShims;$env:PATH"
  }

  # Add mise activation to PowerShell profile if missing
  $profileDir = Split-Path $PROFILE -Parent
  if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
  }

  $activateLine = 'mise activate pwsh | Out-String | Invoke-Expression'

  if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern 'mise activate' -Quiet)) {
    Write-Ok "mise activation already in $PROFILE"
  }
  else {
    Write-Info "Adding mise activation to $PROFILE"
    if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
    Add-Content -Path $PROFILE -Value "`n# mise`n$activateLine`n"
  }
}

function Install-Node {
  Write-Info "Installing Node.js ($NodeVersion) via mise"
  mise use -g "node@$NodeVersion"
  if ($LASTEXITCODE -ne 0) { Stop-Setup "mise failed to install Node.js $NodeVersion." }

  $nodeVer = mise exec -- node -v
  $npmVer  = mise exec -- npm -v
  Write-Ok "Node $nodeVer / npm $npmVer"
}

function Install-ClaudeCode {
  Write-Info 'Installing/updating Claude Code'
  mise exec -- npm install -g @anthropic-ai/claude-code
  if ($LASTEXITCODE -ne 0) { Stop-Setup 'npm failed to install Claude Code.' }
  Write-Ok 'Claude Code ready'
}

function Set-FlowRegistry {
  Write-Info 'Configuring npm registry for @flow/* packages'
  mise exec -- npm config set '@flow:registry' 'https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/'

  $registry = mise exec -- npm config get '@flow:registry' 2>$null
  if ($registry -eq 'https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/') {
    Write-Ok "@flow/* packages will be fetched from $registry"
  }
  else {
    Write-Warn "Registry was set but could not be verified — got: $registry"
  }
}

function Install-FlowSkills {
  Write-Info 'Installing Flow Builder skills for Claude Code'
  Write-Info 'This installs skills to ~/.claude/ so they work across all your projects.'

  mise exec -- npx -y '@flow/builder@latest' install --user 2>&1 | Out-Default
  if ($LASTEXITCODE -ne 0) {
    mise exec -- npm ping --registry 'https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Stop-Setup 'Could not install Flow Builder — the @flow registry is not reachable. Check your network connection and try again.'
    }
    else {
      Stop-Setup 'Flow Builder installer exited with an error. Try manually: npx -y @flow/builder@latest install --user'
    }
  }

  # Verify expected outputs
  $verifyPass = $true

  $skillBuild = Join-Path $HOME '.claude\skills\flow-build'
  $skillSetup = Join-Path $HOME '.claude\skills\flow-setup'
  if ((Test-Path $skillBuild) -and (Test-Path $skillSetup)) {
    Write-Ok 'Skills installed to ~/.claude/skills/'
  }
  else {
    Write-Warn 'Skill folders not found at ~/.claude/skills/ — the installer may have failed silently.'
    $verifyPass = $false
  }

  $claudeJson = Join-Path $HOME '.claude.json'
  if (Test-Path $claudeJson) {
    try {
      $config = Get-Content $claudeJson -Raw | ConvertFrom-Json
      if ($config.mcpServers.'flow-builder') {
        Write-Ok 'MCP server configured in ~/.claude.json'
      }
      else {
        Write-Warn "MCP server entry 'flow-builder' not found in ~/.claude.json"
        $verifyPass = $false
      }
    }
    catch {
      Write-Warn 'Could not parse ~/.claude.json'
      $verifyPass = $false
    }
  }
  else {
    Write-Warn '~/.claude.json not found'
    $verifyPass = $false
  }

  if (-not $verifyPass) {
    Write-Info 'The installer ran but some expected outputs are missing.'
    Write-Info 'Open Claude Code and type /flow-build to check if skills loaded correctly.'
  }
}

function Show-PostInstallHint {
  Write-Host ''
  Write-Bold 'Done.'
  Write-Host @'

Next steps:

  1. Open a new PowerShell window so mise shims are on PATH.
  2. Run `claude` to authenticate and start Claude Code.
  3. Use `/flow-setup` and `/flow-build` inside Claude Code to start building.
  4. Verify: `node -v`, `npm -v`, `claude --version`, `mise ls`.

'@
}

# -- Main -------------------------------------------------------------

function Main {
  $ErrorActionPreference = 'Stop'

  Write-Bold 'Flow setup: mise + Node + Claude Code'
  Write-Info 'Detected OS: Windows'

  Install-Prerequisites
  Install-Mise
  Install-Node
  Install-ClaudeCode
  Set-FlowRegistry
  Install-FlowSkills
  Show-PostInstallHint
}

Main
