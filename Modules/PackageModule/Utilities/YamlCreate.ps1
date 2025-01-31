<#
.SYNOPSIS
  WinGet Manifest creation helper script
.DESCRIPTION
  The intent of this file is to help you generate a manifest for publishing to the Windows Package Manager repository.
  It'll attempt to download an installer from the user-provided URL to calculate a checksum. That checksum and the rest of the input data will be compiled in a .YAML file.
.PARAMETER ManifestsFolder
  The directory to the folder where the old manifests are stored
.PARAMETER OutFolder
  The directory to the folder where the new manifests will be stored
.PARAMETER PackageIdentifier
  The package identifier of the manifest
.PARAMETER PackageVersion
  The package version of the manifest
.PARAMETER InstallerEntries
  The installer entries to be applied to the manifest
.PARAMETER LocaleEntries
  The locale entries to be applied to the manifest
.PARAMETER Logger
  The logger function to be used for logging
.NOTES
  The codes in this file were referenced from https://github.com/microsoft/winget-pkgs/blob/master/Tools/YamlCreate.ps1 under the MIT License

  MIT License

  Copyright (c) Microsoft Corporation. All rights reserved.

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
  SOFTWARE
.LINK
  https://github.com/microsoft/winget-pkgs/blob/HEAD/Tools/YamlCreate.ps1
#>

#Requires -Version 7.0

param (
  [Parameter(Mandatory, HelpMessage = 'The directory to the folder where the old manifests are stored')]
  [string] $ManifestsFolder,

  [Parameter(Mandatory, HelpMessage = 'The directory to the folder where the new manifests will be stored')]
  [string] $OutFolder,

  [Parameter(Mandatory, HelpMessage = 'The package identifier of the manifest')]
  [string] $PackageIdentifier,

  [Parameter(Mandatory, HelpMessage = 'The package version of the manifest')]
  [string] $PackageVersion,

  [Parameter(Mandatory, HelpMessage = 'The installer entries to be applied to the manifest')]
  [Object[]] $InstallerEntries,

  [Parameter(HelpMessage = 'The locale entries to be applied to the manifest')]
  [Object[]] $LocaleEntries,

  [Parameter(Mandatory, HelpMessage = 'The logger function to be used for logging')]
  [ValidateScript({ $_ | Get-Member -Name 'Invoke' -MemberType Method })]
  $Logger
)

$ScriptHeader = '# Created with YamlCreate.ps1 Dumplings Mod'
$ManifestVersion = '1.9.0'
$Utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($false)
$Culture = 'en-US'
$UserAgent = 'Microsoft-Delivery-Optimization/10.0'
$BackupUserAgent = 'winget-cli WindowsPackageManager/1.7.10661 DesktopAppInstaller/Microsoft.DesktopAppInstaller v1.22.10661.0'
$DumplingsLogIdentifier = $DumplingsLogIdentifier + 'YamlCreate'

$SchemaUrls = @{
  version       = "https://aka.ms/winget-manifest.version.${ManifestVersion}.schema.json"
  installer     = "https://aka.ms/winget-manifest.installer.${ManifestVersion}.schema.json"
  defaultLocale = "https://aka.ms/winget-manifest.defaultLocale.${ManifestVersion}.schema.json"
  locale        = "https://aka.ms/winget-manifest.locale.${ManifestVersion}.schema.json"
}
$DirectSchemaUrls = @{
  version       = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.version.${ManifestVersion}.json"
  installer     = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.installer.${ManifestVersion}.json"
  defaultLocale = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.defaultLocale.${ManifestVersion}.json"
  locale        = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.locale.${ManifestVersion}.json"
}

filter UniqueItems {
  [string]$($_.Split(',').Trim() | Select-Object -Unique)
}

filter ToLower {
  [string]$_.ToLower()
}

filter NoWhitespace {
  [string]$_ -replace '\s+', '-'
}

$ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

function Test-String {
  <#
  .SYNOPSIS
    This function validates whether a string matches Minimum Length, Maximum Length, and Regex pattern
    The switches can be used to specify if null values are allowed regardless of validation
  #>
  param (
    [Parameter(Position = 0, Mandatory)]
    [AllowEmptyString()]
    [string] $InputString,
    [regex] $MatchPattern,
    [int] $MinLength,
    [int] $MaxLength,
    [switch] $AllowNull,
    [switch] $NotNull,
    [switch] $IsNull,
    [switch] $Not
  )

  $_isValid = $true

  if ($PSBoundParameters.ContainsKey('MinLength')) {
    $_isValid = $_isValid -and ($InputString.Length -ge $MinLength)
  }
  if ($PSBoundParameters.ContainsKey('MaxLength')) {
    $_isValid = $_isValid -and ($InputString.Length -le $MaxLength)
  }
  if ($PSBoundParameters.ContainsKey('MatchPattern')) {
    $_isValid = $_isValid -and ($InputString -match $MatchPattern)
  }
  if ($AllowNull -and [string]::IsNullOrWhiteSpace($InputString)) {
    $_isValid = $true
  } elseif ($NotNull -and [string]::IsNullOrWhiteSpace($InputString)) {
    $_isValid = $false
  }
  if ($IsNull) {
    $_isValid = [string]::IsNullOrWhiteSpace($InputString)
  }

  if ($Not) {
    return !$_isValid
  } else {
    return $_isValid
  }
}

