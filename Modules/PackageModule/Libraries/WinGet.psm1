# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

Set-StrictMode -Version 3

$ManifestHeader = '# Created with YamlCreate.ps1 Dumplings Mod'
$ManifestVersion = '1.9.0'
$ManifestSchema = @{
  version       = $null
  installer     = $null
  defaultLocale = $null
  locale        = $null
}
$ManifestSchemaUrl = @{
  version       = "https://aka.ms/winget-manifest.version.${ManifestVersion}.schema.json"
  installer     = "https://aka.ms/winget-manifest.installer.${ManifestVersion}.schema.json"
  defaultLocale = "https://aka.ms/winget-manifest.defaultLocale.${ManifestVersion}.schema.json"
  locale        = "https://aka.ms/winget-manifest.locale.${ManifestVersion}.schema.json"
}
$ManifestSchemaDirectUrl = @{
  version       = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.version.${ManifestVersion}.json"
  installer     = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.installer.${ManifestVersion}.json"
  defaultLocale = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.defaultLocale.${ManifestVersion}.json"
  locale        = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v${ManifestVersion}/manifest.locale.${ManifestVersion}.json"
}

$Encoding = [System.Text.UTF8Encoding]::new($false)
$Culture = 'en-US'
$UserAgent = 'Microsoft-Delivery-Optimization/10.0'
$BackupUserAgent = 'winget-cli WindowsPackageManager/1.7.10661 DesktopAppInstaller/Microsoft.DesktopAppInstaller v1.22.10661.0'

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

function Initialize-WinGetManifestSchema {
  <#
  .SYNOPSIS
    Get WinGet manifest schema
  .DESCRIPTION
    Fetch Schema data from github for entry validation, key ordering, and automatic commenting
  #>

  if (-not $Script:ManifestSchema['version']) {
    $Script:ManifestSchema['version'] = Invoke-WebRequest -Uri $Script:ManifestSchemaDirectUrl.version | ConvertFrom-Json -AsHashtable
    Expand-YamlSchema -InputObject $Script:ManifestSchema['version']
  }
  if (-not $Script:ManifestSchema['installer']) {
    $Script:ManifestSchema['installer'] = Invoke-WebRequest -Uri $Script:ManifestSchemaDirectUrl.installer | ConvertFrom-Json -AsHashtable
    Expand-YamlSchema -InputObject $Script:ManifestSchema['installer']
  }
  if (-not $Script:ManifestSchema['defaultLocale']) {
    $Script:ManifestSchema['defaultLocale'] = Invoke-WebRequest -Uri $Script:ManifestSchemaDirectUrl.defaultLocale | ConvertFrom-Json -AsHashtable
    Expand-YamlSchema -InputObject $Script:ManifestSchema['defaultLocale']
  }
  if (-not $Script:ManifestSchema['locale']) {
    $Script:ManifestSchema['locale'] = Invoke-WebRequest -Uri $Script:ManifestSchemaDirectUrl.locale | ConvertFrom-Json -AsHashtable
    Expand-YamlSchema -InputObject $Script:ManifestSchema['locale']
  }
}

function Get-WinGetLocalRepoPath {
  <#
  .SYNOPSIS
    Get the location of the local winget-pkgs repo
  .PARAMETER RepoName
    The name of the upstream repo
  #>
  [OutputType([string])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, HelpMessage = 'The name of the upstream repo')]
    [string]$RepoName = 'winget-pkgs'
  )

  if ((Test-Path -Path 'Variable:\DumplingsPreference') -and -not [string]::IsNullOrWhiteSpace($Global:DumplingsPreference['LocalRepoPath']) -and (Test-Path -Path ($Path = Join-Path $Global:DumplingsPreference.LocalRepoPath 'manifests'))) {
    return Resolve-Path -Path $Path
  } elseif ((Test-Path -Path 'Env:\GITHUB_WORKSPACE') -and (Test-Path -Path ($Path = Join-Path $Env:GITHUB_WORKSPACE $RepoName 'manifests'))) {
    return Resolve-Path -Path $Path
  } elseif ((Test-Path -Path 'Variable:\DumplingsRoot') -and (Test-Path -Path ($Path = Join-Path $Global:DumplingsRoot '..' $RepoName 'manifests'))) {
    return Resolve-Path -Path $Path
  } elseif (Test-Path -Path ($Path = Join-Path $PSScriptRoot '..' '..' '..' '..' $RepoName 'manifests')) {
    return Resolve-Path -Path $Path
  } else {
    throw 'Could not locate local winget-pkgs repo'
  }
}

