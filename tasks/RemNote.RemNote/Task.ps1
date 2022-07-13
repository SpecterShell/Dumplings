$Config = @{
    Identifier = 'RemNote.RemNote'
    Skip       = $false
    Notes      = 'https://feedback.remnote.com/changelog'
}

$Ping = {
    $Uri = 'https://download.remnote.io/latest.yml'
    $Prefix = 'https://download.remnote.io/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
