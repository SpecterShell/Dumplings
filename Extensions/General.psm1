<#
.SYNOPSIS
  A set of helper functions
#>

# Apply default parameters
if ($DumplingsDefaultParameterValues) {
  $PSDefaultParameterValues = $DumplingsDefaultParameterValues
}

function ConvertFrom-UnixTimeSeconds {
  <#
  .SYNOPSIS
    Convert Unix time in seconds to UTC DateTime object
  .PARAMETER Seconds
    The Unix time in seconds
  #>
  [OutputType([datetime])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The Unix time in seconds'
    )]
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
    Convert Unix time in milliseconds to UTC DateTime object
  .PARAMETER Milliseconds
    The Unix time in milliseconds
  #>
  [OutputType([datetime])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The Unix time in milliseconds'
    )]
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
    Adjust the DateTime from specified timezone to UTC
  .PARAMETER DateTime
    The DateTime object to be converted
  .PARAMETER Id
    TimeZoneInfo ID
  #>
  [OutputType([datetime])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The DateTime object to be converted'
    )]
    [datetime]
    $DateTime,

    [parameter(
      Mandatory,
      HelpMessage = 'TimeZoneInfo ID'
    )]
    [ArgumentCompleter({ [System.TimeZoneInfo]::GetSystemTimeZones() | Select-Object -ExpandProperty Id | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [ValidateScript({ [System.TimeZoneInfo]::FindSystemTimeZoneById($_) })]
    [string]
    $Id
  )

  begin {
    $TimeZoneInfo = [System.TimeZoneInfo]::FindSystemTimeZoneById($Id)
  }

  process {
    [System.TimeZoneInfo]::ConvertTimeToUtc($DateTime, $TimeZoneInfo)
  }
}

function ConvertFrom-Xml {
  <#
  .SYNOPSIS
    Convert XML string to XMLDocument object
  .PARAMETER InputObject
    The XML string to be converted
  #>
  [OutputType([xml])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The XML string to be converted'
    )]
    [string]
    $InputObject
  )

  process {
    [xml]$InputObject
  }
}

function ConvertFrom-Ini {
  <#
  .SYNOPSIS
    Convert INI string into ordered hashtable
  .PARAMETER InputObject
    The INI string to be converted
  .PARAMETER CommentChars
    The characters that describe a comment
    Lines starting with the characters provided will be rendered as comments
    Default: ";"
  .PARAMETER IgnoreComments
    Remove lines determined to be comments from the resulting dictionary
  .NOTES
    This code is modified from https://github.com/lipkau/PsIni under the MIT license

    The MIT License (MIT)

    Copyright (c) 2019 Oliver Lipkau

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  .LINK
    https://github.com/lipkau/PsIni
  #>
  # [OutputType([ordered])]
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The INI string to be converted'
    )]
    [string]
    $InputObject,

    [Parameter(
      HelpMessage = 'The characters that describe a comment'
    )]
    [char[]]
    $CommentChars = @(';'),

    [Parameter(
      HelpMessage = 'Remove lines determined to be comments from the resulting dictionary'
    )]
    [switch]
    $IgnoreComments
  )

  begin {
    $SectionRegex = '^\s*\[(.+)\]\s*$'
    $KeyRegex = "^\s*(.+?)\s*=\s*(['`"]?)(.*)\2\s*$"
    $CommentRegex = "^\s*[$($CommentChars -join '')](.*)$"

    # Name of the section, in case the INI string had none
    $RootSection = '_'
  }

  process {
    $Object = [ordered]@{}
    $CommentCount = 0
    switch -Regex ($InputObject.Split([string[]]@("`r`n", "`n"), [System.StringSplitOptions]::None)) {
      $SectionRegex {
        $Section = $Matches[1]
        $Object[$Section] = [ordered]@{}
        $CommentCount = 0
        continue
      }
      $CommentRegex {
        if (-not $IgnoreComments) {
          if (-not $Section) {
            $Section = $RootSection
            $Object[$Section] = [ordered]@{}
          }
          $Key = '#Comment' + ($CommentCount++)
          $Value = $Matches[1]
          $Object[$Section][$Key] = $Value
        }
        continue
      }
      $KeyRegex {
        if (-not $Section) {
          $Section = $RootSection
          $Object[$Section] = [ordered]@{}
        }
        $Key = $Matches[1]
        $Value = $Matches[3].Replace('\r', "`r").Replace('\n', "`n")
        if ($Object[$Section][$Key]) {
          if ($Object[$Section][$Key] -is [array]) {
            $Object[$Section][$Key] += $Value
          } else {
            $Object[$Section][$Key] = @($Object[$Section][$Key], $Value)
          }
        } else {
          $Object[$Section][$Key] = $Value
        }
        continue
      }
    }
    return $Object
  }
}

