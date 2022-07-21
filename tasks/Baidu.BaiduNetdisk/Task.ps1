$Config = @{
    Identifier = 'Baidu.BaiduNetdisk'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pan.baidu.com/disk/cmsdata?platform=guanjia'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object.list[0].version, 'V([\d\.]+)').Groups[1].Value

    # RealVersion
    $Result.RealVersion = [regex]::Match($Result.Version, '^(\d+\.\d+\.\d+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.list[0].url

    # ReleaseTime
    $Result.ReleaseTime = $Object.list[0].publish | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.list[0].detail.more | Format-Text | ConvertTo-OrderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://pan.baidu.com/disk/version'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
