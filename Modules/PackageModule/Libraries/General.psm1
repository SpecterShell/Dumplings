#Requires -Version 7.4

# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'PSNativeCommandUseErrorActionPreference', Justification = 'This is a built-in variable of PowerShell')]
$PSNativeCommandUseErrorActionPreference = $true

function ConvertFrom-UnixTimeSeconds {
  <#
  .SYNOPSIS
    Convert Unix time in seconds to DateTime object in UTC timezone
  .PARAMETER Seconds
    The Unix time in seconds
  #>
  [OutputType([datetime])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The Unix time in seconds')]
    [long]$Seconds
  )

  process {
    [System.DateTimeOffset]::FromUnixTimeSeconds($Seconds).UtcDateTime
  }
}

function ConvertFrom-UnixTimeMilliseconds {
  <#
  .SYNOPSIS
    Convert Unix time in milliseconds to DateTime object in UTC timezone
  .PARAMETER Milliseconds
    The Unix time in milliseconds
  #>
  [OutputType([datetime])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The Unix time in milliseconds')]
    [long]$Milliseconds
  )

  process {
    [System.DateTimeOffset]::FromUnixTimeMilliseconds($Milliseconds).UtcDateTime
  }
}

function ConvertTo-UtcDateTime {
  <#
  .SYNOPSIS
    Adjust DateTime object from specified timezone to UTC
  .PARAMETER DateTime
    The DateTime object
  .PARAMETER Id
    The TimeZoneInfo ID of the source timezone of the DateTime object
  #>
  [OutputType([datetime])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The DateTime object')]
    [datetime]$DateTime,

    [Parameter(Mandatory, HelpMessage = 'The TimeZoneInfo ID of the source timezone of the DateTime object')]
    [ArgumentCompleter({ [System.TimeZoneInfo]::GetSystemTimeZones() | Select-Object -ExpandProperty Id | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [ValidateScript({ [System.TimeZoneInfo]::FindSystemTimeZoneById($_) })]
    [string]$Id
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
  .PARAMETER Content
    The string containing the XML content
  #>
  [OutputType([xml])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string containing the XML content')]
    [AllowEmptyString()]
    [string]$Content
  )

  begin {
    $StringBuilder = [System.Text.StringBuilder]::new()
  }

  process {
    $null = $StringBuilder.AppendLine($Content)
  }

  end {
    [xml]($StringBuilder.ToString() | Convert-LineEndings)
  }
}

function ConvertFrom-Ini {
  <#
  .SYNOPSIS
    Convert INI string into ordered hashtable
  .PARAMETER Content
    The string containing the INI content
  .PARAMETER CommentChars
    The characters that describe a comment
    Lines starting with the characters provided will be rendered as comments
  .PARAMETER IgnoreComments
    Remove lines determined to be comments from the resulting dictionary
  .NOTES
    These codes were modified from https://github.com/lipkau/PsIni under the MIT license

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
  [OutputType([System.Collections.Specialized.OrderedDictionary])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string containing the INI content')]
    [AllowEmptyString()]
    [string]$Content,

    [Parameter(HelpMessage = 'The characters that describe a comment')]
    [char[]]$CommentChars = @(';', '#'),

    [Parameter(HelpMessage = 'Remove lines determined to be comments from the resulting dictionary')]
    [switch]$IgnoreComments
  )

  begin {
    $SectionRegex = '^\s*\[(.+)\]\s*$'
    $KeyRegex = "^\s*(.+?)\s*=\s*(['`"]?)(.*)\2\s*$"
    $CommentRegex = "^\s*[$($CommentChars -join '')](.*)$"

    # Name of the section, in case the INI string had none
    $RootSection = '_'

    $StringBuilder = [System.Text.StringBuilder]::new()
    $CommentCount = 0
  }

  process {
    $null = $StringBuilder.AppendLine($Content)
  }

  end {
    $Object = [ordered]@{}
    foreach ($Text in $StringBuilder.ToString() | Split-LineEndings) {
      switch -Regex ($Text) {
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
    }
    return $Object
  }
}

function ConvertFrom-Base64 {
  <#
  .SYNOPSIS
    Decode a Base64 string into a UTF-8 string or a byte array
  .PARAMETER Content
    The Base64 string
  .PARAMETER Encoding
    The text encoding the Base64 string should be decoded to
  .PARAMETER AsByteStream
    Decode the Base64 string to a byte array
  #>
  [OutputType([string])]
  [CmdletBinding(DefaultParameterSetName = 'String')]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The Base64 string')]
    [AllowEmptyString()]
    [string]$Content,

    [Parameter(ParameterSetName = 'String', HelpMessage = 'The text encoding the Base64 string should be decoded to')]
    [ArgumentCompleter({ [System.Text.Encoding]::GetEncodings() | Select-Object -ExpandProperty Name | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [string]$Encoding,

    [Parameter(ParameterSetName = 'Bytes', HelpMessage = 'Decode the Base64 string to a byte array')]
    [switch]$AsByteStream
  )

  process {
    if ($AsByteStream) {
      [System.Convert]::FromBase64String($Content)
    } elseif ($Encoding) {
      [System.Text.Encoding]::GetEncoding($Encoding).GetString([System.Convert]::FromBase64String($Content))
    } else {
      [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Content))
    }
  }
}

function ConvertTo-HtmlDecodedText {
  <#
  .SYNOPSIS
    Decode the character entities in the given text into their corresponding characters
  .PARAMETER Content
    The string with character entities
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string with character entities')]
    [AllowEmptyString()]
    [string]$Content
  )

  process {
    [System.Net.WebUtility]::HtmlDecode($Content)
  }
}

function ConvertTo-UnescapedUri {
  <#
  .SYNOPSIS
    Unescape the URI
  .PARAMETER Uri
    The Uniform Resource Identifier (URI)
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The Uniform Resource Identifier (URI)')]
    [AllowEmptyString()]
    [string]$Uri
  )

  process {
    [uri]::UnescapeDataString($Uri)
  }
}

function ConvertTo-MarkdownEscapedText {
  <#
  .SYNOPSIS
    Escape the characters that could be interpreted as Markdown syntax
  .PARAMETER Content
    The string to escape the characters
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string to escape the characters')]
    [AllowEmptyString()]
    [string]$Content
  )

  process {
    $Content -replace '([_*\[\]()~`<>#+\-|{}.!\\])', '\$1'
  }
}

function Split-Uri {
  <#
  .SYNOPSIS
    Split the URI
  .PARAMETER Uri
    The Uniform Resource Identifier (URI) to be splitted
  .PARAMETER Parent
    The parent part of the URI
  .PARAMETER LeftPart
    The left part of the URI
  .PARAMETER Components
    The component of the URI
  .PARAMETER Format
    Control how special characters are escaped
  #>
  [OutputType([string])]
  [CmdletBinding(DefaultParameterSetName = 'ParentSet')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'Result', Justification = 'False positive')]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The Uniform Resource Identifier (URI) to be splitted')]
    [uri]$Uri,

    [Parameter(ParameterSetName = 'ParentSet', HelpMessage = 'The parent part of the URI')]
    [switch]$Parent,

    [Parameter(ParameterSetName = 'LeftPartSet', HelpMessage = 'The left part of the URI')]
    [System.UriPartial]$LeftPart = [System.UriPartial]::Path,

    [Parameter(ParameterSetName = 'ComponentSet', HelpMessage = 'The component of the URI')]
    [System.UriComponents[]]$Components,

    [Parameter(ParameterSetName = 'ComponentSet', HelpMessage = 'Control how special characters are escaped')]
    [System.UriFormat]$Format = [System.UriFormat]::UriEscaped
  )

  process {
    switch ($PSCmdlet.ParameterSetName) {
      'ParentSet' {
        return [uri]::new($Uri, '.').OriginalString
      }
      'LeftPartSet' {
        return $Uri.GetLeftPart($LeftPart)
      }
      'ComponentSet' {
        $Components = $Components | ForEach-Object -Begin { $Result = $null } -Process { $Result = $_ -bor $Result } -End { $Result }
        return $Uri.GetComponents($Components, $Format)
      }
      Default {
        throw 'Invalid parameter set'
      }
    }
  }
}

