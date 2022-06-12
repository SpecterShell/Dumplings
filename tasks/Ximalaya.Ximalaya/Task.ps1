$Config = @{
    Identifier = 'Ximalaya.Ximalaya'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/latest.yml'
    $Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
    $Headers = @{
        platform     = 'win32'
        buildversion = '0'
        version      = '0.0.0'
        uid          = ''
    }

    $Result = Invoke-RestMethod -Uri $Uri -Headers $Headers | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri $Result.InstallerUrl -Headers $Headers

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