function Get-WinGetLocalPackageVersion {
  <#
  .SYNOPSIS
    Get the versions of a package
  .DESCRIPTION
    Get the versions of a package from the winget-pkgs repo
  .PARAMETER PackageIdentifier
    The identifier of the package
  .PARAMETER Root
    The root path to the manifests folder of the winget-pkgs repo
  #>
  [OutputType([string[]])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The identifier of the package')]
    [string]$PackageIdentifier,

    [Parameter(Position = 1, HelpMessage = 'The root path to the manifests folder of the winget-pkgs repo')]
    [string]$Root = (Get-WinGetLocalRepoPath)
  )

  process {
    @(
      Join-Path $Root $PackageIdentifier.ToLower().Chars(0) $PackageIdentifier.Replace('.', '\') '*' "${PackageIdentifier}.yaml" |
        Get-ChildItem -File |
        Split-Path -Parent | Split-Path -Leaf |
        Sort-Object $Script:ToNatural -Culture $Script:Culture -Stable
    )
  }
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

function Update-WinGetInstallerManifestInstallers {
  <#
  .SYNOPSIS
    Update the installer entries of the manifest
  .DESCRIPTION
    Update the installer entries of the manifest using the provided installer entries
  #>
  param (
    [Parameter(Position = 0)]
    [System.Collections.IDictionary[]]$OldInstallers,
    [Parameter(Position = 1)]
    [System.Collections.IDictionary[]]$InstallerEntries
  )

  $iteration = 0
  $Installers = @()
  $InstallerFiles = [ordered]@{}
  foreach ($OldInstaller in $OldInstallers) {
    $iteration += 1
    $Installer = $OldInstaller | Copy-Object
    $Task.Log("Updating installer #${iteration}/$($OldInstallers.Count) [$($Installer['InstallerLocale']), $($Installer['Architecture']), $($Installer['InstallerType']), $($Installer['NestedInstallerType']), $($Installer['Scope'])]", 'Verbose')

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
      } elseif ($Key -notin $Script:ManifestSchema.installer.definitions.Installer.properties.Keys) {
        # Check if the key is a valid installer property
        throw "The installer entry has an invalid key: ${Key}"
      } elseif ($Key -in @('InstallerLocale', 'Architecture', 'InstallerType', 'NestedInstallerType', 'Scope')) {
        # Skip the entries used for matching
        continue
      } else {
        try {
          if (Test-YamlObject -InputObject $MatchingInstallerEntry.$Key -Schema $Script:ManifestSchema.installer.properties.Installers.items.properties.$Key -WarningAction Stop) {
            if ($Key -eq 'InstallerUrl') {
              $Installer.$Key = $MatchingInstallerEntry.$Key.Replace(' ', '%20')
            } else {
              $Installer.$Key = $MatchingInstallerEntry.$Key
            }
          } else {
            $Task.Log("The new value of the installer property `"${Key}`" is invalid and thus discarded", 'Warning')
          }
        } catch {
          $Task.Log("The new value of the installer property `"${Key}`" is invalid and thus discarded: ${_}", 'Warning')
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
        $Task.Log("Downloading $($Installer.InstallerUrl)", 'Verbose')
        try {
          $InstallerPath = Get-TempFile -Uri $Installer.InstallerUrl -UserAgent $Script:UserAgent
          $InstallerFiles[$Installer.InstallerUrl] = $InstallerPath
        } catch {
          $Task.Log('Failed to download with the Delivery-Optimization User Agent. Try again with the WinINet User Agent...', 'Warning')
          $InstallerPath = Get-TempFile -Uri $Installer.InstallerUrl -UserAgent $Script:BackupUserAgent
        }
      }

      $Task.Log('Processing installer data...', 'Verbose')

      # Get installer SHA256
      $Installer.InstallerSha256 = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash

      # If the installer is an archive and the nested installer is msi or wix, expand the archive to get the nested installer
      $EffectiveInstallerType = $Installer.Contains('NestedInstallerType') ? $Installer.NestedInstallerType : $Installer.InstallerType
      $EffectiveInstallerPath = $Installer.InstallerType -in @('zip') -and $Installer.NestedInstallerType -ne 'portable' ? (Expand-TempArchive -Path $InstallerPath | Join-Path -ChildPath $Installer.NestedInstallerFiles[0].RelativeFilePath) : $InstallerPath

      # Update ProductCode, UpgradeCode and ProductVersion if the installer is msi, wix or burn, and such fields exist in the old installer
      # ProductCode
      $ProductCode = $null
      if ($EffectiveInstallerType -in @('msi', 'wix')) {
        $ProductCode = $EffectiveInstallerPath | Read-ProductCodeFromMsi -ErrorAction 'Continue'
      } elseif ($EffectiveInstallerType -eq 'burn') {
        $ProductCode = $EffectiveInstallerPath | Read-ProductCodeFromBurn -ErrorAction 'Continue'
      }
      if (-not $MatchingInstallerEntry.Contains('ProductCode') -and $EffectiveInstallerType -in @('msi', 'wix', 'burn') -and $Installer.Contains('ProductCode')) {
        if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
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
            if (-not [string]::IsNullOrWhiteSpace($DisplayName)) {
              $_.DisplayName = $DisplayName
            } else {
              throw 'Failed to get DisplayName'
            }
          }
          if ($_.Contains('DisplayVersion')) {
            if (-not [string]::IsNullOrWhiteSpace($DisplayVersion)) {
              $_.DisplayVersion = $DisplayVersion
            } else {
              throw 'Failed to get DisplayVersion'
            }
          }
          if ($_.Contains('ProductCode')) {
            if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
              $_.ProductCode = $ProductCode
            } else {
              throw 'Failed to get ProductCode'
            }
          }
          if ($_.Contains('UpgradeCode')) {
            if (-not [string]::IsNullOrWhiteSpace($UpgradeCode)) {
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
              $Task.Log('Could not find the WinGet client for getting SignatureSha256. Is it installed and added to PATH?', 'Error')
            } elseif ($_.FullyQualifiedErrorId -eq 'ProgramExitedWithNonZeroCode' -and $i -lt $WinGetMaximumRetryCount - 1) {
              $Task.Log("WinGet exits with exitcode $($_.Exception.ExitCode)", 'Warning')
            }
          }
        }
        if ($SignatureSha256 -and $SignatureSha256.P2) { $SignatureSha256 = $SignatureSha256.P2.ToUpper() }
        if (-not [string]::IsNullOrWhiteSpace($SignatureSha256)) {
          $Installer.SignatureSha256 = $SignatureSha256
        } elseif ($Installer.Contains('SignatureSha256')) {
          $Task.Log('Failed to get SignatureSha256', 'Warning')
          $Installer.Remove('SignatureSha256')
        }
      }

      # Update PackageFamilyName if the installer is msix or appx
      if ($Installer.InstallerType -in @('msix', 'appx')) {
        $PackageFamilyName = $InstallerPath | Read-FamilyNameFromMSIX
        if (-not [string]::IsNullOrWhiteSpace($PackageFamilyName)) {
          $Installer.PackageFamilyName = $PackageFamilyName
        } elseif ($Installer.Contains('PackageFamilyName')) {
          $Task.Log('Failed to get PackageFamilyName', 'Warning')
          $Installer.Remove('PackageFamilyName')
        }
      }
    }

    # Add the updated installer to the new installers array
    $Installers += $Installer
  }

  # Remove the downloaded files
  foreach ($InstallerPath in $InstallerFiles.Values) {
    Remove-Item -Path $InstallerPath -Force -ErrorAction 'Continue'
  }

  return $Installers
}

