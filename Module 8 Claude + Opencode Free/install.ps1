# Module 8 installer for Windows PowerShell 5.1 or newer.
# Run it from YOUR project folder:
#   powershell -ExecutionPolicy Bypass -File module-8\install.ps1
# Safe to run twice.
# Options: -AcceptEdits (answer yes to the edit question), -NoAcceptEdits (answer no).
param(
    [switch]$AcceptEdits,
    [switch]$NoAcceptEdits
)
if ($AcceptEdits -and $NoAcceptEdits) {
    Write-Host 'Usage: install.ps1 [-AcceptEdits | -NoAcceptEdits]'
    exit 2
}
$ErrorActionPreference = 'Stop'

$Src  = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
$Dest = [System.IO.Path]::GetFullPath((Get-Location).ProviderPath).TrimEnd('\', '/')
$script:Changed = $false
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Say($text) { Write-Host $text }
function Mark-Changed { $script:Changed = $true }

if ($Dest -ieq $Src) {
    Say "Run this from your project folder, not from inside the module folder."
    Say "Example: cd my-project, then: powershell -ExecutionPolicy Bypass -File module-8\install.ps1"
    exit 1
}

Say "Installing Module 8 into: $Dest"

# Copy one file only when it is new or different. Returns $true if it copied.
function Copy-IfDifferent($from, $to) {
    if (Test-Path -LiteralPath $to -PathType Leaf) {
        $a = (Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash
        $b = (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash
        if ($a -eq $b) { return $false }
    }
    Copy-Item -LiteralPath $from -Destination $to -Force
    return $true
}

function Same-File($a, $b) {
    if (-not (Test-Path -LiteralPath $a -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $b -PathType Leaf)) { return $false }
    return ((Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $b -Algorithm SHA256).Hash)
}

# 1. Folders
$made = $false
foreach ($d in @('.claude\agents', '.claude\m8', '.claude\opencode-quota', 'scripts')) {
    $p = Join-Path $Dest $d
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
        $made = $true
    }
}
if ($made) { Mark-Changed; Say "ok: folders created" } else { Say "skipped: folders already there" }

# 2. Agents, rule files, scripts
$n = 0
$agentDir = Join-Path $Src 'agents'
if (Test-Path -LiteralPath $agentDir -PathType Container) {
    foreach ($f in @(Get-ChildItem -LiteralPath $agentDir -Filter '*.md' -File)) {
        if (Copy-IfDifferent $f.FullName (Join-Path $Dest ('.claude\agents\' + $f.Name))) { $n++ }
    }
}
if ($n -gt 0) { Mark-Changed; Say "ok: $n agent file(s) copied to .claude\agents" } else { Say "skipped: agents already up to date" }

$n = 0
$ruleDir = Join-Path $Src 'rules'
if (Test-Path -LiteralPath $ruleDir -PathType Container) {
    foreach ($f in @(Get-ChildItem -LiteralPath $ruleDir -Filter '*.md' -File)) {
        if (Copy-IfDifferent $f.FullName (Join-Path $Dest ('.claude\m8\' + $f.Name))) { $n++ }
    }
}
if ($n -gt 0) { Mark-Changed; Say "ok: $n rule file(s) copied to .claude\m8" } else { Say "skipped: rule files already up to date" }

$n = 0
foreach ($s in @('opencode-run.sh')) {
    $from = Join-Path $Src ('scripts\' + $s)
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { Say "skipped: scripts\$s is missing from the module folder"; continue }
    if (Copy-IfDifferent $from (Join-Path $Dest ('scripts\' + $s))) { $n++ }
}
if ($n -gt 0) { Mark-Changed; Say "ok: script copied to scripts\" } else { Say "skipped: scripts already up to date" }

# 3. CLAUDE.md and AGENTS.md
function Place-Doc($name) {
    $docFrom = Join-Path $Src $name
    $docTo = Join-Path $Dest $name
    $alt = $name -replace '\.md$', '.module-8.md'
    $altPath = Join-Path $Dest $alt
    if (-not (Test-Path -LiteralPath $docFrom -PathType Leaf)) { Say "skipped: $name is missing from the module folder"; return }
    if (-not (Test-Path -LiteralPath $docTo -PathType Leaf)) {
        Copy-Item -LiteralPath $docFrom -Destination $docTo
        Mark-Changed
        Say "ok: $name copied"
        return
    }
    if (Same-File $docFrom $docTo) { Say "skipped: $name is already up to date"; return }
    $firstHeading = $null
    foreach ($line in [System.IO.File]::ReadLines($docTo)) {
        if ($line.StartsWith('#')) { $firstHeading = $line; break }
    }
    if ($firstHeading -and $firstHeading.Contains('Orchestration (Module 8')) {
        $bak = $docTo + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $docTo -Destination $bak
        Copy-Item -LiteralPath $docFrom -Destination $docTo -Force
        Mark-Changed
        Say ("ok: $name updated (your old copy is saved as " + (Split-Path -Leaf $bak) + ")")
    } else {
        if (-not (Same-File $docFrom $altPath)) {
            Copy-Item -LiteralPath $docFrom -Destination $altPath -Force
            Mark-Changed
        }
        Say "NOTE: you already have your own $name, so I did not change it."
        Say "      Open $alt and paste its text into your $name."
    }
}
Place-Doc 'CLAUDE.md'
Place-Doc 'AGENTS.md'

# 4. .claude\settings.json (merge, never overwrite)
$tplPath = Join-Path $Src 'settings.json'
$setPath = Join-Path $Dest '.claude\settings.json'
$altSet  = Join-Path $Dest '.claude\settings.module-8.json'

function Settings-ByHand {
    Copy-Item -LiteralPath $tplPath -Destination $altSet -Force
    Say "      I saved the module's list as .claude\settings.module-8.json."
    Say "      Add its `"allow`" and `"deny`" lines to your .claude\settings.json by hand."
}

if (-not (Test-Path -LiteralPath $tplPath -PathType Leaf)) {
    Say "skipped: settings.json is missing from the module folder"
} elseif (-not (Test-Path -LiteralPath $setPath -PathType Leaf)) {
    Copy-Item -LiteralPath $tplPath -Destination $setPath
    Mark-Changed
    Say "ok: .claude\settings.json created"
} else {
    $cur = $null
    $parsed = $true
    try {
        $curText = [System.IO.File]::ReadAllText($setPath).TrimStart([char]0xFEFF)
        $cur = $curText | ConvertFrom-Json
        if ($null -eq $cur -or $cur -isnot [System.Management.Automation.PSCustomObject]) { $parsed = $false }
    } catch {
        $parsed = $false
    }
    if (-not $parsed) {
        Say "NOTE: .claude\settings.json is not valid JSON, so I did not touch it."
        Settings-ByHand
    } else {
        try {
            $tplText = [System.IO.File]::ReadAllText($tplPath).TrimStart([char]0xFEFF)
            $tpl = $tplText | ConvertFrom-Json
            if ($null -eq $cur.PSObject.Properties['permissions']) {
                $cur | Add-Member -NotePropertyName 'permissions' -NotePropertyValue ([pscustomobject]@{})
            }
            $perm = $cur.permissions
            if ($perm -isnot [System.Management.Automation.PSCustomObject]) { throw "permissions is not an object" }
            $added = 0
            foreach ($k in @('allow', 'deny')) {
                $list = @()
                if ($null -ne $perm.PSObject.Properties[$k]) { $list = @($perm.$k) }
                foreach ($e in @($tpl.permissions.$k)) {
                    if ($list -notcontains $e) { $list += $e; $added++ }
                }
                if ($null -ne $perm.PSObject.Properties[$k]) {
                    $perm.$k = [object[]]$list
                } else {
                    $perm | Add-Member -NotePropertyName $k -NotePropertyValue ([object[]]$list)
                }
            }
            if ($added -eq 0) {
                Say "skipped: .claude\settings.json already has the allow-list"
            } else {
                $json = ConvertTo-Json -InputObject $cur -Depth 10
                $null = $json | ConvertFrom-Json   # must parse again before we write it
                [System.IO.File]::WriteAllText($setPath, $json + "`n", $Utf8NoBom)
                Mark-Changed
                Say "ok: .claude\settings.json updated (your other settings are untouched)"
            }
        } catch {
            Say "NOTE: could not update .claude\settings.json, so I left it alone."
            Settings-ByHand
        }
    }
}

# 4b. Edit approval: ask once whether Claude may edit files without asking each time.
# Only ever sets permissions.defaultMode to "acceptEdits". Never any other mode.
function Edits-ByHand {
    Say '      To allow edits without asking, add "defaultMode": "acceptEdits" inside "permissions" in .claude\settings.json by hand.'
}

if (-not (Test-Path -LiteralPath $setPath -PathType Leaf)) {
    Say "skipped: there is no .claude\settings.json to change."
    Edits-ByHand
} else {
    $cur2 = $null
    $ok2 = $true
    try {
        $cur2Text = [System.IO.File]::ReadAllText($setPath).TrimStart([char]0xFEFF)
        $cur2 = $cur2Text | ConvertFrom-Json
        if ($null -eq $cur2 -or $cur2 -isnot [System.Management.Automation.PSCustomObject]) { $ok2 = $false }
        elseif ($null -ne $cur2.PSObject.Properties['permissions'] -and $cur2.permissions -isnot [System.Management.Automation.PSCustomObject]) { $ok2 = $false }
    } catch {
        $ok2 = $false
    }
    if (-not $ok2) {
        Say "NOTE: .claude\settings.json is not valid JSON, so I left edit approval alone."
        Edits-ByHand
    } else {
        $curMode = $null
        if ($null -ne $cur2.PSObject.Properties['permissions'] -and $null -ne $cur2.permissions.PSObject.Properties['defaultMode']) {
            $curMode = $cur2.permissions.defaultMode
        }
        if ($null -ne $curMode) {
            Say "skipped: edit approval is already set to $curMode"
        } else {
            $answer = 'ask'
            if ($AcceptEdits) { $answer = 'yes' } elseif ($NoAcceptEdits) { $answer = 'no' }
            if ($answer -eq 'ask') {
                $interactive = $false
                try { $interactive = ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) } catch { $interactive = $false }
                if ($interactive) {
                    Say "Claude's builders write and change files in this folder while they work."
                    Say "Let them do that without asking you each time? Runs can then finish while you are away."
                    Say "You can change this later in .claude\settings.json."
                    $reply = ''
                    try { $reply = Read-Host 'Allow edits without asking? [y/N]' } catch { $reply = '' }
                    if ($null -eq $reply) { $reply = '' }
                    if (@('y', 'Y', 'yes', 'Yes', 'YES') -ccontains $reply.Trim()) { $answer = 'yes' } else { $answer = 'no' }
                } else {
                    $answer = 'none'
                }
            }
            if ($answer -eq 'yes') {
                try {
                    if ($null -eq $cur2.PSObject.Properties['permissions']) {
                        $cur2 | Add-Member -NotePropertyName 'permissions' -NotePropertyValue ([pscustomobject]@{})
                    }
                    $perm2 = $cur2.permissions
                    if ($null -eq $perm2.PSObject.Properties['defaultMode']) {
                        $perm2 | Add-Member -NotePropertyName 'defaultMode' -NotePropertyValue 'acceptEdits'
                    } else {
                        $perm2.defaultMode = 'acceptEdits'
                    }
                    $json2 = ConvertTo-Json -InputObject $cur2 -Depth 10
                    $null = $json2 | ConvertFrom-Json   # must parse again before we write it
                    [System.IO.File]::WriteAllText($setPath, $json2 + "`n", $Utf8NoBom)
                    Mark-Changed
                    Say "ok: Claude can edit files in this folder without asking (acceptEdits)"
                } catch {
                    Say "NOTE: could not update .claude\settings.json, so I left it alone."
                    Edits-ByHand
                }
            } elseif ($answer -eq 'no') {
                Say "ok: Claude will ask before each file edit. To change later, run this installer again with -AcceptEdits"
            } else {
                Say "skipped: no terminal to ask on. To allow edits without asking, run this installer again with -AcceptEdits"
            }
        }
    }
}

# 5. .gitignore
$gi = Join-Path $Dest '.gitignore'
$added = 0
foreach ($line in @('.claude/opencode-quota/', '.m8/')) {
    $existing = @()
    $raw = ''
    if (Test-Path -LiteralPath $gi -PathType Leaf) {
        $raw = [System.IO.File]::ReadAllText($gi)
        $existing = @($raw -split "`r?`n" | ForEach-Object { $_.Trim() })
    }
    if (($existing -contains $line) -or ($existing -contains $line.TrimEnd('/'))) { continue }
    $prefix = ''
    if ($raw.Length -gt 0 -and -not $raw.EndsWith("`n")) { $prefix = "`n" }
    [System.IO.File]::AppendAllText($gi, $prefix + $line + "`n", $Utf8NoBom)
    $added++
}
if ($added -gt 0) { Mark-Changed; Say "ok: .gitignore updated ($added line(s) added)" } else { Say "skipped: .gitignore already has the lines" }

# 6. Git (reviews read git diff)
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Say "NOTE: git is not installed. Reviews need git."
    Say "      Install Git for Windows (git-scm.com). Mac: run  xcode-select --install"
} else {
    $ErrorActionPreference = 'Continue'   # native tools write to stderr; do not stop on that
    & git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -eq 0) {
        Say "skipped: this folder is already a git repo (left as it is)"
    } else {
        & git init -q *> $null
        Mark-Changed
        Say "ok: git repo started"
        & git rev-parse --verify -q HEAD *> $null
        if ($LASTEXITCODE -ne 0) {
            & git add -A -- . ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*' *> $null
            & git commit -q -m "start" *> $null
            if ($LASTEXITCODE -eq 0) {
                Say "ok: first commit made (your .env files were left out)"
            } else {
                Say "NOTE: I could not make the first commit. Git needs your name and email. Run these lines:"
                Say "      git config --global user.name `"Your Name`""
                Say "      git config --global user.email `"you@example.com`""
                Say "      git add -A; git commit -m start"
            }
        }
    }
    $ErrorActionPreference = 'Stop'
}

# 7. Tool check (report only)
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Say "ok: opencode found"
} else {
    Say "NOTE: opencode not found. Install it:"
    Say "      Windows: npm i -g opencode-ai"
    Say "      Mac:     curl -fsSL https://opencode.ai/install | bash"
}

# 8. Done
Say ""
Say "Module 8 is installed."
if (-not $script:Changed) { Say "Nothing changed this time. It was already up to date." }
Say "Next:"
Say "  1. Sign in to opencode if you have not yet (run it once)."
Say "  2. Start Claude Code in this folder and choose Opus."
Say "  3. Paste a prompt from test-prompt.md."
Say "Note: the runner script is a bash script. Claude Code on Windows uses Git Bash for it."