function Join-Uri {
  <#
  .SYNOPSIS
    Join the URIs
  .PARAMETER Uri
    The main URI to which the child URI is appended
  .PARAMETER ChildUri
    The elements to be applied to the main URI
  .PARAMETER AdditionalChildUri
    Additional elements to be applied to the main URI
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The main URI to which the child URI is appended')]
    [uri[]]$Uri,

    [Parameter(Position = 1, Mandatory, HelpMessage = 'The elements to be applied to the main URI')]
    [string[]]$ChildUri,

    [Parameter(Position = 2, ValueFromRemainingArguments, HelpMessage = 'Additional elements to be applied to the main URI')]
    [string[]]$AdditionalChildUri
  )

  process {
    foreach ($SubUri in $Uri) {
      foreach ($SubChildUri in $ChildUri) {
        $SubUri = [uri]::new($SubUri, $SubChildUri, $true)
      }
      foreach ($SubAdditionalChildUri in $AdditionalChildUri) {
        $SubUri = [uri]::new($SubUri, $SubAdditionalChildUri, $true)
      }
      Write-Output -InputObject $SubUri.AbsoluteUri
    }
  }
}

function Split-LineEndings {
  <#
  .SYNOPSIS
    Split string on all types of line endings
  .PARAMETER Content
    The string to split
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string to split')]
    [AllowEmptyString()]
    [string]$Content
  )

  process {
    $Content.Split([string[]]@("`r`n", "`n"), [System.StringSplitOptions]::None)
  }
}