function Update-WinGetVersionManifest {
  param (
    [Parameter(Position = 0, Mandatory)]
    [System.Collections.IDictionary]$OldVersionManifest,
    [Parameter(Position = 1, Mandatory)]
    [string]$PackageVersion
  )

  # Deep copy the old version manifest
  $VersionManifest = $OldVersionManifest | Copy-Object

  # Bump package version
  $VersionManifest.PackageVersion = $PackageVersion
  # Bump manifest version
  $VersionManifest.ManifestVersion = $Script:ManifestVersion

  return ConvertTo-SortedYamlObject -InputObject $VersionManifest -Schema $Script:ManifestSchema.version -Culture $Script:Culture
}

function Update-WinGetInstallerManifest {
  param (
    [Parameter(Position = 0, Mandatory)]
    [System.Collections.IDictionary]$OldInstallerManifest,
    [Parameter(Position = 1, Mandatory)]
    [System.Collections.IDictionary[]]$InstallerEntries,
    [Parameter(Position = 2, Mandatory)]
    [string]$PackageVersion
  )

  # Deep copy the old installer manifest
  $InstallerManifest = $OldInstallerManifest | Copy-Object

  # Bump package version
  $InstallerManifest.PackageVersion = $PackageVersion
  # Bump manifest version
  $InstallerManifest.ManifestVersion = $Script:ManifestVersion

  # Move Manifest Level Keys to installer Level
  Move-KeysToInstallerLevel -Manifest $InstallerManifest -Installers $InstallerManifest.Installers -Property $Script:ManifestSchema.installer.definitions.Installer.properties.Keys.Where({ $_ -in $Script:ManifestSchema.installer.properties.Keys })
  # Update installer entries
  $InstallerManifest.Installers = Update-WinGetInstallerManifestInstallers -OldInstallers $InstallerManifest.Installers -InstallerEntries $InstallerEntries
  # Move Installer Level Keys to Manifest Level
  Move-KeysToManifestLevel -Installers $InstallerManifest.Installers -Manifest $InstallerManifest -Property $Script:ManifestSchema.installer.definitions.Installer.properties.Keys.Where({ $_ -in $Script:ManifestSchema.installer.properties.Keys })

  # Clean up the existing files just in case
  if ($InstallerManifest.Contains('Commands')) { $InstallerManifest.Commands = @($InstallerManifest.Commands | UniqueItems | NoWhitespace | Sort-Object -Culture $Script:Culture) }
  if ($InstallerManifest.Contains('Protocols')) { $InstallerManifest.Protocols = @($InstallerManifest.Protocols | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Script:Culture) }
  if ($InstallerManifest.Contains('FileExtensions')) { $InstallerManifest.FileExtensions = @($InstallerManifest.FileExtensions | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Script:Culture) }

  return ConvertTo-SortedYamlObject -InputObject $InstallerManifest -Schema $Script:ManifestSchema.installer -Culture $Script:Culture
}

