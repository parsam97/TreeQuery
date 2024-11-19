using module .\SOQLBuilder.psm1

$ExcludedFields = @('OwnerId')
$FieldSelector = { ($_.createable -eq $true -and $_.updateable -eq $true) -and $_.name -notin $ExcludedFields }

[SOQLBuilder]::new().
    AddSObjects({ $_ -match 'financeperiod__c\b' }).
    AddFields($FieldSelector).
    AddOrderBy({$_.name -eq 'blng__PeriodEndDate__c'}).
    Export().
    Execute()
    | Out-Null