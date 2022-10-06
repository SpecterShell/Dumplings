$Config = @{
    Identifier = 'Qingfeng.HeyboxWow'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://accoriapi.xiaoheihe.cn/wow/check_new_version_v2/'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.result.version_list[0].Version

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.version_list[0].DownloadPath

    # ReleaseTime
    $Result.ReleaseTime = $Object.result.version_list[0].PublishTime | ConvertFrom-UnixTimeMilliseconds

    # ReleaseNotes
    $Result.ReleaseNotes = [regex]::Matches($Object.result.version_list[0].VersionLog, '(?<=<li>).+?(?=</li>)').Value | Format-Text | ConvertTo-UnorderedList

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