function ConvertFrom-Base64 {
  <#
  .SYNOPSIS
    Decode Base64 string
  .PARAMETER InputObject
    The Base64 string to be decoded
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The Base64 string to be decoded'
    )]
    [string]
    $InputObject
  )

  process {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
  }
}

function ConvertTo-LF {
  <#
  .SYNOPSIS
    Replace all types of line endings with LF
  .PARAMETER InputObject
    The string to be converted
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The string to be converted'
    )]
    [string]
    $InputObject
  )

  process {
    $InputObject.ReplaceLineEndings("`n")
  }
}

function Split-LineEndings {
  <#
  .SYNOPSIS
    Split string on all types of line endings
  .PARAMETER InputObject
    The string to be splitted
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The string to be splitted'
    )]
    [string]
    $InputObject
  )

  process {
    $InputObject.Split([string[]]@("`r`n", "`n"), [System.StringSplitOptions]::None)
  }
}

function ConvertTo-Https {
  <#
  .SYNOPSIS
    Change the scheme of the URI from HTTP to HTTPS
  .PARAMETER Uri
    The Uniform Resource Identifier (URI) to be converted
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'Uniform Resource Identifier (URI)'
    )]
    [string]
    $Uri
  )

  process {
    $Uri -creplace '^http://', 'https://'
  }
}

function ConvertTo-UnescapedUri {
  <#
  .SYNOPSIS
    Unescape the URI
  .PARAMETER Uri
    The Uniform Resource Identifier (URI) to be converted
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'Uniform Resource Identifier (URI)'
    )]
    [string]
    $Uri
  )

  process {
    [uri]::UnescapeDataString($Uri)
  }
}

function ConvertTo-HtmlDecodedText {
  <#
  .SYNOPSIS
    Converts a string that has been HTML-encoded for HTTP transmission into a decoded string.
  .PARAMETER InputObject
    The string to be decoded
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The string to be decoded'
    )]
    [string]
    $InputObject
  )

  process {
    [System.Net.WebUtility]::HtmlDecode($InputObject)
  }
}

function ConvertTo-OrderedList {
  <#
  .SYNOPSIS
    Prepend numbers to each string
  .PARAMETER InputObject
    The strings to be prepended
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The strings to be prepended'
    )]
    [string[]]
    $InputObject
  )

  begin {
    $Result = @()
    $i = 1
  }

  process {
    $Result += $InputObject -creplace '(?m)^', { "$(($i++)). " }
  }

  end {
    return $Result -join "`n"
  }
}

function ConvertTo-UnorderedList {
  <#
  .SYNOPSIS
    Prepend "- " to each string
  .PARAMETER InputObject
    The strings to be prepended
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The strings to be prepended'
    )]
    [string[]]
    $InputObject
  )

  begin {
    $Result = @()
  }

  process {
    $Result += $InputObject -creplace '(?m)^', '- '
  }

  end {
    return $Result -join "`n"
  }
}

