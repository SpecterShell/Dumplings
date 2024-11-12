<#
.SYNOPSIS
    WinGet Manifest creation helper script
.DESCRIPTION
    The intent of this file is to help you generate a manifest for publishing
    to the Windows Package Manager repository.

    It'll attempt to download an installer from the user-provided URL to calculate
    a checksum. That checksum and the rest of the input data will be compiled in a
    .YAML file.
.EXAMPLE
    PS C:\Projects\winget-pkgs> Get-Help .\Tools\YamlCreate.ps1 -Full
    Show this script's help
.EXAMPLE
    PS C:\Projects\winget-pkgs> .\Tools\YamlCreate.ps1
    Run the script to create a manifest file
.NOTES
    Please file an issue if you run into errors with this script:
    https://github.com/microsoft/winget-pkgs/issues/
.LINK
    https://github.com/microsoft/winget-pkgs/blob/master/Tools/YamlCreate.ps1
#>
#Requires -Version 7
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]

Param
(
  [Parameter(Mandatory = $true)]
  [string] $ManifestsFolder,
  [Parameter(Mandatory = $true)]
  [string] $OutFolder,
  [Parameter(Mandatory = $true)]
  [string] $PackageIdentifier,
  [Parameter(Mandatory = $true)]
  [string] $PackageVersion,
  [Parameter(Mandatory = $true)]
  [Object[]] $InstallerEntries,
  [Parameter(Mandatory = $false)]
  [Object[]] $LocaleEntries,
  [Parameter(Mandatory = $true)]
  [System.Management.Automation.PSMethod]$Logger
)

$ScriptHeader = '# Created with YamlCreate.ps1 v2.4.1 Dumplings Mod'
$ManifestVersion = '1.6.0'
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$Culture = 'en-US'
if (-not ([System.Environment]::OSVersion.Platform -match 'Win')) { $env:TEMP = '/tmp/' }
$script:UserAgent = 'Microsoft-Delivery-Optimization/10.0'
$script:BackupUserAgent = 'winget-cli WindowsPackageManager/1.7.10661 DesktopAppInstaller/Microsoft.DesktopAppInstaller v1.22.10661.0'
$DumplingsLogIdentifier = $DumplingsLogIdentifier + 'YamlCreate'

$SchemaUrls = @{
  version       = "https://aka.ms/winget-manifest.version.$ManifestVersion.schema.json"
  defaultLocale = "https://aka.ms/winget-manifest.defaultLocale.$ManifestVersion.schema.json"
  locale        = "https://aka.ms/winget-manifest.locale.$ManifestVersion.schema.json"
  installer     = "https://aka.ms/winget-manifest.installer.$ManifestVersion.schema.json"
}
$DirectSchemaUrls = @{
  version       = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.version.$ManifestVersion.json"
  defaultLocale = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.defaultLocale.$ManifestVersion.json"
  locale        = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.locale.$ManifestVersion.json"
  installer     = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.installer.$ManifestVersion.json"
}

# Fetch Schema data from github for entry validation, key ordering, and automatic commenting
try {
  $LocaleSchema = $DumplingsSessionStorage['WinGetLocaleSchema'] ??= @(Invoke-WebRequest $DirectSchemaUrls.defaultLocale -UseBasicParsing | ConvertFrom-Json)
  $LocaleProperties = (ConvertTo-Yaml $LocaleSchema.properties | ConvertFrom-Yaml -Ordered).Keys
  $VersionSchema = $DumplingsSessionStorage['WinGetVersionSchema'] ??= @(Invoke-WebRequest $DirectSchemaUrls.version -UseBasicParsing | ConvertFrom-Json)
  $VersionProperties = (ConvertTo-Yaml $VersionSchema.properties | ConvertFrom-Yaml -Ordered).Keys
  $InstallerSchema = $DumplingsSessionStorage['WinGetInstallerSchema'] ??= @(Invoke-WebRequest $DirectSchemaUrls.installer -UseBasicParsing | ConvertFrom-Json)
  $InstallerProperties = (ConvertTo-Yaml $InstallerSchema.properties | ConvertFrom-Yaml -Ordered).Keys
  $InstallerSwitchProperties = (ConvertTo-Yaml $InstallerSchema.definitions.InstallerSwitches.properties | ConvertFrom-Yaml -Ordered).Keys
  $InstallerEntryProperties = (ConvertTo-Yaml $InstallerSchema.definitions.Installer.properties | ConvertFrom-Yaml -Ordered).Keys
  $InstallerDependencyProperties = (ConvertTo-Yaml $InstallerSchema.definitions.Dependencies.properties | ConvertFrom-Yaml -Ordered).Keys
} catch {
  # Here we want to pass the exception as an inner exception for debugging if necessary
  throw [System.Net.WebException]::new('Manifest schemas could not be downloaded. Try running the script again', $_.Exception)
}

filter TrimString {
  $_.Trim()
}

filter UniqueItems {
  [string]$($_.Split(',').Trim() | Select-Object -Unique)
}

filter ToLower {
  [string]$_.ToLower()
}

filter NoWhitespace {
  [string]$_ -replace '\s{1,}', '-'
}

$ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

