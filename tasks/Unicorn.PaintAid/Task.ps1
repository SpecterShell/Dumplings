$Config = @{
    Identifier = 'Unicorn.PaintAid'
    Skip       = $false
}

$Ping = {
    $Uri = 'http://pa.udongman.cn/index.php/upgrade/'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.updater.pa_mversion + '.' + $Object.updater.pa_subversion

    # InstallerUrl
    $Result.InstallerUrl = $Object.updater.TypeWin.package_url + $Object.updater.TypeWin.package.name | ConvertTo-Https

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Result.InstallerUrl, '(\d{8})').Groups[1].Value,
        'yyyyMMdd',
        $null
    ).ToString('yyyy-MM-dd')

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = "http://pa.udongman.cn/index.php/v2/version/detail?version=$($Result.Version)"
    $Object2 = Invoke-RestMethod -Uri $Uri2

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.data.data.func_description | Format-Text
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
