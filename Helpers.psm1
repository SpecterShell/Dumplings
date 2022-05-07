<#
.SYNOPSIS
    Convert a electron-updater YAML update source into to a PSCustomObject object
.PARAMETER Prefix
    The prefix of the InstallerUrls
.OUTPUTS
    pscustomobject
#>
filter ConvertFrom-ElectronUpdater {
    param (
        [string]
        $Prefix
    )

    $Result = [PSCustomObject]@{}
    $Object = $_ | ConvertFrom-Yaml

    # Version
    if ($Object.version) {
        Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.version.Trim() -InputObject $Result
    }

    # InstallerUrls
    if ($Object.files) {
        Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value "$($Prefix)$([System.Uri]::EscapeDataString($Object.files[0].url))" -InputObject $Result
    }

    # ReleaseTime
    if ($Object.releaseDate) {
        Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $Object.releaseDate.ToUniversalTime() -InputObject $Result
    }

    # ReleaseNotes
    if ($Object.releaseNotes) {
        Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value $Object.releaseNotes.Trim() -InputObject $Result
    }

    return $Result
}

<#
.SYNOPSIS
    Convert unix time in seconds to UTC Time
.OUTPUTS
    datetime
#>
filter ConvertFrom-UnixTimeSeconds {
    if ($_ -is [long]) {
        [System.DateTimeOffset]::FromUnixTimeSeconds($_).UtcDateTime
    }
}

<#
.SYNOPSIS
    Convert unix time in milliseconds to UTC Time
.OUTPUTS
    datetime
#>
filter ConvertFrom-UnixTimeMilliseconds {
    if ($_ -is [long]) {
        [System.DateTimeOffset]::FromUnixTimeMilliseconds($_).UtcDateTime
    }
}

<#
.SYNOPSIS
    Get the garbled-less content from the response object
.OUTPUTS
    string
#>
filter Get-ResponseContent {
    if ($_ -is [Microsoft.PowerShell.Commands.WebResponseObject]) {
        $Stream = $_.RawContentStream
        $Stream.Position = 0;
        return [System.IO.StreamReader]::new($Stream).ReadToEnd()
    }
}

Export-ModuleMember -Function *
