. '.\Invoke-SfCli.ps1'

class SOQL {
    [String]$CacheKey
    [Object]$DescribeInfo
    [String]$SobjectName
    [Object]$FieldNames
    [Object]$ChildQueries
    [String]$WhereClause
    [Object]$OrderByFields
    [String]$OrderByDirection = 'ASC'
    [Int]$Limit
    [Int]$Offset
    
    [String[]]$GroupedFieldNames
    [Switch]$IsRelationship
    [Switch]$ExcludeId
    [Int]$Depth
    
    [Boolean]$IsVerbose
    [String]$TargetOrg

    SOQL([String]$SobjectName, [Boolean]$IsVerbose, [String]$TargetOrg) {
        $this.IsVerbose = $IsVerbose
        $this.TargetOrg = $TargetOrg
        $this.Depth = 0
        $this.CacheKey = "TreeQuery:$SobjectName"
        $this.SobjectName = $SobjectName
        $this.DescribeInfo = $this.GetCachedDescribe()
        $this.FieldNames = New-Object System.Collections.Generic.HashSet[String]
        $this.ChildQueries = New-Object System.Collections.Generic.HashSet[String]
        $this.OrderByFields = New-Object System.Collections.Generic.HashSet[String]
        $this.OrderByDirection = 'ASC'
        $this.GroupedFieldNames = @()
        $this.AddField('Id')
    }

    [void] AddField([String]$FieldName) {
        $this.FieldNames.Add($FieldName) | Out-Null
    }

    [void] AddField([SOQL]$InnerSOQL, [String]$RelationshipName) {
        $this.ChildQueries.Add($InnerSOQL.GetQuery($RelationshipName)) | Out-Null
    }

    [void] AddFieldString([String]$FieldName) {
        $this.AddField($FieldName)
    }

    [void] AddRelationshipFields([String]$RelationshipFieldName, [Object]$FieldNames) {
        $ConcatenatedFieldNames = $FieldNames -replace '^', "$RelationshipFieldName."
        foreach ($FieldName in $ConcatenatedFieldNames) {
            $this.AddField($FieldName)
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

    [void] AddFields([Object]$Fields) {
        foreach ($Field in $Fields) {
            $this.AddField($Field.name)
        }
    }
    
    [Object] GetFields([ScriptBlock]$Selector) {
        return $this.GetCachedDescribe().fields | Where-Object $Selector
    }

    [void] AddChildQueries([ScriptBlock]$RelationshipSelector, [SOQL]$InnerSOQL) {
        $this.GetCachedDescribe().childRelationships `
            | Where-Object { $_.childSObject -eq $InnerSOQL.GetSObjectName() } `
            | Where-Object $RelationshipSelector `
            | ForEach-Object {
                $InnerSOQL.Depth += 1
                $this.AddField($InnerSOQL, $_.relationshipName)
            }
    }

    [void] AddParentQueries([ScriptBlock]$RelationFieldSelector, [SOQL]$ParentSOQL) {
        $this.GetCachedDescribe().fields `
            | Where-Object { $_.type -eq 'reference' -and $_.referenceTo -contains $ParentSOQL.GetSObjectName() } `
            | Where-Object $RelationFieldSelector `
            | ForEach-Object {
                $this.AddRelationshipFields($_.relationshipName, $ParentSOQL.FieldNames)
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

    [void] AddOffset([Int]$Offset) {
        $this.Offset = $Offset
    }

    [Object] GetTabs() {
        return "`t" * $this.Depth
    }

    [String] GetSelectElements() {
        $tabs = $this.GetTabs()

        $FieldElements = @()
        $FieldNamesList = New-Object System.Collections.Generic.List[String] -ArgumentList $this.FieldNames

        if ($this.ExcludeId -and $FieldNamesList.Count -gt 1) {
            $FieldNamesList.Remove('Id')
        }

        $FieldNamesJoined = [System.String]::Join(',', $FieldNamesList)
        $FieldElements += $FieldNamesJoined

        $GroupedFieldNamesJoined = [System.String]::Join(",`n$tabs", $this.GroupedFieldNames)
        if ($GroupedFieldNamesJoined) {
            $FieldElements += $GroupedFieldNamesJoined
        }
        
        $ChildQueriesList = New-Object System.Collections.Generic.List[String] -ArgumentList $this.ChildQueries
        $ChildQueriesJoined = [System.String]::Join(',', $ChildQueriesList)
        if ($ChildQueriesJoined) {
            $FieldElements += $ChildQueriesJoined
        }

        return $FieldElements -join ",`n$tabs"
    }

    [String] GetQuery() {
        return $this.GetQuery($this.SobjectName)
    }

    [String] GetQueryClean() {
        return $this.GetQueryPieces($this.SobjectName) -join " "
    }

    [Object] GetQueryPieces([String]$FromName) {
        $QueryPieces = @()

        $QueryPieces += "SELECT $($this.GetSelectElements())"
        $QueryPieces += "FROM $FromName"

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

        if ($this.Offset) {
            $QueryPieces += "OFFSET $($this.Offset)"
        }

        # $QueryPieces[-1] += " ORDER BY Name ASC NULLS FIRST"

        return $QueryPieces
    }

    [String] GetQuery([String]$FromName) {
        # $QueryString = "SELECT $($this.GetSelectElements()) FROM $($this.SobjectName)"
        $QueryPieces = $this.GetQueryPieces($FromName)
        $tabs = $this.GetTabs()
        $QueryString = $QueryPieces -join "`n$tabs"
        # $QueryString = $QueryPieces -join " "

        if ($this.IsRelationship) {
            $QueryString = "($QueryString)"
        }

        $QueryString = "$tabs$QueryString"

        return $QueryString
    }

    [String] GetSObjectName() {
        return $this.SobjectName
    }

    [Object] GetCachedDescribe() {
        $cachedResults = Get-Variable -Scope Global -Name $this.CacheKey -ErrorAction SilentlyContinue
        if ($null -ne $cachedResults) {
            return $cachedResults.Value
        }

        if ($this.TargetOrg) {
            $results = Invoke-SfCli -Command "sobject describe -o $($this.TargetOrg) --sobject $($this.SobjectName)" -Debug $this.IsVerbose
        } else {
            Write-Host -ForegroundColor Red "No default org set. Either set a default target org or use the SetTargetOrgAs(`$Target-Org) method."
            exit 1
        }

        if ($results -ne 1) {
            $this.SetCachedDescribe($results)
        }

        return $results
    }

    [void] SetCachedDescribe($value) {
        Set-Variable -Scope Global -Name $this.CacheKey -Value $value
    }
}