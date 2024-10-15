function Invoke-OnProperty {
    param(
        [Object]$InputObject,
        [ScriptBlock]$ProcessBlock
    )

    # Apply the filter using Where-Object
    & $ProcessBlock $InputObject
}