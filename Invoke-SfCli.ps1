function Invoke-SfCli {
    param(
        [String]$Command,
        [Switch]$Quiet
    )

    if (!$Quiet) {
        Write-Host $Command
    }

    $Command = "sf $Command --json"
    $CliCall = Invoke-Expression $Command
    $ExitCode = $LASTEXITCODE

    $CliCall = $CliCall | ConvertFrom-Json

    if ($CliCall.status -ne 0) {
        return $ExitCode
    }

    return $CliCall.result
}