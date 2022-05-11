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
