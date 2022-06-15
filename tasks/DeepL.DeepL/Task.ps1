$Config = @{
    Identifier = 'DeepL.DeepL'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://appdownload.deepl.com/windows/x64/RELEASES'
    $Content = (Invoke-RestMethod -Uri $Uri).Split(' ')

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Content[1], 'DeepL-([\d\.]+)-full\.nupkg').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = "https://appdownload.deepl.com/windows/full/$($Result.Version.Replace('.', '_'))/DeepLSetup.exe"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