# Various patterns used in validation to simplify the validation logic
$Patterns = @{
  PackageIdentifier             = $VersionSchema.properties.PackageIdentifier.pattern
  IdentifierMaxLength           = $VersionSchema.properties.PackageIdentifier.maxLength
  PackageVersion                = $InstallerSchema.definitions.PackageVersion.pattern
  VersionMaxLength              = $VersionSchema.properties.PackageVersion.maxLength
  InstallerSha256               = $InstallerSchema.definitions.Installer.properties.InstallerSha256.pattern
  InstallerUrl                  = $InstallerSchema.definitions.Installer.properties.InstallerUrl.pattern
  InstallerUrlMaxLength         = $InstallerSchema.definitions.Installer.properties.InstallerUrl.maxLength
  ValidArchitectures            = $InstallerSchema.definitions.Architecture.enum
  ValidInstallerTypes           = $InstallerSchema.definitions.InstallerType.enum
  ValidNestedInstallerTypes     = $InstallerSchema.definitions.NestedInstallerType.enum
  SilentSwitchMaxLength         = $InstallerSchema.definitions.InstallerSwitches.properties.Silent.maxLength
  ProgressSwitchMaxLength       = $InstallerSchema.definitions.InstallerSwitches.properties.SilentWithProgress.maxLength
  CustomSwitchMaxLength         = $InstallerSchema.definitions.InstallerSwitches.properties.Custom.maxLength
  SignatureSha256               = $InstallerSchema.definitions.Installer.properties.SignatureSha256.pattern
  FamilyName                    = $InstallerSchema.definitions.PackageFamilyName.pattern
  FamilyNameMaxLength           = $InstallerSchema.definitions.PackageFamilyName.maxLength
  PackageLocale                 = $LocaleSchema.properties.PackageLocale.pattern
  InstallerLocaleMaxLength      = $InstallerSchema.definitions.Locale.maxLength
  ProductCodeMinLength          = $InstallerSchema.definitions.ProductCode.minLength
  ProductCodeMaxLength          = $InstallerSchema.definitions.ProductCode.maxLength
  MaxItemsFileExtensions        = $InstallerSchema.definitions.FileExtensions.maxItems
  MaxItemsProtocols             = $InstallerSchema.definitions.Protocols.maxItems
  MaxItemsCommands              = $InstallerSchema.definitions.Commands.maxItems
  MaxItemsSuccessCodes          = $InstallerSchema.definitions.InstallerSuccessCodes.maxItems
  MaxItemsInstallModes          = $InstallerSchema.definitions.InstallModes.maxItems
  PackageLocaleMaxLength        = $LocaleSchema.properties.PackageLocale.maxLength
  PublisherMaxLength            = $LocaleSchema.properties.Publisher.maxLength
  PackageNameMaxLength          = $LocaleSchema.properties.PackageName.maxLength
  MonikerMaxLength              = $LocaleSchema.definitions.Tag.maxLength
  GenericUrl                    = $LocaleSchema.definitions.Url.pattern
  GenericUrlMaxLength           = $LocaleSchema.definitions.Url.maxLength
  AuthorMinLength               = $LocaleSchema.properties.Author.minLength
  AuthorMaxLength               = $LocaleSchema.properties.Author.maxLength
  LicenseMaxLength              = $LocaleSchema.properties.License.maxLength
  CopyrightMinLength            = $LocaleSchema.properties.Copyright.minLength
  CopyrightMaxLength            = $LocaleSchema.properties.Copyright.maxLength
  TagsMaxItems                  = $LocaleSchema.properties.Tags.maxItems
  ShortDescriptionMaxLength     = $LocaleSchema.properties.ShortDescription.maxLength
  DescriptionMinLength          = $LocaleSchema.properties.Description.minLength
  DescriptionMaxLength          = $LocaleSchema.properties.Description.maxLength
  ValidInstallModes             = $InstallerSchema.definitions.InstallModes.items.enum
  FileExtension                 = $InstallerSchema.definitions.FileExtensions.items.pattern
  FileExtensionMaxLength        = $InstallerSchema.definitions.FileExtensions.items.maxLength
  ReleaseNotesMinLength         = $LocaleSchema.properties.ReleaseNotes.MinLength
  ReleaseNotesMaxLength         = $LocaleSchema.properties.ReleaseNotes.MaxLength
  RelativeFilePathMinLength     = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.RelativeFilePath.minLength
  RelativeFilePathMaxLength     = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.RelativeFilePath.maxLength
  PortableCommandAliasMinLength = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.PortableCommandAlias.minLength
  PortableCommandAliasMaxLength = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.PortableCommandAlias.maxLength
  ArchiveInstallerTypes         = @('zip')
  ARP_DisplayNameMinLength      = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayName.minLength
  ARP_DisplayNameMaxLength      = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayName.maxLength
  ARP_PublisherMinLength        = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.Publisher.minLength
  ARP_PublisherMaxLength        = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.Publisher.maxLength
  ARP_DisplayVersionMinLength   = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayVersion.minLength
  ARP_DisplayVersionMaxLength   = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayVersion.maxLength
}

# This function validates whether a string matches Minimum Length, Maximum Length, and Regex pattern
# The switches can be used to specify if null values are allowed regardless of validation
Function Test-String {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [AllowEmptyString()]
    [string] $InputString,
    [Parameter(Mandatory = $false)]
    [regex] $MatchPattern,
    [Parameter(Mandatory = $false)]
    [int] $MinLength,
    [Parameter(Mandatory = $false)]
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

# Gets the effective installer type from an installer
Function Get-EffectiveInstallerType {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $Installer
  )
  if ($Installer.Keys -notcontains 'InstallerType') {
    throw [System.ArgumentException]::new('Invalid Function Parameters. Installer must contain `InstallerType` key')
  }
  if ($Installer.InstallerType -notin $Patterns.ArchiveInstallerTypes) {
    return $Installer.InstallerType
  }
  if ($Installer.Keys -notcontains 'NestedInstallerType') {
    throw [System.ArgumentException]::new("Invalid Function Parameters. Installer type $($Installer.InstallerType) must contain `NestedInstallerType` key")
  }
  return $Installer.NestedInstallerType
}

# Checks a file name for validity and returns a boolean value
Function Test-ValidFileName {
  param([string]$FileName)
  $IndexOfInvalidChar = $FileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
  # IndexOfAny() returns the value -1 to indicate no such character was found
  return $IndexOfInvalidChar -eq -1
}

Function Get-InstallerFile {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $URI,
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $PackageIdentifier,
    [Parameter(Mandatory = $true, Position = 2)]
    [string] $PackageVersion

  )
  # Create a filename based on the Package Identifier and Version; Try to get the extension from the URL
  # If the extension isn't found, use a custom one
  $_URIPath = $URI.Split('?')[0]
  $_Filename = "$PackageIdentifier v$PackageVersion - $(Get-Date -f 'yyyy.MM.dd-hh.mm.ss')" + $(if ([System.IO.Path]::HasExtension($_URIPath)) { [System.IO.Path]::GetExtension($_URIPath) } else { '.winget-tmp' })
  if (Test-ValidFileName $_Filename) { $_OutFile = Join-Path $env:TEMP -ChildPath $_Filename }
  else { $_OutFile = (New-TemporaryFile).FullName }

  # Download the file
  try {
    Invoke-WebRequest -Uri $URI -UserAgent $script:UserAgent -OutFile $_OutFile
  } catch {
    # Failed to download with the Delivery-Optimization User Agent, so try again with the WinINet User Agent
    Invoke-WebRequest -Uri $URI -UserAgent $script:BackupUserAgent -OutFile $_OutFile
  }

  return $_OutFile
}

Function Get-MSIProperty {
  Param
  (
    [Parameter(Mandatory = $true)]
    [string] $MSIPath,
    [Parameter(Mandatory = $true)]
    [string] $Parameter
  )
  try {
    $windowsInstaller = New-Object -com WindowsInstaller.Installer
    $database = $windowsInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstaller, @($MSIPath, 0))
    $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ("SELECT Value FROM Property WHERE Property = '$Parameter'"))
    $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
    $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
    $outputObject = $($record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1))
    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
    [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)
    [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($database)
    [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($windowsInstaller)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    return $outputObject
  } catch {
    Write-Error -Message $_.ToString()
    break
  }
}

function Get-PublisherHash($publisherName) {
  # Sourced from https://marcinotorowski.com/2021/12/19/calculating-hash-part-of-msix-package-family-name
  $publisherNameAsUnicode = [System.Text.Encoding]::Unicode.GetBytes($publisherName)
  $publisherSha256 = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash($publisherNameAsUnicode)
  $publisherSha256First8Bytes = $publisherSha256 | Select-Object -First 8
  $publisherSha256AsBinary = $publisherSha256First8Bytes | ForEach-Object { [System.Convert]::ToString($_, 2).PadLeft(8, '0') }
  $asBinaryStringWithPadding = [System.String]::Concat($publisherSha256AsBinary).PadRight(65, '0')

  $encodingTable = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

  $result = ''
  for ($i = 0; $i -lt $asBinaryStringWithPadding.Length; $i += 5) {
    $asIndex = [System.Convert]::ToInt32($asBinaryStringWithPadding.Substring($i, 5), 2)
    $result += $encodingTable[$asIndex]
  }

  return $result.ToLower()
}

