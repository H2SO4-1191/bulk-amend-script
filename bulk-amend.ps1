param(
    [string]$Message      = "Changed Visibility",
    [int]$DelaySeconds    = 10,
    [switch]$DryRun
)

$Root = $PSScriptRoot
if (-not $Root) { $Root = (Get-Location).Path }

# ---------------------------------------------------------------- logging ---
$LogFile = Join-Path $Root ("bulk-amend_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Start-Transcript -Path $LogFile | Out-Null

function Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $color = switch ($Level) {
        'OK'   { 'Green' }
        'WARN' { 'Yellow' }
        'ERR'  { 'Red' }
        'STEP' { 'Cyan' }
        'DRY'  { 'Magenta' }
        default { 'Gray' }
    }
    Write-Host ("[{0}] [{1,-4}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Msg) -ForegroundColor $color
}

# ------------------------------------------------------------ git helpers ---
function Invoke-Git {
    param(
        [string]$Repo,
        [string[]]$GitArgs,
        [switch]$Mutating
    )
    if ($DryRun -and $Mutating) {
        Log "git $($GitArgs -join ' ')" 'DRY'
        return [pscustomobject]@{ Ok = $true; Output = '' }
    }
    $out = & git -C $Repo @GitArgs 2>&1 | ForEach-Object { "$_" }
    $ok  = ($LASTEXITCODE -eq 0)
    [pscustomobject]@{ Ok = $ok; Output = (($out -join "`n").Trim()) }
}

function Get-AllBranches {
    param([string]$Repo)
    $local  = @((Invoke-Git $Repo @('for-each-ref', '--format=%(refname:short)', 'refs/heads')).Output -split "`n" | Where-Object { $_ })
    $remote = @((Invoke-Git $Repo @('for-each-ref', '--format=%(refname:short)', 'refs/remotes/origin')).Output -split "`n" |
               Where-Object { $_ -and $_ -ne 'origin' -and $_ -ne 'origin/HEAD' } |
               ForEach-Object { $_ -replace '^origin/', '' })
    @($local + $remote | Select-Object -Unique)
}

function Update-Branch {
    param(
        [string]$Repo,
        [string]$Branch,
        [string]$MergeFrom = ''
    )

    Log "  [$Branch] checkout" 'STEP'
    $r = Invoke-Git $Repo @('checkout', $Branch) -Mutating
    if (-not $r.Ok) { throw "checkout '$Branch' failed: $($r.Output)" }

    # Safety: never force-push over commits that exist only on the remote
    # (if the branch only exists on origin, checkout creates it from origin, so it can't be behind)
    $hasLocal  = Invoke-Git $Repo @('rev-parse', '--verify', '--quiet', "refs/heads/$Branch")
    $hasRemote = Invoke-Git $Repo @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Branch")
    if ($hasLocal.Ok -and $hasRemote.Ok) {
        $behindRaw = (Invoke-Git $Repo @('rev-list', '--count', "refs/heads/$Branch..refs/remotes/origin/$Branch")).Output
        if ($behindRaw -notmatch '^\d+$') { throw "could not compare '$Branch' with origin/${Branch}: $behindRaw" }
        $behind = [int]$behindRaw
        if ($behind -gt 0) {
            throw "'$Branch' is $behind commit(s) behind origin/$Branch - a force push would delete them. Pull/rebase first."
        }
    }

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $env:GIT_COMMITTER_DATE = $now

    if ($MergeFrom) {
        Log "  [$Branch] merging '$MergeFrom'" 'STEP'
        $m = Invoke-Git $Repo @('merge', $MergeFrom, '-m', $Message) -Mutating
        if (-not $m.Ok) {
            Invoke-Git $Repo @('merge', '--abort') -Mutating | Out-Null
            throw "merge '$MergeFrom' -> '$Branch' failed (conflict?), merge aborted: $($m.Output)"
        }
    }

    Log "  [$Branch] git add ." 'STEP'
    $a = Invoke-Git $Repo @('add', '.') -Mutating
    if (-not $a.Ok) { throw "add failed: $($a.Output)" }

    Log "  [$Branch] amend -> '$Message' @ $now" 'STEP'
    $c = Invoke-Git $Repo @('commit', '--amend', '-m', $Message, '--date', $now, '--no-verify') -Mutating
    if (-not $c.Ok) { throw "amend failed: $($c.Output)" }

    Log "  [$Branch] push --force-with-lease" 'STEP'
    $p = Invoke-Git $Repo @('push', 'origin', $Branch, '--force-with-lease') -Mutating
    if (-not $p.Ok) { throw "push '$Branch' failed: $($p.Output)" }

    Log "  [$Branch] done" 'OK'
}

# ------------------------------------------------------------------- main ---
$startTime = Get-Date
$results   = New-Object System.Collections.Generic.List[object]

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Log "git is not installed or not in PATH." 'ERR'
    Stop-Transcript | Out-Null
    exit 1
}

if ($DryRun) { Log "DRY RUN - nothing will be changed." 'DRY' }
Log "Scanning: $Root"
Log "Message : $Message | Delay: ${DelaySeconds}s | Log: $LogFile"

$folders = Get-ChildItem -Path $Root -Directory | Sort-Object {
    if ($_.Name -match '^(\d+)') { [int]$Matches[1] } else { [int]::MaxValue }
}

