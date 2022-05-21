$Config = @{
    'Identifier' = 'NetEase.MCLauncher'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://x19.update.netease.com/pl/x19_java_patchlist'
    $Object = ("{$(Invoke-RestMethod -Uri $Uri)}" | ConvertFrom-Json).PSObject.Properties | Where-Object -FilterScript { $_.Value.url -cmatch '\.exe' } | Sort-Object -Descending

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object[0].Name

    # InstallerUrl
    $Result.InstallerUrl = "https://x19.gdl.netease.com/MCLauncher_publish_$($Result.Version).exe"

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
