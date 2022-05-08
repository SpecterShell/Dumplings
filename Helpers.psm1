filter ConvertFrom-ElectronUpdater {
    <#
    .SYNOPSIS
        Convert a electron-updater YAML update source into to a PSCustomObject object
    .PARAMETER Prefix
        The prefix of the InstallerUrls
    .OUTPUTS
        pscustomobject
    #>
    param (
        [string]
        $Prefix
    )

    $Result = [PSCustomObject]@{}
    $Object = $_ | ConvertFrom-Yaml

    # Version
    if ($Object.version) {
        Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.version -InputObject $Result
    }

    # InstallerUrls
    if ($Object.files) {
        $InstallerUrls = "$($Prefix)$([System.Uri]::EscapeDataString($Object.files[0].url))"
        Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $InstallerUrls -InputObject $Result
    }

    # ReleaseTime
    if ($Object.releaseDate) {
        Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $Object.releaseDate.ToUniversalTime() -InputObject $Result
    }

    # ReleaseNotes
    if ($Object.releaseNotes) {
        Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value ($Object.releaseNotes | Format-Text) -InputObject $Result
    }

    return $Result
}

filter ConvertFrom-UnixTimeSeconds {
    <#
    .SYNOPSIS
        Convert unix time in seconds to UTC Time
    .OUTPUTS
        datetime
    #>

    if ($_ -is [long]) {
        [System.DateTimeOffset]::FromUnixTimeSeconds($_).UtcDateTime
    }
}

filter ConvertFrom-UnixTimeMilliseconds {
    <#
    .SYNOPSIS
        Convert unix time in milliseconds to UTC Time
    .OUTPUTS
        datetime
    #>

    if ($_ -is [long]) {
        [System.DateTimeOffset]::FromUnixTimeMilliseconds($_).UtcDateTime
    }
}

filter ConvertTo-OrderedList {
    <#
    .SYNOPSIS
        Prepend numbers to the string
    .OUTPUTS
        string
    #>

    begin {
        $Result = @()
        $i = 1
    }

    process {
        $Result += $_ -creplace '^', { "$(($i++)). " }
    }

    end {
        return $Result -join "`n"
    }
}

filter ConvertTo-UnorderedList {
    <#
    .SYNOPSIS
        Prepend "- " to the string
    .OUTPUTS
        string
    #>

    begin {
        $Result = @()
    }

    process {
        $Result += $_ -creplace '^', '- '
    }

    end {
        return $Result -join "`n"
    }
}

filter Get-ResponseContent {
    <#
    .SYNOPSIS
        Get the garbled-less content from the response object
    .OUTPUTS
        string
    #>

    if ($_ -is [Microsoft.PowerShell.Commands.WebResponseObject]) {
        $Stream = $_.RawContentStream
        $Stream.Position = 0;
        return [System.IO.StreamReader]::new($Stream).ReadToEnd()
    }
}

Export-ModuleMember -Function *
