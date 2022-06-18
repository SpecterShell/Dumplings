$Config = @{
    Identifier = '1MHz.Knotes'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://knotes2-release-cn.s3.amazonaws.com/win/latest.yml'
    $Prefix = 'https://knotes2-release-cn.s3.amazonaws.com/win/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://help.knotesapp.com/changelog-posts/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $Uri3 = 'https://help.knotesapp.cn/changelog-posts/'
    $Object3 = Invoke-WebRequest -Uri $Uri3 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/html/body/div[2]/div/article[1]/div[1]/h2').InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('/html/body/div[2]/div/article[1]/div[2]//*[self::span or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : '') + $_.InnerText } |
            Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    if ($Object3.SelectSingleNode('/html/body/div[2]/div/article[1]/div[1]/h2').InnerText.Contains($Result.Version)) {
        # ReleaseNotesCN
        $Result.ReleaseNotesCN = $Object3.SelectNodes('/html/body/div[2]/div/article[1]/div[2]//*[self::span or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : '') + $_.InnerText } |
            Format-Text
    }
    else {
        # ReleaseNotesCN
        $Result.ReleaseNotesCN = $null
    }

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = $Uri3
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
