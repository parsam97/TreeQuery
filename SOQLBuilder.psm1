using module .\SOQL.psm1
. '.\Invoke-SfCli.ps1'

class SOQLBuilder {
    [String]$JobName
    [SOQL[]]$SoqlArray
    [Switch]$IsVerbose
    [String]$TargetOrg

    SOQLBuilder() {
        $this.Initialize()
    }

    SOQLBuilder([ScriptBlock]$SObjectsSelector) {
        $this.Initialize()
        $this.AddSObjects($SObjectsSelector)
    }

    SOQLBuilder([ScriptBlock]$SObjectsSelector, [ScriptBlock]$FieldsSelector) {
        $this.Initialize()
        $this.AddSObjects($SObjectsSelector)
        $this.AddFields($FieldsSelector)
    }

    SOQLBuilder([ScriptBlock]$SObjectsSelector, [ScriptBlock]$FieldsSelector, [String]$WhereClause) {
        $this.Initialize()
        $this.AddSObjects($SObjectsSelector)
        $this.AddFields($FieldsSelector)
        $this.AddWhere($WhereClause)
    }

    SOQLBuilder([ScriptBlock]$SObjectsSelector, [ScriptBlock]$FieldsSelector, [String]$WhereClause, [ScriptBlock]$OrderBySelector) {
        $this.Initialize()
        $this.AddSObjects($SObjectsSelector)
        $this.AddFields($FieldsSelector)
        $this.AddWhere($WhereClause)
        $this.AddOrderBy($OrderBySelector)
    }

    SOQLBuilder([ScriptBlock]$SObjectsSelector, [ScriptBlock]$FieldsSelector, [String]$WhereClause, [ScriptBlock]$OrderBySelector, [String]$OrderByDirection) {
        $this.Initialize()
        $this.AddSObjects($SObjectsSelector)
        $this.AddFields($FieldsSelector)
        $this.AddWhere($WhereClause)
        $this.AddOrderBy($OrderBySelector, $OrderByDirection)
    }

    SOQLBuilder([ScriptBlock]$SObjectsSelector, [ScriptBlock]$FieldsSelector, [String]$WhereClause, [ScriptBlock]$OrderBySelector, [String]$OrderByDirection, [Int]$Limit) {
        $this.Initialize()
        $this.AddSObjects($SObjectsSelector)
        $this.AddFields($FieldsSelector)
        $this.AddWhere($WhereClause)
        $this.AddOrderBy($OrderBySelector, $OrderByDirection)
        $this.AddLimit($Limit)
    }
    
    [void] Initialize() {
        $this.SoqlArray = @()
        $this.JobName = 'TreeQuery'
        $this.SetTargetOrg()
    }

    [void] SetTargetOrg() {
        $SfConfigTargetOrg = Invoke-SfCli -Command 'config get target-org'
        if ($SfConfigTargetOrg.Count -gt 0 -and $SfConfigTargetOrg[0].value) {
            $this.TargetOrg = $SfConfigTargetOrg[0].value
        }
    }

    [SOQLBuilder] MakeVerbose() {
        $this.IsVerbose = $true
        return $this
    }

    [SOQLBuilder] MakeVerbose([Boolean]$MakeVerbose) {
        $this.IsVerbose = $MakeVerbose
        return $this
    }

    [SOQLBuilder] NameJob([String]$JobName) {
        $this.JobName = $JobName
        return $this
    }

    [SOQLBuilder] SetTargetOrgAs([String]$TargetOrg) {
        $SfOrgDisplay = Invoke-SfCli "org display --target-org $TargetOrg" -Debug $this.IsVerbose
        if ($SfOrgDisplay.accessToken) {
            $this.TargetOrg = $SfOrgDisplay.username
        } else {
            $this.TargetOrg = $null
        }
        return $this
    }

