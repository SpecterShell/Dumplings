$Config = @{
    Identifier = 'LiTang.QianJi'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://gitee.com/qianjigroup/qianji-public-test/raw/master/upgrade-windows.txt'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.versionName

    # InstallerUrl
    $Result.InstallerUrl = $Object.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.changeLogs | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
