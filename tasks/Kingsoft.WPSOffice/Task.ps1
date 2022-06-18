$Config = @{
    Identifier = 'Kingsoft.WPSOffice'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://params.wps.com/api/map/web/newwpsapk?pttoken=newwinpackages'
    $Object1 = (Invoke-RestMethod -Uri $Uri1).staticjs.website.wpsnewpackages.downloads | ConvertFrom-Base64 | ConvertFrom-Json

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object1.'500.1001'.downloadurl

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'WPSOffice_([\d\.]+)\.exe').Groups[1].Value

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.wps.com/whatsnew/pc/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('//*[@id="root"]/div[2]/div/div[1]/div[1]/a/div/p[2]').InnerText.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match(
            $Object2.SelectSingleNode('//*[@id="root"]/div[2]/div/div[1]/div[1]/a/div/p[1]/span[1]').InnerText,
            '(\d{1,2}/\d{1,2}/\d{4})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="root"]/div[2]/div/div[3]/div/div/div//text()').InnerText | Format-Text
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

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