function Convert-LineEndings {
  <#
  .SYNOPSIS
    Replace all types of line endings with the specified one
  .PARAMETER Content
    The string to convert the line endings
  .PARAMETER LineEnding
    The line ending to convert to
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The string to be converted')]
    [AllowEmptyString()]
    [string]$Content,

    [Parameter(HelpMessage = 'The line ending to convert to')]
    [ArgumentCompletions("`n", "`r`n")]
    [string]$LineEnding = "`n"
  )

  process {
    $Content.ReplaceLineEndings($LineEnding)
  }
}

function ConvertTo-Https {
  <#
  .SYNOPSIS
    Change the scheme of the URI from HTTP to HTTPS
  .PARAMETER Uri
    The Uniform Resource Identifier (URI)
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The Uniform Resource Identifier (URI)')]
    [AllowEmptyString()]
    [string]$Uri
  )

  process {
    $Uri -creplace '^http://', 'https://'
  }
}

function ConvertTo-OrderedList {
  <#
  .SYNOPSIS
    Prepend ordered numbers ("1. ", "2. ", ...) to each line of the strings and then concatenate the strings into one
  .PARAMETER Content
    The strings to prepend
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The strings to prepend')]
    [string[]]$Content
  )

  begin {
    $StringList = [System.Collections.Generic.List[string]]::new()
    $i = 1
  }

  process {
    foreach ($SubContent in $Content) {
      $StringList.Add(($Content -creplace '(?m)^', { "$(($i++)). " }))
    }
  }

  end {
    return $StringList -join "`n"
  }
}

function ConvertTo-UnorderedList {
  <#
  .SYNOPSIS
    Prepend "- " to each line of the strings and then concatenate the strings into one
  .PARAMETER Content
    The strings to prepend
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The strings to prepend')]
    [string[]]$Content
  )

  begin {
    $StringList = [System.Collections.Generic.List[string]]::new()
  }

  process {
    foreach ($SubContent in $Content) {
      $StringList.Add(($Content -creplace '(?m)^', '- '))
    }
  }

  end {
    return $StringList -join "`n"
  }
}

function New-TempFile {
  <#
  .SYNOPSIS
    Create a new temporary file in DumplingsCache or system temp folder
  .OUTPUTS
    The path to the new temporary file
  #>
  [OutputType([string])]

  $Parent = (Test-Path -Path Variable:\DumplingsCache) -and (Test-Path -Path $Global:DumplingsCache) ? $Global:DumplingsCache : [System.IO.Path]::GetTempPath()
  $Path = (New-Item -Path $Parent -Name (New-Guid).Guid -ItemType File -Force).FullName
  return $Path
}

function New-TempFolder {
  <#
  .SYNOPSIS
    Create a new temporary folder in DumplingsCache or system temp folder
  .OUTPUTS
    The path to the new temporary folder
  #>
  [OutputType([string])]

  $Parent = (Test-Path -Path Variable:\DumplingsCache) -and (Test-Path -Path $Global:DumplingsCache) ? $Global:DumplingsCache : [System.IO.Path]::GetTempPath()
  $Path = (New-Item -Path $Parent -Name (New-Guid).Guid -ItemType Directory -Force).FullName
  return $Path
}

function Get-TempFile {
  <#
  .SYNOPSIS
    Download the file from the given URL to a temporary file and return its path
  .NOTES
    All the parameters except '-OutFile' will be passed to Invoke-WebRequest
  .OUTPUTS
    The path to the new temporary file
  #>
  [OutputType([string])]

  $FilePath = New-TempFile
  Invoke-WebRequest -OutFile $FilePath @args
  return $FilePath
}

function Expand-TempArchive {
  <#
  .SYNOPSIS
    Extract files from the given ZIP archive to a temporary folder and return the path of the destination folder
  .PARAMETER Path
    The path of the ZIP archive to be extracted
  .OUTPUTS
    The path of the destination folder
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the ZIP archive')]
    [string]$Path
  )

  process {
    $TempFolderPath = New-TempFolder
    Expand-Archive -Path $Path -DestinationPath $TempFolderPath
    return $TempFolderPath
  }
}

