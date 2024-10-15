function Invoke-BuildSoql {
    param(
        [String]$SObject,
        [ScriptBlock]$FieldSelector
    )

    $ContextInfo = Invoke-SfCli -Command `
        "sobject describe -s $SobjectName"

    return "SELECT Id FROM $SObject"
}