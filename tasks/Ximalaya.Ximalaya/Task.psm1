$Config = @{
    'Identifier' = 'Ximalaya.Ximalaya'
    'Skip'       = $false
}

$Uri = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/latest.yml'
$Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
$Headers = @{
    platform     = 'win32'
    buildversion = '0'
    version      = '0.0.0'
    uid          = ''
}

$Fetch = {
    $Result = Invoke-RestMethod -Uri $Uri -Headers $Headers | ConvertFrom-ElectronUpdater -Prefix $Prefix
    $Result.InstallerUrls = (Invoke-WebRequest -Uri $Result.InstallerUrls -Method Head -Headers $Headers).BaseResponse.RequestMessage.RequestUri.AbsoluteUri
    return $Result
}

Export-ModuleMember -Variable Config, Fetch
