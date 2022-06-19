$Config = @{
    Identifier = 'EaseUS.PartitionMaster'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://download.easeus.com/api/index.php/Home/Index/productInstall?pid=5&version=free'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.curNum

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.download3

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
