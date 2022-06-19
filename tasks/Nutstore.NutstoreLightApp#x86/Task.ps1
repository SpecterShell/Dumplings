$Config = @{
    Identifier = 'Nutstore.NutstoreLightApp'
    Skip       = $false
    Notes      = 'x86'
}

$Ping = {
    $Uri1 = 'https://www.jianguoyun.com/static/exe/latestVersion'
    $Object1 = (Invoke-RestMethod -Uri $Uri1) | Where-Object -Property 'OS' -EQ -Value 'windows-lightapp-electron-x86'

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.exVer

    # InstallerUrl
    $Result.InstallerUrl = $Object1.exUrl

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
