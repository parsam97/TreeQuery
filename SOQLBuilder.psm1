using module .\SOQL.psm1

. 'C:\Users\parsa\OneDrive - PINKTUM\src\TreeQuery\Invoke-SfCli.ps1'

class SOQLBuilder {
    [String]$JobName
    [SOQL[]]$SoqlArray
    [Switch]$IsVerbose

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
    }

    [SOQLBuilder] MakeVerbose() {
        $this.IsVerbose = $true
        return $this
    }

    [SOQLBuilder] NameJob([String]$JobName) {
        $this.JobName = $JobName
        return $this
    }

    [SOQLBuilder] AddSObjects([ScriptBlock]$Selector) {
        $SobjectNames = $this.GetCachedList() | Where-Object $Selector
        foreach ($SobjectName in $SobjectNames) {
            $this.SoqlArray += [SOQL]::new($SobjectName, $this.IsVerbose)
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

    [SOQLBuilder] AddChildQueries([ScriptBlock]$RelationFieldSelector, [SOQLBuilder]$ChildBuilder) {
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

    [Object[]] GetQueries() {
        return $this.SoqlArray
    }

    [Object[]] GetQueryTexts() {
        return $this.SoqlArray | ForEach-Object { $_.GetQuery() }
    }

    [SOQLBuilder] Export() {
        $this.ExportToFile($this.JobName) | Out-Null
        return $this
    }

    [SOQLBuilder] Execute() {
        $SoqlDirs = $this.ExportToFile('temp')
        $this.ExecuteQueries($SoqlDirs)
        $this.RemoveQueryTemps($SoqlDirs)
        return $this
    }

    [void] ExecuteQueries([String[]]$SoqlDirs) {
        $FileNamePrefix = $this.JobName
        $SoqlDirs | ForEach-Object {
            $SoqlDirectory = $_
            $OutputDirectory = (Get-Item $SoqlDirectory).Directory.FullName
            $Command = "data export beta tree -d '$OutputDirectory' -q '$SoqlDirectory' -x $FileNamePrefix"
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
        $results = Invoke-SfCli -Command "sobject list" -Debug $this.IsVerbose
        $this.SetCachedList($results)
        return $results
    }

    [void] SetCachedList($value) {
        Set-Variable -Scope Global -Name 'sobjectlist' -Value $value
    }
}