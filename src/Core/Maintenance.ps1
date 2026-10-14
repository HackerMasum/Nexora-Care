$ErrorActionPreference = 'Continue'
$Root = Join-Path $env:LOCALAPPDATA 'NexoraCare'
$Log = Join-Path $Root 'Logs\Maintenance.log'

function Write-Log($Message) {
    Add-Content -LiteralPath $Log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

try {
    Write-Log 'Maintenance started.'
    $TempPath = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
    $Expected = [IO.Path]::GetFullPath(
        (Join-Path $env:LOCALAPPDATA 'Temp')
    ).TrimEnd('\')

    if ($TempPath -ieq $Expected -and (Test-Path -LiteralPath $TempPath -PathType Container)) {
        Get-ChildItem -LiteralPath $TempPath -File -Force -ErrorAction SilentlyContinue |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
            ForEach-Object {
                try {
                    if ($_.LastWriteTime -lt (Get-Date).AddDays(-1)) {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                    }
                } catch {
                    Write-Log 'A temporary file was skipped (locked or inaccessible).'
                }
            }
        Write-Log 'Eligible temporary files processed.'
    } else {
        Write-Log 'Unexpected TEMP path; cleanup skipped.'
    }

    try {
        & powercfg.exe /setactive SCHEME_BALANCED 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'Balanced power plan activated successfully.'
        } else {
            Write-Log "Power plan change failed with exit code $LASTEXITCODE."
        }
    } catch {
        Write-Log 'Power plan change unavailable.'
    }

    Write-Log 'Maintenance finished.'
} catch {
    Write-Log "Maintenance error: $($_.Exception.Message)"
}
