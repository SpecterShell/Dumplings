$Config = @{
    Identifier = 'Xiaomi.XiaomiCloud'
    Skip       = $false
    Notes      = '升级源'
}

$Ping = {
    $Uri = "https://update-server.micloud.xiaomi.net/api/v1/latest.yml?channel=public&platform=win32&arch=x64&machine_id=$((New-Guid).Guid)"
    $Prefix = 'https://cdn.cnbj1.fds.api.mi-img.com/archive/update-server/public/win32/x64/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