function Expand-InstallShield {
  <#
  .SYNOPSIS
    Extract files from an InstallShield executable file to the same folder using ISx
  .PARAMETER Path
    The path of the InstallShield executable file to be extracted
  .PARAMETER ISxPath
    The path to the InstallShield installer extractor (ISx) tool
  .LINK
    https://github.com/lifenjoiner/ISx
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path of the InstallShield executable file to be extracted')]
    [string]$Path,

    [Parameter(HelpMessage = 'The path to the InstallShield installer extractor (ISx) tool')]
    [string]$ISxPath
  )

  begin {
    if ([string]::IsNullOrEmpty($ISxPath)) {
      if (Test-Path -Path (Join-Path $PSScriptRoot '..' 'Assets' 'ISx.exe')) {
        $ISxPath = Join-Path $PSScriptRoot '..' 'Assets' 'ISx.exe' -Resolve
      } elseif ((Test-Path -Path Variable:\DumplingsRoot) -and (Test-Path -Path (Join-Path $DumplingsRoot 'Assets' 'ISx.exe'))) {
        $ISxPath = Join-Path $DumplingsRoot 'Assets' 'ISx.exe' -Resolve
      } elseif (Get-Command 'ISx.exe' -ErrorAction SilentlyContinue) {
        $ISxPath = (Get-Command 'ISx.exe').Path
      } else {
        throw 'The ISx tool could not be found'
      }
    }
    if (-not (Test-Path -Path $ISxPath)) {
      throw 'The path to the ISx tool specified is invalid'
    }
  }

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    & $ISxPath $Path | Out-Host

    return "$(Join-Path (Split-Path -Path $Path -Parent) (Split-Path -Path $Path -LeafBase))_u"
  }
}

function Expand-Burn {
  <#
  .SYNOPSIS
    Read the ProductCode property value of the WiX bundle file
  .PARAMETER Path
    The path to the WiX bundle file
  .PARAMETER DarkPath
    The path to the Windows Installer XML Toolset Decompiler tool
  .LINK
    https://github.com/wixtoolset/wix3
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the WiX bundle file')]
    [string]$Path,

    [Parameter(HelpMessage = 'The path to the Windows Installer XML Toolset Decompiler (Dark) tool')]
    [string]$DarkPath
  )

  begin {
    if ([string]::IsNullOrEmpty($DarkPath)) {
      if (Test-Path -Path Env:\WIX) {
        $DarkPath = Join-Path $Env:WIX 'bin' 'dark.exe' -Resolve
      } elseif (Get-Command 'dark.exe' -ErrorAction SilentlyContinue) {
        $DarkPath = (Get-Command 'dark.exe').Path
      } else {
        throw 'The Dark tool could not be found'
      }
    }
    if (-not (Test-Path -Path $DarkPath)) {
      throw 'The path to the dark tool specified is invalid'
    }
  }

  process {
    $Item = Get-Item -Path $Path
    if ($Item.Extension -ne '.exe') {
      $Path = New-Item -Path "${Path}.exe" -ItemType HardLink -Value $Path -Force
    } else {
      $Path = $Item.FullName
    }

    $TempFolderPath = New-TempFolder
    & $DarkPath -nologo -x $TempFolderPath $Path | Out-Host

    return $TempFolderPath
  }
}

function Invoke-GitHubApi {
  <#
  .SYNOPSIS
    Invoke GitHub API with default headers and provided token
  #>

  $IndexOfBody = $args.IndexOf('-Body')
  if ($IndexOfBody -gt -1 -and $args[$IndexOfBody + 1] -is [System.Collections.IDictionary]) {
    $args[$IndexOfBody + 1] = ConvertTo-Json -InputObject $args[$IndexOfBody + 1] -Depth 5 -Compress -EscapeHandling EscapeNonAscii
  }

  $IndexOfToken = $args.IndexOf('-Token')
  if ($IndexOfToken -gt -1) {
    $args[$IndexOfToken + 1] = ConvertTo-SecureString -String $args[$IndexOfToken + 1] -AsPlainText
    Invoke-RestMethod -Authentication Bearer -Headers @{ Accept = 'application/vnd.github+json' } -ContentType 'application/json' @args
  } elseif (Test-Path Env:\GH_DUMPLINGS_TOKEN) {
    $Token = ConvertTo-SecureString -String $Env:GH_DUMPLINGS_TOKEN -AsPlainText
    Invoke-RestMethod -Authentication Bearer -Token $Token -Headers @{ Accept = 'application/vnd.github+json' } -ContentType 'application/json' @args
  } else {
    throw 'A token required to invoke GitHub API is not provided through "-Token" parameter or defined in "GH_DUMPLINGS_TOKEN" environment variable'
  }
}

function Get-RedirectedUrl {
  <#
  .SYNOPSIS
    Get the redirected URI for the given URI
  #>
  [OutputType([string])]
  param ()

  (Invoke-WebRequest -Method Head @args).BaseResponse.RequestMessage.RequestUri.AbsoluteUri
}

