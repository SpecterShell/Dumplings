$Config = @{
    Identifier = 'Alibaba.Teambition'
    Skip       = $false
    Notes      = '下载源'
}

$Ping = {
    $Uri = 'https://www.teambition.com/site/client-config'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.download_links.pc

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'Teambition-([\d\.]+)-win\.exe').Groups[1].Value

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
