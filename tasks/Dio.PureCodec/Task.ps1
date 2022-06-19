$Config = @{
    Identifier = 'Dio.PureCodec'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.wmzhe.com/soft-13163.html'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.SelectSingleNode('//*[@id="app"]/div[3]/div[1]/div[1]/div[2]/div[1]/ul[1]/li[4]/span[2]').InnerText.Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="download_group"]/li[9]/dl/dd/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact($Result.Version, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'http://qxys.3vfree.cn/ShowPost.asp?ThreadID=206'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $ReleaseNotes = @()
    switch ($Object2.SelectNodes("//*[@id='Post892']/td/table/tr[1]/td[2]/div[2]/div[2]/node()[string()='$($Result.Version)']/following-sibling::node()")) {
        ({ $_.Name -eq '#text' }) { $ReleaseNotes += $_.InnerText }
        ({ $_.Name -eq 'br' -and $_.NextSibling.Name -eq '#text' }) { continue }
        ({ $_.Name -eq 'br' -and $_.NextSibling.Name -eq 'br' }) { break }
    }

    if ($ReleaseNotes) {
        # ReleaseNotes
        $Result.ReleaseNotes = $ReleaseNotes | Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
