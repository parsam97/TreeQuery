function Invoke-SfCli {
    param(
        [String]$Command,
        [Boolean]$Debug
    )

    $Command = "sf $Command --json"

    if ($Debug) {
        Write-Host $Command -ForegroundColor DarkGreen
    }

    $CliCall = Invoke-Expression $Command
    $ExitCode = $LASTEXITCODE

    $CliCall = $CliCall | ConvertFrom-Json

    if ($ExitCode -ne 0 -or $CliCall.code -eq 1 -or $CliCall.status -ne 0) {
        Write-Host $CliCall.message -ForegroundColor Red
        return $ExitCode
    }

    return $CliCall.result
}