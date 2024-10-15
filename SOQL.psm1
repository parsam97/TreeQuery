. .\Invoke-SfCli.ps1

class SOQL {
    [Object]$DescribeInfo
    [String]$SobjectName
    [Object]$FieldNames
    [Object]$InnerQueries
    [String]$WhereClause
    [Object]$OrderByFields
    [String]$OrderByDirection
    [Int]$Limit

    [Switch]$IsRelationship
    [Int]$Depth

    SOQL([String]$SobjectName) {
        $this.Depth = 1
        $this.SobjectName = $SobjectName
        $this.DescribeInfo = $this.GetCachedDescribe()
        $this.FieldNames = New-Object System.Collections.Generic.HashSet[String]
        $this.InnerQueries = New-Object System.Collections.Generic.HashSet[String]
        $this.OrderByFields = New-Object System.Collections.Generic.HashSet[String]
        $this.AddField('Id')
    }

    [void] AddField([String]$FieldName) {
        $this.FieldNames.Add($FieldName) | Out-Null
    }

    [void] AddField([SOQL]$InnerSOQL) {
        $this.InnerQueries.Add($InnerSOQL.GetQuery()) | Out-Null
    }

    [void] AddField([String]$RelationshipFieldName, [Object]$FieldNames) {
        foreach ($FieldName in $FieldNames) {
            $this.AddField("$RelationshipFieldName.$FieldName")
        }
    }

    [void] AddOrderByField([String]$FieldName) {
        if ($this.OrderByFields.Count -ge 32) { return }
        $this.OrderByFields.Add($FieldName) | Out-Null
    }

    [void] AddFields([ScriptBlock]$Selector) {
        $temp = $this.GetCachedDescribe().fields | Where-Object $Selector | Select-Object -ExpandProperty name
        foreach ($FieldName in $temp) {
            $this.AddField($FieldName)
        }
    }

    [void] AddFields([SOQL]$InnerSOQL) {
        $InnerSOQL.SobjectName = $this.GetCachedDescribe().childRelationships | Where-Object {
            $_.childSObject -eq $InnerSOQL.SobjectName
        } | Select-Object -ExpandProperty relationshipName
        if ($InnerSOQL.SobjectName) {
            $InnerSOQL.Depth += 1
            $this.AddField($InnerSOQL)
        }
    }

    [void] AddParentQuery([SOQL]$ParentSOQL) {
        $this.GetCachedDescribe().fields | Where-Object {
            $_.type -eq 'reference' -and $_.referenceTo -contains $ParentSOQL.SobjectName
        } | ForEach-Object {
            $this.AddField($_.relationshipName, $ParentSOQL.FieldNames)
        }
    }

    [void] AddWhere([String]$WhereClause) {
        $this.WhereClause = $WhereClause
    }

    [void] AddOrderBy([ScriptBlock]$Selector, [String]$Direction) {
        $this.OrderByDirection = $Direction
        
        $temp = $this.GetCachedDescribe().fields `
            | Where-Object { $_.sortable } `
            | Where-Object $Selector `
            | Select-Object -ExpandProperty name
        foreach ($FieldName in $temp) {
            $this.AddOrderByField($FieldName)
        }
    }

    [void] AddLimit([Int]$Limit) {
        $this.Limit = $Limit
    }

    [Object] GetTabs() {
        return "`t" * $this.Depth
    }

    [String] GetSelectElements() {
        $FieldElements = @()
        $FieldNamesList = New-Object System.Collections.Generic.List[String] -ArgumentList $this.FieldNames
        $FieldNamesJoined = [System.String]::Join(',', $FieldNamesList)
        $FieldElements += $FieldNamesJoined
        
        $InnerQueriesList = New-Object System.Collections.Generic.List[String] -ArgumentList $this.InnerQueries
        $InnerQueriesJoined = [System.String]::Join(',', $InnerQueriesList)
        if ($InnerQueriesJoined) {
            $FieldElements += $InnerQueriesJoined
        }

        $tabs = $this.GetTabs()

        return $FieldElements -join ",`n$tabs"
    }

    [String] GetQuery() {
        # $QueryString = "SELECT $($this.GetSelectElements()) FROM $($this.SobjectName)"
        # $tabs = $this.GetTabs()

        $QueryPieces = @()

        $QueryPieces += "SELECT $($this.GetSelectElements())"
        $QueryPieces += "FROM $($this.SobjectName)"

        if ($this.WhereClause) {
            $QueryPieces[-1] += " WHERE $($this.WhereClause)"
        }

        if ($this.OrderByFields.Count -gt 0) {
            $OrderByFieldsList = New-Object System.Collections.Generic.List[String] -ArgumentList $this.OrderByFields
            $OrderByFieldsJoined = [System.String]::Join(',', $OrderByFieldsList)
            $QueryPieces += "ORDER BY $OrderByFieldsJoined $($this.OrderByDirection)"
        }

        if ($this.Limit) {
            $QueryPieces += "LIMIT $($this.Limit)"
        }

        # $QueryPieces[-1] += " ORDER BY Name ASC NULLS FIRST"

        # $QueryString = $QueryPieces -join "`n"
        $QueryString = $QueryPieces -join " "

        if ($this.IsRelationship) {
            $QueryString = "($QueryString)"
        }
        return $QueryString
    }

    [String] GetSObjectName() {
        return $this.SobjectName
    }

    [Object] GetCachedDescribe() {
        $cachedResults = Get-Variable -Scope Global -Name $this.SobjectName -ErrorAction SilentlyContinue
        if ($null -ne $cachedResults) {
            return $cachedResults.Value
        }
        $results = Invoke-SfCli -Command "sobject describe -s $($this.SobjectName)"
        $this.SetCachedDescribe($results)
        return $results
    }

    [void] SetCachedDescribe($value) {
        Set-Variable -Scope Global -Name $this.SobjectName -Value $value
    }
}