# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
  Capture or compare WinGet installed-state evidence inside a validation VM.
.DESCRIPTION
  Collects ARP entries, protocol registrations, and file-extension associations
  without launching installers or applications. The script is self-contained
  and compatible with Windows PowerShell 5.1 so it can be copied into a clean VM.
.PARAMETER Action
  Capture a snapshot or compare two existing snapshot files.
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
#>
[CmdletBinding()]
param (
  [ValidateSet('Capture', 'Compare')]
  [string]$Action = 'Capture',

  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
  [string]$Phase = 'Custom',

  [Parameter(Mandatory)]
  [string]$OutputPath,

  [string]$BeforePath,

  [string]$AfterPath,

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

function Get-WinGetVMInstalledStateSnapshot {
  param ([Parameter(Mandatory)][string]$SnapshotPhase)

  $Associations = Get-VMAssociationSnapshot
  return [pscustomobject][ordered]@{
    SchemaVersion             = 1
    Phase                     = $SnapshotPhase
    CapturedAtUtc             = [DateTime]::UtcNow.ToString('o')
    ComputerName              = $env:COMPUTERNAME
    UserName                  = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    UserSid                   = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    IsElevated                = Test-VMProcessElevated
    OperatingSystem           = [Environment]::OSVersion.VersionString
    Is64BitOperatingSystem    = [Environment]::Is64BitOperatingSystem
    Is64BitProcess            = [Environment]::Is64BitProcess
    ARPEntries                = @(Get-VMArpEntrySnapshot)
    ProtocolAssociations      = @($Associations.ProtocolAssociations)
    FileExtensionAssociations = @($Associations.FileExtensionAssociations)
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

  return [pscustomobject][ordered]@{
    SchemaVersion        = 1
    ComparedAtUtc        = [DateTime]::UtcNow.ToString('o')
    BeforePhase          = $Before.Phase
    AfterPhase           = $After.Phase
    Summary              = [pscustomobject][ordered]@{
      ARPChanges           = $ARPChanges.Count
      VisibleARPChanges    = $VisibleARPChanges.Count
      HiddenARPChanges     = $HiddenARPChanges.Count
      ProtocolChanges      = $ProtocolChanges.Count
      FileExtensionChanges = $FileExtensionChanges.Count
    }
    ARPChanges           = $ARPChanges
    VisibleARPChanges    = $VisibleARPChanges
    HiddenARPChanges     = $HiddenARPChanges
    ProtocolChanges      = $ProtocolChanges
    FileExtensionChanges = $FileExtensionChanges
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
} else {
  $Result = Get-WinGetVMInstalledStateSnapshot -SnapshotPhase $Phase
}

Write-VMJsonFile -InputObject $Result -LiteralPath $OutputPath
if ($PassThru) { $Result }
