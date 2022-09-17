$Config = @{
    Identifier = 'JinweiZhiguang.MasterAgent'
    Skip       = $false
}

$Ping = {
    $Result = [ordered]@{}

    $Uri = 'https://mastergo.com/api/v1/config'
    $Object = (Invoke-RestMethod -Uri $Uri).data | ConvertFrom-Json

    # Version
    $Result.Version = $Object.fontWindow

    # InstallerUrl
    $Result.InstallerUrl = "https://static.mastergo.com/plugins/master-agent/windows/MasterAgentInstall-$($Result.Version).exe"

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
