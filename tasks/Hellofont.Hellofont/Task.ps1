$Config = @{
    'Identifier' = 'Hellofont.Hellofont'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/latest.yml'
    $Prefix = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/'

    $Result = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix
    $Result.ReleaseNotes = $Result.ReleaseNotes -replace '<br/>', "`n" -replace '&nbsp;', ' ' | Format-Text
    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
