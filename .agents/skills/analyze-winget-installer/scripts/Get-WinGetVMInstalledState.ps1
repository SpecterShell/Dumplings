# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
  Capture or compare WinGet installed-state evidence inside a validation VM.
.DESCRIPTION
  Collects ARP entries, protocol registrations, file-extension associations,
  environment PATH entries, and bounded installer-log evidence without launching
  installers or applications. The script is self-contained and compatible with
  Windows PowerShell 5.1 so it can be copied into a clean VM.
.PARAMETER Action
  Capture a snapshot, compare two snapshots, or collect installer-log evidence.
.PARAMETER Phase
  A stable label such as BeforeInstall, AfterInstall, or AfterFirstRun.
.PARAMETER OutputPath
  JSON file written by the selected action.
.PARAMETER BeforePath
  Snapshot captured before the operation being validated.
.PARAMETER AfterPath
  Snapshot captured after the operation being validated.
.PARAMETER PassThru
  Return the snapshot or comparison object in addition to writing JSON.
.PARAMETER LogPath
  Requested installer log file, directory, or filename prefix. Repeat as needed.
.PARAMETER SinceUtc
  UTC launch time used to select adjacent and temporary log files.
.PARAMETER LogOutputDirectory
  Guest directory that receives bounded copies of discovered log files.
.PARAMETER InstallerExitCode
  Exit code captured by the caller from the installer process.
.PARAMETER InstallerMode
  Validation mode associated with the process result.
.PARAMETER InstallerTimedOut
  Indicates that the installer exceeded the validation timeout.
.PARAMETER IncludeTemporaryLogs
  Search the current user's temporary directory for recent text-oriented logs.
.PARAMETER MaximumLogFiles
  Maximum number of discovered log files to process.
.PARAMETER MaximumLogFileBytes
  Maximum size of one log file copied into evidence.
.PARAMETER MaximumTotalLogBytes
  Maximum combined size of copied log files.
.PARAMETER LogTailLineCount
  Maximum number of trailing text lines retained in JSON for each log.
