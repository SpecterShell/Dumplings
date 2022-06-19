$Config = @{
    Identifier = 'HithinkRoyalflush.THS.Hevo'
    Skip       = $false
    Notes      = @'
升级源
https://t.10jqka.com.cn/circle/11889/
'@
}

$Ping = {
    $Uri = 'http://voyager.hevo.10jqka.com.cn/api/checkversion2?tag=HevoB2C&version=8.2.1.15'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.Hevo.HevoUpdate.TargetVersion

    # InstallerUrl
    $Result.InstallerUrl = $Object.Hevo.HevoUpdate.UpdateUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.Hevo.HevoUpdate.UpdateDescription | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
