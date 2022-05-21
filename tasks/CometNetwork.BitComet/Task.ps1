$Config = @{
    'Identifier' = 'CometNetwork.BitComet'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://update.bitcomet.com/client/bitcomet/'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = 'https://www.bitcomet.com/en/changelog'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.BitComet.AutoUpdate.UpdateGroupList.LatestDownload.file1.'#text'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.bitcomet.com/achive/BitComet_$($Result.Version)_setup.exe"

    # ReleaseTime
    if ($Object2.SelectSingleNode('/html/body/div/div/dl/dt[1]').InnerText -cmatch '(\d{4}\.\d{1,2}\.\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('/html/body/div/div/dl/dt[1]/following-sibling::dd[count(.|/html/body/div/div/dl/dt[2]/preceding-sibling::dd)=count(/html/body/div/div/dl/dt[2]/preceding-sibling::dd)]').InnerText | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
