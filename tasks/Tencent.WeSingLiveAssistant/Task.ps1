$Config = @{
    Identifier = 'Tencent.WeSingLiveAssistant'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://c.y.qq.com/r/ahb8'
    $Request = [System.Net.WebRequest]::Create($Uri)
    $Request.UserAgent = 'Windows'
    $Request.AllowAutoRedirect = $false
    $Response = $Request.GetResponse()

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Response.GetResponseHeader('Location')

    $Response.Dispose()
    return $Result
}

$ComparedProperties = @('InstallerUrl')

return @{
    Config             = $Config
    Ping               = $Ping
    ComparedProperties = $ComparedProperties
}
