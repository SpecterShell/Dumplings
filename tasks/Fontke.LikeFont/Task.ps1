$Config = @{
    Identifier = 'Fontke.LikeFont'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://desk.likefont.com/client/update'
    $UserAgent = 'likefont/0'
    $Object = Invoke-RestMethod -Uri $Uri -UserAgent $UserAgent

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.desktop.version

    # InstallerUrl
    $Result.InstallerUrl = 'https://www.likefont.com/download/windows/LikeFont.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