Function Get-PackageFamilyName {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $FilePath
  )
  if ($FilePath -notmatch '\.(msix|appx)(bundle){0,1}$') { return $null }

  # Make the downloaded installer a zip file
  $_MSIX = Get-Item $FilePath
  $_Zip = Join-Path $_MSIX.Directory.FullName -ChildPath 'MSIX_YamlCreate.zip'
  $_ZipFolder = [System.IO.Path]::GetDirectoryName($_ZIp) + '\' + [System.IO.Path]::GetFileNameWithoutExtension($_Zip)
  Copy-Item -Path $_MSIX.FullName -Destination $_Zip
  # Expand the zip file to access the manifest inside
  Expand-Archive $_Zip -DestinationPath $_ZipFolder -Force
  # Package could be a single package or a bundle, so regex search for either of them
  $_AppxManifest = Get-ChildItem $_ZipFolder -Recurse -File -Filter '*.xml' | Where-Object { $_.Name -match '^Appx(Bundle)?Manifest.xml$' } | Select-Object -First 1
  [XML] $_XMLContent = Get-Content $_AppxManifest.FullName -Raw -Encoding $Utf8NoBomEncoding
  # The path to the node is different between single package and bundles, this should work to get either
  $_Identity = $_XMLContent.GetElementsByTagName('Identity')[0]
  # Cleanup the files that were created
  Remove-Item $_Zip -Force
  Remove-Item $_ZipFolder -Recurse -Force
  # Return the PFN
  return $_Identity.Name + '_' + $(Get-PublisherHash $_Identity.Publisher)
}

