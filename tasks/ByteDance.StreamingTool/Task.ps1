$Config = @{
    Identifier = 'ByteDance.StreamingTool'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6888137292980951303&uid=&branch=master&buildId='
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.manifest.win32.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        $Object.data.manifest.win32.extra.x86.installerUrl
        $Object.data.manifest.win32.extra.x64.installerUrl
    )

    # ReleaseNotes
    $Result.ReleaseNotes = '"' + $Object.data.releaseNote + '"' | ConvertFrom-Json | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
