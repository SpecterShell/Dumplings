$Config = @{
    Identifier = 'ByteDance.Douyin#Up'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=7044145585217083655&branch=master&buildId=&uid='
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.manifest.win32.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.manifest.win32.urls.Where({$_.region -eq 'cn'}).url

    # ReleaseTime
    $Result.ReleaseTime = $Object.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.data.releaseNote

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
