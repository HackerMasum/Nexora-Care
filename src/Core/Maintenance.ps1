param(
    [switch]$AuditOnly
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA) -or
    [string]::IsNullOrWhiteSpace($env:TEMP)) {
    Write-Warning 'LOCALAPPDATA or TEMP is missing; maintenance stopped without changes.'
    return
}

$Root = Join-Path $env:LOCALAPPDATA 'NexoraCare'
$Log = Join-Path $Root 'Logs\Maintenance.log'

function Write-Log {
    param([Parameter(Mandatory)][string]$Message)

    try {
        $LogDirectory = Split-Path -Parent $Log
        if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force -ErrorAction Stop |
                Out-Null
        }

        Add-Content -LiteralPath $Log `
            -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" `
            -ErrorAction Stop
    } catch {
        Write-Warning "Could not write maintenance log: $($_.Exception.Message)"
    }
}

try {
    if ($AuditOnly) {
        Write-Log 'Audit-only maintenance started; no files will be deleted and no power plan will be changed.'
    } else {
        Write-Log 'Maintenance started.'
    }


    $TempPath = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
    $Expected = [IO.Path]::GetFullPath(
        (Join-Path $env:LOCALAPPDATA 'Temp')
    ).TrimEnd('\')

    if ($TempPath -ine $Expected -or
        -not (Test-Path -LiteralPath $TempPath -PathType Container)) {
        Write-Log 'Unexpected or unavailable TEMP path; cleanup skipped.'
        return
    }

    $Cutoff = (Get-Date).AddDays(-1)

    Get-ChildItem -LiteralPath $TempPath -File -Force -ErrorAction Stop |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        } |
        ForEach-Object {
            if ($_.LastWriteTime -lt $Cutoff) {
                if ($AuditOnly) {
                    Write-Log "Audit only: eligible file found: $($_.Name)"
                } else {
                    try {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                        Write-Log "Temporary file removed: $($_.Name)"
                    } catch {
                        Write-Log "Temporary file skipped: $($_.Name); removal failed."
                    }
                }
            }
        }

    if ($AuditOnly) {
        Write-Log 'Audit-only scan finished; no files were removed.'
    } else {
        Write-Log 'Eligible temporary files processed.'

        try {
            & powercfg.exe /setactive SCHEME_BALANCED 2>$null
            $PowerCfgExitCode = $LASTEXITCODE

            if ($PowerCfgExitCode -eq 0) {
                Write-Log 'Balanced power plan activated successfully.'
            } else {
                Write-Log "Power plan change failed with exit code $PowerCfgExitCode."
            }
        } catch {
            Write-Log 'Power plan change unavailable.'
        }

        Write-Log 'Maintenance finished.'
    }
} catch {
    Write-Log "Maintenance error: $($_.Exception.Message)"
}