function Get-RedirectedUrl1st {
  <#
  .SYNOPSIS
    Get the first redirected URI for the given URI
  .PARAMETER Uri
    The Uniform Resource Identifier (URI)
  .PARAMETER UserAgent
    The user agent string for the web request
  .PARAMETER Headers
    The header hashtable for the web request
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The Uniform Resource Identifier (URI)')]
    [string]$Uri,

    [Parameter(HelpMessage = 'The user agent string for the web request')]
    [string]$UserAgent,

    [Parameter(HelpMessage = 'The header hashtable for the web request')]
    [System.Collections.IDictionary]$Headers
  )

  process {
    $Request = [System.Net.WebRequest]::Create($Uri)
    if ($UserAgent) {
      $Request.UserAgent = $UserAgent
    }
    if ($Headers) {
      $Headers.GetEnumerator() | ForEach-Object -Process { $Request.Headers.Set($_.Key, $_.Value) }
    }
    $Request.AllowAutoRedirect = $false
    $Response = $Request.GetResponse()
    Write-Output -InputObject $Response.GetResponseHeader('Location')
    $Response.Close()
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
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string containing the JSON')]
    [ValidateNotNullOrEmpty()]
    [string]$Content,

    [Parameter(Mandatory, HelpMessage = 'The string indicating where the JSON starts after')]
    [ValidateNotNullOrEmpty()]
    [string]$StartsFrom
  )

  process {
    [Newtonsoft.Json.JsonConvert]::DeserializeObject(
      $Content.Substring($Content.IndexOf($StartsFrom) + $StartsFrom.Length),
      [Newtonsoft.Json.JsonSerializerSettings]@{
        TypeNameHandling         = [Newtonsoft.Json.TypeNameHandling]::None
        MetadataPropertyHandling = [Newtonsoft.Json.MetadataPropertyHandling]::Ignore
        CheckAdditionalContent   = $false
      }
    ).ToString()
  }
}

function Read-ResponseContent {
  <#
  .SYNOPSIS
    Obtain garble-free content from the stream
  .PARAMETER Response
    The stream to read (e.g. The raw content stream from Invoke-WebRequest)
  .PARAMETER Encoding
    The content encoding
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The stream to read (e.g. The raw content stream from Invoke-WebRequest)')]
    [System.IO.Stream]$RawContentStream,

    [Parameter(HelpMessage = 'The content encoding')]
    [ArgumentCompleter({ [System.Text.Encoding]::GetEncodings() | Select-Object -ExpandProperty Name | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [string]$Encoding
  )

  process {
    # The stream of the response content passed to function may be closed.
    # Force open the stream by setting the pointer to the beginning
    $RawContentStream.Position = 0
    if ($Encoding) {
      return [System.IO.StreamReader]::new($RawContentStream, [System.Text.Encoding]::GetEncoding($Encoding)).ReadToEnd()
    } else {
      return [System.IO.StreamReader]::new($RawContentStream).ReadToEnd()
    }
  }
}

function Read-ProductVersionFromExe {
  <#
  .SYNOPSIS
    Read the product version of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the EXE file')]
    [string]$Path
  )

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductVersion.Trim()
  }
}

function Read-ProductVersionRawFromExe {
  <#
  .SYNOPSIS
    Read the raw product version of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([version])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the EXE file')]
    [string]$Path
  )

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductVersionRaw
  }
}

function Read-FileVersionFromExe {
  <#
  .SYNOPSIS
    Read the file version property of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the EXE file')]
    [string]$Path
  )

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion.Trim()
  }
}

function Read-FileVersionRawFromExe {
  <#
  .SYNOPSIS
    Read the raw file version of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([version])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the EXE file')]
    [string]$Path
  )

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersionRaw
  }
}

function Read-MsiProperty {
  <#
  .SYNOPSIS
    Query a value from the MSI file using SQL-like query
  .PARAMETER Path
    The path to the MSI file
  .PARAMETER Query
    The SQL-like query
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the MSI file')]
    [string]$Path,

    [Parameter(Mandatory, HelpMessage = 'The SQL-like query')]
    [string]$Query
  )

  begin {
    $WindowsInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
  }

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    $Database = $WindowsInstaller.OpenDatabase($Path, 0)
    $View = $Database.OpenView($Query)
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

function Read-ProductVersionFromMsi {
  <#
  .SYNOPSIS
    Read the ProductVersion property value from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the MSI file')]
    [string]$Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='ProductVersion'"
  }
}

function Read-ProductCodeFromMsi {
  <#
  .SYNOPSIS
    Read the ProductCode property value from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the MSI file')]
    [string]$Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='ProductCode'"
  }
}

function Read-UpgradeCodeFromMsi {
  <#
  .SYNOPSIS
    Read the UpgradeCode property value from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the MSI file')]
    [string]$Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='UpgradeCode'"
  }
}

function Read-ProductNameFromMsi {
  <#
  .SYNOPSIS
    Read the ProductName property value from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the MSI file')]
    [string]$Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='ProductName'"
  }
}