# Prompts user for Installer Values using the `Quick Update` Method
# Sets the $script:Installers value as an output
# Returns void
Function Read-QuickInstallerEntry {
  # We know old manifests exist if we got here without error
  # Fetch the old installers based on the manifest type
  if ($script:OldInstallerManifest) { $_OldInstallers = $script:OldInstallerManifest['Installers'] } else {
    $_OldInstallers = $script:OldVersionManifest['Installers']
  }

  $_iteration = 0
  $_NewInstallers = @()
  foreach ($_OldInstaller in $_OldInstallers) {
    # Create the new installer as an exact copy of the old installer entry
    # This is to ensure all previously entered and un-modified parameters are retained
    $_iteration += 1
    $_NewInstaller = Copy-Object -InputObject $_OldInstaller
    $_NewInstaller.Remove('InstallerSha256')

    # Show the user which installer is being updated
    $Logger.Invoke("Updating installer #${_iteration}/$($_OldInstallers.Count) [$($_NewInstaller['InstallerLocale']), $($_NewInstaller['Architecture']), $($_NewInstaller['InstallerType']), $($_NewInstaller['NestedInstallerType']), $($_NewInstaller['Scope'])]", 'Verbose')

    # Apply inputs
    $ToUpdate = $false
    foreach ($InstallerEntry in $InstallerEntries) {
      $Updatable = $true
      foreach ($_key in @('InstallerLocale', 'Architecture', 'InstallerType', 'NestedInstallerType', 'Scope')) {
        if ($_NewInstaller.Contains($_key) -and $InstallerEntry.Contains($_key) -and $_NewInstaller.$_key -ne $InstallerEntry.$_key) {
          $Updatable = $false
        } elseif (-not $_NewInstaller.Contains($_key) -and $InstallerEntry.Contains($_key)) {
          $Updatable = $false
        }
      }
      if ($Updatable) {
        $ToUpdate = $true
        $MatchingInstallerEntry = $InstallerEntry
      }
    }
    if ($ToUpdate) {
      if ($_NewInstaller['ReleaseDate']) { $_NewInstaller.Remove('ReleaseDate') }
      foreach ($_key in $MatchingInstallerEntry.Keys) {
        if ($_key -eq 'InstallerUrl') {
          if (Test-String $MatchingInstallerEntry.$_key -IsNull) { throw "The new value for installer property ${_key} is invalid: $($MatchingInstallerEntry.$_key)" }
          if (Test-String -not $MatchingInstallerEntry.$_key -MaxLength $Patterns.InstallerUrlMaxLength) { throw [System.ArgumentException]::new("The value must has a length between 1 and $($Patterns.InstallerUrlMaxLength) characters") }
          if (Test-String -not $MatchingInstallerEntry.$_key -MatchPattern $Patterns.InstallerUrl) { throw [System.ArgumentException]::new('The value entered does not match the pattern requirements defined in the manifest schema') }
          $_NewInstaller[$_key] = $MatchingInstallerEntry.$_key.Replace(' ', '%20')
        } elseif ($_key -in $InstallerEntryProperties -and $_key -notin @('InstallerLocale', 'Architecture', 'InstallerType', 'NestedInstallerType', 'Scope', 'InstallerUrl')) {
          if ($MatchingInstallerEntry.$_key -is [string] -and (Test-String $MatchingInstallerEntry.$_key -IsNull)) {
            $Logger.Invoke("The new value of the installer property ${_key} is invalid and thus discarded: $($MatchingInstallerEntry.$_key)", 'Warning')
            continue
          } elseif ($MatchingInstallerEntry.$_key -isnot [string] -and $null -eq $MatchingInstallerEntry.$_key) {
            $Logger.Invoke("The new value of the installer property ${_key} is invalid and thus discarded", 'Warning')
            continue
          }
          $_NewInstaller[$_key] = $MatchingInstallerEntry.$_key
        } elseif ($_key -notin $InstallerEntryProperties) {
          throw "The installer property ${_key} is invalid: $($MatchingInstallerEntry.$_key)"
        }
      }
    } else {
      throw "No matching installer entry for [$($_NewInstaller['InstallerLocale']), $($_NewInstaller['Architecture']), $($_NewInstaller['InstallerType']), $($_NewInstaller['tNestedInstallerType']), $($_NewInstaller['Scope'])]"
    }

    if ($_NewInstallers.Count -gt 0 -and $_NewInstaller.InstallerUrl -in $_NewInstallers.InstallerUrl) {
      $_MatchingInstaller = $_NewInstallers | Where-Object { $_.InstallerUrl -eq $_NewInstaller.InstallerUrl } | Select-Object -First 1
      if ($_MatchingInstaller['InstallerSha256']) { $_NewInstaller['InstallerSha256'] = $_MatchingInstaller.InstallerSha256 }
      if ($_MatchingInstaller['InstallerType']) { $_NewInstaller['InstallerType'] = $_MatchingInstaller.InstallerType }
      if ($_MatchingInstaller['ProductCode']) { $_NewInstaller['ProductCode'] = $_MatchingInstaller.ProductCode }
      elseif ( ($_NewInstaller.Keys -contains 'ProductCode') -and ($script:dest -notmatch '.exe$')) { $_NewInstaller.Remove('ProductCode') }
      if ($_MatchingInstaller['AppsAndFeaturesEntries']) { $_NewInstaller['AppsAndFeaturesEntries'] = $_MatchingInstaller.AppsAndFeaturesEntries }
      elseif ($_NewInstaller.Keys -contains 'AppsAndFeaturesEntries') { $_NewInstaller.Remove('AppsAndFeaturesEntries') }
      if ($_MatchingInstaller['PackageFamilyName']) { $_NewInstaller['PackageFamilyName'] = $_MatchingInstaller.PackageFamilyName }
      elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') { $_NewInstaller.Remove('PackageFamilyName') }
      if ($_MatchingInstaller['SignatureSha256']) { $_NewInstaller['SignatureSha256'] = $_MatchingInstaller.SignatureSha256 }
      elseif ($_NewInstaller.Keys -contains 'SignatureSha256') { $_NewInstaller.Remove('SignatureSha256') }
      if ($_MatchingInstaller['ReleaseDate']) { $_NewInstaller['ReleaseDate'] = $_MatchingInstaller.ReleaseDate }
      elseif ($_NewInstaller.Keys -contains 'ReleaseDate') { $_NewInstaller.Remove('ReleaseDate') }
    }

    if ($_NewInstaller.Keys -notcontains 'InstallerSha256') {
      $Logger.Invoke('Downloading installer...', 'Verbose')
      $script:dest = Get-InstallerFile -URI $_NewInstaller['InstallerUrl'] -PackageIdentifier $PackageIdentifier -PackageVersion $PackageVersion
      # Check that MSI's aren't actually WIX, and EXE's aren't NSIS, INNO or BURN
      $Logger.Invoke('Installer downloaded!', 'Verbose')
      $Logger.Invoke('Processing installer data...', 'Verbose')
      # Get the Sha256
      $_NewInstaller['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
      # If the installer is archive and nested installer is msi or wix, expand the archive first
      if ($_NewInstaller.InstallerType -cin @($Patterns.ArchiveInstallerTypes) -and $_NewInstaller.NestedInstallerType -ne 'portable') {
        $ExpandedArchivePath = "$($script:dest).expanded"
        Expand-Archive -Path $script:dest -DestinationPath $ExpandedArchivePath -Force
        $EffectiveInstallerPath = Join-Path $ExpandedArchivePath -ChildPath $_NewInstaller.NestedInstallerFiles[0].RelativeFilePath
      } else {
        $EffectiveInstallerPath = $script:dest
      }
      # Update the product code, if a new one exists
      # If a new product code doesn't exist, and the installer isn't an `.exe` file, remove the product code if it exists
      $MSIProductCode = $null
      if ((Get-EffectiveInstallerType $_NewInstaller) -in @('msi'; 'wix')) {
        if ([System.Environment]::OSVersion.Platform -match 'Win') {
          $MSIProductCode = ([string](Get-MSIProperty -MSIPath $EffectiveInstallerPath -Parameter 'ProductCode') | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
        } elseif ([System.Environment]::OSVersion.Platform -match 'Unix') {
          $MSIProductCode = ([string](file $EffectiveInstallerPath) | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
        }
      }
      if ((Get-EffectiveInstallerType $_NewInstaller) -eq 'burn') {
        if ([System.Environment]::OSVersion.Platform -match 'Win') {
          $MSIProductCode = Read-ProductCodeFromBurn -Path $EffectiveInstallerPath
        }
      }
      if (Test-String -not $MSIProductCode -IsNull) {
        $_NewInstaller['ProductCode'] = $MSIProductCode
        # Also replace the old product code in ARP entries with the new one
        if ($_NewInstaller.Contains('AppsAndFeaturesEntries')) {
          foreach ($AppsAndFeaturesEntry in $_NewInstaller.AppsAndFeaturesEntries) {
            if ($AppsAndFeaturesEntry.Contains('ProductCode') -and $AppsAndFeaturesEntry.ProductCode -eq $_OldInstaller.ProductCode) {
              $AppsAndFeaturesEntry.ProductCode = $MSIProductCode
            }
          }
        }
      } elseif ( ($_NewInstaller.Keys -contains 'ProductCode') -and ((Get-EffectiveInstallerType $_NewInstaller) -in @('appx'; 'msi'; 'msix'; 'wix'; 'burn'))) {
        $_NewInstaller.Remove('ProductCode')
      }

      # If the installer is msix or appx, try getting the new SignatureSha256
      # If the new SignatureSha256 can't be found, remove it if it exists
      $NewSignatureSha256 = $null
      if ($_NewInstaller.InstallerType -in @('msix', 'appx')) {
        if (Get-Command 'winget' -ErrorAction SilentlyContinue) { $NewSignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($NewSignatureSha256.P2) { $NewSignatureSha256 = $NewSignatureSha256.P2.ToUpper() } }
      }
      if (Test-String -not $NewSignatureSha256 -IsNull) {
        $_NewInstaller['SignatureSha256'] = $NewSignatureSha256
      } elseif ($_NewInstaller.Keys -contains 'SignatureSha256') {
        $_NewInstaller.Remove('SignatureSha256')
      }
      # If the installer is msix or appx, try getting the new package family name
      # If the new package family name can't be found, remove it if it exists
      if ($script:dest -match '\.(msix|appx)(bundle){0,1}$') {
        $PackageFamilyName = Get-PackageFamilyName $script:dest
        if (Test-String $PackageFamilyName -MatchPattern $Patterns.FamilyName) {
          $_NewInstaller['PackageFamilyName'] = $PackageFamilyName
        } elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') {
          $_NewInstaller.Remove('PackageFamilyName')
        }
      }
      # Remove the downloaded files
      Remove-Item -Path $script:dest
      $Logger.Invoke('Installer updated!', 'Verbose')
    }

    # Add the updated installer to the new installers array
    $_NewInstaller = Restore-YamlKeyOrder $_NewInstaller $InstallerEntryProperties -NoComments
    $_NewInstallers += $_NewInstaller
  }
  $script:Installers = $_NewInstallers
}

# Sorts keys within an object based on a reference ordered dictionary
# If a key does not exist, it sets the value to a special character to be removed / commented later
# Returns the result as a new object
Function Restore-YamlKeyOrder {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'InputObject', Justification = 'The variable is used inside a conditional but ScriptAnalyser does not recognize the scope')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'NoComments', Justification = 'The variable is used inside a conditional but ScriptAnalyser does not recognize the scope')]
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $InputObject,
    [Parameter(Mandatory = $true, Position = 1)]
    [PSCustomObject] $SortOrder,
    [switch] $NoComments
  )

  $_ExcludedKeys = @(
    'InstallerSwitches'
    'Capabilities'
    'RestrictedCapabilities'
    'InstallerSuccessCodes'
    'ProductCode'
    'UpgradeCode'
    'PackageFamilyName'
    'InstallerLocale'
    'InstallerType'
    'NestedInstallerType'
    'NestedInstallerFiles'
    'Scope'
    'UpgradeBehavior'
    'Dependencies'
    'InstallationMetadata'
    'Platform'
    'Icons'
    'Agreements'
  )

  $_Temp = [ordered] @{}
  $SortOrder.GetEnumerator() | ForEach-Object {
    if ($InputObject.Contains($_)) {
      $_Temp.Add($_, $InputObject[$_])
    } else {
      if (!$NoComments -and $_ -notin $_ExcludedKeys) {
        $_Temp.Add($_, "$([char]0x2370)")
      }
    }
  }
  return $_Temp
}

# Takes a comma separated list of values, converts it to an array object, and adds the result to a specified object-key
Function Add-YamlListParameter {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $Object,
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $Parameter,
    [Parameter(Mandatory = $true, Position = 2)]
    $Values
  )
  $_Values = @()
  Foreach ($Value in $Values.Split(',').Trim()) {
    $_Values += $Value
  }
  $Object[$Parameter] = $_Values
}

# Takes a single value and adds it to a specified object-key
Function Add-YamlParameter {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $Object,
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $Parameter,
    [Parameter(Mandatory = $true, Position = 2)]
    [string] $Value
  )
  $Object[$Parameter] = $Value
}

