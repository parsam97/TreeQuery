using module .\SOQL.psm1

. .\Invoke-SfCli.ps1

class SOQLBuilder {
    [SOQL[]]$SoqlArray

    SOQLBuilder() {
        $this.SoqlArray = @()
    }

    [void] AddSObjects([ScriptBlock]$Selector) {
        $SobjectNames = $this.GetCachedList() | Where-Object $Selector
        foreach ($SobjectName in $SobjectNames) {
            $this.SoqlArray += [SOQL]::new($SobjectName)
        }
    }

    [void] AddFields([ScriptBlock]$Selector) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddFields($Selector)
        }
    }

    [void] AddWhere([String]$WhereClause) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddWhere($WhereClause)
        }
    }

    [void] AddOrderBy([ScriptBlock]$Selector) {
        $this.AddOrderBy($Selector, 'ASC')
    }

    [void] AddOrderBy([ScriptBlock]$Selector, [String]$Direction) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddOrderBy($Selector, $Direction)
        }
    }

    [void] AddLimit([Int]$Limit) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddLimit($Limit)
        }
    }

    [void] AddInnerQueries([SOQLBuilder]$ChildBuilder) {
        foreach ($Soql in $this.SoqlArray) {
            foreach ($ChildSoql in $ChildBuilder.SoqlArray) {
                $ChildSoql.IsRelationship = $true
                $Soql.AddFields($ChildSoql)
            }
        }
    }

    [void] AddParentQueries([SOQLBuilder]$ParentBuilder) {
        foreach ($Soql in $this.SoqlArray) {
            foreach ($ParentSoql in $ParentBuilder.SoqlArray) {
                $Soql.AddParentQuery($ParentSoql)
            }
        }
    }

    [Object[]] GetQueries() {
        return $this.SoqlArray
    }

    [Object] GetCachedList() {
        $cachedResults = Get-Variable -Scope Global -Name 'sobjectlist' -ErrorAction SilentlyContinue
        if ($null -ne $cachedResults) {
            return $cachedResults.Value
        }
        $results = Invoke-SfCli -Command "sobject list"
        $this.SetCachedList($results)
        return $results
    }

    [void] SetCachedList($value) {
        Set-Variable -Scope Global -Name 'sobjectlist' -Value $value
    }
}