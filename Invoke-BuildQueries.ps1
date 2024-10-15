. .\Invoke-SfFetch.ps1
. .\Invoke-BuildSoql.ps1

function Invoke-BuildQueries {
    param(
        [Object]$ContextInfo,
        [Object[]]$SobjectOptions,
        [Object[]]$FieldOptions
    )

    foreach ($SobjectOption in $SobjectOptions) {
    }

    # $SobjectNames = Invoke-SfFetch -SelectorScript $SelectorFrom

    # $Queries = @()
    # $SobjectNames | % {
    #     $Queries += Invoke-BuildSoql -SObject $_ -FieldSelector $SelectorSelect
    # }

    return $Queries
}