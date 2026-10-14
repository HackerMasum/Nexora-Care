param(
    [switch]$AuditOnly
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is missing; uninstall stopped without changes.'
}

$Root = Join-Path $env:LOCALAPPDATA 'NexoraCare'
$TaskName = 'NexoraCare-AutomaticMaintenance'
$BackupFile = Join-Path $Root 'Backup\MenuShowDelay.json'
$Key = 'HKCU:\Control Panel\Desktop'

# Validate the backup before any uninstall action.
$BackupExists = Test-Path -LiteralPath $BackupFile -PathType Leaf
$Data = $null

if ($BackupExists) {
    try {
        $Raw = Get-Content -LiteralPath $BackupFile -Raw -ErrorAction Stop
        $Data = ConvertFrom-Json -InputObject $Raw -ErrorAction Stop

        if ($null -eq $Data -or
            $Data -isnot [System.Management.Automation.PSCustomObject]) {
            throw 'Backup must contain a JSON object.'
        }

        $ValueExistedProperty = $Data.PSObject.Properties['ValueExisted']
        if ($null -eq $ValueExistedProperty -or
            $ValueExistedProperty.Value -isnot [bool]) {
            throw 'ValueExisted must be a JSON Boolean (true or false).'
        }

        if ($ValueExistedProperty.Value) {
            $OriginalValueProperty = $Data.PSObject.Properties['OriginalValue']

            if ($null -eq $OriginalValueProperty -or
                $OriginalValueProperty.Value -isnot [string] -or
                [string]::IsNullOrWhiteSpace($OriginalValueProperty.Value) -or
                $OriginalValueProperty.Value -notmatch '^\d+$') {
                throw 'OriginalValue must be a non-empty string of digits when ValueExisted is true.'
            }
        }
    } catch {
        throw "Backup validation failed; no uninstall actions were performed. $($_.Exception.Message)"
    }
}

if ($AuditOnly) {
    Write-Host 'AUDIT ONLY: no scheduled task or registry changes will be made.'

    if ($BackupExists) {
        Write-Host 'PASS: settings backup is structurally valid.'
        if ($Data.ValueExisted) {
            Write-Host "Audit: would consider restoring original MenuShowDelay value '$($Data.OriginalValue)' only if the current value is 0."
        } else {
            Write-Host 'Audit: would consider removing MenuShowDelay only if its current value is 0.'
        }
    } else {
        Write-Host 'Audit: no settings backup found; registry setting would be left unchanged.'
    }

    Write-Host "Audit: scheduled task '$TaskName' was not inspected or changed."
    Write-Host "Audit complete. Product files were not removed: $Root"
    return
}

# Normal uninstall starts only after any existing backup has passed validation.
try {
    $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($null -eq $Task) {
        Write-Host 'Scheduled task was not present.'
    } else {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host 'Scheduled task removed.'
    }
} catch {
    Write-Warning "Could not remove scheduled task: $($_.Exception.Message)"
}

if (-not $BackupExists) {
    Write-Host 'No settings backup found; registry setting left unchanged.'
} else {
    try {
        $Current = Get-ItemProperty -LiteralPath $Key -Name MenuShowDelay -ErrorAction SilentlyContinue

        if ($null -ne $Current -and [string]$Current.MenuShowDelay -ceq '0') {
            if ($Data.ValueExisted) {
                Set-ItemProperty -LiteralPath $Key -Name MenuShowDelay `
                    -Value $Data.OriginalValue -ErrorAction Stop
                Write-Host 'Original MenuShowDelay value restored.'
            } else {
                Remove-ItemProperty -LiteralPath $Key -Name MenuShowDelay -ErrorAction Stop
                Write-Host 'MenuShowDelay value removed to restore its original absence.'
            }
        } else {
            Write-Host 'MenuShowDelay was not exactly 0 or was absent; left unchanged.'
        }
    } catch {
        Write-Warning "Settings recovery was not completed: $($_.Exception.Message)"
    }
}

Write-Host "Review and manually remove remaining product files if desired: $Root"
