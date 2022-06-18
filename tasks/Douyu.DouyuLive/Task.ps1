$Config = @{
    Identifier = 'Douyu.DouyuLive'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://venus.douyucdn.cn/venus/release/pc/checkPackage?appCode=Douyu_Live_PC_Client'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.versionName

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.fileUrl

    # ReleaseTime
    $Result.ReleaseTime = $Object.data.updateTime | ConvertFrom-UnixTimeSeconds

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.data.changelog | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
