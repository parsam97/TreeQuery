. .\Invoke-SfCli.ps1
. .\Invoke-OnProperty

$SfDescribeListCommand = "sobject list"

function Invoke-SfFetch {
    param(
        [Object]$ContextInfo,
        [ScriptBlock]$SelectorScript
    )

    if (-not $ContextInfo) {
        $ContextInfo = (Invoke-SfCli -Command $SfDescribeListCommand).result
    }

    return Invoke-OnProperty -InputObject $ContextInfo -ProcessBlock $SelectorScript
}