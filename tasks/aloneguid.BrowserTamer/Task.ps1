$Config = @{
    'Identifier' = 'aloneguid.BrowserTamer'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://www.aloneguid.uk/projects/bt'
    $Prefix = 'https://www.aloneguid.uk/projects/bt/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.SelectSingleNode('//*[@id="page"]/main/div/table/tbody/tr[1]/td[1]/strong').InnerText.Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + $Object.SelectSingleNode('//*[@id="page"]/main/div/table/tbody/tr[1]/td[4]/a').Attributes['href'].Value

    # ReleaseTime
    if ($Object.SelectSingleNode('//*[@id="page"]/main/div/table/tbody/tr[1]/td[2]').InnerText.Trim() -cmatch '(\d{2}/\d{2}/\d{2})') {
        $Result.ReleaseTime = [datetime]::ParseExact('20/05/2022', 'dd/MM/yyyy', $null).ToString('yyyy-MM-dd')
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('//*[@id="page"]/main/div/table/tbody/tr[1]/td[3]').InnerText | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.aloneguid.uk/projects/bt#version-history'

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
