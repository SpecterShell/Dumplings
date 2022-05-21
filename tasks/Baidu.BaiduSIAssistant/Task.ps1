$Config = @{
    'Identifier' = 'Baidu.BaiduSIAssistant'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://fanyiapp.cdn.bcebos.com/tongchuan/assistant/update/latest.yml'
    $Object = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.files[0].url

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact($Object.releaseDate, "ddd MMM dd yyyy HH:mm:ss 'GMT'K '(GMT'K')'", [cultureinfo]::GetCultureInfo('en-US')).ToUniversalTime()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.detail | Format-Text | ConvertTo-UnorderedList

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