#>
[CmdletBinding()]
param (
  [ValidateSet('Capture', 'Compare', 'CollectLogs')]
  [string]$Action = 'Capture',

  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
  [string]$Phase = 'Custom',

  [Parameter(Mandatory)]
  [string]$OutputPath,

  [string]$BeforePath,

  [string]$AfterPath,

  [string[]]$LogPath,

  [Nullable[datetime]]$SinceUtc,

  [string]$LogOutputDirectory,

  [Nullable[int]]$InstallerExitCode,

  [string]$InstallerMode = 'silent',

  [switch]$InstallerTimedOut,

  [bool]$IncludeTemporaryLogs = $true,

  [ValidateRange(1, 4096)]
  [int]$MaximumLogFiles = 256,

  [ValidateRange(1, 1073741824)]
  [long]$MaximumLogFileBytes = 33554432,

  [ValidateRange(1, 4294967296)]
  [long]$MaximumTotalLogBytes = 134217728,

  [ValidateRange(1, 10000)]
  [int]$LogTailLineCount = 200,

  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

function ConvertTo-VMRegistryValue {
  param ([AllowNull()]$Value)

  if ($null -eq $Value) { return $null }
  if ($Value -is [byte[]]) { return [Convert]::ToBase64String($Value) }
  if ($Value -is [string[]]) { return @($Value) }
  return $Value
}

function Get-VMRegistryValueEvidence {
  param ([Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$Key)

  $Values = foreach ($Name in @($Key.GetValueNames() | Sort-Object)) {
    $DisplayName = $Name
    if ([string]::IsNullOrEmpty($DisplayName)) { $DisplayName = '(Default)' }
    [pscustomobject][ordered]@{
      Name  = $DisplayName
      Type  = [string]$Key.GetValueKind($Name)
      Value = ConvertTo-VMRegistryValue -Value $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
  }
  return @($Values)
}

function Get-VMRegistryValue {
  param (
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$Key,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Name
  )

  return $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}

function Get-VMRegistryString {
  param (
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$Key,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Name
  )

  $Value = Get-VMRegistryValue -Key $Key -Name $Name
  if ($null -eq $Value) { return $null }
  return [string]$Value
}

function Get-VMRegistryRootDefinition {
  param (
    [Parameter(Mandatory)][Microsoft.Win32.RegistryHive]$Hive,
    [Parameter(Mandatory)][Microsoft.Win32.RegistryView]$View,
    [Parameter(Mandatory)][string]$HiveName,
    [Parameter(Mandatory)][string]$ViewName,
    [Parameter(Mandatory)][string]$Scope
  )

  [pscustomobject][ordered]@{
    Hive     = $Hive
    View     = $View
    HiveName = $HiveName
    ViewName = $ViewName
    Scope    = $Scope
  }
}

function Get-VMArpRegistryRoot {
  $Roots = @(
    (Get-VMRegistryRootDefinition -Hive LocalMachine -View Registry64 -HiveName 'HKLM' -ViewName 'Registry64' -Scope 'machine'),
    (Get-VMRegistryRootDefinition -Hive LocalMachine -View Registry32 -HiveName 'HKLM' -ViewName 'Registry32' -Scope 'machine'),
    (Get-VMRegistryRootDefinition -Hive CurrentUser -View Default -HiveName 'HKCU' -ViewName 'Default' -Scope 'user')
  )
  return $Roots
}

function Get-VMClassesRegistryRoot {
  return Get-VMArpRegistryRoot
}

function Get-VMArpEntrySnapshot {
  $SubKeyPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
  $Entries = foreach ($Root in Get-VMArpRegistryRoot) {
    $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Root.Hive, $Root.View)
    try {
      $UninstallKey = $BaseKey.OpenSubKey($SubKeyPath)
      if ($null -eq $UninstallKey) { continue }
      try {
        foreach ($ProductCode in @($UninstallKey.GetSubKeyNames() | Sort-Object)) {
          $EntryKey = $UninstallKey.OpenSubKey($ProductCode)
          if ($null -eq $EntryKey) { continue }
          try {
            $DisplayName = Get-VMRegistryString -Key $EntryKey -Name 'DisplayName'
            $SystemComponentValue = Get-VMRegistryValue -Key $EntryKey -Name 'SystemComponent'
            $WindowsInstallerValue = Get-VMRegistryValue -Key $EntryKey -Name 'WindowsInstaller'
            $IsSystemComponent = $false
            if ($null -ne $SystemComponentValue) { $IsSystemComponent = ([int64]$SystemComponentValue -ne 0) }
            $IsVisible = -not [string]::IsNullOrWhiteSpace($DisplayName) -and -not $IsSystemComponent
            $RegistryPath = "$($Root.HiveName)\$SubKeyPath\$ProductCode"

            [pscustomobject][ordered]@{
              Identity             = "ARP|$($Root.HiveName)|$($Root.ViewName)|$ProductCode"
              RegistryPath         = $RegistryPath
              RegistryHive         = $Root.HiveName
              RegistryView         = $Root.ViewName
              Scope                = $Root.Scope
              ProductCode          = $ProductCode
              DisplayName          = $DisplayName
              DisplayVersion       = Get-VMRegistryString -Key $EntryKey -Name 'DisplayVersion'
              Publisher            = Get-VMRegistryString -Key $EntryKey -Name 'Publisher'
              InstallLocation      = Get-VMRegistryString -Key $EntryKey -Name 'InstallLocation'
              UninstallString      = Get-VMRegistryString -Key $EntryKey -Name 'UninstallString'
              QuietUninstallString = Get-VMRegistryString -Key $EntryKey -Name 'QuietUninstallString'
              ModifyPath           = Get-VMRegistryString -Key $EntryKey -Name 'ModifyPath'
              Language             = Get-VMRegistryValue -Key $EntryKey -Name 'Language'
              EstimatedSize        = Get-VMRegistryValue -Key $EntryKey -Name 'EstimatedSize'
              NoModify             = Get-VMRegistryValue -Key $EntryKey -Name 'NoModify'
              NoRepair             = Get-VMRegistryValue -Key $EntryKey -Name 'NoRepair'
              WindowsInstaller     = if ($null -eq $WindowsInstallerValue) { $false } else { [int64]$WindowsInstallerValue -ne 0 }
              IsSystemComponent    = $IsSystemComponent
              IsVisible            = $IsVisible
              Values               = @(Get-VMRegistryValueEvidence -Key $EntryKey)
            }
          } finally {
            $EntryKey.Dispose()
          }
        }
      } finally {
        $UninstallKey.Dispose()
      }
    } finally {
      $BaseKey.Dispose()
    }
  }
  return @($Entries | Sort-Object Identity)
}

function Get-VMClassDetail {
  param (
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$ClassesKey,
    [AllowNull()][string]$ProgId
  )

  if ([string]::IsNullOrWhiteSpace($ProgId)) { return $null }
  $ClassKey = $ClassesKey.OpenSubKey($ProgId)
  if ($null -eq $ClassKey) {
    return [pscustomobject][ordered]@{ ProgId = $ProgId; Description = $null; Command = $null; DefaultIcon = $null; Values = @() }
  }
  try {
    $Command = $null
    $CommandKey = $ClassKey.OpenSubKey('shell\open\command')
    if ($null -ne $CommandKey) {
      try { $Command = Get-VMRegistryString -Key $CommandKey -Name '' } finally { $CommandKey.Dispose() }
    }
    $DefaultIcon = $null
    $IconKey = $ClassKey.OpenSubKey('DefaultIcon')
    if ($null -ne $IconKey) {
      try { $DefaultIcon = Get-VMRegistryString -Key $IconKey -Name '' } finally { $IconKey.Dispose() }
    }
    return [pscustomobject][ordered]@{
      ProgId      = $ProgId
      Description = Get-VMRegistryString -Key $ClassKey -Name ''
      Command     = $Command
      DefaultIcon = $DefaultIcon
      Values      = @(Get-VMRegistryValueEvidence -Key $ClassKey)
    }
  } finally {
    $ClassKey.Dispose()
  }
}

function Get-VMOpenWithProgId {
  param ([Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$ExtensionKey)

  $ProgIds = @()
  $OpenWithKey = $ExtensionKey.OpenSubKey('OpenWithProgids')
  if ($null -ne $OpenWithKey) {
    try { $ProgIds = @($OpenWithKey.GetValueNames() | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) } finally { $OpenWithKey.Dispose() }
  }
  return $ProgIds
}

function Get-VMDirectAssociationSnapshot {
  param (
    [Parameter(Mandatory)]$Root,
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$ClassesKey
  )

  foreach ($ClassName in @($ClassesKey.GetSubKeyNames() | Sort-Object)) {
    $ClassKey = $ClassesKey.OpenSubKey($ClassName)
    if ($null -eq $ClassKey) { continue }
    try {
      if ($ClassName.StartsWith('.', [StringComparison]::Ordinal)) {
        if ($ClassName -notmatch '^\.[A-Za-z0-9][A-Za-z0-9._+-]{0,254}$') { continue }
        $DefaultProgId = Get-VMRegistryString -Key $ClassKey -Name ''
        $OpenWithProgIds = @(Get-VMOpenWithProgId -ExtensionKey $ClassKey)
        $AllProgIds = @($DefaultProgId) + $OpenWithProgIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
        $Details = @($AllProgIds | ForEach-Object { Get-VMClassDetail -ClassesKey $ClassesKey -ProgId $_ })
        [pscustomobject][ordered]@{
          Identity        = "FileExtension|$($Root.HiveName)|$($Root.ViewName)|Classes|$($ClassName.ToLowerInvariant())"
          Source          = 'Classes'
          RegistryHive    = $Root.HiveName
          RegistryView    = $Root.ViewName
          Scope           = $Root.Scope
          Name            = $ClassName.TrimStart('.').ToLowerInvariant()
          Extension       = $ClassName.ToLowerInvariant()
          RegistryPath    = "$($Root.HiveName)\Software\Classes\$ClassName"
          ApplicationName = $null
          DefaultProgId   = $DefaultProgId
          ProgIds         = @($AllProgIds)
          ContentType     = Get-VMRegistryString -Key $ClassKey -Name 'Content Type'
          PerceivedType   = Get-VMRegistryString -Key $ClassKey -Name 'PerceivedType'
          ClassDetails    = $Details
          Values          = @(Get-VMRegistryValueEvidence -Key $ClassKey)
        }
        continue
      }

      $UrlProtocol = Get-VMRegistryValue -Key $ClassKey -Name 'URL Protocol'
      if ($null -eq $UrlProtocol) { continue }
      if ($ClassName -notmatch '^[A-Za-z][A-Za-z0-9+.-]{0,254}$') { continue }
      [pscustomobject][ordered]@{
        Identity        = "Protocol|$($Root.HiveName)|$($Root.ViewName)|Classes|$($ClassName.ToLowerInvariant())"
        Source          = 'Classes'
        RegistryHive    = $Root.HiveName
        RegistryView    = $Root.ViewName
        Scope           = $Root.Scope
        Name            = $ClassName.ToLowerInvariant()
        RegistryPath    = "$($Root.HiveName)\Software\Classes\$ClassName"
        ApplicationName = $null
        ProgId          = $ClassName
        ClassDetails    = Get-VMClassDetail -ClassesKey $ClassesKey -ProgId $ClassName
        Values          = @(Get-VMRegistryValueEvidence -Key $ClassKey)
      }
    } finally {
      $ClassKey.Dispose()
    }
  }
}

function Get-VMCapabilityAssociationSnapshot {
  param (
    [Parameter(Mandatory)]$Root,
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$BaseKey,
    [Parameter(Mandatory)][Microsoft.Win32.RegistryKey]$ClassesKey
  )

  $RegisteredApplications = $BaseKey.OpenSubKey('SOFTWARE\RegisteredApplications')
  if ($null -eq $RegisteredApplications) { return }
  try {
    foreach ($ApplicationName in @($RegisteredApplications.GetValueNames() | Sort-Object)) {
      $CapabilitiesPath = [string](Get-VMRegistryValue -Key $RegisteredApplications -Name $ApplicationName)
      if ([string]::IsNullOrWhiteSpace($CapabilitiesPath)) { continue }
      $CapabilitiesKey = $BaseKey.OpenSubKey($CapabilitiesPath.TrimStart('\'))
      if ($null -eq $CapabilitiesKey) { continue }
      try {
        foreach ($Mapping in @(
            [pscustomobject]@{ SubKey = 'FileAssociations'; Kind = 'FileExtension' },
            [pscustomobject]@{ SubKey = 'URLAssociations'; Kind = 'Protocol' }
          )) {
          $AssociationKey = $CapabilitiesKey.OpenSubKey($Mapping.SubKey)
          if ($null -eq $AssociationKey) { continue }
          try {
            foreach ($Name in @($AssociationKey.GetValueNames() | Sort-Object)) {
              $ProgId = [string](Get-VMRegistryValue -Key $AssociationKey -Name $Name)
              if ([string]::IsNullOrWhiteSpace($ProgId)) { continue }
              if ($Mapping.Kind -eq 'FileExtension') {
                if ($Name -notmatch '^\.[A-Za-z0-9][A-Za-z0-9._+-]{0,254}$') { continue }
                [pscustomobject][ordered]@{
                  Identity         = "FileExtension|$($Root.HiveName)|$($Root.ViewName)|Capabilities|$ApplicationName|$($Name.ToLowerInvariant())"
                  Source           = 'RegisteredApplications'
                  RegistryHive     = $Root.HiveName
                  RegistryView     = $Root.ViewName
                  Scope            = $Root.Scope
                  Name             = $Name.TrimStart('.').ToLowerInvariant()
                  Extension        = $Name.ToLowerInvariant()
                  RegistryPath     = "$($Root.HiveName)\$CapabilitiesPath\FileAssociations"
                  ApplicationName  = $ApplicationName
                  CapabilitiesPath = $CapabilitiesPath
                  DefaultProgId    = $ProgId
                  ProgIds          = @($ProgId)
                  ContentType      = $null
                  PerceivedType    = $null
                  ClassDetails     = @(Get-VMClassDetail -ClassesKey $ClassesKey -ProgId $ProgId)
                  Values           = @([pscustomobject][ordered]@{ Name = $Name; Type = [string]$AssociationKey.GetValueKind($Name); Value = $ProgId })
                }
              } else {
                if ($Name -notmatch '^[A-Za-z][A-Za-z0-9+.-]{0,254}$') { continue }
                [pscustomobject][ordered]@{
                  Identity         = "Protocol|$($Root.HiveName)|$($Root.ViewName)|Capabilities|$ApplicationName|$($Name.ToLowerInvariant())"
                  Source           = 'RegisteredApplications'
                  RegistryHive     = $Root.HiveName
                  RegistryView     = $Root.ViewName
                  Scope            = $Root.Scope
                  Name             = $Name.ToLowerInvariant()
                  RegistryPath     = "$($Root.HiveName)\$CapabilitiesPath\URLAssociations"
                  ApplicationName  = $ApplicationName
                  CapabilitiesPath = $CapabilitiesPath
                  ProgId           = $ProgId
                  ClassDetails     = Get-VMClassDetail -ClassesKey $ClassesKey -ProgId $ProgId
                  Values           = @([pscustomobject][ordered]@{ Name = $Name; Type = [string]$AssociationKey.GetValueKind($Name); Value = $ProgId })
                }
              }
            }
          } finally {
            $AssociationKey.Dispose()
          }
        }
      } finally {
        $CapabilitiesKey.Dispose()
      }
    }
  } finally {
    $RegisteredApplications.Dispose()
  }
}

function Get-VMAssociationSnapshot {
  $Protocols = @()
  $FileExtensions = @()
  foreach ($Root in Get-VMClassesRegistryRoot) {
    $BaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Root.Hive, $Root.View)
    try {
      $ClassesKey = $BaseKey.OpenSubKey('SOFTWARE\Classes')
      if ($null -eq $ClassesKey) { continue }
      try {
        $Associations = @(
          Get-VMDirectAssociationSnapshot -Root $Root -ClassesKey $ClassesKey
          Get-VMCapabilityAssociationSnapshot -Root $Root -BaseKey $BaseKey -ClassesKey $ClassesKey
        )
        $Protocols += @($Associations | Where-Object { $_.Identity -like 'Protocol|*' })
        $FileExtensions += @($Associations | Where-Object { $_.Identity -like 'FileExtension|*' })
      } finally {
        $ClassesKey.Dispose()
      }
    } finally {
      $BaseKey.Dispose()
    }
  }
  return [pscustomobject][ordered]@{
    ProtocolAssociations      = @($Protocols | Sort-Object Identity -Unique)
    FileExtensionAssociations = @($FileExtensions | Sort-Object Identity -Unique)
  }
}

function Test-VMProcessElevated {
  $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
  return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-VMPathCommandCandidate {
  param (
    [Parameter(Mandatory)][string]$DirectoryPath,
    [ValidateRange(1, 4096)][int]$MaximumCommands = 1024
  )

  if (-not [IO.Directory]::Exists($DirectoryPath)) { return @() }
  $ExecutableExtensions = @($env:PATHEXT -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLowerInvariant() })
  if ($ExecutableExtensions.Count -eq 0) { $ExecutableExtensions = @('.com', '.exe', '.bat', '.cmd') }
  if ('.ps1' -notin $ExecutableExtensions) { $ExecutableExtensions += '.ps1' }
  $Commands = Get-ChildItem -LiteralPath $DirectoryPath -File -Force -ErrorAction SilentlyContinue | Where-Object { [IO.Path]::GetExtension($_.Name).ToLowerInvariant() -in $ExecutableExtensions } | Sort-Object Name | Select-Object -First $MaximumCommands | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) }
  return @($Commands | Sort-Object -Unique)
}

function Get-VMEnvironmentPathSnapshot {
  $Entries = foreach ($Definition in @(
      [pscustomobject]@{ Scope = 'user'; Target = [EnvironmentVariableTarget]::User },
      [pscustomobject]@{ Scope = 'machine'; Target = [EnvironmentVariableTarget]::Machine }
    )) {
    $PathValue = [Environment]::GetEnvironmentVariable('Path', $Definition.Target)
    $Ordinal = 0
    foreach ($RawEntry in @([string]$PathValue -split ';')) {
      $Ordinal++
      $TrimmedEntry = $RawEntry.Trim().Trim('"')
      if ([string]::IsNullOrWhiteSpace($TrimmedEntry)) { continue }
      $ExpandedPath = [Environment]::ExpandEnvironmentVariables($TrimmedEntry)
      try { $ExpandedPath = [IO.Path]::GetFullPath($ExpandedPath) } catch {}
      $IdentityPath = $ExpandedPath
      $PathRoot = [IO.Path]::GetPathRoot($ExpandedPath)
      if ($ExpandedPath.Length -gt $PathRoot.Length) { $IdentityPath = $ExpandedPath.TrimEnd('\', '/') }
      [pscustomobject][ordered]@{
        Identity          = "EnvironmentPath|$($Definition.Scope)|$($IdentityPath.ToLowerInvariant())"
        Scope             = $Definition.Scope
        Ordinal           = $Ordinal
        RawEntry          = $TrimmedEntry
        ExpandedPath      = $ExpandedPath
        Exists            = [IO.Directory]::Exists($ExpandedPath)
        CommandCandidates = @(Get-VMPathCommandCandidate -DirectoryPath $ExpandedPath)
      }
    }
  }
  return @($Entries | Sort-Object Identity -Unique)
}

function Add-VMInstallerLogCandidate {
  param (
    [Parameter(Mandatory)][hashtable]$Seen,
    [Parameter(Mandatory)]$Candidates,
    [Parameter(Mandatory)][IO.FileInfo]$File,
    [Parameter(Mandatory)][string]$Origin,
    [Parameter(Mandatory)][datetime]$CutoffUtc,
    [switch]$RequireRecent
  )

  if ($RequireRecent -and $File.LastWriteTimeUtc -lt $CutoffUtc) { return }
  $FullName = $File.FullName
  if ($Seen.ContainsKey($FullName)) { return }
  $Seen[$FullName] = $true
  $Candidates.Add([pscustomobject][ordered]@{ File = $File; Origin = $Origin })
}

function Get-VMInstallerLogCandidate {
  param (
    [AllowNull()][string[]]$RequestedPath,
    [Parameter(Mandatory)][datetime]$CutoffUtc,
    [bool]$IncludeTemp,
    [ValidateRange(1, 4096)][int]$MaximumFiles
  )

  $Seen = @{}
  $Candidates = New-Object 'System.Collections.Generic.List[object]'
  foreach ($Requested in @($RequestedPath)) {
    if ([string]::IsNullOrWhiteSpace($Requested)) { continue }
    try { $FullRequestedPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Requested)) } catch { continue }
    $Exact = Get-Item -LiteralPath $FullRequestedPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $Exact -and -not $Exact.PSIsContainer) {
      Add-VMInstallerLogCandidate -Seen $Seen -Candidates $Candidates -File $Exact -Origin 'RequestedFile' -CutoffUtc $CutoffUtc
    }
    if ($null -ne $Exact -and $Exact.PSIsContainer) {
      foreach ($File in @(Get-ChildItem -LiteralPath $Exact.FullName -File -Recurse -Force -ErrorAction SilentlyContinue)) {
        Add-VMInstallerLogCandidate -Seen $Seen -Candidates $Candidates -File $File -Origin 'RequestedDirectory' -CutoffUtc $CutoffUtc -RequireRecent
      }
    }

    $AdjacentDirectory = if ($null -eq $Exact -or -not $Exact.PSIsContainer) { [IO.Path]::GetDirectoryName($FullRequestedPath) } else { $null }
    if (-not [string]::IsNullOrWhiteSpace($AdjacentDirectory) -and [IO.Directory]::Exists($AdjacentDirectory)) {
      $RequestedStem = [IO.Path]::GetFileNameWithoutExtension($FullRequestedPath)
      foreach ($File in @(Get-ChildItem -LiteralPath $AdjacentDirectory -File -Force -ErrorAction SilentlyContinue)) {
        if (-not [string]::IsNullOrWhiteSpace($RequestedStem) -and -not $File.Name.StartsWith($RequestedStem, [StringComparison]::OrdinalIgnoreCase)) { continue }
        Add-VMInstallerLogCandidate -Seen $Seen -Candidates $Candidates -File $File -Origin 'Adjacent' -CutoffUtc $CutoffUtc -RequireRecent
      }
    }
  }

  if ($IncludeTemp -and [IO.Directory]::Exists($env:TEMP)) {
    $TextLogExtensions = @('.log', '.txt', '.xml', '.json', '.yaml', '.yml', '.ini', '.config', '.out', '.err')
    foreach ($File in @(Get-ChildItem -LiteralPath $env:TEMP -File -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTimeUtc -ge $CutoffUtc -and ([string]::IsNullOrEmpty($_.Extension) -or $_.Extension.ToLowerInvariant() -in $TextLogExtensions) })) {
      Add-VMInstallerLogCandidate -Seen $Seen -Candidates $Candidates -File $File -Origin 'TemporaryDirectory' -CutoffUtc $CutoffUtc -RequireRecent
    }
  }

  return @($Candidates | Sort-Object @{ Expression = { switch ($_.Origin) { 'RequestedFile' { 0 } 'RequestedDirectory' { 1 } 'Adjacent' { 2 } default { 3 } } } }, @{ Expression = { $_.File.LastWriteTimeUtc }; Descending = $true }, @{ Expression = { $_.File.FullName } } | Select-Object -First $MaximumFiles)
}

