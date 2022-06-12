$Config = @{
    Identifier = 'Baidu.BaiduTranslate'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://fanyiapp.cdn.bcebos.com/fanyi-client/update/latest.yml'
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

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