# Fetch the value of a manifest value regardless of which manifest file it exists in
Function Get-MultiManifestParameter {
  Param(
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $Parameter
  )
  $_vals = $($script:OldInstallerManifest[$Parameter] + $script:OldLocaleManifest[$Parameter] + $script:OldVersionManifest[$Parameter] | Where-Object { $_ })
  return ($_vals -join ', ')
}

Function Get-DebugString {
  $debug = ' $debug='
  $debug += $(switch ($script:Option) {
      'New' { 'NV' }
      'QuickUpdateVersion' { 'QU' }
      'EditMetadata' { 'MD' }
      'NewLocale' { 'NL' }
      'Auto' { 'AU' }
      Default { 'XX' }
    })
  $debug += $(
    switch ($script:SaveOption) {
      '0' { 'S0.' }
      '1' { 'S1.' }
      '2' { 'S2.' }
      Default { 'SU.' }
    }
  )
  $debug += $(switch (([System.Environment]::NewLine).Length) {
      1 { 'LF.' }
      2 { 'CRLF.' }
      Default { 'XX.' }
    })
  $debug += $PSVersionTable.PSVersion -Replace '\.', '-'
  $debug += '.'
  $debug += [System.Environment]::OSVersion.Platform
  return $debug
}

Function Write-ManifestContent {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $FilePath,
    [Parameter(Mandatory = $true, Position = 1)]
    [PSCustomObject] $YamlContent,
    [Parameter(Mandatory = $true, Position = 2)]
    [string] $Schema
  )
  [System.IO.File]::WriteAllLines($FilePath, @(
      $ScriptHeader + $(Get-DebugString)
      "# yaml-language-server: `$schema=$Schema"
      ''
      # This regex looks for lines with the special character ⍰ and comments them out
      $(ConvertTo-Yaml $YamlContent -Options DisableAliases).TrimEnd() -replace "(.*) $([char]0x2370)", "# `$1"
    ), $Utf8NoBomEncoding)

  $Logger.Invoke("Yaml file created: ${FilePath}", 'Verbose')
}

# Take all the entered values and write the version manifest file
Function Write-VersionManifest {
  # Create new empty manifest
  [PSCustomObject]$VersionManifest = [ordered]@{}

  # Write these values into the manifest
  $_Singletons = [ordered]@{
    'PackageIdentifier' = $PackageIdentifier
    'PackageVersion'    = $PackageVersion
    'DefaultLocale'     = if ($PackageLocale) { $PackageLocale } else { 'en-US' }
    'ManifestType'      = 'version'
    'ManifestVersion'   = $ManifestVersion
  }
  foreach ($_Item in $_Singletons.GetEnumerator()) {
    If ($_Item.Value) { Add-YamlParameter -Object $VersionManifest -Parameter $_Item.Name -Value $_Item.Value }
  }
  $VersionManifest = Restore-YamlKeyOrder $VersionManifest $VersionProperties

  # Create the folder for the file if it doesn't exist
  New-Item -ItemType 'Directory' -Force -Path $OutFolder | Out-Null
  $script:VersionManifestPath = Join-Path $OutFolder -ChildPath "$PackageIdentifier.yaml"

  # Write the manifest to the file
  Write-ManifestContent -FilePath $VersionManifestPath -YamlContent $VersionManifest -Schema $SchemaUrls.version
}

