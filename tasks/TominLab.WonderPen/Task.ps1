$Config = @{
    Identifier = 'TominLab.WonderPen'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.tominlab.com/api/product/check-update?app=wonderpen'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.version

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri 'https://www.atominn.com/to/get-file/wonderpen?key=win-installer'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.tominlab.com/api/product/update-detail?app=wonderpen'
    $Object2 = (Invoke-RestMethod -Uri $Uri2).data | Where-Object -Property 'version' -EQ -Value $Result.Version

    if ($Object2) {
        # ReleaseTime
        $Result.ReleaseTime = $Object2.date_ms | ConvertFrom-UnixTimeMilliseconds

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.desc.en | Format-Text

        # ReleaseNotesCN
        $Result.ReleaseNotesCN = $Object2.desc.cn | Format-Text
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

        # ReleaseNotes
        $Result.ReleaseNotes = $null

        # ReleaseNotesCN
        $Result.ReleaseNotesCN = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
