# Apply default parameters for most web requests if exists
if ($DefaultWebRequestParameters) {
    $PSDefaultParameterValues = $DefaultWebRequestParameters
}

function ConvertFrom-UnixTimeSeconds {
    <#
    .SYNOPSIS
        Convert Unix time in seconds to UTC DateTime
    .PARAMETER Seconds
        The Unix time in seconds
    .OUTPUTS
        datetime
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [long]
        $Seconds
    )

    process {
        [System.DateTimeOffset]::FromUnixTimeSeconds($Seconds).UtcDateTime
    }
}

function ConvertFrom-UnixTimeMilliseconds {
    <#
    .SYNOPSIS
        Convert Unix time in milliseconds to UTC DateTime
    .PARAMETER Milliseconds
        The Unix time in milliseconds
    .OUTPUTS
        datetime
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [long]
        $Milliseconds
    )

    process {
        [System.DateTimeOffset]::FromUnixTimeMilliseconds($Milliseconds).UtcDateTime
    }
}

function ConvertTo-UtcDateTime {
    <#
    .SYNOPSIS
        Change the DateTime from specified timezone to UTC
    .PARAMETER DateTime
        The DateTime object to be converted
    .PARAMETER Id
        Timezone ID
    .OUTPUTS
        datetime
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [datetime]
        $DateTime,

        [parameter(Mandatory)]
        [string]
        $Id
    )

    process {
        [System.TimeZoneInfo]::ConvertTimeToUtc($DateTime, [System.TimeZoneInfo]::FindSystemTimeZoneById($Id))
    }
}

function ConvertFrom-Xml {
    <#
    .SYNOPSIS
        Convert XML text to object
    .PARAMETER InputObject
        The XML text to be converted
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [string]
        $InputObject
    )

    process {
        [xml]$InputObject
    }
}

function ConvertFrom-Base64 {
    <#
    .SYNOPSIS
        Decoding Base64 string
    .PARAMETER InputObject
        The Base64 string to be decoded
    .OUTPUTS
        string
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [string]
        $InputObject
    )

    process {
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
    }
}

function ConvertTo-Https {
    <#
    .SYNOPSIS
        Change the scheme of the URI from HTTP to HTTPS
    .PARAMETER Uri
        The URI to be converted
    .OUTPUTS
        datetime
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Uri
    )

    process {
        $Uri -creplace '^http://', 'https://'
    }
}

function ConvertTo-Lf {
    <#
    .SYNOPSIS
        Replace CRLF endline with LF endline
    .PARAMETER Text
        The text to be converted
    .OUTPUTS
        string
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Text
    )

    process {
        $Text -creplace "`r`n", "`n"
    }
}

function ConvertTo-OrderedList {
    <#
    .SYNOPSIS
        Prepend numbers to the string
    .PARAMETER List
        String(s) of the entries
    .OUTPUTS
        string
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [string]
        $List
    )

    begin {
        $Result = @()
        $i = 1
    }

    process {
        $Result += $List -creplace '(?m)^', { "$(($i++)). " }
    }

    end {
        return $Result -join "`n"
    }
}

function ConvertTo-UnorderedList {
    <#
    .SYNOPSIS
        Prepend "- " to the string
    .PARAMETER List
        String(s) of the entries
    .OUTPUTS
        string
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [string]
        $List
    )

    begin {
        $Result = @()
    }

    process {
        $Result += $List -creplace '(?m)^', '- '
    }

    end {
        return $Result -join "`n"
    }
}

function Get-TempFile {
    <#
    .SYNOPSIS
        Download the file and return its path
    .OUTPUTS
        string
    #>

    $WorkingDirectory = New-Item -Path $env:TEMP -Name 'Panda' -ItemType Directory -Force
    $FilePath = Join-Path -Path $WorkingDirectory -ChildPath (New-Guid).Guid
    Invoke-WebRequest -OutFile $FilePath @args
    return $FilePath
}

function Get-RedirectedUrl {
    <#
    .SYNOPSIS
        Get the redirected URL from the given URL
    .OUTPUTS
        string
    #>

    (Invoke-WebRequest -Method Head @args).BaseResponse.RequestMessage.RequestUri.AbsoluteUri
}

function Read-ResponseContent {
    <#
    .SYNOPSIS
        Get garble-less content from the response object
    .PARAMETER Response
        The response object
    .OUTPUTS
        string
    #>
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebResponseObject]
        $Response
    )

    process {
        $Stream = $Response.RawContentStream
        $Stream.Position = 0;
        return [System.IO.StreamReader]::new($Stream).ReadToEnd()
    }
}

function Read-ProductVersionFromExe {
    <#
    .SYNOPSIS
        Read ProductVersion from EXE file
    .OUTPUTS
        string
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Path
    )

    process {
        [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductVersion.Trim()
    }
}
function Read-ProductVersionFromMsi {
    <#
    .SYNOPSIS
        Read ProductVersion from Database file
    .OUTPUTS
        string
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Path
    )

    begin {
        $WindowsInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
    }

    process {
        $Database = $WindowsInstaller.OpenDatabase($Path, 0)
        $View = $Database.OpenView("SELECT Value FROM Property WHERE Property='ProductVersion'")
        $View.Execute() | Out-Null
        $Record = $View.Fetch()
        Write-Output -InputObject ($Record.GetType().InvokeMember('StringData', 'GetProperty', $null, $Record, 1))
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($View) | Out-Null
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Database) | Out-Null
    }

    end {
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($WindowsInstaller) | Out-Null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

Export-ModuleMember -Function *
