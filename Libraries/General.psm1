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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The Unix time in seconds')]
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
    Convert Unix time in milliseconds to DateTime object in UTC timezone
  .PARAMETER Milliseconds
    The Unix time in milliseconds
  #>
  [OutputType([datetime])]
  param (
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The Unix time in milliseconds')]
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
    Adjust DateTime object from specified timezone to UTC
  .PARAMETER DateTime
    The DateTime object to be converted
  .PARAMETER Id
    The TimeZoneInfo ID of the source timezone of the DateTime object
  #>
  [OutputType([datetime])]
  param (
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The DateTime object to be converted')]
    [datetime]
    $DateTime,

    [parameter(Mandatory, HelpMessage = 'The TimeZoneInfo ID of the source timezone of the DateTime object')]
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
  .PARAMETER Content
    The XML string to be converted
  #>
  [OutputType([xml])]
  param (
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The XML string to be converted')]
    [string]
    $Content
  )

  begin {
    $Buffer = [System.Collections.Generic.List[string]]::new()
  }

  process {
    $Buffer.Add($Content)
  }

  end {
    [xml]($Buffer -join "`n")
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
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The INI string to be converted')]
    [AllowEmptyString()]
    [string]
    $Content,

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

    $Object = [ordered]@{}
    $CommentCount = 0
  }

  process {
    $StringReader = [System.IO.StringReader]::new($Content)

    for ($Text = $StringReader.ReadLine(); $null -ne $Text; $Text = $StringReader.ReadLine()) {
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

    $StringReader.Dispose()
  }

  end {
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The Base64 string to be decoded')]
    [string]
    $InputObject,

    [Parameter(HelpMessage = 'The encoding of the content')]
    [ArgumentCompleter({ [System.Text.Encoding]::GetEncodings() | Select-Object -ExpandProperty Name | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [string]
    $Encoding
  )

  process {
    if ($Encoding) {
      [System.Text.Encoding]::GetEncoding($Encoding).GetString([System.Convert]::FromBase64String($InputObject))
    } else {
      [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
    }
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The string to be decoded')]
    [string]
    $InputObject
  )

  process {
    [System.Net.WebUtility]::HtmlDecode($InputObject)
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Uniform Resource Identifier (URI)')]
    [string]
    $Uri
  )

  process {
    [uri]::UnescapeDataString($Uri)
  }
}

function ConvertTo-MarkdownEscapedText {
  <#
  .SYNOPSIS
    Escape the text to make it not parsed as Markdown syntax
  .PARAMETER InputObject
    The text to be escaped
  #>
  [OutputType([string])]
  param (
    [parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The text to be escaped')]
    [AllowEmptyString()]
    [string]
    $InputObject
  )

  process {
    $InputObject -replace '([_*\[\]()~`<>#+\-|{}.!\\])', '\$1'
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
    [parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'The Uniform Resource Identifier (URI) to be splitted')]
    [uri]
    $Uri,

    [parameter(ParameterSetName = 'ParentSet', HelpMessage = 'The parent part of the URI')]
    [switch]
    $Parent,

    [parameter(ParameterSetName = 'LeftPartSet', HelpMessage = 'The left part of the URI')]
    [System.UriPartial]
    $LeftPart = [System.UriPartial]::Path,

    [parameter(ParameterSetName = 'ComponentSet', HelpMessage = 'The component of the URI')]
    [System.UriComponents[]]
    $Components,

    [parameter(ParameterSetName = 'ComponentSet', HelpMessage = 'Control how special characters are escaped')]
    [System.UriFormat]
    $Format = [System.UriFormat]::UriEscaped
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
    [parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The main URI to which the child URI is appended')]
    [uri[]]
    $Uri,

    [parameter(Position = 1, Mandatory, HelpMessage = 'The elements to be applied to the main URI')]
    [string[]]
    $ChildUri,

    [parameter(Position = 2, ValueFromRemainingArguments, HelpMessage = 'Additional elements to be applied to the main URI')]
    [string[]]
    $AdditionalChildUri
  )

  process {
    foreach ($SubUri in $Uri) {
      foreach ($SubChildUri in $ChildUri) {
        $SubUri = [uri]::new($SubUri, $SubChildUri)
      }
      foreach ($SubAdditionalChildUri in $AdditionalChildUri) {
        $SubUri = [uri]::new($SubUri, $SubAdditionalChildUri)
      }
      Write-Output -InputObject $SubUri.AbsoluteUri
    }
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The string to be splitted')]
    [string]
    $InputObject
  )

  process {
    $InputObject.Split([string[]]@("`r`n", "`n"), [System.StringSplitOptions]::None)
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The string to be converted')]
    [string]
    $InputObject
  )

  process {
    $InputObject.ReplaceLineEndings("`n")
  }
}

function ConvertTo-Https {
  <#
  .SYNOPSIS
    Change the scheme of the URI from HTTP to HTTPS
  .PARAMETER Uri
    The Uniform Resource Identifier (URI) to be converted
  .OUTPUTS
    The URI with its scheme converted to HTTPS
  #>
  [OutputType([string])]
  param (
    [parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'Uniform Resource Identifier (URI)')]
    [string]
    $Uri
  )

  process {
    $Uri -creplace '^http://', 'https://'
  }
}

function ConvertTo-OrderedList {
  <#
  .SYNOPSIS
    Prepend ordered numbers ("1. ", "2. ", ...) to each line of the strings and then concatenate the strings into one
  .PARAMETER InputObject
    The strings to be prepended
  .OUTPUTS
    The concatenated string with each line prepended with ordered numbers
  #>
  [OutputType([string])]
  param (
    [parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'The strings to be prepended')]
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
    Prepend "- " to each line of the strings and then concatenate the strings into one
  .PARAMETER InputObject
    The strings to be prepended
  .OUTPUTS
    The concatenated string with each line prepended with "- "
  #>
  [OutputType([string])]
  param (
    [parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'The strings to be prepended')]
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

function New-TempFile {
  <#
  .SYNOPSIS
    Create a new temporary file in DumplingsCache or system temp folder
  .OUTPUTS
    The path to the new temporary file
  #>
  [OutputType([string])]

  $Parent = (Test-Path -Path Variable:\DumplingsCache) -and (Test-Path -Path $Global:DumplingsCache) ? $Global:DumplingsCache : $Env:TEMP
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

  $Parent = (Test-Path -Path Variable:\DumplingsCache) -and (Test-Path -Path $Global:DumplingsCache) ? $Global:DumplingsCache : $Env:TEMP
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
    [string]
    $Path
  )

  process {
    $FolderPath = New-TempFolder
    Expand-Archive -Path $Path -DestinationPath $FolderPath
    return $FolderPath
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
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The path of the InstallShield executable file to be extracted')]
    [string]
    $Path,

    [Parameter(HelpMessage = 'The path to the InstallShield installer extractor (ISx) tool')]
    [string]
    $ISxPath = (Test-Path -Path Variable:\DumplingsRoot) ? (Join-Path $DumplingsRoot 'Assets' 'ISx.exe') : (Join-Path $PSScriptRoot '..' 'Assets' 'ISx.exe')
  )

  begin {
    if (-not (Test-Path -Path $ISxPath)) {
      throw 'The path to the ISx tool specified is invalid'
    }
  }

  process {
    & $ISxPath $Path | Out-Host
    return "$(Join-Path (Split-Path -Path $Path -Parent) (Split-Path -Path $Path -LeafBase))_u"
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

function Invoke-WondershareJsonUpgradeApi {
  <#
  .SYNOPSIS
    Invoke Wondershare's JSON upgrade API
  #>
  param (
    [parameter(Mandatory)]
    [int]
    $ProductId,

    [parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Version,

    [switch]
    $X86 = $false,

    [int]
    $Type = 2,

    [string]
    $Locale = 'en-US'
  )

  $Uri2 = "https://pc-api.300624.com/v${Type}/product/check-upgrade?pid=${ProductId}&client_sign={}&version=${Version}&platform=win_$($x86 ? 'x86' : 'x64')"
  if ($Type -ge 3) {
    $Params1 = @{
      Uri         = 'https://pc-api.300624.com/v3/user/client/token'
      Method      = 'Post'
      Headers     = @{
        'X-Client-Type' = 1
        'X-Client-Sn'   = '{}'
        'X-App-Key'     = '58bd26679d74e279c8421ecc.demo'
        'X-Prod-Id'     = $ProductId
        'X-Prod-Ver'    = $Version
      }
      Body        = @{
        grant_type = 'client_credentials'
        app_secret = 'Op00P1TrqfIKzM9qbo44mcIXFiOxKTRytx'
      } | ConvertTo-Json -Compress
      ContentType = 'application/json'
    }
    $Object1 = Invoke-RestMethod @Params1

    $Params2 = @{
      Uri            = $Uri2
      Authentication = 'Bearer'
      Token          = ConvertTo-SecureString -String $Object1.data.access_token -AsPlainText
    }
    $Object2 = Invoke-RestMethod @Params2
  } else {
    $Object2 = Invoke-RestMethod -Uri $Uri2
  }

  return [ordered]@{
    Version   = $Object2.data.version
    Installer = @()
    Locale    = @(
      [ordered]@{
        Locale = $Locale
        Key    = 'ReleaseNotes'
        Value  = $Object2.data.whats_new_content | Format-Text
      }
    )
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The URI that will be redirected')]
    [string]
    $Uri,

    [Parameter(HelpMessage = 'The user agent string for the web request')]
    [string]
    $UserAgent,

    [Parameter(HelpMessage = 'The user agent string for the web request')]
    [System.Collections.IDictionary]
    $Headers
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
    [parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The string containing the JSON')]
    [string]
    $InputObject,

    [parameter(Mandatory, HelpMessage = 'The string indicating where the JSON starts after')]
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
    [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'The response object from the Invoke-WebRequest command')]
    [System.IO.Stream]
    $RawContentStream,

    [Parameter(HelpMessage = 'The encoding of the content')]
    [ArgumentCompleter({ [System.Text.Encoding]::GetEncodings() | Select-Object -ExpandProperty Name | Select-String -Pattern "^$($args[2])" -Raw | ForEach-Object -Process { $_.Contains(' ') ? "'${_}'" : $_ } })]
    [string]
    $Encoding
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
    Read the product version property of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([string])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the EXE file')]
    [string]
    $Path
  )

  process {
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductVersion.Trim()
  }
}

function Read-ProductVersionRawFromExe {
  <#
  .SYNOPSIS
    Read the raw product version property of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([version])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the EXE file')]
    [string]
    $Path
  )

  process {
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
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the EXE file')]
    [string]
    $Path
  )

  process {
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion.Trim()
  }
}

function Read-FileVersionRawFromExe {
  <#
  .SYNOPSIS
    Read the raw file version property of the EXE file
  .PARAMETER Path
    The path to the EXE file
  #>
  [OutputType([version])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the EXE file')]
    [string]
    $Path
  )

  process {
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersionRaw
  }
}

function Read-MsiProperty {
  <#
  .SYNOPSIS
    Read property value from a table of the specified MSI file using SQL-like query
  .PARAMETER Path
    The path to the MSI file
  .PARAMETER Query
    The SQL-like query
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'The path to the MSI file')]
    [string]
    $Path,

    [Parameter(Position = 1, Mandatory, HelpMessage = 'The SQL-like query')]
    [string]
    $Query
  )

  begin {
    $WindowsInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
  }

  process {
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
    Read the value of the ProductVersion property from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the MSI file')]
    [string]
    $Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='ProductVersion'"
  }
}

function Read-ProductCodeFromMsi {
  <#
  .SYNOPSIS
    Read the value of the ProductCode property from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the MSI file')]
    [string]
    $Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='ProductCode'"
  }
}

function Read-UpgradeCodeFromMsi {
  <#
  .SYNOPSIS
    Read the value of the UpgradeCode property from the MSI file
  .PARAMETER Path
    The path to the MSI file
  #>
  [OutputType([string])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the MSI file')]
    [string]
    $Path
  )

  process {
    Read-MsiProperty -Path $Path -Query "SELECT Value FROM Property WHERE Property='UpgradeCode'"
  }
}

function Read-MsiSummaryValue {
  <#
  .SYNOPSIS
    Read property value from the summary of the MSI file
  .PARAMETER Path
    The path to the MSI file
  .PARAMETER Name
    The name of the property
  #>
  param (
    [Parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'The path to the MSI file')]
    [string]
    $Path,

    [Parameter(Position = 1, Mandatory, HelpMessage = 'The name of the property')]
    [ValidateSet('Codepage', 'Title', 'Subject', 'Author', 'Keywords', 'Comments', 'Template', 'LastAuthor', 'RevNumber', 'EditTime', 'LastPrinted', 'CreateDtm', 'LastSaveDtm', 'PageCount', 'WordCount', 'CharCount', 'AppName', 'Security')]
    [string]
    $Name
  )

  begin {
    $WindowsInstaller = New-Object -ComObject 'WindowsInstaller.Installer'
  }

  process {
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
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the WiX bundle file')]
    [string]
    $Path,

    [Parameter(HelpMessage = 'The path to the Windows Installer XML Toolset Decompiler (Dark) tool')]
    [string]
    $DarkPath
  )

  begin {
    if ([string]::IsNullOrEmpty($DarkPath)) {
      if (Test-Path Env:\WIX) {
        $DarkPath = Join-Path $Env:WIX 'bin' 'dark.exe' -Resolve
      } elseif (Get-Command 'dark.exe' -ErrorAction SilentlyContinue) {
        $DarkPath = (Get-Command 'dark.exe').Path
      } else {
        throw 'Dark tool not specified and not found'
      }
    }
    if (-not (Test-Path -Path $DarkPath)) {
      throw 'The path to the dark tool specified is invalid'
    }
  }

  process {
    $FolderPath = New-TempFolder
    $Path = New-Item -Path "${Path}.exe" -ItemType HardLink -Value $Path -Force

    & $DarkPath -nologo -x $FolderPath $Path | Out-Host
    if ($LASTEXITCODE) {
      throw 'Failed to extract burn installer'
    }

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
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The path to the WiX bundle file')]
    [string]
    $Path,

    [Parameter(HelpMessage = 'The path to the Windows Installer XML Toolset Decompiler (Dark) tool')]
    [string]
    $DarkPath
  )

  begin {
    if ([string]::IsNullOrEmpty($DarkPath)) {
      if (Test-Path Env:\WIX) {
        $DarkPath = Join-Path $Env:WIX 'bin' 'dark.exe' -Resolve
      } elseif (Get-Command 'dark.exe' -ErrorAction SilentlyContinue) {
        $DarkPath = (Get-Command 'dark.exe').Path
      } else {
        throw 'Dark tool not specified and not found'
      }
    }
    if (-not (Test-Path -Path $DarkPath)) {
      throw 'The path to the dark tool specified is invalid'
    }
  }

  process {
    $FolderPath = New-TempFolder
    $Path = New-Item -Path "${Path}.exe" -ItemType HardLink -Value $Path -Force

    & $DarkPath -nologo -x $FolderPath $Path | Out-Host
    if ($LASTEXITCODE) {
      throw 'Failed to extract burn installer'
    }

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
    [Parameter(Mandatory, HelpMessage = 'The version used as a reference for comparison')]
    [string]
    $ReferenceVersion,

    [Parameter(Mandatory, HelpMessage = 'The version that is compared to the reference version')]
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
    The prefix of the installer URL
  .PARAMETER Locale
    The locale of the release notes (if present)
  #>
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The YAML object of the Electron Updater manifest to be handled')]
    $InputObject,

    [Parameter(HelpMessage = 'The prefix of the installer URL')]
    [ValidateNotNullOrWhiteSpace()]
    [string]
    $Prefix,

    [Parameter(HelpMessage = 'The locale of the release notes (if present)')]
    [ValidateNotNullOrWhiteSpace()]
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
  try {
    # The prefix is a valid URL
    $Result.Installer += [ordered]@{
      InstallerUrl = Join-Uri $Prefix $InputObject.files[0].url
    }
  } catch {
    # The prefix is not a valid URL
    $Result.Installer += [ordered]@{
      InstallerUrl = $Prefix + $InputObject.files[0].url
    }
  }

  # ReleaseTime
  if ($InputObject.releaseDate) {
    $Result.ReleaseTime = $InputObject.releaseDate | Get-Date -AsUTC
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

function Write-Log {
  <#
  .SYNOPSIS
    Write message to the host under specified level
  .PARAMETER Message
    The message content
  .PARAMETER Identifier
    The identifier to be prepended to the message
  .PARAMETER Level
    Log level - Verbose, Log, Info, Warning or Error
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The message content')]
    $Object,

    [Parameter(HelpMessage = 'The identifier to be prepended to the message')]
    [AllowEmptyString()]
    [string]
    $Identifier,

    [Parameter(HelpMessage = 'Log level - Verbose, Log, Info, Warning or Error')]
    [ValidateSet('Verbose', 'Log', 'Info', 'Warning', 'Error')]
    [string]
    $Level = 'Log'
  )

  process {
    $Color = switch ($Level) {
      'Verbose' { "`e[32m" } # Green
      'Info' { "`e[34m" } # Blue
      'Warning' { "`e[33m" } # Yellow
      'Error' { "`e[31m" } # Red
      Default { "`e[39m" } # Default
    }

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsWriteLog')
    $Mutex.WaitOne(2000) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($Identifier)) {
      Write-Host -Object "${Color}`e[1m${Identifier}:`e[22m ${Object}`e[0m"
    } else {
      Write-Host -Object "${Color}${Object}`e[0m"
    }
    $Mutex.ReleaseMutex()
    $Mutex.Close()
  }
}

function Copy-Object {
  <#
  .SYNOPSIS
    Clone an object
  .PARAMETER InputObject
    The object to be cloned
  #>
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The object to be cloned')]
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
