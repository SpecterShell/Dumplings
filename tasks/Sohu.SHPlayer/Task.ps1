$Config = @{
    Identifier = 'Sohu.SHPlayer'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://p2p.hd.sohu.com.cn/update?clienttype=3&version=7.0.0.0'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.cdn

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://tv.sohu.com/down/index.shtml?downLoad=windows'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Read-ResponseContent -Encoding 'GBK' | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/html/body/div[3]/div/div[1]/div[2]/div/p/span').InnerText.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match(
            $Object2.SelectSingleNode('/html/body/div[3]/div/div[1]/div[2]/div/p/span').InnerText,
            '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('/html/body/div[3]/div/div[1]/div[2]/div/div/p').InnerText | Format-Text
    } else {
        # ReleaseTime
        $Result.ReleaseTime = $null

        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