function Get-TempFile {
  <#
  .SYNOPSIS
    Download the file and return its path
  #>

  $WorkingDirectory = New-Item -Path $env:TEMP -Name 'Dumplings' -ItemType Directory -Force
  $FilePath = Join-Path -Path $WorkingDirectory -ChildPath (New-Guid).Guid
  Invoke-WebRequest -OutFile $FilePath @args
  return $FilePath
}

function Expand-TempArchive {
  <#
  .SYNOPSIS
    Extract files from ZIP archive and return the path of root directory
  .PARAMETER Path
    The path to the root directory to which the files were extracted
  #>
  [OutputType([string])]
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The path to the ZIP archive'
    )]
    [string]
    $Path
  )

  process {
    $WorkingDirectory = New-Item -Path $Env:TEMP -Name 'Dumplings' -ItemType Directory -Force
    $FolderPath = Join-Path -Path $WorkingDirectory -ChildPath (New-Guid).Guid
    Expand-Archive -Path $Path -DestinationPath $FolderPath
    return $FolderPath
  }
}

function Get-RedirectedUrl {
  <#
  .SYNOPSIS
    Get the redirected URI from the given URI
  #>

  (Invoke-WebRequest -Method Head @args).BaseResponse.RequestMessage.RequestUri.AbsoluteUri
}

function Get-RedirectedUrl1st {
  <#
  .SYNOPSIS
    Get the first redirected URL from the given URL
  .PARAMETER Uri
    The Uniform Resource Identifier (URI) that will be redirected
  .PARAMETER UserAgent
    The user agent string for the web request
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The URI that will be redirected'
    )]
    [string]
    $Uri,

    [Parameter(
      HelpMessage = 'The user agent string for the web request'
    )]
    [string]
    $UserAgent
  )

  process {
    $Request = [System.Net.WebRequest]::Create($Uri)
    if ($UserAgent) {
      $Request.UserAgent = $UserAgent
    }
    $Request.AllowAutoRedirect = $false
    $Response = $Request.GetResponse()
    Write-Output -InputObject $Response.GetResponseHeader('Location')
    $Response.Close()
  }
}

function Read-ResponseContent {
  <#
  .SYNOPSIS
    Get garble-less content from the response object
  .PARAMETER Response
    The response object from the Invoke-WebRequest command
  .PARAMETER Encoding
    The encoding of the content
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The response object from the Invoke-WebRequest command'
    )]
    [Microsoft.PowerShell.Commands.WebResponseObject]
    $Response,

    [Parameter(
      HelpMessage = 'The encoding of the content'
    )]
    [ArgumentCompleter({ [System.Text.Encoding]::GetEncodings() | Select-Object -ExpandProperty Name | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [string]
    $Encoding
  )

  process {
    $Stream = $Response.RawContentStream
    # The stream of the response content passed to function may be closed.
    # Force open the stream by setting the pointer to the beginning
    $Stream.Position = 0
    if ($Encoding) {
      return [System.IO.StreamReader]::new($Stream, [System.Text.Encoding]::GetEncoding($Encoding)).ReadToEnd()
    } else {
      return [System.IO.StreamReader]::new($Stream).ReadToEnd()
    }
  }
}

function Get-EmbeddedJson {
  <#
  .SYNOPSIS
    Extract embedded JSON from the string, especially the JSONP ones
  .PARAMETER InputObject
    The string containing the JSON
  .PARAMETER StartsFrom
    The string indicating where the JSON starts after
  .LINK
    https://stackoverflow.com/questions/48470971/how-to-deserialize-a-jsonp-response-preferably-with-jsontextreader-and-not-a-st
  .LINK
    https://github.com/PowerShell/PowerShell/blob/master/src/Microsoft.PowerShell.Commands.Utility/commands/utility/WebCmdlet/JsonObject.cs
  #>
  [OutputType([string])]
  param (
    [parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The string containing the JSON'
    )]
    [string]
    $InputObject,

    [parameter(
      Mandatory,
      HelpMessage = 'The string indicating where the JSON starts after'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $StartsFrom
  )

  process {
    [Newtonsoft.Json.JsonConvert]::DeserializeObject(
      $InputObject.Substring($InputObject.IndexOf($StartsFrom) + $StartsFrom.Length),
      [Newtonsoft.Json.JsonSerializerSettings]@{
        TypeNameHandling         = [Newtonsoft.Json.TypeNameHandling]::None
        MetadataPropertyHandling = [Newtonsoft.Json.MetadataPropertyHandling]::Ignore
        CheckAdditionalContent   = $false
      }
    ).ToString()
  }
}

function Read-ProductVersionFromExe {
  <#
  .SYNOPSIS
    Read the ProductVersion property of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([string])]
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The path to the EXE file'
    )]
    [string]
    $Path
  )

  process {
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductVersion.Trim()
  }
}