function Read-MsiSummaryValue {
  <#
  .SYNOPSIS
    Read a specified property value from the summary table of the MSI file
  .PARAMETER Path
    The MSI file path
  .PARAMETER Name
    The property name
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The MSI file path')]
    [string]$Path,

    [Parameter(Mandatory, HelpMessage = 'The property name')]
    [ValidateSet('Codepage', 'Title', 'Subject', 'Author', 'Keywords', 'Comments', 'Template', 'LastAuthor', 'RevNumber', 'EditTime', 'LastPrinted', 'CreateDtm', 'LastSaveDtm', 'PageCount', 'WordCount', 'CharCount', 'AppName', 'Security')]
    [string]$Name
  )

  begin {
    $WindowsInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
    $Index = switch ($Name) {
      'Codepage' { 1 }
      'Title' { 2 }
      'Subject' { 3 }
      'Author' { 4 }
      'Keywords' { 5 }
      'Comments' { 6 }
      'Template' { 7 }
      'LastAuthor' { 8 }
      'RevNumber' { 9 }
      'EditTime' { 10 }
      'LastPrinted' { 11 }
      'CreateDtm' { 12 }
      'LastSaveDtm' { 13 }
      'PageCount' { 14 }
      'WordCount' { 15 }
      'CharCount' { 16 }
      'AppName' { 18 }
      'Security' { 19 }
      Default { throw 'No such property or property not supported' }
    }
  }

  process {
    # Obtain the absolute path of the file
    $Path = (Get-Item -Path $Path).FullName

    $Database = $WindowsInstaller.OpenDatabase($Path, 0)
    $SummaryInfo = $Database.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null , $Database, $null)
    Write-Output -InputObject ($SummaryInfo.GetType().InvokeMember('Property', 'GetProperty', $Null, $SummaryInfo, $Index))

    [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($SummaryInfo) | Out-Null
    [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Database) | Out-Null
  }

  end {
    [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($WindowsInstaller) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }
}

function Read-ProductCodeFromBurn {
  <#
  .SYNOPSIS
    Read the ProductCode property of the WiX bundle file
  .PARAMETER Path
    The path to the WiX bundle file
  .PARAMETER DarkPath
    The path to the Windows Installer XML Toolset Decompiler tool
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the WiX bundle file')]
    [string]$Path,

    [Parameter(HelpMessage = 'The path to the Windows Installer XML Toolset Decompiler (Dark) tool')]
    [string]$DarkPath
  )

  process {
    $FolderPath = Expand-Burn -Path $Path -DarkPath $DarkPath

    $BootstrapperApplicationDataPath = Join-Path $FolderPath 'UX' 'BootstrapperApplicationData.xml'
    $ManifestPath = Join-Path $FolderPath 'UX' 'manifest.xml'
    if (Test-Path -Path $BootstrapperApplicationDataPath) {
      $BootstrapperApplicationData = Get-Content -Path $BootstrapperApplicationDataPath -Raw | ConvertFrom-Xml
      Write-Output -InputObject $BootstrapperApplicationData.BootstrapperApplicationData.WixBundleProperties.Id
    } elseif (Test-Path -Path $ManifestPath) {
      Write-Host -Object 'Fallbacking to the manifest file'
      $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Xml
      Write-Output -InputObject $Manifest.BurnManifest.Registration.Id
    } else {
      throw 'The BootstrapperApplicationData and manifest files do not exist'
    }

    Remove-Item -Path $FolderPath -Recurse -Force
  }
}

function Read-UpgradeCodeFromBurn {
  <#
  .SYNOPSIS
    Read the UpgradeCode property of the WiX bundle file
  .PARAMETER Path
    The path to the WiX bundle file
  .PARAMETER DarkPath
    The path to the Windows Installer XML Toolset Decompiler tool
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the WiX bundle file')]
    [string]$Path,

    [Parameter(HelpMessage = 'The path to the Windows Installer XML Toolset Decompiler (Dark) tool')]
    [string]$DarkPath
  )

  process {
    $FolderPath = Expand-Burn -Path $Path -DarkPath $DarkPath

    $BootstrapperApplicationDataPath = Join-Path $FolderPath 'UX' 'BootstrapperApplicationData.xml'
    $ManifestPath = Join-Path $FolderPath 'UX' 'manifest.xml'
    if (Test-Path -Path $BootstrapperApplicationDataPath) {
      $BootstrapperApplicationData = Get-Content -Path $BootstrapperApplicationDataPath -Raw | ConvertFrom-Xml
      Write-Output -InputObject $BootstrapperApplicationData.BootstrapperApplicationData.WixBundleProperties.UpgradeCode
    } elseif (Test-Path -Path $ManifestPath) {
      Write-Host -Object 'Fallbacking to the manifest file'
      $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Xml
      Write-Output -InputObject $Manifest.BurnManifest.RelatedBundle.Id
    } else {
      throw 'The BootstrapperApplicationData and manifest files do not exist'
    }

    Remove-Item -Path $FolderPath -Recurse -Force
  }
}

