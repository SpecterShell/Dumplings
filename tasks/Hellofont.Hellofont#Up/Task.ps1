$Config = @{
    Identifier = 'Hellofont.Hellofont'
    Skip       = $false
    Notes      = '升级源'
}

$Ping = {
    $Uri = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/latest.yml'
    $Prefix = 'https://hellofont.oss-cn-beijing.aliyuncs.com/Client/Release/'

    $Result = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    # ReleaseNotes
    $Result.ReleaseNotes = $Result.ReleaseNotes.Replace('<br/>', "`n") | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.hellofont.cn/download'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
