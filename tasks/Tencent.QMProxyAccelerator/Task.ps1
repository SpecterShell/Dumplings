$Config = @{
    Identifier = 'Tencent.QMProxyAccelerator'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pc1.gtimg.com/pc/jiasu/data/jiasuadtag.js'
    $Object = [regex]::Match(
        (Invoke-RestMethod -Uri $Uri),
        '(\[.+\])'
    ).Groups[1].Value | ConvertFrom-Json | Where-Object -Property 'adtag' -EQ -Value 'main'

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.Version

    # InstallerUrl
    $Result.InstallerUrl = $Object.url

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