function Read-FileVersionFromExe {
  <#
  .SYNOPSIS
    Read the FileVersion property of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([string])]
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The path to the EXE file'
    )]
    [string]
    $Path
  )

  process {
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion.Trim()
  }
}

function Read-ProductVersionFromMsi {
  <#
  .SYNOPSIS
    Read the ProductVersion property of the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The path to the MSI file'
    )]
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

  # clean {
  #   [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($WindowsInstaller) | Out-Null
  #   [System.GC]::Collect()
  #   [System.GC]::WaitForPendingFinalizers()
  # }
}

function Compare-Version {
  <#
  .SYNOPSIS
    Compare two versions
  .PARAMETER ReferenceVersion
    The version used as a reference for comparison
  .PARAMETER DifferenceVersion
    The version that is compared to the reference version
  #>
  [OutputType([int])]
  param (
    [Parameter(
      Mandatory,
      HelpMessage = 'The version used as a reference for comparison'
    )]
    [string]
    $ReferenceVersion,

    [Parameter(
      Mandatory,
      HelpMessage = 'The version that is compared to the reference version'
    )]
    [string]
    $DifferenceVersion
  )

  $ReferenceVersionPadded = $ReferenceVersion -creplace '\d+', { $_.Value.PadLeft(20) }
  $DifferenceVersionPadded = $DifferenceVersion -creplace '\d+', { $_.Value.PadLeft(20) }

  if ($ReferenceVersionPadded -lt $DifferenceVersionPadded) {
    return 1
  } elseif ($ReferenceVersionPadded -gt $DifferenceVersionPadded) {
    return -1
  } else {
    return 0
  }
}

function ConvertFrom-ElectronUpdater {
  <#
  .SYNOPSIS
    Convert Electron Updater manifest into organized hashtable
  .PARAMETER InputObject
    The YAML object of the Electron Updater manifest to be handled
  .PARAMETER Prefix
    The prefix of the InstallerUrl
    If the installer is located in the same directory as the manifest, the prefix of its URL will be ignored
  .PARAMETER Locale
    The locale of the ReleaseNotes
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The YAML object of the Electron Updater manifest to be handled'
    )]
    $InputObject,

    [Parameter(
      HelpMessage = 'The prefix of the InstallerUrl'
    )]
    [string]
    $Prefix = '',

    [Parameter(
      HelpMessage = 'The locale of the ReleaseNotes'
    )]
    [string]
    $Locale = 'en-US'
  )

  $Result = [ordered]@{
    Installer = @()
    Locale    = @()
  }

  # Version
  $Result.Version = $InputObject.version

  # InstallerUrl
  $Result.Installer += [ordered]@{
    InstallerUrl = $Prefix + $InputObject.files[0].url
  }

  # ReleaseTime
  if ($InputObject.releaseDate) {
    $Result.ReleaseTime = (Get-Date -Date $InputObject.releaseDate).ToUniversalTime()
  }

  # ReleaseNotes
  if ($InputObject.releaseNotes) {
    $Result.Locale += [ordered]@{
      Locale = $Locale
      Key    = 'ReleaseNotes'
      Value  = $InputObject.releaseNotes | Format-Text
    }
  }

  return $Result
}

Export-ModuleMember -Function *
