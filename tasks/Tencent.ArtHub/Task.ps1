$Config = @{
    'Identifier' = 'Tencent.ArtHub'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://dldir1.qq.com/arthub/desktop/versions/latest-win32.yml'
    $Prefix = 'https://dldir1.qq.com/arthub/desktop/versions/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
