$Config = @{
    Identifier = 'Qingfeng.HeyboxWow'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://accoriapi.xiaoheihe.cn/wow/check_new_version_v2/'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.result.new_version

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.url

    # ReleaseNotes
    $Result.ReleaseNotes = [regex]::Matches($Object.result.change_log, '(?<=<li>).+?(?=</li>)').Value | Format-Text | ConvertTo-UnorderedList

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
