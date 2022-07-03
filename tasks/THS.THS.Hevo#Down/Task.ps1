$Config = @{
    Identifier = 'THS.THS.Hevo'
    Skip       = $false
    Notes      = @'
下载源
https://t.10jqka.com.cn/circle/11889/
'@
}

$Ping = {
    $Uri1 = 'https://ai.10jqka.com.cn/java-extended-api/voyageversion/getDefaultVersionInfo'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = 'https://download.10jqka.com.cn/index/download/id/275/'
    $Request2 = [System.Net.WebRequest]::Create($Uri2)
    $Request2.AllowAutoRedirect = $false
    $Response2 = $Request2.GetResponse()

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.version

    # InstallerUrl
    $Result.InstallerUrl = $Response2.GetResponseHeader('Location')

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.data.description | Format-Text

    $Response2.Dispose()
    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
