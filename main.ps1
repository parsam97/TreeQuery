using module .\SOQLBuilder.psm1

[SOQLBuilder]$QuoteLines = [SOQLBuilder]::new()

$QuoteLines.AddSObjects({ $_ -match 'SBQQ__QuoteLine__c\b' })
$QuoteLines.AddFields({ $_ })
$QuoteLines.AddOrderBy({ $_.nameField -eq $true })
$QuoteLines.AddWhere("SBQQ__ChargeType__c = 'One-Time' AND SBQQ__ProductCode__c LIKE 'SF_%'")
$QuoteLines.AddLimit(10)

[SOQLBuilder]$Quotes = [SOQLBuilder]::new()
$Quotes.AddSObjects({ $_ -eq 'SBQQ__Quote__c' })
$Quotes.AddFields({ $_ })

$QuoteLines.AddParentQueries($Quotes)

# [SOQLBuilder]$sub1Builder = [SOQLBuilder]::new()
# $sub1Builder.AddSObjects({ $_ -match 'blng__RevenueT\w+__c\b' })
# $sub1Builder.AddFields({ $_.custom -eq $true -and $_.name -notlike 'blng__*' })

# [SOQLBuilder]$sub2Builder = [SOQLBuilder]::new()
# $sub2Builder.AddSObjects({ $_ -eq 'Booking__c' })
# $sub2Builder.AddFields({ $_.custom -eq $false })

# $sub1Builder.AddInnerQueries($sub2Builder)
# $QuoteLines.AddInnerQueries($sub1Builder)

$Queries = $QuoteLines.GetQueries()


# Exporting
$CurrentTime = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutputDirectory = ".\data\$CurrentTime"
$Queries | ForEach-Object {
    $QueryString = $_.GetQuery()
    $QueryObject = $_.GetSObjectName()
    $Input = $(Write-Host "Query? " -ForegroundColor Green -NoNewline; Write-Host $QueryString -NoNewline; Read-Host)
    if ($Input -eq 1) {
        continue
    }

    # If there is no folder by the name of the current time, create one
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
    }

    # Write $QueryString to file
    $TempFile = "$OutputDirectory\$QueryObject.soql"
    $QueryString | Out-File -FilePath $TempFile -Encoding utf8

    # Export data
    Invoke-SfCli -Command "data export tree -d $OutputDirectory -q $TempFile" -Quiet | Out-Null
}


# Get fieldInfo sample obj
# $(sf sobject describe -s blng__InvoiceLine__c --json | ConvertFrom-Json).result.fields[0]

# Get childRelationship sample obj
# $(sf sobject describe -s blng__InvoiceLine__c --json | ConvertFrom-Json).result.childRelationships[0]