$repos = @()
foreach ($f in $folders) {
    if (Test-Path (Join-Path $f.FullName '.git')) {
        $repos += $f
    } else {
        Log "Not a git repo, ignoring: $($f.Name)" 'WARN'
    }
}
Log "Found $($repos.Count) repo(s)."

for ($i = 0; $i -lt $repos.Count; $i++) {
    $repo   = $repos[$i].FullName
    $name   = $repos[$i].Name
    $status = 'SUCCESS'
    $detail = ''
    $done   = @()
    $origBranch = $null

    Write-Host ""
    Log ("=== [{0}/{1}] {2} ===" -f ($i + 1), $repos.Count, $name) 'STEP'

    try {
        # --- sanity checks
        if (-not (Invoke-Git $repo @('rev-parse', '--verify', '--quiet', 'HEAD')).Ok) { throw "SKIP: repo has no commits yet" }
        if (-not (Invoke-Git $repo @('remote', 'get-url', 'origin')).Ok)               { throw "SKIP: no 'origin' remote" }

        $origBranch = (Invoke-Git $repo @('rev-parse', '--abbrev-ref', 'HEAD')).Output

        $dirty = (Invoke-Git $repo @('status', '--porcelain')).Output
        if ($dirty) { Log "  Uncommitted changes found - they will be included in the amended commit." 'WARN' }

        Log "  Fetching origin..."
        $fetch = Invoke-Git $repo @('fetch', 'origin', '--prune')
        if (-not $fetch.Ok) { throw "fetch failed (network/auth?): $($fetch.Output)" }

        # --- detect branches
        $all = Get-AllBranches $repo

        $default = $null
        $head = (Invoke-Git $repo @('symbolic-ref', '--short', 'refs/remotes/origin/HEAD')).Output
        if ($head) {
            $cand = $head -replace '^origin/', ''
            if ($all -contains $cand) { $default = $cand }
        }
        if (-not $default) {
            foreach ($c in 'main', 'master') {
                if ($all -contains $c) { $default = $c; break }
            }
        }
        if (-not $default) { $default = $origBranch }
        if (-not $default -or $default -eq 'HEAD') { throw "SKIP: could not determine default branch" }

        $dev = $null
        foreach ($c in 'dev', 'development') {
            if (($all -contains $c) -and ($c -ne $default)) { $dev = $c; break }
        }

        $others = @($all | Where-Object { $_ -ne $default -and $_ -ne $dev })
        Log "  Default branch : $default"
        if ($dev)    { Log "  Dev branch     : $dev (will be processed first, then merged into $default)" }
        if ($others) { Log "  Other branches : $($others -join ', ') (left untouched)" }

        # --- do the work
        if ($dev) {
            Update-Branch -Repo $repo -Branch $dev
            $done += $dev
            Update-Branch -Repo $repo -Branch $default -MergeFrom $dev
            $done += $default
        } else {
            Update-Branch -Repo $repo -Branch $default
            $done += $default
        }

        if ($DryRun) { $detail = "Would push: $($done -join ' -> ')" }
        else         { $detail = "Pushed: $($done -join ' -> ')" }
        Log "  $name finished OK" 'OK'
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -like 'SKIP:*') {
            $status = 'SKIPPED'
            $detail = $msg.Substring(5).Trim()
            Log "  Skipped: $detail" 'WARN'
        } else {
            $status = 'FAILED'
            $detail = $msg
            Log "  FAILED: $detail" 'ERR'
        }
    }
    finally {
        Remove-Item Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
        # put the repo back on the branch it was on before
        if ($origBranch -and $origBranch -ne 'HEAD' -and -not $DryRun) {
            $cur = (Invoke-Git $repo @('rev-parse', '--abbrev-ref', 'HEAD')).Output
            if ($cur -ne $origBranch) { Invoke-Git $repo @('checkout', $origBranch) | Out-Null }
        }
    }

    $results.Add([pscustomobject]@{
        '#'      = $i + 1
        Repo     = $name
        Status   = $status
        Branches = ($done -join ', ')
        Detail   = $detail
    })

    if ($i -lt $repos.Count - 1 -and -not $DryRun) {
        Log "Waiting $DelaySeconds seconds before next repo..."
        Start-Sleep -Seconds $DelaySeconds
    }
}

# ---------------------------------------------------------------- summary ---
$elapsed = (Get-Date) - $startTime
$ok      = @($results | Where-Object Status -eq 'SUCCESS').Count
$skipped = @($results | Where-Object Status -eq 'SKIPPED').Count
$failed  = @($results | Where-Object Status -eq 'FAILED').Count

Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Cyan
$results | Format-Table '#', Repo, Status, Branches, Detail -AutoSize -Wrap
Write-Host ("Total: {0} | " -f $results.Count) -NoNewline
Write-Host ("Success: {0}  " -f $ok) -ForegroundColor Green -NoNewline
Write-Host ("Skipped: {0}  " -f $skipped) -ForegroundColor Yellow -NoNewline
Write-Host ("Failed: {0}" -f $failed) -ForegroundColor Red
Write-Host ("Time: {0:mm\:ss}   Log file: {1}" -f $elapsed, $LogFile)

if ($failed -gt 0) {
    Write-Host "`nFailed repos:" -ForegroundColor Red
    $results | Where-Object Status -eq 'FAILED' | ForEach-Object { Write-Host "  - $($_.Repo): $($_.Detail)" -ForegroundColor Red }
}

Stop-Transcript | Out-Null