# Take all the entered values and write the installer manifest file
Function Write-InstallerManifest {
  # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
  if ($script:OldManifestType -eq 'MultiManifest') {
    $InstallerManifest = $script:OldInstallerManifest
  }
  if (!$InstallerManifest) { [PSCustomObject]$InstallerManifest = [ordered]@{} }

  # Add the properties to the manifest
  Add-YamlParameter -Object $InstallerManifest -Parameter 'PackageIdentifier' -Value $PackageIdentifier
  Add-YamlParameter -Object $InstallerManifest -Parameter 'PackageVersion' -Value $PackageVersion
  If ($script:Parameters['MinimumOSVersion']) {
    $InstallerManifest['MinimumOSVersion'] = $script:Parameters['MinimumOSVersion']
  } Else {
    If ($InstallerManifest['MinimumOSVersion']) { $_InstallerManifest.Remove('MinimumOSVersion') }
  }

  $_ListSections = [ordered]@{
    'FileExtensions'        = $script:Parameters['FileExtensions']
    'Protocols'             = $script:Parameters['Protocols']
    'Commands'              = $script:Parameters['Commands']
    'InstallerSuccessCodes' = $script:Parameters['InstallerSuccessCodes']
    'InstallModes'          = $script:Parameters['InstallModes']
  }
  foreach ($Section in $_ListSections.GetEnumerator()) {
    If ($Section.Value) { Add-YamlListParameter -Object $InstallerManifest -Parameter $Section.Name -Values $Section.Value }
  }

  if ($Option -ne 'EditMetadata') {
    $InstallerManifest['Installers'] = $script:Installers
  } elseif ($script:OldInstallerManifest) {
    $InstallerManifest['Installers'] = $script:OldInstallerManifest['Installers']
  } else {
    $InstallerManifest['Installers'] = $script:OldVersionManifest['Installers']
  }

  Add-YamlParameter -Object $InstallerManifest -Parameter 'ManifestType' -Value 'installer'
  Add-YamlParameter -Object $InstallerManifest -Parameter 'ManifestVersion' -Value $ManifestVersion
  If ($InstallerManifest['Dependencies']) {
    $InstallerManifest['Dependencies'] = Restore-YamlKeyOrder $InstallerManifest['Dependencies'] $InstallerDependencyProperties -NoComments
  }
  # Move Installer Level Keys to Manifest Level
  $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties -and $_ -notin @('ProductCode', 'NestedInstallerFiles', 'NestedInstallerType') }
  foreach ($_Key in $_KeysToMove) {
    if ($_Key -in $InstallerManifest.Installers[0].Keys) {
      # Handle the switches specially
      if ($_Key -eq 'InstallerSwitches') {
        # Go into each of the subkeys to see if they are the same
        foreach ($_InstallerSwitchKey in $InstallerManifest.Installers[0].$_Key.Keys) {
          $_AllAreSame = $true
          $_FirstInstallerSwitchKeyValue = ConvertTo-Json -InputObject $InstallerManifest.Installers[0].$_Key.$_InstallerSwitchKey
          foreach ($_Installer in $InstallerManifest.Installers) {
            if ($_Installer.Contains($_Key) -and $_Installer.$_Key.Contains($_InstallerSwitchKey)) {
              $_CurrentInstallerSwitchKeyValue = ConvertTo-Json -InputObject $_Installer.$_Key.$_InstallerSwitchKey
              if (Test-String $_CurrentInstallerSwitchKeyValue -IsNull) { $_AllAreSame = $false }
              else { $_AllAreSame = $_AllAreSame -and (@(Compare-Object $_CurrentInstallerSwitchKeyValue $_FirstInstallerSwitchKeyValue).Length -eq 0) }
            } else {
              $_AllAreSame = $false
            }
          }
          if ($_AllAreSame) {
            if ($_Key -notin $InstallerManifest.Keys) { $InstallerManifest[$_Key] = @{} }
            $InstallerManifest.$_Key[$_InstallerSwitchKey] = $InstallerManifest.Installers[0].$_Key.$_InstallerSwitchKey
          }
        }
        # Remove them from the individual installer switches if we moved them to the manifest level
        if ($_Key -in $InstallerManifest.Keys) {
          foreach ($_InstallerSwitchKey in $InstallerManifest.$_Key.Keys) {
            foreach ($_Installer in $InstallerManifest.Installers) {
              if ($_Installer.Keys -contains $_Key) {
                if ($_Installer.$_Key.Keys -contains $_InstallerSwitchKey) { $_Installer.$_Key.Remove($_InstallerSwitchKey) }
                if (@($_Installer.$_Key.Keys).Count -eq 0) { $_Installer.Remove($_Key) }
              }
            }
          }
        }
      } else {
        # Check if all installers are the same
        $_AllAreSame = $true
        $_FirstInstallerKeyValue = ConvertTo-Json -InputObject $InstallerManifest.Installers[0].$_Key
        foreach ($_Installer in $InstallerManifest.Installers) {
          $_CurrentInstallerKeyValue = ConvertTo-Json -InputObject $_Installer[$_Key]
          if (Test-String $_CurrentInstallerKeyValue -IsNull) { $_AllAreSame = $false }
          else { $_AllAreSame = $_AllAreSame -and (@(Compare-Object $_CurrentInstallerKeyValue $_FirstInstallerKeyValue).Length -eq 0) }
        }
        # If all installers are the same move the key to the manifest level
        if ($_AllAreSame) {
          $InstallerManifest[$_Key] = $InstallerManifest.Installers[0].$_Key
          foreach ($_Installer in $InstallerManifest.Installers) {
            $_Installer.Remove($_Key)
          }
        }
      }
    }
  }
  if ($InstallerManifest.Keys -contains 'InstallerSwitches') { $InstallerManifest['InstallerSwitches'] = Restore-YamlKeyOrder $InstallerManifest.InstallerSwitches $InstallerSwitchProperties -NoComments }
  foreach ($_Installer in $InstallerManifest.Installers) {
    if ($_Installer.Keys -contains 'InstallerSwitches') { $_Installer['InstallerSwitches'] = Restore-YamlKeyOrder $_Installer.InstallerSwitches $InstallerSwitchProperties -NoComments }
  }

  # Clean up the existing files just in case
  if ($InstallerManifest['Commands']) { $InstallerManifest['Commands'] = @($InstallerManifest['Commands'] | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }
  if ($InstallerManifest['Protocols']) { $InstallerManifest['Protocols'] = @($InstallerManifest['Protocols'] | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }
  if ($InstallerManifest['FileExtensions']) { $InstallerManifest['FileExtensions'] = @($InstallerManifest['FileExtensions'] | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }

  $InstallerManifest = Restore-YamlKeyOrder $InstallerManifest $InstallerProperties -NoComments

  # Create the folder for the file if it doesn't exist
  New-Item -ItemType 'Directory' -Force -Path $OutFolder | Out-Null
  $script:InstallerManifestPath = Join-Path $OutFolder -ChildPath "$PackageIdentifier.installer.yaml"

  # Write the manifest to the file
  Write-ManifestContent -FilePath $InstallerManifestPath -YamlContent $InstallerManifest -Schema $SchemaUrls.installer
}

# Take all the entered values and write the locale manifest file
Function Write-LocaleManifest {
  # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
  if ($script:OldManifestType -eq 'MultiManifest') {
    $LocaleManifest = $script:OldLocaleManifest
  }
  if (!$LocaleManifest) { [PSCustomObject]$LocaleManifest = [ordered]@{} }

  # Add the properties to the manifest
  $_Singletons = [ordered]@{
    'PackageIdentifier'   = $PackageIdentifier
    'PackageVersion'      = $PackageVersion
    'PackageLocale'       = $PackageLocale
    'Publisher'           = $script:Parameters['Publisher']
    'PublisherUrl'        = $script:Parameters['PublisherUrl']
    'PublisherSupportUrl' = $script:Parameters['PublisherSupportUrl']
    'PrivacyUrl'          = $script:Parameters['PrivacyUrl']
    'Author'              = $script:Parameters['Author']
    'PackageName'         = $script:Parameters['PackageName']
    'PackageUrl'          = $script:Parameters['PackageUrl']
    'License'             = $script:Parameters['License']
    'LicenseUrl'          = $script:Parameters['LicenseUrl']
    'Copyright'           = $script:Parameters['Copyright']
    'CopyrightUrl'        = $script:Parameters['CopyrightUrl']
    'ShortDescription'    = $script:Parameters['ShortDescription']
    'Description'         = $script:Parameters['Description']
    'ReleaseNotes'        = $script:Parameters['ReleaseNotes']
    'ReleaseNotesUrl'     = $script:Parameters['ReleaseNotesUrl']
  }
  foreach ($_Item in $_Singletons.GetEnumerator()) {
    If ($_Item.Value) { Add-YamlParameter -Object $LocaleManifest -Parameter $_Item.Name -Value $_Item.Value }
  }

  If ($script:Parameters['Tags']) { Add-YamlListParameter -Object $LocaleManifest -Parameter 'Tags' -Values $script:Parameters['Tags'] }
  If (!$LocaleManifest.ManifestType) { $LocaleManifest['ManifestType'] = 'defaultLocale' }
  If ($script:Parameters['Moniker'] -and $($LocaleManifest.ManifestType -eq 'defaultLocale')) { Add-YamlParameter -Object $LocaleManifest -Parameter 'Moniker' -Value $script:Parameters['Moniker'] }
  Add-YamlParameter -Object $LocaleManifest -Parameter 'ManifestVersion' -Value $ManifestVersion

  # Clean up the existing files just in case
  if ($LocaleManifest['Tags']) { $LocaleManifest['Tags'] = @($LocaleManifest['Tags'] | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }
  if ($LocaleManifest['Moniker']) { $LocaleManifest['Moniker'] = $LocaleManifest['Moniker'] | ToLower | NoWhitespace }

  # Clean up the volatile fields
  if ($LocaleManifest['ReleaseNotes']) { $LocaleManifest.Remove('ReleaseNotes') }

  # Apply inputs
  if ($LocaleEntries) {
    foreach ($LocaleEntry in $LocaleEntries) {
      if (-not $LocaleEntry.Contains('Key') -or -not $LocaleEntry.Contains('Value') -or (Test-String $LocaleEntry.Key -IsNull)) {
        throw 'Detected an invalid locale property updates'
      } elseif ($LocaleEntry.Key -notin $LocaleProperties) {
        throw "The locale property ${_key} is invalid: $($LocaleEntry.Value)"
      } elseif ($LocaleEntry.Contains('Locale') -and $LocaleEntry.Locale -ne $PackageLocale) {
        continue
      } elseif ($LocaleEntry.Value -is [string] -and (Test-String -Not $LocaleEntry.Value -IsNull)) {
        $LocaleManifest[$LocaleEntry.Key] = $LocaleEntry.Value
      } elseif ($LocaleEntry.Value -isnot [string] -and $null -ne $LocaleEntry.Value) {
        $LocaleManifest[$LocaleEntry.Key] = $LocaleEntry.Value
      } else {
        $LocaleManifest.Remove($LocaleEntry.Key)
      }
    }
  }

  # Remove ReleaseNotes if too long
  if ($LocaleManifest.Contains('ReleaseNotes') -and $LocaleManifest['ReleaseNotes'].Length -gt $Patterns.ReleaseNotesMaxLength) {
    $LocaleManifest.Remove('ReleaseNotes')
  }

  # Update the year in Copyright
  # if ($LocaleManifest.Contains('Copyright') -and $LocaleManifest['Copyright'].Contains(((Get-Date -AsUTC).Year - 1).ToString())) {
  #   $LocaleManifest['Copyright'] = $LocaleManifest['Copyright'].Replace(((Get-Date -AsUTC).Year - 1).ToString(), (Get-Date -AsUTC).Year.ToString())
  # }

  $LocaleManifest = Restore-YamlKeyOrder $LocaleManifest $LocaleProperties

  # Set the appropriate langage server depending on if it is a default locale file or generic locale file
  if ($LocaleManifest.ManifestType -eq 'defaultLocale') { $yamlServer = $SchemaUrls.defaultLocale } else { $yamlServer = $SchemaUrls.locale }

  # Create the folder for the file if it doesn't exist
  New-Item -ItemType 'Directory' -Force -Path $OutFolder | Out-Null
  $script:LocaleManifestPath = Join-Path $OutFolder -ChildPath "$PackageIdentifier.locale.$PackageLocale.yaml"

  # Write the manifest to the file
  Write-ManifestContent -FilePath $LocaleManifestPath -YamlContent $LocaleManifest -Schema $yamlServer

  # Copy over all locale files from previous version that aren't the same
  if ($OldManifests) {
    ForEach ($DifLocale in $OldManifests) {
      if ($DifLocale.Name -notin @("$PackageIdentifier.yaml", "$PackageIdentifier.installer.yaml", "$PackageIdentifier.locale.$PackageLocale.yaml")) {
        if (!(Test-Path $OutFolder)) { New-Item -ItemType 'Directory' -Force -Path $OutFolder | Out-Null }
        $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $DifLocale.FullName -Encoding $Utf8NoBomEncoding) -join "`n") -Ordered
        $script:OldLocaleManifest['PackageVersion'] = $PackageVersion
        if ($script:OldLocaleManifest.Keys -contains 'Moniker') { $script:OldLocaleManifest.Remove('Moniker') }
        $script:OldLocaleManifest['ManifestVersion'] = $ManifestVersion
        # Clean up the existing files just in case
        if ($script:OldLocaleManifest['Tags']) { $script:OldLocaleManifest['Tags'] = @($script:OldLocaleManifest['Tags'] | ToLower | UniqueItems | NoWhitespace | Sort-Object -Culture $Culture) }

        # Clean up the volatile fields
        if ($OldLocaleManifest['ReleaseNotes']) { $OldLocaleManifest.Remove('ReleaseNotes') }

        # Apply inputs
        if ($null -ne $LocaleEntries) {
          foreach ($LocaleEntry in $LocaleEntries) {
            if (-not $LocaleEntry.Contains('Key') -or -not $LocaleEntry.Contains('Value') -or (Test-String $LocaleEntry.Key -IsNull)) {
              throw 'Detected an invalid locale property updates'
            } elseif ($LocaleEntry.Key -notin $LocaleProperties) {
              throw "The locale property ${_key} is invalid: $($LocaleEntry.Value)"
            } elseif ($LocaleEntry.Contains('Locale') -and $LocaleEntry.Locale -ne $OldLocaleManifest.PackageLocale) {
              continue
            } elseif ($LocaleEntry.Value -is [string] -and (Test-String -Not $LocaleEntry.Value -IsNull)) {
              $OldLocaleManifest[$LocaleEntry.Key] = $LocaleEntry.Value
            } elseif ($LocaleEntry.Value -isnot [string] -and $null -ne $LocaleEntry.Value) {
              $OldLocaleManifest[$LocaleEntry.Key] = $LocaleEntry.Value
            } else {
              $OldLocaleManifest.Remove($LocaleEntry.Key)
            }
          }
        }

        # Remove ReleaseNotes if too long
        if ($OldLocaleManifest.Contains('ReleaseNotes') -and $OldLocaleManifest['ReleaseNotes'].Length -gt $Patterns.ReleaseNotesMaxLength) {
          $OldLocaleManifest.Remove('ReleaseNotes')
        }

        # Update the year in Copyright
        # if ($OldLocaleManifest.Contains('Copyright') -and $OldLocaleManifest['Copyright'].Contains(((Get-Date -AsUTC).Year - 1).ToString())) {
        #   $OldLocaleManifest['Copyright'] = $OldLocaleManifest['Copyright'].Replace(((Get-Date -AsUTC).Year - 1).ToString(), (Get-Date -AsUTC).Year.ToString())
        # }

        $script:OldLocaleManifest = Restore-YamlKeyOrder $script:OldLocaleManifest $LocaleProperties
        Write-ManifestContent -FilePath $(Join-Path $OutFolder -ChildPath $DifLocale.Name) -YamlContent $OldLocaleManifest -Schema $SchemaUrls.locale
      }
    }
  }
}

## START OF MAIN SCRIPT ##

$script:Option = 'QuickUpdateVersion'
$script:SaveOption = $null

# Request Package Identifier and Validate
$PackageIdentifierFolder = $PackageIdentifier.Replace('.', '\')
if (Test-String -not $PackageIdentifier -MinLength 4 -MaxLength $Patterns.IdentifierMaxLength) {
  throw [System.ArgumentException]::new("The value must has a length between 4 and $($Patterns.IdentifierMaxLength) characters")
}
if (Test-String -not $PackageIdentifier -MatchPattern $Patterns.PackageIdentifier) {
  throw [System.ArgumentException]::new('The value entered does not match the pattern requirements defined in the manifest schema')
}

# Request Package Version and Validate
if (Test-String -not $PackageVersion -MaxLength $Patterns.VersionMaxLength -NotNull) {
  throw [System.ArgumentException]::new("The value must has a length between 1 and $($Patterns.VersionMaxLength) characters")
}
if (Test-String -not $PackageVersion -MatchPattern $Patterns.PackageVersion) {
  throw [System.ArgumentException]::new('The value entered does not match the pattern requirements defined in the manifest schema')
}

# Set the folder for the specific package and version
$script:AppFolder = Join-Path $ManifestsFolder -ChildPath $PackageIdentifier.ToLower().Chars(0) | Join-Path -ChildPath $PackageIdentifierFolder | Join-Path -ChildPath $PackageVersion

# If the user selected `QuickUpdateVersion`, the old manifests must exist
# If the user selected `New`, the old manifest type is specified as none
if (-not (Test-Path -Path "$AppFolder\..")) {
  throw [ManifestException]::new('The manifest of previous version of the package does not exist.')
}

# Try getting the last version of the package and the old manifests to be updated
try {
  $script:LastVersion = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter '*.yaml' -ErrorAction SilentlyContinue).FullName ) -Leaf | Sort-Object $ToNatural -Culture $Culture | Select-Object -Last 1
  $script:ExistingVersions = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter '*.yaml' -ErrorAction SilentlyContinue).FullName ) -Leaf | Sort-Object $ToNatural -Culture $Culture | Select-Object -Unique
  $Logger.Invoke("Found existing version: ${LastVersion}", 'Verbose')
  $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$LastVersion"
} catch {
  # Take no action here, we just want to catch the exceptions as a precaution
  Out-Null
}