function Read-ProductNameFromBurn {
  <#
  .SYNOPSIS
    Read the ProductName property of the WiX bundle file
  .PARAMETER Path
    The path to the WiX bundle file
  .PARAMETER DarkPath
    The path to the Windows Installer XML Toolset Decompiler tool
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the WiX bundle file')]
    [string]$Path,

    [Parameter(HelpMessage = 'The path to the Windows Installer XML Toolset Decompiler (Dark) tool')]
    [string]$DarkPath
  )

  process {
    $FolderPath = Expand-Burn -Path $Path -DarkPath $DarkPath

    $BootstrapperApplicationDataPath = Join-Path $FolderPath 'UX' 'BootstrapperApplicationData.xml'
    $ManifestPath = Join-Path $FolderPath 'UX' 'manifest.xml'
    if (Test-Path -Path $BootstrapperApplicationDataPath) {
      $BootstrapperApplicationData = Get-Content -Path $BootstrapperApplicationDataPath -Raw | ConvertFrom-Xml
      Write-Output -InputObject $BootstrapperApplicationData.BootstrapperApplicationData.WixBundleProperties.DisplayName
    } elseif (Test-Path -Path $ManifestPath) {
      Write-Host -Object 'Fallbacking to the manifest file'
      $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Xml
      Write-Output -InputObject $Manifest.BurnManifest.Registration.Arp.DisplayName
    } else {
      throw 'The BootstrapperApplicationData and manifest files do not exist'
    }

    Remove-Item -Path $FolderPath -Recurse -Force
  }
}

function Get-MSIXPublisherHash {
  <#
  .SYNOPSIS
    Calculate the hash part of the MSIX package family name
  .PARAMETER PublisherName
    The publisher name
  .LINK
    https://marcinotorowski.com/2021/12/19/calculating-hash-part-of-msix-package-family-name
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The publisher name')]
    [ValidateNotNullOrEmpty()]
    [string]$PublisherName
  )

  begin {
    $EncodingTable = '0123456789abcdefghjkmnpqrstvwxyz'
  }

  process {
    $PublisherNameSha256 = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::Unicode.GetBytes($PublisherName))
    $PublisherNameSha256First8Binary = $PublisherNameSha256[0..7] | ForEach-Object { [System.Convert]::ToString($_, 2).PadLeft(8, '0') }
    $PublisherNameSha256Fisrt8BinaryPadded = [System.String]::Concat($PublisherNameSha256First8Binary).PadRight(65, '0')

    $Result = for ($i = 0; $i -lt $PublisherNameSha256Fisrt8BinaryPadded.Length; $i += 5) {
      $EncodingTable[[System.Convert]::ToInt32($PublisherNameSha256Fisrt8BinaryPadded.Substring($i, 5), 2)]
    }

    return [System.String]::Concat($Result)
  }
}

function Read-FamilyNameFromMSIX {
  <#
  .SYNOPSIS
    Read the family name of the MSIX/AppX package
  .PARAMETER Path
    The path to the MSIX/AppX package
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path to the MSIX/AppX package')]
    [string]$Path
  )

  process {
    $FolderPath = Expand-TempArchive -Path $Path

    $ManifestPath = Get-ChildItem -Path $FolderPath -Include @('AppxManifest.xml', 'AppxBundleManifest.xml') -Recurse -File | Select-Object -First 1
    if (Test-Path -Path $ManifestPath.FullName) {
      $Manifest = Get-Content -Path $ManifestPath.FullName -Raw | ConvertFrom-Xml
      $Identity = $Manifest.GetElementsByTagName('Identity')[0]
      Write-Output -InputObject "$($Identity.Name)_$(Get-MSIXPublisherHash -PublisherName $Identity.Publisher)"
    } else {
      throw 'The manifest file does not exist'
    }

    Remove-Item -Path $FolderPath -Recurse -Force
  }
}

