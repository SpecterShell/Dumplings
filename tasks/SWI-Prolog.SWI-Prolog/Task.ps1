$Config = @{
    Identifier = 'SWI-Prolog.SWI-Prolog'
    Skip       = $false
    Notes      = 'https://www.swi-prolog.org/ChangeLog?branch=stable'
}

$Ping = {
    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = @(
        (Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x86.exe')
        (Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x64.exe')
    )

    # Version
    $Result.Version = [regex]::Match(
        $Result.InstallerUrl[0],
        'swipl-([\d\.]+)'
    ).Groups[1].Value

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
