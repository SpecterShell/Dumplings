$Config = @{
    Identifier = 'Qingfeng.HeyboxAccelerator'
    Skip       = $true
}

$Ping = {
    $Uri = 'https://accoriapi.xiaoheihe.cn/proxy/pc_has_new_version/'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.result.new_version

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.url

    # ReleaseNotes
    $Result.ReleaseNotes = [regex]::Matches($Object.result.change_log, '(?<=<li>).+?(?=</li>)').Value | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