# If the old manifests exist, find the default locale
if ($OldManifests.Name -match "$([Regex]::Escape($PackageIdentifier))\.locale\..*\.yaml") {
  $_LocaleManifests = $OldManifests | Where-Object { $_.Name -match "$([Regex]::Escape($PackageIdentifier))\.locale\..*\.yaml" }
  foreach ($_Manifest in $_LocaleManifests) {
    $_ManifestContent = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $($_Manifest.FullName) -Encoding $Utf8NoBomEncoding) -join "`n") -Ordered
    if ($_ManifestContent.ManifestType -eq 'defaultLocale') { $PackageLocale = $_ManifestContent.PackageLocale }
  }
}

# If the old manifests exist, read their information into variables
# Also ensure additional requirements are met for creating or updating files
if ($OldManifests.Name -eq "$PackageIdentifier.installer.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.locale.$PackageLocale.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.yaml") {
  $script:OldManifestType = 'MultiManifest'
  $script:OldInstallerManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.installer.yaml") -Encoding $Utf8NoBomEncoding) -join "`n") -Ordered
  # Move Manifest Level Keys to installer Level
  $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties }
  foreach ($_Key in $_KeysToMove) {
    if ($_Key -in $script:OldInstallerManifest.Keys) {
      # Handle Installer switches separately
      if ($_Key -eq 'InstallerSwitches') {
        $_SwitchKeysToMove = $script:OldInstallerManifest.$_Key.Keys
        foreach ($_SwitchKey in $_SwitchKeysToMove) {
          # If the InstallerSwitches key doesn't exist, we need to create it, otherwise, preserve switches that were already there
          foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
            if ('InstallerSwitches' -notin $_Installer.Keys) { $_Installer['InstallerSwitches'] = @{} }
            $_Installer.InstallerSwitches["$_SwitchKey"] = $script:OldInstallerManifest.$_Key.$_SwitchKey
          }
        }
        $script:OldInstallerManifest.Remove($_Key)
        continue
      } else {
        foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
          if ($_Key -notin $_Installer.Keys) {
            $_Installer[$_Key] = $script:OldInstallerManifest.$_Key
          }
        }
      }
      New-Variable -Name $_Key -Value $($script:OldInstallerManifest.$_Key -join ', ') -Scope Script -Force
      $script:OldInstallerManifest.Remove($_Key)
    }
  }
  $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.locale.$PackageLocale.yaml") -Encoding $Utf8NoBomEncoding) -join "`n") -Ordered
  $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding $Utf8NoBomEncoding) -join "`n") -Ordered
} elseif ($OldManifests.Name -eq "$PackageIdentifier.yaml") {
  $script:OldManifestType = 'MultiManifest'
  $script:OldSingletonManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding $Utf8NoBomEncoding) -join "`n") -Ordered
  $PackageLocale = $script:OldSingletonManifest.PackageLocale
  # Create new empty manifests
  $script:OldInstallerManifest = [ordered]@{}
  $script:OldLocaleManifest = [ordered]@{}
  $script:OldVersionManifest = [ordered]@{}
  # Parse version keys to version manifest
  foreach ($_Key in $($OldSingletonManifest.Keys | Where-Object { $_ -in $VersionProperties })) {
    $script:OldVersionManifest[$_Key] = $script:OldSingletonManifest.$_Key
  }
  $script:OldVersionManifest['ManifestType'] = 'version'
  # Parse locale keys to locale manifest
  foreach ($_Key in $($OldSingletonManifest.Keys | Where-Object { $_ -in $LocaleProperties })) {
    $script:OldLocaleManifest[$_Key] = $script:OldSingletonManifest.$_Key
  }
  $script:OldLocaleManifest['ManifestType'] = 'defaultLocale'
  # Parse installer keys to installer manifest
  foreach ($_Key in $($OldSingletonManifest.Keys | Where-Object { $_ -in $InstallerProperties })) {
    $script:OldInstallerManifest[$_Key] = $script:OldSingletonManifest.$_Key
  }
  $script:OldInstallerManifest['ManifestType'] = 'installer'
  # Move Manifest Level Keys to installer Level
  $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties }
  foreach ($_Key in $_KeysToMove) {
    if ($_Key -in $script:OldInstallerManifest.Keys) {
      # Handle Installer switches separately
      if ($_Key -eq 'InstallerSwitches') {
        $_SwitchKeysToMove = $script:OldInstallerManifest.$_Key.Keys
        foreach ($_SwitchKey in $_SwitchKeysToMove) {
          # If the InstallerSwitches key doesn't exist, we need to create it, otherwise, preserve switches that were already there
          foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
            if ('InstallerSwitches' -notin $_Installer.Keys) { $_Installer['InstallerSwitches'] = @{} }
            $_Installer.InstallerSwitches["$_SwitchKey"] = $script:OldInstallerManifest.$_Key.$_SwitchKey
          }
        }
        $script:OldInstallerManifest.Remove($_Key)
        continue
      } else {
        foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
          if ($_Key -notin $_Installer.Keys) {
            $_Installer[$_Key] = $script:OldInstallerManifest.$_Key
          }
        }
      }
      New-Variable -Name $_Key -Value $($script:OldInstallerManifest.$_Key -join ', ') -Scope Script -Force
      $script:OldInstallerManifest.Remove($_Key)
    }
  }
} else {
  throw [ManifestException]::new("Version $LastVersion does not contain the required manifests")
}

