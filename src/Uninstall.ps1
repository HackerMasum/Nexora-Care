$ErrorActionPreference = 'Stop'
$Root = Join-Path $env:LOCALAPPDATA 'NexoraCare'
$TaskName = 'NexoraCare-AutomaticMaintenance'
$BackupFile = Join-Path $Root 'Backup\MenuShowDelay.json'
$Key = 'HKCU:\Control Panel\Desktop'

$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $Task) {
    Write-Host 'Scheduled task was not present.'
} else {
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host 'Scheduled task removed.'
    } catch {
        Write-Warning "Could not remove scheduled task: $($_.Exception.Message)"
    }
}

if (Test-Path -LiteralPath $BackupFile -PathType Leaf) {
    try {
        $Data = Get-Content -LiteralPath $BackupFile -Raw | ConvertFrom-Json -ErrorAction Stop

        if ($null -eq $Data.PSObject.Properties['ValueExisted']) {
            throw 'Backup is missing ValueExisted.'
        }

        $Current = Get-ItemProperty -LiteralPath $Key -Name MenuShowDelay -ErrorAction SilentlyContinue
        if ($null -ne $Current -and [string]$Current.MenuShowDelay -eq '0') {
            if ([bool]$Data.ValueExisted) {
                if ($null -eq $Data.PSObject.Properties['OriginalValue'] -or
                    [string]::IsNullOrWhiteSpace([string]$Data.OriginalValue)) {
                    throw 'Backup is missing a valid OriginalValue.'
                }

                Set-ItemProperty -LiteralPath $Key -Name MenuShowDelay `
                    -Value ([string]$Data.OriginalValue) -ErrorAction Stop
                Write-Host 'Original MenuShowDelay value restored.'
            } else {
                Remove-ItemProperty -LiteralPath $Key -Name MenuShowDelay -ErrorAction Stop
                Write-Host 'MenuShowDelay value removed to restore its original absence.'
            }
        } else {
            Write-Host 'MenuShowDelay was not 0; left unchanged.'
        }
    } catch {
        Write-Warning "Settings recovery was not completed: $($_.Exception.Message)"
    }
} else {
    Write-Host 'No settings backup found; registry setting left unchanged.'
}

Write-Host "Review and manually remove remaining product files if desired: $Root"