function Update-WinGetLocaleManifest {
  param (
    [Parameter(Mandatory, HelpMessage = 'The old locale manifests to update')]
    [System.Collections.IDictionary[]]$OldLocaleManifests,
    [Parameter(Position = 1)]
    [System.Collections.IDictionary[]]$LocaleEntries,
    [Parameter(Position = 2, Mandatory)]
    [string]$PackageVersion
  )

  $LocaleManifests = @()

  # Copy over all locale files from previous version that aren't the same
  foreach ($OldLocaleManifest in $OldLocaleManifests) {
    $LocaleManifest = $OldLocaleManifest | Copy-Object

    # Bump package version
    $LocaleManifest.PackageVersion = $PackageVersion
    # Bump manifest version
    $LocaleManifest.ManifestVersion = $Script:ManifestVersion
    # Clean up volatile fields
    if ($LocaleManifest.Contains('ReleaseNotes')) { $LocaleManifest.Remove('ReleaseNotes') }

    # Apply inputs
    if ($LocaleEntries) {
      foreach ($LocaleEntry in $LocaleEntries) {
        if (-not $LocaleEntry.Contains('Key') -or -not $LocaleEntry.Contains('Value') -or [string]::IsNullOrWhiteSpace($LocaleEntry.Key)) {
          # Check if the locale entry contains the required properties
          throw 'The locale entry does not contain the required properties'
        } elseif ($LocaleEntry.Key -notin $Script:ManifestSchema.locale.properties.Keys) {
          # Check if the key property is a valid locale property
          throw "The locale entry has an invalid key `"$($LocaleEntry.Key)`""
        } elseif ($LocaleEntry.Contains('Locale') -and $LocaleEntry.Locale -notmatch $Script:ManifestSchema.locale.properties.PackageLocale.pattern) {
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
            if (Test-YamlObject -InputObject $LocaleEntry.Value -Schema $Script:ManifestSchema.locale.properties[$LocaleEntry.Key] -WarningAction Stop) {
              $LocaleManifest[$LocaleEntry.Key] = $LocaleEntry.Value
            } else {
              $Task.Log("The locale entry `"$($LocaleEntry.Key)`" has an invalid value and thus discarded", 'Warning')
            }
          } catch {
            $Task.Log("The locale entry `"$($LocaleEntry.Key)`" has an invalid value and thus discarded: ${_}", 'Warning')
          }
        }
      }
    }

    if ($LocaleManifest.Contains('Tags')) { $LocaleManifest.Tags = @($LocaleManifest.Tags | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Script:Culture) }
    if ($LocaleManifest.Contains('Moniker')) {
      if ($LocaleManifest.ManifestType -eq 'defaultLocale') {
        $LocaleManifest['Moniker'] = $LocaleManifest['Moniker'] | ToLower | NoWhitespace
      } else {
        $LocaleManifest.Remove('Moniker')
      }
    }
    # Remove ReleaseNotes if too long
    if ($LocaleManifest.Contains('ReleaseNotes') -and $LocaleManifest.ReleaseNotes.Length -gt $Script:ManifestSchema.locale.properties.ReleaseNotes.maxLength) { $LocaleManifest.Remove('ReleaseNotes') }

    $Schema = $LocaleManifest.ManifestType -eq 'defaultLocale' ? $Script:ManifestSchema.defaultLocale : $Script:ManifestSchema.locale
    $LocaleManifests += ConvertTo-SortedYamlObject -InputObject $LocaleManifest -Schema $Schema -Culture $Script:Culture
  }

  return $LocaleManifests
}

function Read-WinGetManifests {
  <#
  .SYNOPSIS
    Read the manifests for a package
  .DESCRIPTION
    Read the installer, locale and version manifests for a package using the provided package identifier and manifests path
  .PARAMETER PackageIdentifier
    The package identifier of the manifest
  .PARAMETER ManifestsPath
    The directory to the folder where the manifests are stored
  #>
  [OutputType([System.Collections.IDictionary])]
  param (
    [Parameter(Mandatory, HelpMessage = 'The package identifier of the manifest')]
    [string] $PackageIdentifier,
    [Parameter(Mandatory, HelpMessage = 'The directory to the folder where the old manifests are stored')]
    [string] $ManifestsPath
  )

  # If the old manifests exist, find the default locale
  $Manifests = Join-Path $ManifestsPath '*.yaml' | Get-ChildItem -File
  $Manifest = $Manifests | Where-Object -FilterScript { $_.Name -eq "${PackageIdentifier}.yaml" } | Get-Content -Raw -Encoding $Script:Encoding | ConvertFrom-Yaml -Ordered
  if ($Manifest.ManifestType -eq 'version') {
    $ManifestType = 'MultiManifest'
    $PackageLocale = $Manifest.DefaultLocale
  } elseif ($Manifest.ManifestType -eq 'singleton') {
    $ManifestType = 'SingletonManifest'
    $PackageLocale = $Manifest.PackageLocalet
  } else {
    throw "Unrecognized manifest type $($Manifest.ManifestType)"
  }

  # If the old manifests exist, read their information into variables
  # Also ensure additional requirements are met for creating or updating files
  if ($ManifestType -eq 'MultiManifest' -and $Manifests.Name -contains "${PackageIdentifier}.yaml" -and $Manifests.Name -contains "${PackageIdentifier}.installer.yaml" -and $Manifests.Name -contains "${PackageIdentifier}.locale.${PackageLocale}.yaml") {
    $VersionManifest = $Manifest
    $InstallerManifest = $Manifests | Where-Object -FilterScript { $_.Name -eq "${PackageIdentifier}.installer.yaml" } | Get-Content -Raw -Encoding $Script:Encoding | ConvertFrom-Yaml -Ordered
    $LocaleManifests = @($Manifests | Where-Object -FilterScript { $_.Name -like "${PackageIdentifier}.locale.*.yaml" } | ForEach-Object -Process { Get-Content -Path $_ -Raw -Encoding $Script:Encoding | ConvertFrom-Yaml -Ordered })
  } elseif ($ManifestType -eq 'Singleton' -and $Manifests.Name -contains "${PackageIdentifier}.yaml") {
    $SingletonManifest = $Manifest
    # Parse version keys to version manifest
    $VersionManifest = [ordered]@{}
    foreach ($Key in $SingletonManifest.Keys.Where({ $_ -in $Script:ManifestSchema.version.properties.Keys })) {
      $VersionManifest[$Key] = $SingletonManifest.$Key
    }
    $VersionManifest['DefaultLocale'] = $PackageLocale
    $VersionManifest['ManifestType'] = 'version'
    # Parse installer keys to installer manifest
    $InstallerManifest = [ordered]@{}
    foreach ($Key in $SingletonManifest.Keys.Where({ $_ -in $Script:ManifestSchema.installer.properties.Keys })) {
      $InstallerManifest[$Key] = $SingletonManifest.$Key
    }
    $InstallerManifest['ManifestType'] = 'installer'
    # Parse default locale keys to default locale manifest
    $DefaultLocaleManifest = [ordered]@{}
    foreach ($Key in $SingletonManifest.Keys.Where({ $_ -in $Script:ManifestSchema.locale.properties.Keys })) {
      $DefaultLocaleManifest[$Key] = $SingletonManifest.$Key
    }
    $DefaultLocaleManifest['ManifestType'] = 'defaultLocale'
    # Create locale manifests
    $LocaleManifests = @($DefaultLocaleManifest)
  } else {
    throw "Version ${LastVersion} does not contain the required manifests"
  }

  return @{
    Installer = $InstallerManifest
    Locale    = $LocaleManifests
    Version   = $VersionManifest
  }
}

function Update-WinGetManifests {
  <#
  .SYNOPSIS
    Update WinGet package manifests
  .DESCRIPTION
    Update WinGet package manifests using the provided installer and locale entries
  .PARAMETER PackageVersion
    The package version of the manifest
  .PARAMETER VersionManifest
    The version manifest to update
  .PARAMETER InstallerManifest
    The installer manifest to update
  .PARAMETER LocaleManifests
    The locale manifests to update
  .PARAMETER InstallerEntries
    The installer entries to be applied to the installer manifest
  .PARAMETER LocaleEntries
    The locale entries to be applied to the locale manifest
  #>
  [OutputType([System.Collections.IDictionary])]
  param (
    [Parameter(Mandatory, HelpMessage = 'The package version of the manifest')]
    [string]$PackageVersion,
    [Parameter(Mandatory, HelpMessage = 'The version manifest to update')]
    [System.Collections.IDictionary]$VersionManifest,
    [Parameter(Mandatory, HelpMessage = 'The installer manifest to update')]
    [System.Collections.IDictionary]$InstallerManifest,
    [Parameter(Mandatory, HelpMessage = 'The locale manifests to update')]
    [System.Collections.IDictionary[]]$LocaleManifests,
    [Parameter(Mandatory, HelpMessage = 'The installer entries to be applied to the installer manifest')]
    [System.Collections.IDictionary[]]$InstallerEntries,
    [Parameter(HelpMessage = 'The locale entries to be applied to the locale manifest')]
    [System.Collections.IDictionary[]]$LocaleEntries = @()
  )

  return @{
    Installer = Update-WinGetInstallerManifest -OldInstallerManifest $InstallerManifest -InstallerEntries $InstallerEntries -PackageVersion $PackageVersion
    Locale    = Update-WinGetLocaleManifest -OldLocaleManifests $LocaleManifests -LocaleEntries $LocaleEntries -PackageVersion $PackageVersion
    Version   = Update-WinGetVersionManifest -OldVersionManifest $VersionManifest -PackageVersion $PackageVersion
  }
}

function Write-WinGetManifestContent {
  param (
    [Parameter(Position = 0, Mandatory)]
    [string]$FilePath,
    [Parameter(Position = 1, Mandatory)]
    [System.Collections.IDictionary]$YamlContent,
    [Parameter(Position = 2, Mandatory)]
    [string]$Schema
  )

  [System.IO.File]::WriteAllLines($FilePath, @(
      $Script:ManifestHeader
      "# yaml-language-server: `$schema=$Schema"
      ''
      (ConvertTo-Yaml $YamlContent -Options DisableAliases).TrimEnd()
    ), $Script:Encoding)

  $Task.Log("Yaml file created: ${FilePath}", 'Verbose')
}

function Write-WinGetManifests {
  <#
  .SYNOPSIS
    Write the new manifests for a WinGet package
  .DESCRIPTION
    Write the new manifests for a WinGet package using the provided version, installer and locale manifests
  .PARAMETER PackageIdentifier
    The package identifier of the manifest
  .PARAMETER VersionManifest
    The version manifest to write
  .PARAMETER InstallerManifest
    The installer manifest to write
  .PARAMETER LocaleManifests
    The locale manifests to write
  .PARAMETER ManifestsPath
    The directory to the folder where the new manifests will be stored
  #>
  param (
    [Parameter(Mandatory, HelpMessage = 'The package identifier of the manifest')]
    [string]$PackageIdentifier,
    [Parameter(Mandatory, HelpMessage = 'The version manifest to write')]
    [System.Collections.IDictionary]$VersionManifest,
    [Parameter(Mandatory, HelpMessage = 'The installer manifest to write')]
    [System.Collections.IDictionary]$InstallerManifest,
    [Parameter(Mandatory, HelpMessage = 'The locale manifests to write')]
    [System.Collections.IDictionary[]]$LocaleManifests,
    [Parameter(Mandatory, HelpMessage = 'The directory to the folder where the new manifests will be stored')]
    [string]$ManifestsPath
  )

  $InstallerManifestPath = Join-Path $ManifestsPath "${PackageIdentifier}.installer.yaml"
  Write-WinGetManifestContent -FilePath $InstallerManifestPath -YamlContent $InstallerManifest -Schema $Script:ManifestSchemaUrl.installer

  foreach ($LocaleManifest in $LocaleManifests) {
    $LocaleManifestPath = Join-Path $ManifestsPath "${PackageIdentifier}.locale.$($LocaleManifest.PackageLocale).yaml"
    $SchemaUrl = $LocaleManifest.ManifestType -eq 'defaultLocale' ? $Script:ManifestSchemaUrl.defaultLocale : $Script:ManifestSchemaUrl.locale
    Write-WinGetManifestContent -FilePath $LocaleManifestPath -YamlContent $LocaleManifest -Schema $SchemaUrl
  }

  $VersionManifestPath = Join-Path $ManifestsPath "${PackageIdentifier}.yaml"
  Write-WinGetManifestContent -FilePath $VersionManifestPath -YamlContent $VersionManifest -Schema $Script:ManifestSchemaUrl.version
}

function Send-WinGetManifest {
  <#
  .SYNOPSIS
    Generate and submit WinGet package manifests
  .DESCRIPTION
    Generate WinGet package manifests, upload them to the origin repo and create a pull request in the upstream repo
    Specifically, it does the following:
    1. Check existing pull requests in upstream.
    2. Generate new manifests using the information from current state.
    3. Validate new manifests.
    4. Upload new manifests to origin.
    5. Create pull requests in upstream.
  .PARAMETER Task
    The task object to be handled
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The task object to be handled')]
    $Task
  )

  #region Parameters for repo
  # Parameters for repo
  $UpstreamRepoOwner = $Global:DumplingsPreference['WinGetUpstreamRepoOwner'] ?? 'microsoft'
  $UpstreamRepoName = $Global:DumplingsPreference['WinGetUpstreamRepoName'] ?? 'winget-pkgs'
  $UpstreamRepoBranch = $Global:DumplingsPreference['WinGetUpstreamRepoBranch'] ?? 'master'

  if ($Global:DumplingsPreference['WinGetOriginRepoOwner']) {
    $OriginRepoOwner = $Global:DumplingsPreference.WinGetOriginRepoOwner
  } elseif (Test-Path -Path 'Env:\GITHUB_ACTIONS') {
    $OriginRepoOwner = $Env:GITHUB_REPOSITORY_OWNER
  } else {
    throw 'The WinGet origin repo owner is unset'
  }
  $OriginRepoName = $Global:DumplingsPreference['WinGetOriginRepoName'] ?? 'winget-pkgs'
  $OriginRepoBranch = $Global:DumplingsPreference['WinGetOriginRepoBranch'] ?? 'master'

  $LocalRepoPath = Get-WinGetLocalRepoPath
  #endregion

  #region Parameters for package
  Initialize-WinGetManifestSchema

  [string]$PackageIdentifier = $Task.Config.WinGetIdentifier
  try {
    $null = Test-YamlObject -InputObject $PackageIdentifier -Schema $Script:ManifestSchema.version.properties.PackageIdentifier -WarningAction Stop
  } catch {
    throw "The PackageIdentifier `"${PackageIdentifier}`" is invalid: ${_}"
  }

  [string]$PackageVersion = $Task.CurrentState.Contains('RealVersion') ? $Task.CurrentState.RealVersion : $Task.CurrentState.Version
  try {
    $null = Test-YamlObject -InputObject $PackageVersion -Schema $Script:ManifestSchema.version.properties.PackageVersion -WarningAction Stop
  } catch {
    throw "The PackageVersion `"${PackageVersion}`" is invalid: ${_}"
  }

  $PackagePath = Join-Path $LocalRepoPath $PackageIdentifier.ToLower().Chars(0) $PackageIdentifier.Replace('.', '\')
  if (-not (Test-Path -Path $PackagePath)) { throw "The folder of the package ${PackageIdentifier} does not exist" }

  $PackageLastVersion = Get-WinGetLocalPackageVersion -PackageIdentifier $PackageIdentifier -Root $LocalRepoPath | Select-Object -Last 1
  if (-not $PackageLastVersion) { throw "Could not find any version of the package ${PackageIdentifier}" }

  $OldManifestsPath = Join-Path $PackagePath $PackageLastVersion
  $NewManifestsPath = (New-Item -Path (Join-Path $Global:DumplingsOutput 'WinGet' $PackageIdentifier $PackageVersion) -ItemType Directory -Force).FullName
  #endregion

  #region Parameters for publishing
  $NewBranchName = "${PackageIdentifier}-${PackageVersion}-$(Get-Random)" -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
  $NewCommitType = if ($Global:DumplingsPreference['NewCommitType']) {
    $Global:DumplingsPreference.NewCommitType
  } else {
    switch (([Versioning]$PackageVersion).CompareTo([Versioning]$PackageLastVersion)) {
      { $_ -gt 0 } { 'New version'; continue }
      0 { 'Update'; continue }
      { $_ -lt 0 } { 'Add version'; continue }
    }
  }
  $NewCommitName = "${NewCommitType}: ${PackageIdentifier} version ${PackageVersion}"
  if ($Task.CurrentState.Contains('RealVersion')) { $NewCommitName += " ($($Task.CurrentState.Version))" }
  #endregion

  #region Check existing pull requests in the upstream repo
  if ($Global:DumplingsPreference['Force']) {
    $Task.Log('Skip checking pull requests in the upstream repo in force mode', 'Info')
  } elseif ($Global:DumplingsPreference['Dry']) {
    $Task.Log('Skip checking pull requests in the upstream repo in dry mode', 'Info')
  } elseif ($Task.Config['IgnorePRCheck']) {
    $Task.Log('Skip checking pull requests in the upstream repo as the task is set to do so', 'Info')
  } elseif ($Task.LastState.Contains('Version') -and $Task.LastState.Contains('RealVersion') -and ($Task.LastState.Version -ne $Task.CurrentState.Version) -and ($Task.LastState.RealVersion -eq $Task.CurrentState.RealVersion)) {
    $Task.Log("Skip checking pull requests in the upstream repo as the version is updated while the real version isn't", 'Info')
  } else {
    $Task.Log('Checking existing pull requests in the upstream repo', 'Verbose')
    $OldPullRequests = Invoke-GitHubApi -Uri "https://api.github.com/search/issues?q=repo%3A${UpstreamRepoOwner}%2F${UpstreamRepoName}%20is%3Apr%20$($PackageIdentifier.Replace('.', '%2F'))%2F${PackageVersion}%20in%3Apath"
    if ($OldPullRequestsItems = $OldPullRequests.items | Where-Object -FilterScript { $_.title -match "(\s|^)$([regex]::Escape($PackageIdentifier))(\s|$)" -and $_.title -match "(\s|^)$([regex]::Escape($PackageVersion))(\s|$)" }) {
      throw "Found existing pull requests:`n$($OldPullRequestsItems | Select-Object -First 3 | ForEach-Object -Process { "$($_.title) - $($_.html_url)" } | Join-String -Separator "`n")"
    }
  }
  #endregion

  #region Generate manifests
  try {
    # Map the release date to the installer entries
    if ($Task.CurrentState['ReleaseTime']) {
      $ReleaseDate = $Task.CurrentState.ReleaseTime -is [datetime] -or $Task.CurrentState.ReleaseTime -is [System.DateTimeOffset] ? $Task.CurrentState.ReleaseTime.ToUniversalTime().ToString('yyyy-MM-dd') : ($Task.CurrentState.ReleaseTime | Get-Date -Format 'yyyy-MM-dd')
      $Task.CurrentState.Installer | ForEach-Object -Process { if (-not $_.Contains('ReleaseDate')) { $_.ReleaseDate = $ReleaseDate } }
    }

    # Read the old manifests
    $OldManifests = Read-WinGetManifests -PackageIdentifier $PackageIdentifier -ManifestsPath $OldManifestsPath
    # If the old manifests exist, make sure to use the same casing as the existing package identifier
    $PackageIdentifier = $OldManifests.Version.PackageIdentifier
    # Update the manifests
    $NewManifests = Update-WinGetManifests -PackageVersion $PackageVersion -VersionManifest $OldManifests.Version -InstallerManifest $OldManifests.Installer -LocaleManifests $OldManifests.Locale -InstallerEntries $Task.CurrentState.Installer -LocaleEntries $Task.CurrentState.Locale
    # Write the new manifests
    Write-WinGetManifests -PackageIdentifier $PackageIdentifier -VersionManifest $NewManifests.Version -InstallerManifest $NewManifests.Installer -LocaleManifests $NewManifests.Locale -ManifestsPath $NewManifestsPath
  } catch {
    throw "Failed to generate manifests: ${_}"
  }
  #endregion

  #region Validate manifests using WinGet client
  $WinGetOutput = ''
  $WinGetMaximumRetryCount = 3
  for ($i = 0; $i -lt $WinGetMaximumRetryCount; $i++) {
    try {
      winget.exe validate $NewManifestsPath | Out-String -Stream -OutVariable 'WinGetOutput'
      break
    } catch {
      if ($_.FullyQualifiedErrorId -eq 'CommandNotFoundException') {
        throw 'Failed to validate manifests: Could not locate WinGet client for validating manifests. Is it installed and added to PATH?'
      } elseif ($_.FullyQualifiedErrorId -eq 'ProgramExitedWithNonZeroCode') {
        # WinGet may throw warnings for, for example, not specifying the installer switches for EXE installers. Such warnings are ignored
        if ($_.Exception.ExitCode -eq -1978335192) {
          break
        } else {
          # WinGet may crash when multiple instances are initiated simultaneously. Retry the validation for a few times
          if ($i -eq $WinGetMaximumRetryCount - 1) {
            throw "Failed to pass manifests validation: $($WinGetOutput -join "`n")"
          } else {
            $Task.Log("WinGet exits with exitcode $($_.Exception.ExitCode)", 'Warning')
          }
        }
      } else {
        throw "Failed to validate manifests: ${_}"
      }
    }
  }
  #endregion

  # Do not upload manifests in dry mode
  if ($Global:DumplingsPreference['Dry']) {
    $Task.Log('Running in dry mode. Exiting...', 'Info')
    return
  }

  #region Create a new branch in the origin repo
  # The new branch is based on the default branch of the origin repo instead of the one of the upstream repo
  # This is to mitigate the occasional and weird issue of "ref not found" when creating a branch based on the upstream default branch
  # The origin repo should be synced as early as possible to avoid conflicts with other commits
  try {
    $OriginRepoBranchRef = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/ref/heads/${OriginRepoBranch}"
    $NewBranchRef = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/refs" -Method Post -Body @{
      ref = "refs/heads/${NewBranchName}"
      sha = $OriginRepoBranchRef.object.sha
    }
  } catch {
    throw "Failed to create a new branch in the origin repo: ${_}"
  }
  #endregion

  #region Upload new manifests and remove old manifests
  try {
    $NewBlobs = @()
    Get-ChildItem -Path $NewManifestsPath -Include '*.yaml' -Recurse -File | ForEach-Object -Process {
      $NewBlob = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/blobs" -Method Post -Body @{
        content  = Get-Content -Path $_ -Raw -Encoding $Script:Encoding
        encoding = 'utf-8'
      }
      $NewBlobs += @{
        Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${PackageVersion}/$($_.Name)"
        Sha  = $NewBlob.sha
      }
    }
    if ($NewBlobs.Count -eq 0) { throw 'Could not find any files to upload' }

    # Remove old manifests, if
    # 1. The task is configured to remove the last version, or
    # 2. No installer URL is changed compared with the last state while the version is updated
    $RemoveLastVersionReason = $null
    if ($Task.Config['RemoveLastVersion']) {
      $RemoveLastVersionReason = 'This task is configured to remove the last version'
    } elseif ($Task.LastState.Contains('Version') -and ($Task.LastState.Version -ne $Task.CurrentState.Version) -and -not (Compare-Object -ReferenceObject $Task.LastState -DifferenceObject $Task.CurrentState -Property { $_.Installer.InstallerUrl })) {
      $RemoveLastVersionReason = 'No installer URL is changed compared with the last state while the version is updated'
    }
    if ($RemoveLastVersionReason) {
      if ($PackageLastVersion -ne $PackageVersion) {
        $Task.Log("Removing the manifests of the last version ${PackageLastVersion}: ${RemoveLastVersionReason}", 'Info')
        Get-ChildItem -Path "${LocalRepoPath}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\${PackageLastVersion}\*.yaml" -File | ForEach-Object -Process {
          $NewBlobs += @{
            Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${PackageLastVersion}/$($_.Name)"
            Sha  = $null
          }
        }
      } else {
        $Task.Log("Overriding the manifests of the last version ${PackageLastVersion}: ${RemoveLastVersionReason}", 'Info')
      }
    }
  } catch {
    throw "Failed to upload manifests: ${_}"
  }
  #endregion

  #region Build a new tree containing the uploaded/removing files
  try {
    $NewTree = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/trees" -Method Post -Body @{
      tree      = @($NewBlobs | ForEach-Object -Process { @{ path = $_.Path ; mode = '100644'; type = 'blob'; sha = $_.Sha } })
      base_tree = $NewBranchRef.object.sha
    }
  } catch {
    throw "Failed to create a new tree: ${_}"
  }
  #endregion

  #region Create a new commit from the tree
  try {
    $NewCommit = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/commits" -Method Post -Body @{
      tree    = $NewTree.sha
      message = $NewCommitName
      parents = @($NewBranchRef.object.sha)
    }
  } catch {
    throw "Failed to create a new commit: ${_}"
  }
  #endregion

  #region Move the branch HEAD to the commit
  try {
    $null = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/refs/heads/${NewBranchName}" -Method Post -Body @{
      sha = $NewCommit.sha
    }
  } catch {
    throw "Failed to move the branch HEAD to the commit: ${_}"
  }
  #endregion

  #region Create a pull request in the upstream repo
  try {
    $NewPullRequest = Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamRepoOwner}/${UpstreamRepoName}/pulls" -Method Post -Body @{
      title = $NewCommitName
      body  = (Test-Path -Path 'Env:\GITHUB_ACTIONS') ? "Automated by [🥟 ${Env:GITHUB_REPOSITORY_OWNER}/Dumplings](https://github.com/${Env:GITHUB_REPOSITORY_OWNER}/Dumplings) in workflow run [#${Env:GITHUB_RUN_NUMBER}](https://github.com/${Env:GITHUB_REPOSITORY_OWNER}/Dumplings/actions/runs/${Env:GITHUB_RUN_ID})." : "Created by [🥟 Dumplings](https://github.com/${OriginRepoOwner}/Dumplings)."
      head  = "${OriginRepoOwner}:${NewBranchName}"
      base  = $UpstreamRepoBranch
    }
    $Task.Log("Pull request created: $($NewPullRequest.title) - $($NewPullRequest.html_url)", 'Info')
  } catch {
    throw "Failed to create a pull request: ${_}"
  }
  #endregion
}