# If the old manifests exist, read the manifest keys into their specific variables
$script:Parameters = @{}
if ($OldManifests) {
  $_Parameters = @(
    'Publisher'; 'PublisherUrl'; 'PublisherSupportUrl'; 'PrivacyUrl'
    'Author'
    'PackageName'; 'PackageUrl'; 'Moniker'
    'License'; 'LicenseUrl'
    'Copyright'; 'CopyrightUrl'
    'ShortDescription'; 'Description'
    'Channel'
    'Platform'; 'MinimumOSVersion'
    'InstallerType'; 'NestedInstallerType'
    'Scope'
    'UpgradeBehavior'
    'PackageFamilyName'; 'ProductCode'
    'Tags'; 'FileExtensions'
    'Protocols'; 'Commands'
    'InstallerSuccessCodes'
    'Capabilities'; 'RestrictedCapabilities'
    'InstallModes'
  )
  Foreach ($param in $_Parameters) {
    $_ReadValue = $(if ($script:OldManifestType -eq 'MultiManifest') { (Get-MultiManifestParameter $param) } else { $script:OldVersionManifest[$param] })
    if (Test-String -Not $_ReadValue -IsNull) { $script:Parameters[$param] = $_ReadValue }
  }
}

# If the old manifests exist, make sure to use the same casing as the existing package identifier
if ($OldManifests) {
  $script:PackageIdentifier = $OldManifests.Where({ $_.Name -like "$PackageIdentifier.yaml" }).BaseName
}

Read-QuickInstallerEntry
Write-LocaleManifest
Write-InstallerManifest
Write-VersionManifest

class UnmetDependencyException : Exception {
  UnmetDependencyException([string] $message) : base($message) {}
  UnmetDependencyException([string] $message, [Exception] $exception) : base($message, $exception) {}
}

class ManifestException : Exception {
  ManifestException([string] $message) : base($message) {}
}