    [SOQLBuilder] PrintDefaultSf() {
        if ($this.TargetOrg) {
            Write-Host "========== SF CLI CALLS WILL BE MADE AGAINST THE FOLLOWING TARGET ORG =========="
            $this.TargetOrg | Write-Host
        } else {
            Write-Host "TargetOrg is empty: '$($this.TargetOrg)'"
        }

        return $this
    }

    [SOQLBuilder] AddSObjects([ScriptBlock]$Selector) {
        $SobjectNames = $this.GetCachedList() | Where-Object $Selector

        if ($this.IsVerbose) {
            Write-Debug "$($SobjectNames.Count) selected objects: $($SobjectNames -join ", ")"
        }

        foreach ($SobjectName in $SobjectNames) {
            $this.SoqlArray += [SOQL]::new($SobjectName, $this.IsVerbose, $this.TargetOrg)
        }

        if ($this.SoqlArray.Count -eq 0 -and $this.TargetOrg) {
            $ConfigList = Invoke-SfCli -Command 'config list' -Debug $this.IsVerbose
            $AliasList = Invoke-SfCli -Command 'alias list' -Debug $this.IsVerbose

            $TargetOrgAlias = $ConfigList | Where-Object { $_.key -eq 'target-org'} | Select-Object -ExpandProperty value
            $TargetOrgUsername = $AliasList | Where-Object { $_.alias -eq $TargetOrgAlias } | Select-Object -ExpandProperty value

            Write-Error "Nothing found for selector $($Selector.ToString()). Signed in as $TargetOrgUsername ($TargetOrgAlias)"
        }

        return $this
    }

    [SOQLBuilder] AddFields() {
        return $this.AddFields({ $true })
    }

