$Config = @{
    'Identifier' = 'Ximalaya.Ximalaya'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/latest.yml'
    $Prefix = 'https://pc.ximalaya.com/ximalaya-pc-updater/api/v1/update/full/'
    $Headers = @{
        platform     = 'win32'
        buildversion = '0'
        version      = '0.0.0'
        uid          = ''
    }

    $Result = Invoke-RestMethod @WebRequestParameters -Uri $Uri -Headers $Headers | ConvertFrom-ElectronUpdater -Prefix $Prefix
    $Result.InstallerUrls = (Invoke-WebRequest @WebRequestParameters -Uri $Result.InstallerUrls -Method Head -Headers $Headers).BaseResponse.RequestMessage.RequestUri.AbsoluteUri
    return $Result
}

return [PSCustomObject]@{Config = $Config; Fetch = $Fetch }