function ConvertFrom-ElectronUpdater {
  <#
  .SYNOPSIS
    Convert Electron Updater manifest into organized hashtable
  .PARAMETER Content
    The YAML object of the Electron Updater manifest
  .PARAMETER Prefix
    The prefix of the installer URL
  .PARAMETER Locale
    The locale of the release notes (if present)
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The YAML object of the Electron Updater manifest')]
    $Content,

    [Parameter(HelpMessage = 'The prefix of the installer URL')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Prefix,

    [Parameter(HelpMessage = 'The locale of the release notes (if present)')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Locale = 'en-US'
  )

  $Result = [ordered]@{
    Installer = @()
    Locale    = @()
  }

  # Version
  $Result.Version = $Content.version

  # InstallerUrl
  try {
    # The prefix is a valid URL
    $Result.Installer += [ordered]@{
      InstallerUrl = Join-Uri $Prefix $Content.files[0].url
    }
  } catch {
    # The prefix is not a valid URL
    $Result.Installer += [ordered]@{
      InstallerUrl = $Prefix + $Content.files[0].url
    }
  }

  # ReleaseTime
  if ($Content.releaseDate) {
    $Result.ReleaseTime = $Content.releaseDate | Get-Date -AsUTC
  }

  # ReleaseNotes
  if ($Content.releaseNotes) {
    $Result.Locale += [ordered]@{
      Locale = $Locale
      Key    = 'ReleaseNotes'
      Value  = $Content.releaseNotes | Format-Text
    }
  }

  return $Result
}

function ConvertFrom-SquirrelReleases {
  <#
  .SYNOPSIS
    Convert Squirrel releases into organized hashtable
  .PARAMETER Content
    The string containing Squirrel releases information
  .LINK
    https://github.com/Squirrel/Squirrel.Windows/blob/HEAD/src/Squirrel/Utility.cs
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The string containing Squirrel releases information')]
    [string]$Content
  )

  begin {
    $EntryRegex = [regex]::new('^([0-9a-fA-F]{40})\s+(\S+)\s+(\d+)[\r]*$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $CommentRegex = [regex]::new('\s*#.*$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $StagingRegex = [regex]::new('#\s+(\d{1,3})%$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $SuffixRegex = [regex]::new('(-full|-delta)?\.nupkg$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $VersionRegex = [regex]::new('\d+(\.\d+){0,3}(-[A-Za-z][0-9A-Za-z-]*)?', [System.Text.RegularExpressions.RegexOptions]::Compiled)

    $Result = @()
  }

  process {
    $Result += $Content | Split-LineEndings | Where-Object -FilterScript { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object -Process {
      $Entry = $_

      $StagingPercentage = $Entry -match $StagingRegex ? $Matches[1] / 100 : $null

      $Entry = $Entry -replace $CommentRegex
      if ([string]::IsNullOrWhiteSpace($Entry)) {
        return
      }

      $Match = $EntryRegex.Match($Entry)
      if (-not $Match.Success -or $Match.Groups.Count -ne 4) {
        throw "Invalid release entry: ${Entry}"
      }

      $Filename = $Match.Groups[2].Value

      $BaseUrl = $null
      $Query = $null

      $Uri = [uri]$null
      if ([uri]::TryCreate($Filename, [System.UriKind]::Absolute, [ref]$Uri) -and $Uri.Scheme -in @([uri]::UriSchemeHttp, [uri]::UriSchemeHttps)) {
        $Path = $Uri.LocalPath
        $Authority = $Uri.GetLeftPart([System.UriPartial]::Authority)

        if ([string]::IsNullOrEmpty($Path) -or [string]::IsNullOrEmpty($Authority)) {
          throw "Invalid URL: ${Filename}"
        }

        $IndexOfLastPathSeparator = $Path.LastIndexOf('/') + 1
        $BaseUrl = $Authority + $Path.Substring(0, $IndexOfLastPathSeparator)
        $Filename = $Path.Substring($IndexOfLastPathSeparator)

        if (-not [string]::IsNullOrEmpty($Uri.Query)) {
          $Query = $Uri.Query
        }
      }

      if ($Filename.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -gt -1) {
        throw "Filename can either be an absolute HTTP[s] URL, *or* a file name: ${Filename}"
      }

      return [pscustomobject]@{
        Version           = $VersionRegex.Match($SuffixRegex.Replace($Filename, '')).Value
        Sha1              = $Match.Groups[1].Value
        Filename          = $Filename
        Filesize          = [Int64]::Parse($Match.Groups[3].Value)
        IsDelta           = $Filename.EndsWith('-delta.nupkg', [System.StringComparison]::InvariantCultureIgnoreCase)
        BaseUrl           = $BaseUrl
        Query             = $Query
        StagingPercentage = $StagingPercentage
      }
    }
  }

  end {
    return $Result
  }
}

function Copy-Object {
  <#
  .SYNOPSIS
    Deep clone an object
  .PARAMETER InputObject
    The object to clone
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The object to clone')]
    $InputObject
  )

  begin {
    $BinaryFormatter = [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new()
    $BinaryFormatter.Context = [System.Runtime.Serialization.StreamingContext]::new([System.Runtime.Serialization.StreamingContextStates]::Clone)
  }

  process {
    $MemoryStream = [System.IO.MemoryStream]::new()
    $BinaryFormatter.Serialize($MemoryStream, $InputObject)
    $MemoryStream.Position = 0
    $BinaryFormatter.Deserialize($MemoryStream)
    $MemoryStream.Close()
  }
}

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'DumplingsDefaultUserAgent', Justification = 'This variable will be exported')]
$DumplingsDefaultUserAgent = [Microsoft.PowerShell.Commands.PSUserAgent].GetProperty('UserAgent', [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Static).GetValue($null)

Export-ModuleMember -Function * -Variable 'DumplingsDefaultUserAgent'
