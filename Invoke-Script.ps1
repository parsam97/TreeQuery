. .\Invoke-BuildQueries.ps1

$MainQueries = Invoke-BuildQueries `
    -SobjectOptions @(
        {
            param($_)
            $_ | Where-Object { $_ -match 'blng__Invoice\w+__c\b' }
        }
    ) `
    -FieldOptions @(
        {
            param($_)
            $_.fields `
                | Where-Object { $_.custom -eq $false } `
                | Select-Object -ExpandProperty name
        }
        Invoke-BuildQueries `
            -SobjectOptions {
                param($_)
                $_.childRelationships `
                    | Where-Object { $_.childSObject -match 'blng__\w+__c\b' } `
                    | Select-Object -ExpandProperty relationshipName
            } `
            -FieldOptions {
                param($_)
                $_.fields `
                    | Where-Object { $_.custom -eq $true } `
                    | Select-Object -ExpandProperty name
            }
    )

$MainQueries | % {
    Write-Host "_: $_"
}

<#

1. the from selector chooses the sobjects of the query
contextInfo is empty, so we use the default 'sobject list'

2. the select selector chooses what goes into the select part of the query
we choose childRelationships and return the relationshipName 

3. we notice this is an inner query

#>