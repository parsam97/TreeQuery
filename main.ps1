using module .\SOQLBuilder.psm1

[SOQLBuilder]::new().
    AddSObjects({ $_ -match 'SBQQ__QuoteLine__c\b' }).
    AddFields({ $_ }).
    AddParentQueries([SOQLBuilder]::new().
        AddSObjects({ $_ -eq 'SBQQ__Quote__c' }).
        AddFields({ $_ }).
        AddParentQueries([SOQLBuilder]::new().
            AddSObjects({ $_ -eq 'Opportunity' }).
            AddFields({ $_ }))).
    AddWhere("SBQQ__ChargeType__c = 'Recurring' AND SBQQ__ProductCode__c LIKE 'SF_%'").
    AddOrderBy({ $_.name -eq 'CreatedDate' }, 'DESC').
    ExportQueries('Recurring')


# Get fieldInfo sample obj
# $(sf sobject describe -s blng__InvoiceLine__c --json | ConvertFrom-Json).result.fields[0]

# Get childRelationship sample obj
# $(sf sobject describe -s blng__InvoiceLine__c --json | ConvertFrom-Json).result.childRelationships[0]