    [SOQLBuilder] AddFieldString([String]$Field) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddFieldString($Field)
        }
        return $this
    }

    [SOQLBuilder] AddFields([ScriptBlock]$Selector) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddFields($Selector)
        }
        return $this
    }

    [SOQLBuilder] AddWhere([String]$WhereClause) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddWhere($WhereClause)
        }
        return $this
    }

    [SOQLBuilder] AddOrderBy([ScriptBlock]$Selector) {
        $this.AddOrderBy($Selector, 'ASC')
        return $this
    }

    [SOQLBuilder] AddOrderBy([ScriptBlock]$Selector, [String]$Direction) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddOrderBy($Selector, $Direction)
        }
        return $this
    }

    [SOQLBuilder] AddLimit([Int]$Limit) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddLimit($Limit)
        }
        return $this
    }

    [SOQLBuilder] AddOffset([Int]$Offset) {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.AddOffset($Offset)
        }
        return $this
    }

    [SOQLBuilder] AddChildQueries([ScriptBlock]$RelationFieldSelector, [SOQLBuilder]$ChildBuilder) {
        if ($this.IsVerbose) { $ChildBuilder.MakeVerbose() }

        foreach ($Soql in $this.SoqlArray) {
            foreach ($ChildSoql in $ChildBuilder.SoqlArray) {
                $ChildSoql.IsRelationship = $true
                $Soql.AddChildQueries($RelationFieldSelector, $ChildSoql)
            }
        }
        return $this
    }

    [SOQLBuilder] AddChildQueries([SOQLBuilder]$ChildBuilder) {
        return $this.AddChildQueries({ $true }, $ChildBuilder)
    }

    [SOQLBuilder] AddParentQueries([ScriptBlock]$RelationFieldSelector, [SOQLBuilder]$ParentBuilder) {
        foreach ($Soql in $this.SoqlArray) {
            foreach ($ParentSoql in $ParentBuilder.SoqlArray) {
                $Soql.AddParentQueries($RelationFieldSelector, $ParentSoql)
            }
        }
        return $this
    }

    [SOQLBuilder] AddParentQueries([SOQLBuilder]$ParentBuilder) {
        return $this.AddParentQueries({ $true }, $ParentBuilder)
    }

    [SOQLBuilder] ExcludeId() {
        foreach ($Soql in $this.SoqlArray) {
            $Soql.ExcludeId = $true
        }
        return $this
    }

    [String] GetJobName() {
        return $this.JobName
    }

    [Object[]] GetQueries() {
        return $this.SoqlArray
    }

    [Object[]] GetQueryTexts() {
        return $this.SoqlArray | ForEach-Object { $_.GetQueryClean() }
    }

    [Object[]] GetQuerySObjects() {
        return $this.SoqlArray | ForEach-Object { $_.SobjectName }
    }

    [SOQLBuilder] Clear() {
        $this.SoqlArray = @()
        return $this
    }

    [SOQLBuilder] Export() {
        $this.ExportToFile($this.JobName) | Out-Null
        return $this
    }

    [SOQLBuilder] Execute() {
        return $this.Execute($False)
    }

    [SOQLBuilder] Execute([Boolean]$WithPlan) {
        $SoqlDirs = $this.ExportToFile('temp')
        $this.ExecuteQueries($SoqlDirs, $WithPlan)
        $this.RemoveQueryTemps($SoqlDirs)
        return $this
    }

    [void] ExecuteQueries([String[]]$SoqlDirs, [Boolean]$WithPlan) {
        $FileNamePrefix = $this.JobName
        $SoqlDirs | ForEach-Object {
            $SoqlDirectory = $_
            $OutputDirectory = (Get-Item $SoqlDirectory).Directory.FullName
            $Command = "data export tree -o $($this.TargetOrg) --output-dir '$OutputDirectory' --query '$SoqlDirectory' --prefix $FileNamePrefix"
            if ($WithPlan) { $Command += " --plan" }
            Invoke-SfCli -Command $Command -Debug $this.IsVerbose
        }
    }

    [void] RemoveQueryTemps([String[]]$ExportedDirs) {
        $ExportedDirs | ForEach-Object { Remove-Item -Path $_ -Force }
    }

    [String] GetOutputDirectory() {
        $RelativePath = ".\data\$($this.JobName)\"
        # If there is no folder by the name of the output directory, create one
        if (-not (Test-Path -Path $RelativePath)) {
            return (New-Item -Path $RelativePath -ItemType Directory).FullName
        } else {
            return (Get-Item $RelativePath).FullName
        }
    }

    [String[]] GetExportedJsonFiles() {
        return $this.GetOutputDirectory() | ForEach-Object { Get-ChildItem -Path $_ -Filter '*.json' -Recurse }
    }

    [String[]] ExportToFile($Prefix) {
        $ExportedSOQLs = @()
        $this.SoqlArray | ForEach-Object {
            $QueryString = $_.GetQuery()
            $SObjectName = $_.GetSObjectName()

            # Write $QueryString to file
            $TempFile = Join-Path -Path $this.GetOutputDirectory() -ChildPath "$Prefix$SObjectName.soql"
            $QueryString | Out-File -FilePath $TempFile -Encoding utf8

            $ExportedSOQLs += (Get-Item -Path $TempFile).FullName
        }

        return $ExportedSOQLs
    }

    [Object] GetCachedList() {
        $cachedResults = Get-Variable -Scope Global -Name 'sobjectlist' -ErrorAction SilentlyContinue
        if ($null -ne $cachedResults) {
            return $cachedResults.Value
        }

        if ($this.TargetOrg) {
            $results = Invoke-SfCli -Command "sobject list --target-org $($this.TargetOrg)" -Debug $this.IsVerbose
        } else {
            Write-Host -ForegroundColor Red "No default org set. Either set a default target org or use the SetTargetOrgAs(`$Target-Org) method."
            exit 1
        }

        if ($results -ne 1) {
            $this.SetCachedList($results)
        }

        return $results
    }

    [void] SetCachedList($value) {
        Set-Variable -Scope Global -Name 'sobjectlist' -Value $value
    }
}