function Get-VMInstallerLogTail {
  param (
    [Parameter(Mandatory)][IO.FileInfo]$File,
    [ValidateRange(1, 10000)][int]$LineCount
  )

  $TextExtensions = @('', '.log', '.txt', '.xml', '.json', '.yaml', '.yml', '.ini', '.config', '.out', '.err')
  if ($File.Extension.ToLowerInvariant() -notin $TextExtensions) { return @() }
  try { return @(Get-Content -LiteralPath $File.FullName -Tail $LineCount -ErrorAction Stop | ForEach-Object { [string]$_ }) } catch { return @() }
}

function Copy-VMInstallerLogFile {
  param (
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestinationPath,
    [Parameter(Mandatory)][ValidateRange(0, 4294967296)][long]$MaximumBytes
  )

  $Source = $null
  $Destination = $null
  try {
    $Source = [IO.File]::Open($SourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $SourceLength = $Source.Length
    if ($SourceLength -gt $MaximumBytes) { throw "The log grew beyond the remaining evidence limit of $MaximumBytes bytes." }
    $Destination = [IO.File]::Open($DestinationPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $Buffer = New-Object byte[] 65536
    $Remaining = $SourceLength
    while ($Remaining -gt 0) {
      $Read = $Source.Read($Buffer, 0, [int][Math]::Min($Buffer.Length, $Remaining))
      if ($Read -le 0) { throw "The log ended before the expected $SourceLength bytes were copied." }
      $Destination.Write($Buffer, 0, $Read)
      $Remaining -= $Read
    }
    return $SourceLength
  } finally {
    if ($null -ne $Destination) { $Destination.Dispose() }
    if ($null -ne $Source) { $Source.Dispose() }
  }
}

function Get-WinGetVMInstallerLogEvidence {
  param (
    [AllowNull()][string[]]$RequestedPath,
    [Parameter(Mandatory)][datetime]$StartedAtUtc,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [AllowNull()][Nullable[int]]$ExitCode,
    [Parameter(Mandatory)][string]$Mode,
    [bool]$TimedOut,
    [bool]$IncludeTemp,
    [int]$MaximumFiles,
    [long]$MaximumFileBytes,
    [long]$MaximumTotalBytes,
    [int]$TailLineCount
  )

  $FullEvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
  if (-not [IO.Directory]::Exists($FullEvidenceDirectory)) { $null = [IO.Directory]::CreateDirectory($FullEvidenceDirectory) }
  $Warnings = New-Object 'System.Collections.Generic.List[string]'
  $EvidenceFiles = New-Object 'System.Collections.Generic.List[object]'
  $CopiedBytes = [int64]0
  $Index = 0
  foreach ($Candidate in @(Get-VMInstallerLogCandidate -RequestedPath $RequestedPath -CutoffUtc $StartedAtUtc -IncludeTemp $IncludeTemp -MaximumFiles $MaximumFiles)) {
    $Index++
    $File = $Candidate.File
    $SafeName = ($File.Name -replace '[^A-Za-z0-9._-]', '_')
    if ([string]::IsNullOrWhiteSpace($SafeName)) { $SafeName = 'installer.log' }
    $EvidenceFileName = ('{0:D4}-{1}' -f $Index, $SafeName)
    $DestinationPath = Join-Path $FullEvidenceDirectory $EvidenceFileName
    $Copied = $false
    $SkipReason = $null
    if ($File.Length -gt $MaximumFileBytes) {
      $SkipReason = "File exceeds MaximumLogFileBytes ($MaximumFileBytes)."
    } elseif ($CopiedBytes + $File.Length -gt $MaximumTotalBytes) {
      $SkipReason = "Combined files exceed MaximumTotalLogBytes ($MaximumTotalBytes)."
    } else {
      try {
        $RemainingTotalBytes = $MaximumTotalBytes - $CopiedBytes
        $CopiedFileBytes = Copy-VMInstallerLogFile -SourcePath $File.FullName -DestinationPath $DestinationPath -MaximumBytes ([Math]::Min($MaximumFileBytes, $RemainingTotalBytes))
        $Copied = $true
        $CopiedBytes += $CopiedFileBytes
      } catch {
        $SkipReason = $_.Exception.Message
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($SkipReason)) { $Warnings.Add("Log '$($File.FullName)' was not copied: $SkipReason") }
    $EvidenceFiles.Add([pscustomobject][ordered]@{
        SourcePath       = $File.FullName
        Origin           = $Candidate.Origin
        Length           = $File.Length
        LastWriteTimeUtc = $File.LastWriteTimeUtc.ToString('o')
        EvidenceFileName = if ($Copied) { $EvidenceFileName } else { $null }
        Copied           = $Copied
        SkipReason       = $SkipReason
        TailLines        = @(Get-VMInstallerLogTail -File $File -LineCount $TailLineCount)
      })
  }
  if ($EvidenceFiles.Count -eq 0) { $Warnings.Add('No installer log files were found at the requested, adjacent, or temporary locations.') }

  return [pscustomobject][ordered]@{
    SchemaVersion     = 1
    CollectedAtUtc    = [DateTime]::UtcNow.ToString('o')
    StartedAtUtc      = $StartedAtUtc.ToUniversalTime().ToString('o')
    InstallerMode     = $Mode
    InstallerExitCode = if ($null -eq $ExitCode) { $null } else { [int]$ExitCode }
    ExitCodeIsZero    = if ($null -eq $ExitCode) { $null } else { [int]$ExitCode -eq 0 }
    InstallerTimedOut = $TimedOut
    RequestedLogPaths = @($RequestedPath)
    IncludedTempLogs  = $IncludeTemp
    EvidenceDirectory = $FullEvidenceDirectory
    CopiedBytes       = $CopiedBytes
    Files             = $EvidenceFiles.ToArray()
    Warnings          = $Warnings.ToArray()
  }
}

function Get-WinGetVMInstalledStateSnapshot {
  param ([Parameter(Mandatory)][string]$SnapshotPhase)

  $Associations = Get-VMAssociationSnapshot
  $ARPEntries = @(Get-VMArpEntrySnapshot)
  $Protocols = @($Associations.ProtocolAssociations)
  $FileExtensions = @($Associations.FileExtensionAssociations)
  $EnvironmentPaths = @(Get-VMEnvironmentPathSnapshot)
  if (($ARPEntries.Count + $Protocols.Count + $FileExtensions.Count) -eq 0) {
    throw 'The installed-state collector returned no ARP, protocol, or file-extension records. This usually means the guest registry was not accessible in the current PowerShell Direct session; discard this capture and verify the guest credential and registry access.'
  }

  return [pscustomobject][ordered]@{
    SchemaVersion             = 2
    Phase                     = $SnapshotPhase
    CapturedAtUtc             = [DateTime]::UtcNow.ToString('o')
    ComputerName              = $env:COMPUTERNAME
    UserName                  = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    UserSid                   = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    IsElevated                = Test-VMProcessElevated
    OperatingSystem           = [Environment]::OSVersion.VersionString
    Is64BitOperatingSystem    = [Environment]::Is64BitOperatingSystem
    Is64BitProcess            = [Environment]::Is64BitProcess
    EvidenceCounts            = [pscustomobject][ordered]@{
      ARPEntries       = $ARPEntries.Count
      Protocols        = $Protocols.Count
      FileExtensions   = $FileExtensions.Count
      EnvironmentPaths = $EnvironmentPaths.Count
    }
    ARPEntries                = $ARPEntries
    ProtocolAssociations      = $Protocols
    FileExtensionAssociations = $FileExtensions
    EnvironmentPaths          = $EnvironmentPaths
  }
}

function ConvertTo-VMCanonicalJson {
  param ([Parameter(Mandatory)]$InputObject)
  return ($InputObject | ConvertTo-Json -Depth 30 -Compress)
}

function Compare-VMInstalledStateCollection {
  param (
    [AllowNull()][object[]]$Before,
    [AllowNull()][object[]]$After
  )

  $BeforeMap = @{}
  foreach ($Item in @($Before)) { $BeforeMap[[string]$Item.Identity] = $Item }
  $AfterMap = @{}
  foreach ($Item in @($After)) { $AfterMap[[string]$Item.Identity] = $Item }
  $Changes = @()

  foreach ($Identity in @($AfterMap.Keys | Sort-Object)) {
    if (-not $BeforeMap.ContainsKey($Identity)) {
      $Changes += [pscustomobject][ordered]@{ Status = 'Added'; Identity = $Identity; Before = $null; After = $AfterMap[$Identity] }
      continue
    }
    if ((ConvertTo-VMCanonicalJson -InputObject $BeforeMap[$Identity]) -cne (ConvertTo-VMCanonicalJson -InputObject $AfterMap[$Identity])) {
      $Changes += [pscustomobject][ordered]@{ Status = 'Modified'; Identity = $Identity; Before = $BeforeMap[$Identity]; After = $AfterMap[$Identity] }
    }
  }
  foreach ($Identity in @($BeforeMap.Keys | Sort-Object)) {
    if (-not $AfterMap.ContainsKey($Identity)) {
      $Changes += [pscustomobject][ordered]@{ Status = 'Removed'; Identity = $Identity; Before = $BeforeMap[$Identity]; After = $null }
    }
  }
  return @($Changes | Sort-Object @{ Expression = { @('Added', 'Modified', 'Removed').IndexOf($_.Status) } }, Identity)
}

function Test-VMArpChangeVisible {
  param ([Parameter(Mandatory)]$Change)
  if ($null -ne $Change.After) { return [bool]$Change.After.IsVisible }
  if ($null -ne $Change.Before) { return [bool]$Change.Before.IsVisible }
  return $false
}

function Compare-WinGetVMInstalledStateSnapshot {
  param (
    [Parameter(Mandatory)]$Before,
    [Parameter(Mandatory)]$After
  )

  $ARPChanges = @(Compare-VMInstalledStateCollection -Before $Before.ARPEntries -After $After.ARPEntries)
  $VisibleARPChanges = @($ARPChanges | Where-Object { Test-VMArpChangeVisible -Change $_ })
  $HiddenARPChanges = @($ARPChanges | Where-Object { -not (Test-VMArpChangeVisible -Change $_) })
  $ProtocolChanges = @(Compare-VMInstalledStateCollection -Before $Before.ProtocolAssociations -After $After.ProtocolAssociations)
  $FileExtensionChanges = @(Compare-VMInstalledStateCollection -Before $Before.FileExtensionAssociations -After $After.FileExtensionAssociations)
  $BeforeEnvironmentPaths = if ($Before.PSObject.Properties['EnvironmentPaths']) { @($Before.EnvironmentPaths) } else { @() }
  $AfterEnvironmentPaths = if ($After.PSObject.Properties['EnvironmentPaths']) { @($After.EnvironmentPaths) } else { @() }
  $EnvironmentPathChanges = @(Compare-VMInstalledStateCollection -Before $BeforeEnvironmentPaths -After $AfterEnvironmentPaths)

  return [pscustomobject][ordered]@{
    SchemaVersion          = 2
    ComparedAtUtc          = [DateTime]::UtcNow.ToString('o')
    BeforePhase            = $Before.Phase
    AfterPhase             = $After.Phase
    Summary                = [pscustomobject][ordered]@{
      ARPChanges             = $ARPChanges.Count
      VisibleARPChanges      = $VisibleARPChanges.Count
      HiddenARPChanges       = $HiddenARPChanges.Count
      ProtocolChanges        = $ProtocolChanges.Count
      FileExtensionChanges   = $FileExtensionChanges.Count
      EnvironmentPathChanges = $EnvironmentPathChanges.Count
    }
    ARPChanges             = $ARPChanges
    VisibleARPChanges      = $VisibleARPChanges
    HiddenARPChanges       = $HiddenARPChanges
    ProtocolChanges        = $ProtocolChanges
    FileExtensionChanges   = $FileExtensionChanges
    EnvironmentPathChanges = $EnvironmentPathChanges
  }
}

function Write-VMJsonFile {
  param (
    [Parameter(Mandatory)]$InputObject,
    [Parameter(Mandatory)][string]$LiteralPath
  )

  $FullPath = [IO.Path]::GetFullPath($LiteralPath)
  $Directory = [IO.Path]::GetDirectoryName($FullPath)
  if (-not [string]::IsNullOrWhiteSpace($Directory) -and -not [IO.Directory]::Exists($Directory)) {
    $null = [IO.Directory]::CreateDirectory($Directory)
  }
  $Json = $InputObject | ConvertTo-Json -Depth 30
  [IO.File]::WriteAllText($FullPath, $Json, (New-Object Text.UTF8Encoding($false)))
}

if ($Action -eq 'Compare') {
  if ([string]::IsNullOrWhiteSpace($BeforePath) -or [string]::IsNullOrWhiteSpace($AfterPath)) {
    throw 'BeforePath and AfterPath are required for Compare.'
  }
  $Before = Get-Content -LiteralPath $BeforePath -Raw | ConvertFrom-Json
  $After = Get-Content -LiteralPath $AfterPath -Raw | ConvertFrom-Json
  $Result = Compare-WinGetVMInstalledStateSnapshot -Before $Before -After $After
} elseif ($Action -eq 'CollectLogs') {
  if ($null -eq $SinceUtc) { throw 'SinceUtc is required for CollectLogs.' }
  if ([string]::IsNullOrWhiteSpace($LogOutputDirectory)) { throw 'LogOutputDirectory is required for CollectLogs.' }
  $Result = Get-WinGetVMInstallerLogEvidence -RequestedPath $LogPath -StartedAtUtc ([datetime]$SinceUtc) -EvidenceDirectory $LogOutputDirectory -ExitCode $InstallerExitCode -Mode $InstallerMode -TimedOut ([bool]$InstallerTimedOut) -IncludeTemp $IncludeTemporaryLogs -MaximumFiles $MaximumLogFiles -MaximumFileBytes $MaximumLogFileBytes -MaximumTotalBytes $MaximumTotalLogBytes -TailLineCount $LogTailLineCount
} else {
  $Result = Get-WinGetVMInstalledStateSnapshot -SnapshotPhase $Phase
}

Write-VMJsonFile -InputObject $Result -LiteralPath $OutputPath
if ($PassThru) { $Result }
