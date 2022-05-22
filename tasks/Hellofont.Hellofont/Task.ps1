$Config = @{
    'Identifier' = 'Hellofont.Hellofont'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/latest.yml'
    $Prefix = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/'

    $Result = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    # ReleaseNotes
    $Result.ReleaseNotes = [System.Web.HttpUtility]::HtmlDecode($Result.ReleaseNotes).Replace('<br/>', "`n") | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