function Update-InstallerEntry {
  $OldInstallers = $OldInstallerManifest['Installers']

  $iteration = 0
  $Installers = @()
  $InstallerFiles = [ordered]@{}
  foreach ($OldInstaller in $OldInstallers) {
    $iteration += 1
    $Installer = $OldInstaller | Copy-Object
    $Logger.Invoke("Updating installer #${iteration}/$($OldInstallers.Count) [$($Installer['InstallerLocale']), $($Installer['Architecture']), $($Installer['InstallerType']), $($Installer['NestedInstallerType']), $($Installer['Scope'])]", 'Verbose')

    # Clean up volatile fields
    $Installer.Remove('InstallerSha256')
    if ($Installer.Contains('ReleaseDate')) { $Installer.Remove('ReleaseDate') }

    # Apply inputs
    $ToUpdate = $false
    foreach ($InstallerEntry in $InstallerEntries) {
      $Updatable = $true
      # Find matching installer entry
      # The installer entry will be chosen if the installer contain all the keys present in the installer entry, and their values are the same
      foreach ($Key in @('InstallerLocale', 'Architecture', 'InstallerType', 'NestedInstallerType', 'Scope')) {
        if ($InstallerEntry.Contains($Key) -and $Installer.Contains($Key) -and $Installer.$Key -ne $InstallerEntry.$Key) {
          # Skip this entry if the installer has this key, but with a different value
          $Updatable = $false
        } elseif ($InstallerEntry.Contains($Key) -and -not $Installer.Contains($Key)) {
          # Skip this entry if the installer doesn't have this key
          $Updatable = $false
        }
      }
      # If the installer entry matches the installer, use the last matching entry for updating the installer
      if ($Updatable) {
        $ToUpdate = $true
        $MatchingInstallerEntry = $InstallerEntry
      }
    }
    # If no matching installer entry is found, throw an error
    if (-not $ToUpdate) {
      throw "No matching installer entry for [$($Installer['InstallerLocale']), $($Installer['Architecture']), $($Installer['InstallerType']), $($Installer['tNestedInstallerType']), $($Installer['Scope'])]"
    }
    # Update the installer using the matching installer entry
    foreach ($Key in $MatchingInstallerEntry.Keys) {
      if ($Key -eq 'Script') {
        # Run custom script if exists
        Invoke-Command -ScriptBlock $MatchingInstallerEntry.$Key -NoNewScope
      } elseif ($Key -notin $Patterns.InstallerEntryProperties) {
        # Check if the key is a valid installer property
        throw "The installer entry has an invalid key: ${Key}"
      } elseif ($Key -in @('InstallerLocale', 'Architecture', 'InstallerType', 'NestedInstallerType', 'Scope')) {
        # Skip the entries used for matching
        continue
      } else {
        try {
          if (Test-YamlObject -InputObject $MatchingInstallerEntry.$Key -Schema $InstallerSchema.properties.Installers.items.properties.$Key -WarningAction Stop) {
            if ($Key -eq 'InstallerUrl') {
              $Installer.$Key = $MatchingInstallerEntry.$Key.Replace(' ', '%20')
            } else {
              $Installer.$Key = $MatchingInstallerEntry.$Key
            }
          } else {
            $Logger.Invoke("The new value of the installer property `"${Key}`" is invalid and thus discarded", 'Warning')
          }
        } catch {
          $Logger.Invoke("The new value of the installer property `"${Key}`" is invalid and thus discarded: ${_}", 'Warning')
        }
      }
    }

    # Update the installer using the matching installer
    $MatchingInstaller = $Installers | Where-Object -FilterScript { $_.InstallerUrl -ceq $Installer.InstallerUrl } | Select-Object -First 1
    if ($MatchingInstaller -and ($Installer.Contains('NestedInstallerFiles') ? ((ConvertTo-Json -InputObject $Installer.NestedInstallerFiles -Depth 10 -Compress) -ceq (ConvertTo-Json -InputObject $MatchingInstaller.NestedInstallerFiles -Depth 10 -Compress)) : $true)) {
      foreach ($Key in @('InstallerSha256', 'SignatureSha256', 'PackageFamilyName', 'ProductCode', 'ReleaseDate', 'AppsAndFeaturesEntries')) {
        if ($MatchingInstaller.Contains($Key) -and -not $MatchingInstallerEntry.Contains($Key)) {
          $Installer.$Key = $MatchingInstaller.$Key
        } elseif (-not $MatchingInstaller.Contains($Key) -and $Installer.Contains($Key)) {
          $Installer.Remove($Key)
        }
      }
    }

    # Download and analyze the installer file
    # Skip if there is matching installer, or the "InstallerSha256" is explicitly specified
    if (-not $Installer.Contains('InstallerSha256')) {
      if ($InstallerFiles.Contains($Installer.InstallerUrl) -and (Test-Path -Path $InstallerFiles[$Installer.InstallerUrl])) {
        $InstallerPath = $InstallerFiles[$Installer.InstallerUrl]
      } else {
        $Logger.Invoke("Downloading $($Installer.InstallerUrl)", 'Verbose')
        try {
          $InstallerPath = Get-TempFile -Uri $Installer.InstallerUrl -UserAgent $UserAgent
          $InstallerFiles[$Installer.InstallerUrl] = $InstallerPath
        } catch {
          $Logger.Invoke('Failed to download with the Delivery-Optimization User Agent. Try again with the WinINet User Agent...', 'Warning')
          $InstallerPath = Get-TempFile -Uri $Installer.InstallerUrl -UserAgent $BackupUserAgent
        }
        $Logger.Invoke('Installer downloaded!', 'Verbose')
      }

      $Logger.Invoke('Processing installer data...', 'Verbose')

      # Get installer SHA256
      $Installer.InstallerSha256 = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash

      # If the installer is an archive and the nested installer is msi or wix, expand the archive to get the nested installer
      $EffectiveInstallerType = $Installer.Contains('NestedInstallerType') ? $Installer.NestedInstallerType : $Installer.InstallerType
      $EffectiveInstallerPath = $Installer.InstallerType -in $Patterns.ArchiveInstallerTypes -and $Installer.NestedInstallerType -ne 'portable' ? (Expand-TempArchive -Path $InstallerPath | Join-Path -ChildPath $Installer.NestedInstallerFiles[0].RelativeFilePath) : $InstallerPath

      # Update ProductCode, UpgradeCode and ProductVersion if the installer is msi, wix or burn, and such fields exist in the old installer
      # ProductCode
      $ProductCode = $null
      if ($EffectiveInstallerType -in @('msi', 'wix')) {
        $ProductCode = $EffectiveInstallerPath | Read-ProductCodeFromMsi -ErrorAction 'Continue'
      } elseif ($EffectiveInstallerType -eq 'burn') {
        $ProductCode = $EffectiveInstallerPath | Read-ProductCodeFromBurn -ErrorAction 'Continue'
      }
      if (-not $MatchingInstallerEntry.Contains('ProductCode') -and $EffectiveInstallerType -in @('msi', 'wix', 'burn') -and $Installer.Contains('ProductCode')) {
        if (Test-String $ProductCode -NotNull) {
          $Installer.ProductCode = $ProductCode
        } else {
          throw 'Failed to get ProductCode'
        }
      }
      if (-not $MatchingInstallerEntry.Contains('AppsAndFeaturesEntries') -and $EffectiveInstallerType -in @('msi', 'wix', 'burn') -and $Installer['AppsAndFeaturesEntries']) {
        # UpgradeCode
        $UpgradeCode = $null
        if ($EffectiveInstallerType -in @('msi', 'wix')) {
          $UpgradeCode = $EffectiveInstallerPath | Read-UpgradeCodeFromMsi -ErrorAction 'Continue'
        } elseif ($EffectiveInstallerType -eq 'burn') {
          $UpgradeCode = $EffectiveInstallerPath | Read-UpgradeCodeFromBurn -ErrorAction 'Continue'
        }
        # DisplayVersion
        $DisplayVersion = $null
        if ($EffectiveInstallerType -in @('msi', 'wix')) {
          $DisplayVersion = $EffectiveInstallerPath | Read-ProductVersionFromMsi -ErrorAction 'Continue'
        } elseif ($EffectiveInstallerType -eq 'burn') {
          $DisplayVersion = $EffectiveInstallerPath | Read-ProductVersionFromExe -ErrorAction 'Continue'
        }
        # DisplayName
        $DisplayName = $null
        if ($EffectiveInstallerType -in @('msi', 'wix')) {
          $DisplayName = $EffectiveInstallerPath | Read-ProductNameFromMsi -ErrorAction 'Continue'
        } elseif ($EffectiveInstallerType -eq 'burn') {
          $DisplayName = $EffectiveInstallerPath | Read-ProductNameFromBurn -ErrorAction 'Continue'
        }
        # Match the AppsAndFeaturesEntries that...
        $Installer.AppsAndFeaturesEntries | Where-Object -FilterScript {
          # ...have the same UpgradeCode as the new installer, or...
          ($UpgradeCode -and $_['UpgradeCode'] -and $UpgradeCode -eq $_.UpgradeCode) -or
          # ...have the same ProductCode as the old installer, or...
          ($OldInstaller['ProductCode'] -and $_['ProductCode'] -and $OldInstaller.ProductCode -eq $_.ProductCode) -or
          # ...is the only entry in the installer
          ($Installer.AppsAndFeaturesEntries.Count -eq 1)
        } | ForEach-Object -Process {
          if ($_.Contains('DisplayName')) {
            if (Test-String $DisplayName -NotNull) {
              $_.DisplayName = $DisplayName
            } else {
              throw 'Failed to get DisplayName'
            }
          }
          if ($_.Contains('DisplayVersion')) {
            if ((Test-String $DisplayVersion -NotNull) ) {
              $_.DisplayVersion = $DisplayVersion
            } else {
              throw 'Failed to get DisplayVersion'
            }
          }
          if ($_.Contains('ProductCode')) {
            if (Test-String $ProductCode -NotNull) {
              $_.ProductCode = $ProductCode
            } else {
              throw 'Failed to get ProductCode'
            }
          }
          if ($_.Contains('UpgradeCode')) {
            if (Test-String $UpgradeCode -NotNull) {
              $_.UpgradeCode = $UpgradeCode
            } else {
              throw 'Failed to get UpgradeCode'
            }
          }
        }
      }

      # Update SignatureSha256 if the installer is msix or appx
      if ($Installer.InstallerType -in @('msix', 'appx')) {
        $SignatureSha256 = $null
        $WinGetMaximumRetryCount = 3
        for ($i = 0; $i -lt $WinGetMaximumRetryCount; $i++) {
          try {
            $SignatureSha256 = winget hash -m $InstallerPath | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String
            break
          } catch {
            if ($_.FullyQualifiedErrorId -eq 'CommandNotFoundException') {
              $Logger.Invoke('Could not find the WinGet client for getting SignatureSha256. Is it installed and added to PATH?', 'Error')
            } elseif ($_.FullyQualifiedErrorId -eq 'ProgramExitedWithNonZeroCode' -and $i -lt $WinGetMaximumRetryCount - 1) {
              $Logger.Invoke("WinGet exits with exitcode $($_.Exception.ExitCode)", 'Warning')
            }
          }
        }
        if ($SignatureSha256 -and $SignatureSha256.P2) { $SignatureSha256 = $SignatureSha256.P2.ToUpper() }
        if (Test-String $SignatureSha256 -NotNull) {
          $Installer.SignatureSha256 = $SignatureSha256
        } elseif ($Installer.Contains('SignatureSha256')) {
          $Logger.Invoke('Failed to get SignatureSha256', 'Warning')
          $Installer.Remove('SignatureSha256')
        }
      }

      # Update PackageFamilyName if the installer is msix or appx
      if ($Installer.InstallerType -in @('msix', 'appx')) {
        $PackageFamilyName = $InstallerPath | Read-FamilyNameFromMSIX
        if (Test-String $PackageFamilyName -NotNull) {
          $Installer.PackageFamilyName = $PackageFamilyName
        } elseif ($Installer.Contains('PackageFamilyName')) {
          $Logger.Invoke('Failed to get PackageFamilyName', 'Warning')
          $Installer.Remove('PackageFamilyName')
        }
      }

      $Logger.Invoke('Installer updated!', 'Verbose')
    }

    # Add the updated installer to the new installers array
    $Installers += $Installer
  }

  # Remove the downloaded files
  foreach ($InstallerPath in $InstallerFiles.Values) {
    Remove-Item -Path $InstallerPath -Force -ErrorAction 'Continue'
  }

  $script:Installers = $Installers
}

function Move-KeysToInstallerLevel {
  param (
    [Parameter(Position = 0, Mandatory)]
    [System.Collections.IDictionary]$Manifest,
    [Parameter(Position = 1, Mandatory)]
    [System.Collections.IDictionary[]]$Installers,
    [Parameter(Position = 2)]
    [string[]]$Property,
    [Parameter()]
    [int]$Depth = 2,
    [Parameter(DontShow)]
    [int]$CurrentDepth = 0
  )

  if ($CurrentDepth -ge $Depth) { return }
  foreach ($Key in @($Manifest.Keys)) {
    if ($Property -and $Key -notin $Property) { continue }
    $ToRemove = $true
    if ($Manifest.$Key -is [System.Collections.IDictionary]) {
      $PreservedManifestKeys = [System.Collections.Generic.HashSet[string]]::new()
      foreach ($Installer in $Installers) {
        $ManifestEntry = $Manifest.$Key | Copy-Object
        $InstallerEntry = $Installer.Contains($Key) -and $Installer.$Key ? $Installer.$Key : [ordered]@{}
        Move-KeysToInstallerLevel -Manifest $ManifestEntry -Installers $InstallerEntry -Depth $Depth -CurrentDepth ($CurrentDepth + 1)
        $PreservedManifestKeys.UnionWith([string[]]($ManifestEntry.Keys))
        if ($InstallerEntry.Count -gt 0) { $Installer.$Key = $InstallerEntry }
      }
      if ($PreservedManifestKeys.Count -gt 0) {
        $ToRemove = $false
        foreach ($KeyToRemove in $Manifest.$Key.Keys.Where({ $_ -notin $PreservedManifestKeys })) { $Manifest.$Key.Remove($KeyToRemove) }
      }
    } elseif ($Manifest.$Key -is [System.Collections.IEnumerable] -and $Manifest.$Key -isnot [string]) {
      $ManifestEntry = $Manifest.$Key
      $ManifestEntryHash = ConvertTo-Json -InputObject $ManifestEntry -Depth 10 -Compress
      foreach ($Installer in $Installers) {
        if (-not $Installer.Contains($Key)) {
          $Installer.$Key = $Manifest.$Key
        } elseif ($Installer.Contains($Key) -and -not $Installer.$Key) {
          $Installer.$Key = $Manifest.$Key
        } elseif ($Installer.Contains($Key) -and (ConvertTo-Json -InputObject $Installer.$Key -Depth 10 -Compress) -ne $ManifestEntryHash) {
          $ToRemove = $false
        }
      }
    } else {
      foreach ($Installer in $Installers) {
        if (-not $Installer.Contains($Key)) {
          $Installer.$Key = $Manifest.$Key
        } elseif ($Installer.Contains($Key) -and -not $Installer.$Key) {
          $Installer.$Key = $Manifest.$Key
        } elseif ($Installer.Contains($Key) -and $Installer.$Key -ne $Manifest.$Key) {
          $ToRemove = $false
        }
      }
    }
    if ($ToRemove) {
      $Manifest.Remove($Key)
    }
  }
}

function Move-KeysToManifestLevel {
  param (
    [Parameter(Position = 0, Mandatory)]
    [System.Collections.IDictionary[]]$Installers,
    [Parameter(Position = 1, Mandatory)]
    [System.Collections.IDictionary]$Manifest,
    [Parameter(Position = 2)]
    [string[]]$Property,
    [Parameter()]
    [int]$Depth = 2,
    [Parameter(DontShow)]
    [int]$CurrentDepth = 0
  )

  if ($CurrentDepth -ge $Depth) { return }
  $AllKeys = @($Installers | ForEach-Object -Process { $_.Keys } | Select-Object -Unique)
  foreach ($Key in $AllKeys) {
    if ($Property -and $Key -notin $Property) { continue }
    if ($Installers.Where({ $_.Contains($Key) -and $_.$Key -is [System.Collections.IDictionary] })) {
      $InstallersEntry = @($Installers | ForEach-Object -Process { $_.Contains($Key) -and $_.$Key ? $_.$Key : [ordered]@{} })
      $ManifestEntry = $Manifest.Contains($Key) -and $Manifest.$Key ? $Manifest.$Key : [ordered]@{}

      # Move the same elements across all the objects to the manifest level
      Move-KeysToManifestLevel -Installers $InstallersEntry -Manifest $ManifestEntry -Depth $Depth -CurrentDepth ($CurrentDepth + 1)

      # If the manifest entry is not empty, add it to the manifest
      if ($ManifestEntry.Count -gt 0) {
        $Manifest.$Key = $ManifestEntry
      }
      # If the installer entry is empty, remove it from the installers
      foreach ($Installer in $Installers) {
        if ($Installer.Contains($Key) -and $Installer.$Key.Count -eq 0) {
          $Installer.Remove($Key)
        }
      }
    } elseif ($Installers.Where({ $_.Contains($Key) -and $_.$Key -is [System.Collections.IEnumerable] -and $_.$Key -isnot [string] })) {
      if ($Manifest.Contains($Key)) {
        $ManifestEntryHash = ConvertTo-Json -InputObject $Manifest.$Key -Depth 10 -Compress
        foreach ($Installer in $Installers) {
          $InstallersEntryHash = ConvertTo-Json -InputObject $Installer.$Key -Depth 10 -Compress
          if ($ManifestEntryHash -ceq $InstallersEntryHash) {
            $Installer.Remove($Key)
          }
        }
      } elseif (-not $Manifest.Contains($Key) -and -not ($Installers.Where({ -not $_.Contains($Key) })) -and @($Installers | Sort-Object -Property { ConvertTo-Json -InputObject $_.$Key -Depth 10 -Compress } -Unique).Count -eq 1) {
        $Manifest.$Key = $Installers[0].$Key
        foreach ($Installer in $Installers) {
          $Installer.Remove($Key)
        }
      }
    } else {
      if ($Manifest.Contains($Key)) {
        foreach ($Installer in $Installers) {
          if ($Installer.$Key -ceq $Manifest.$Key) {
            $Installer.Remove($Key)
          }
        }
      } elseif (-not $Manifest.Contains($Key) -and -not ($Installers.Where({ -not $_.Contains($Key) })) -and @($Installers | Sort-Object -Property { $_.$Key } -Unique).Count -eq 1) {
        $Manifest.$Key = $Installers[0].$Key
        foreach ($Installer in $Installers) {
          $Installer.Remove($Key)
        }
      }
    }
  }
}

function Write-ManifestContent {
  param (
    [Parameter(Position = 0, Mandatory)]
    [string] $FilePath,
    [Parameter(Position = 1, Mandatory)]
    $YamlContent,
    [Parameter(Position = 2, Mandatory)]
    [string] $Schema
  )

  [System.IO.File]::WriteAllLines($FilePath, @(
      $ScriptHeader
      "# yaml-language-server: `$schema=$Schema"
      ''
      # This regex looks for lines with the special character ⍰ and comments them out
      $(ConvertTo-Yaml $YamlContent -Options DisableAliases).TrimEnd() -replace "(.*) $([char]0x2370)", "# `$1"
    ), $Utf8NoBomEncoding)

  $Logger.Invoke("Yaml file created: ${FilePath}", 'Verbose')
}

function Write-VersionManifest {
  <#
  .SYNOPSIS
    Take all the entered values and write the version manifest file
  #>
  # Create new empty manifest
  $VersionManifest = $OldVersionManifest | Copy-Object

  # Bump package version
  $VersionManifest.PackageVersion = $PackageVersion
  # Bump manifest version
  $VersionManifest.ManifestVersion = $ManifestVersion

  $VersionManifest = ConvertTo-SortedYamlObject -InputObject $VersionManifest -Schema $VersionSchema -Culture $Culture

  # Create the folder for the file if it doesn't exist
  $null = New-Item -Path $OutFolder -ItemType 'Directory' -Force
  # Write the manifest to the file
  $VersionManifestPath = Join-Path $OutFolder "${PackageIdentifier}.yaml"
  Write-ManifestContent -FilePath $VersionManifestPath -YamlContent $VersionManifest -Schema $SchemaUrls.version
}

function Write-InstallerManifest {
  # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
  $InstallerManifest = $OldInstallerManifest | Copy-Object

  # Bump package version
  $InstallerManifest.PackageVersion = $PackageVersion
  # Bump manifest version
  $InstallerManifest.ManifestVersion = $ManifestVersion
  # Update installer entries
  $InstallerManifest.Installers = $script:Installers

  # Move Installer Level Keys to Manifest Level
  Move-KeysToManifestLevel -Installers $InstallerManifest.Installers -Manifest $InstallerManifest -Property $Patterns.InstallerEntryProperties.Where({ $_ -in $InstallerProperties })

  # Clean up the existing files just in case
  if ($InstallerManifest.Contains('Commands')) { $InstallerManifest.Commands = @($InstallerManifest.Commands | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }
  if ($InstallerManifest.Contains('Protocols')) { $InstallerManifest.Protocols = @($InstallerManifest.Protocols | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }
  if ($InstallerManifest.Contains('FileExtensions')) { $InstallerManifest.FileExtensions = @($InstallerManifest.FileExtensions | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }

  $InstallerManifest = ConvertTo-SortedYamlObject -InputObject $InstallerManifest -Schema $InstallerSchema -Culture $Culture

  # Create the folder for the file if it doesn't exist
  $null = New-Item -Path $OutFolder -ItemType 'Directory' -Force
  # Write the manifest to the file
  $InstallerManifestPath = Join-Path $OutFolder "${PackageIdentifier}.installer.yaml"
  Write-ManifestContent -FilePath $InstallerManifestPath -YamlContent $InstallerManifest -Schema $SchemaUrls.installer
}

function Write-LocaleManifest {
  # Copy over all locale files from previous version that aren't the same
  foreach ($OldLocaleManifest in $OldLocaleManifests) {
    $LocaleManifest = $OldLocaleManifest | Copy-Object

    # Bump package version
    $LocaleManifest.PackageVersion = $PackageVersion
    # Bump manifest version
    $LocaleManifest.ManifestVersion = $ManifestVersion
    # Clean up volatile fields
    if ($LocaleManifest.Contains('ReleaseNotes')) { $LocaleManifest.Remove('ReleaseNotes') }

    # Apply inputs
    if ($LocaleEntries) {
      foreach ($LocaleEntry in $LocaleEntries) {
        if (-not $LocaleEntry.Contains('Key') -or -not $LocaleEntry.Contains('Value') -or (Test-String $LocaleEntry.Key -IsNull)) {
          # Check if the locale entry contains the required properties
          throw 'The locale entry does not contain the required properties'
        } elseif ($LocaleEntry.Key -notin $Patterns.LocaleProperties) {
          # Check if the key property is a valid locale property
          throw "The locale entry has an invalid key `"$($LocaleEntry.Key)`""
        } elseif ($LocaleEntry.Contains('Locale') -and $LocaleEntry.Locale -notmatch $Patterns.PackageLocale) {
          # Check if the locale property is a valid locale
          throw "The locale entry has an invalid locale `"$($LocaleEntry.Locale)`" contains an invalid locale"
        } elseif ($LocaleEntry.Contains('Locale') -and $LocaleEntry.Locale -notcontains $LocaleManifest.PackageLocale) {
          # If the locale entry contains a locale property, only match the locale manifests with these locales
          continue
        } elseif ($null -eq $LocaleEntry.Value) {
          # If the value is null, remove the key from the locale manifest
          $LocaleManifest.Remove($LocaleEntry.Key)
        } else {
          try {
            if (Test-YamlObject -InputObject $LocaleEntry.Value -Schema $LocaleSchema.properties[$LocaleEntry.Key] -WarningAction Stop) {
              $LocaleManifest[$LocaleEntry.Key] = $LocaleEntry.Value
            } else {
              $Logger.Invoke("The locale entry `"$($LocaleEntry.Key)`" has an invalid value and thus discarded", 'Warning')
            }
          } catch {
            $Logger.Invoke("The locale entry `"$($LocaleEntry.Key)`" has an invalid value and thus discarded: ${_}", 'Warning')
          }
        }
      }
    }

    if ($LocaleManifest.Contains('Tags')) { $LocaleManifest.Tags = @($LocaleManifest.Tags | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }
    if ($LocaleManifest.Contains('Moniker')) {
      if ($LocaleManifest.ManifestType -eq 'defaultLocale') {
        $LocaleManifest['Moniker'] = $LocaleManifest['Moniker'] | ToLower | NoWhitespace
      } else {
        $LocaleManifest.Remove('Moniker')
      }
    }
    # Remove ReleaseNotes if too long
    if ($LocaleManifest.Contains('ReleaseNotes') -and $LocaleManifest.ReleaseNotes.Length -gt $Patterns.ReleaseNotesMaxLength) { $LocaleManifest.Remove('ReleaseNotes') }

    $Schema = $LocaleManifest.ManifestType -eq 'defaultLocale' ? $DefaultLocaleSchema : $LocaleSchema
    $LocaleManifest = ConvertTo-SortedYamlObject -InputObject $LocaleManifest -Schema $Schema -Culture $Culture

    # Create the folder for the file if it doesn't exist
    $null = New-Item -Path $OutFolder -ItemType 'Directory' -Force
    # Write the manifest to the file
    $LocaleManifestPath = Join-Path $OutFolder "${PackageIdentifier}.locale.$($LocaleManifest.PackageLocale).yaml"
    $SchemaUrl = $LocaleManifest.ManifestType -eq 'defaultLocale' ? $SchemaUrls.defaultLocale : $SchemaUrls.locale
    Write-ManifestContent -FilePath $LocaleManifestPath -YamlContent $LocaleManifest -Schema $SchemaUrl
  }
}


# Fetch Schema data from github for entry validation, key ordering, and automatic commenting
$VersionSchema = $Global:DumplingsSessionStorage['WinGetVersionSchema'] ??= Invoke-WebRequest -Uri $DirectSchemaUrls.version | ConvertFrom-Json -AsHashtable
Expand-YamlSchema -InputObject $VersionSchema

$InstallerSchema = $Global:DumplingsSessionStorage['WinGetInstallerSchema'] ??= Invoke-WebRequest -Uri $DirectSchemaUrls.installer | ConvertFrom-Json -AsHashtable
Expand-YamlSchema -InputObject $InstallerSchema
$InstallerProperties = $InstallerSchema.properties.Keys

$DefaultLocaleSchema = $Global:DumplingsSessionStorage['WinGetDefaultLocaleSchema'] ??= Invoke-WebRequest -Uri $DirectSchemaUrls.defaultLocale | ConvertFrom-Json -AsHashtable
Expand-YamlSchema -InputObject $DefaultLocaleSchema
$LocaleSchema = $Global:DumplingsSessionStorage['WinGetLocaleSchema'] ??= Invoke-WebRequest -Uri $DirectSchemaUrls.locale | ConvertFrom-Json -AsHashtable
Expand-YamlSchema -InputObject $LocaleSchema

# Various patterns used in validation to simplify the validation logic
$Patterns = @{
  VersionProperties          = $VersionSchema.properties.Keys
  InstallerEntryProperties   = $InstallerSchema.definitions.Installer.properties.Keys
  LocaleProperties           = $LocaleSchema.properties.Keys
  PackageIdentifier          = $VersionSchema.properties.PackageIdentifier.pattern
  PackageIdentifierMaxLength = $VersionSchema.properties.PackageIdentifier.maxLength
  PackageVersion             = $VersionSchema.properties.PackageVersion.pattern
  PackageVersionMaxLength    = $VersionSchema.properties.PackageVersion.maxLength
  PackageLocale              = $LocaleSchema.properties.PackageLocale.pattern
  ReleaseNotesMaxLength      = $LocaleSchema.properties.ReleaseNotes.maxLength
  ArchiveInstallerTypes      = @('zip')
}

# Validate the package identifier
if (Test-String -not $PackageIdentifier -MaxLength $Patterns.PackageIdentifierMaxLength) {
  throw [System.ArgumentException]::new("The package identifier ${PackageIdentifier} ($($PackageIdentifier.Length) characters) exceeds the maximum length of $($Patterns.PackageIdentifierMaxLength) characters")
}
if (Test-String -not $PackageIdentifier -MatchPattern $Patterns.PackageIdentifier) {
  throw [System.ArgumentException]::new("The package identifier ${PackageIdentifier} does not match the pattern requirements defined in the manifest schema")
}

# Validate the package version
if (Test-String -not $PackageVersion -MaxLength $Patterns.PackageVersionMaxLength -NotNull) {
  throw [System.ArgumentException]::new("The package version ${PackageIdentifier} ($($PackageIdentifier.Length) characters) exceeds the maximum length of $($Patterns.PackageVersionMaxLength) characters")
}
if (Test-String -not $PackageVersion -MatchPattern $Patterns.PackageVersion) {
  throw [System.ArgumentException]::new("The package version ${PackageIdentifier} does not match the pattern requirements defined in the manifest schema")
}

# Set and validate the folder for the specific package
$PackageFolder = Join-Path $ManifestsFolder $PackageIdentifier.ToLower().Chars(0) $PackageIdentifier.Replace('.', '\')
if (-not (Test-Path -Path $PackageFolder)) {
  throw "The folder of the package ${PackageIdentifier} does not exist"
}

# Try getting the last version of the package and the old manifests to be updated
$LastVersion = Join-Path $PackageFolder '*' "${PackageIdentifier}.yaml" | Get-ChildItem -File | Select-Object -ExpandProperty 'Directory' | Select-Object -ExpandProperty 'Name' | Sort-Object $ToNatural -Culture $Culture -Bottom 1
if (-not $LastVersion) {
  throw "The package ${PackageIdentifier} does not have any previous versions of manifests"
}
$Logger.Invoke("Found existing version: ${LastVersion}", 'Verbose')

# If the old manifests exist, find the default locale
$OldManifests = Join-Path $PackageFolder $LastVersion '*.yaml' | Get-ChildItem -File
$OldManifest = $OldManifests | Where-Object -FilterScript { $_.Name -eq "${PackageIdentifier}.yaml" } | Get-Content -Raw -Encoding $Utf8NoBomEncoding | ConvertFrom-Yaml -Ordered
if ($OldManifest.ManifestType -eq 'version') {
  $OldManifestType = 'MultiManifest'
  $PackageLocale = $OldManifest.DefaultLocale
} elseif ($OldManifest.ManifestType -eq 'singleton') {
  $OldManifestType = 'SingletonManifest'
  $PackageLocale = $OldManifest.PackageLocale
} else {
  throw "Unrecognized manifest type $($OldManifest.ManifestType)"
}

# If the old manifests exist, make sure to use the same casing as the existing package identifier
$PackageIdentifier = $OldManifest.PackageIdentifier

# If the old manifests exist, read their information into variables
# Also ensure additional requirements are met for creating or updating files
if ($OldManifestType -eq 'MultiManifest' -and $OldManifests.Name -contains "${PackageIdentifier}.yaml" -and $OldManifests.Name -contains "${PackageIdentifier}.installer.yaml" -and $OldManifests.Name -contains "${PackageIdentifier}.locale.${PackageLocale}.yaml") {
  $OldVersionManifest = $OldManifest
  $OldInstallerManifest = $OldManifests | Where-Object -FilterScript { $_.Name -eq "${PackageIdentifier}.installer.yaml" } | Get-Content -Raw -Encoding $Utf8NoBomEncoding | ConvertFrom-Yaml -Ordered
  $OldLocaleManifests = @($OldManifests | Where-Object -FilterScript { $_.Name -like "${PackageIdentifier}.locale.*.yaml" } | ForEach-Object -Process { Get-Content -Path $_ -Raw -Encoding $Utf8NoBomEncoding | ConvertFrom-Yaml -Ordered })
} elseif ($OldManifestType -eq 'Singleton' -and $OldManifests.Name -contains "${PackageIdentifier}.yaml") {
  $OldSingletonManifest = $OldManifest
  # Parse version keys to version manifest
  $OldVersionManifest = [ordered]@{}
  foreach ($Key in $OldSingletonManifest.Keys.Where({ $_ -in $Patterns.VersionProperties })) {
    $OldVersionManifest[$Key] = $OldSingletonManifest.$Key
  }
  $OldVersionManifest['DefaultLocale'] = $PackageLocale
  $OldVersionManifest['ManifestType'] = 'version'
  # Parse installer keys to installer manifest
  $OldInstallerManifest = [ordered]@{}
  foreach ($Key in $OldSingletonManifest.Keys.Where({ $_ -in $InstallerProperties })) {
    $OldInstallerManifest[$Key] = $OldSingletonManifest.$Key
  }
  $OldInstallerManifest['ManifestType'] = 'installer'
  # Parse default locale keys to default locale manifest
  $OldDefaultLocaleManifest = [ordered]@{}
  foreach ($Key in $OldSingletonManifest.Keys.Where({ $_ -in $Patterns.LocaleProperties })) {
    $OldDefaultLocaleManifest[$Key] = $OldSingletonManifest.$Key
  }
  $OldDefaultLocaleManifest['ManifestType'] = 'defaultLocale'
  # Create locale manifests
  $OldLocaleManifests = @($OldDefaultLocaleManifest)
} else {
  throw "Version ${LastVersion} does not contain the required manifests"
}

# Move Manifest Level Keys to installer Level
Move-KeysToInstallerLevel -Manifest $OldInstallerManifest -Installers $OldInstallerManifest.Installers -Property $Patterns.InstallerEntryProperties.Where({ $_ -in $InstallerProperties })

Update-InstallerEntry
Write-VersionManifest
Write-InstallerManifest
Write-LocaleManifest
