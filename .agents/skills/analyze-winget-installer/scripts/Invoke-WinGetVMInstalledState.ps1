# SPDX-License-Identifier: MIT
#requires -Version 7.4

<#
.SYNOPSIS
  Stage and invoke the WinGet installed-state collector in a Hyper-V VM.
.DESCRIPTION
  Uses Hyper-V Guest Service for staging and PowerShell Direct for capture and
  bounded installer-log retrieval. It never launches an installer or application.
  Run those explicitly between BeforeInstall, AfterInstall, and AfterFirstRun captures.
.PARAMETER Action
  Stage the guest collector, capture a VM phase, compare host snapshots, or collect logs.
.PARAMETER VMName
  Hyper-V virtual machine name for Stage and Capture.
.PARAMETER Phase
  Snapshot phase label used for Capture and the output file name.
.PARAMETER OutputDirectory
  Host directory that receives snapshot or comparison JSON.
.PARAMETER Credential
  Guest credential used by PowerShell Direct.
.PARAMETER UserName
  Guest user name used to prompt for a credential or build an explicitly empty-password credential.
.PARAMETER AllowEmptyPassword
  Permit an empty password for UserName. This must be requested explicitly.
.PARAMETER LogPath
  Guest installer log file, directory, or filename prefix. Repeat as needed.
.PARAMETER InstallerStartedAtUtc
  UTC installer launch time used to identify adjacent and temporary logs.
.PARAMETER InstallerExitCode
  Exit code captured from the installer process by the agent.
.PARAMETER InstallerMode
  Validation mode associated with the process result.
.PARAMETER InstallerTimedOut
  Indicates that the installer exceeded the validation timeout.
.PARAMETER IncludeTemporaryLogs
  Search the guest user's temporary directory for recent logs.
.PARAMETER SkipLogFileTransfer
  Keep file metadata and tails but do not copy full log files from the guest.
#>
[CmdletBinding()]
param (
  [ValidateSet('Stage', 'Capture', 'Compare', 'CollectLogs')]
  [string]$Action = 'Capture',

  [string]$VMName,

  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
  [string]$Phase = 'Custom',

  [string]$OutputDirectory = (Join-Path $PWD 'VMValidation'),

  [pscredential]$Credential,

  [string]$UserName,

  [switch]$AllowEmptyPassword,

  [string]$GuestDirectory = 'C:\DumplingsValidation',

  [string]$BeforePath,

  [string]$AfterPath,

  [string]$ComparisonOutputPath,

  [string[]]$LogPath,

  [Nullable[datetime]]$InstallerStartedAtUtc,

  [Nullable[int]]$InstallerExitCode,

  [string]$InstallerMode = 'silent',

  [switch]$InstallerTimedOut,

  [bool]$IncludeTemporaryLogs = $true,

  [switch]$SkipLogFileTransfer,

  [ValidateRange(1, 4096)]
  [int]$MaximumLogFiles = 256,

  [ValidateRange(1, 1073741824)]
  [long]$MaximumLogFileBytes = 33554432,

  [ValidateRange(1, 4294967296)]
  [long]$MaximumTotalLogBytes = 134217728,

  [ValidateRange(1, 10000)]
  [int]$LogTailLineCount = 200
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$GuestScriptSource = Join-Path $PSScriptRoot 'Get-WinGetVMInstalledState.ps1'

function Import-DumplingsHyperVModule {
  $env:PSModulePath += ';C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
  Import-Module Hyper-V -PassThru
}

function Get-DumplingsVMCredential {
  param (
    [AllowNull()][pscredential]$SuppliedCredential,
    [AllowNull()][string]$SuppliedUserName,
    [switch]$PermitEmptyPassword
  )

  if ($null -ne $SuppliedCredential) { return $SuppliedCredential }
  if ([string]::IsNullOrWhiteSpace($SuppliedUserName)) {
    return Get-Credential -Message 'Enter the Hyper-V guest credential used by PowerShell Direct.'
  }
  if ($PermitEmptyPassword) {
    return New-Object Management.Automation.PSCredential($SuppliedUserName, (New-Object Security.SecureString))
  }
  return Get-Credential -UserName $SuppliedUserName -Message 'Enter the Hyper-V guest password used by PowerShell Direct.'
}

function Get-DumplingsValidationVM {
  if ([string]::IsNullOrWhiteSpace($VMName)) { throw 'VMName is required for Stage and Capture.' }
  $VM = Get-VM -Name $VMName -ErrorAction Stop
  if ([string]$VM.State -ne 'Running') { throw "VM '$VMName' must be running; current state is '$($VM.State)'." }
  $GuestServiceId = '6C09BB55-D683-4DA0-8931-C9BF705F6480'
  $GuestService = Get-VMIntegrationService -VMName $VMName | Where-Object {
    $_.Name -eq 'Guest Service Interface' -or ($_.PSObject.Properties['Id'] -and [string]$_.Id -eq $GuestServiceId)
  } | Select-Object -First 1
  if ($null -eq $GuestService -or -not $GuestService.Enabled) {
    throw "VM '$VMName' must have Hyper-V Guest Service Interface enabled."
  }
  return $VM
}

function Copy-DumplingsCollectorToVM {
  $null = Get-DumplingsValidationVM
  if (-not (Test-Path -LiteralPath $GuestScriptSource -PathType Leaf)) { throw "Guest collector not found: $GuestScriptSource" }
  $GuestScriptPath = Join-Path $GuestDirectory 'Get-WinGetVMInstalledState.ps1'
  Copy-VMFile -VMName $VMName -SourcePath $GuestScriptSource -DestinationPath $GuestScriptPath -FileSource Host -CreateFullPath -Force
  return $GuestScriptPath
}

function ConvertFrom-DumplingsVMSnapshotJson {
  param ([Parameter(Mandatory)][AllowEmptyString()][string]$Json)

  try { $Snapshot = $Json | ConvertFrom-Json -ErrorAction Stop } catch { throw "The VM collector returned invalid JSON: $($_.Exception.Message)" }
  foreach ($Property in @('SchemaVersion', 'Phase', 'ARPEntries', 'ProtocolAssociations', 'FileExtensionAssociations')) {
    if (-not $Snapshot.PSObject.Properties[$Property]) { throw "The VM collector result is missing required property '$Property'." }
  }
  if ([int]$Snapshot.SchemaVersion -ge 2 -and -not $Snapshot.PSObject.Properties['EnvironmentPaths']) {
    throw "The VM collector result is missing required property 'EnvironmentPaths'."
  }
  $EvidenceCount = @($Snapshot.ARPEntries).Count + @($Snapshot.ProtocolAssociations).Count + @($Snapshot.FileExtensionAssociations).Count
  if ($EvidenceCount -eq 0) {
    throw 'The VM collector returned an empty installed-state snapshot. Discard it and verify the guest credential, PowerShell Direct session, and registry access before continuing validation.'
  }
  return $Snapshot
}

function ConvertFrom-DumplingsVMLogEvidenceJson {
  param ([Parameter(Mandatory)][AllowEmptyString()][string]$Json)

  try { $Evidence = $Json | ConvertFrom-Json -ErrorAction Stop } catch { throw "The VM log collector returned invalid JSON: $($_.Exception.Message)" }
  foreach ($Property in @('SchemaVersion', 'InstallerMode', 'InstallerExitCode', 'InstallerTimedOut', 'Files', 'Warnings')) {
    if (-not $Evidence.PSObject.Properties[$Property]) { throw "The VM log collector result is missing required property '$Property'." }
  }
  return $Evidence
}

function Write-DumplingsHostJson {
  param (
    [Parameter(Mandatory)]$InputObject,
    [Parameter(Mandatory)][string]$LiteralPath
  )

  $FullPath = [IO.Path]::GetFullPath($LiteralPath)
  $Directory = [IO.Path]::GetDirectoryName($FullPath)
  if (-not [IO.Directory]::Exists($Directory)) { $null = [IO.Directory]::CreateDirectory($Directory) }
  [IO.File]::WriteAllText($FullPath, ($InputObject | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
  return $FullPath
}

if ($Action -eq 'Compare') {
  if ([string]::IsNullOrWhiteSpace($BeforePath) -or [string]::IsNullOrWhiteSpace($AfterPath)) {
    throw 'BeforePath and AfterPath are required for Compare.'
  }
  if ([string]::IsNullOrWhiteSpace($ComparisonOutputPath)) {
    $BeforeName = [IO.Path]::GetFileNameWithoutExtension($BeforePath)
    $AfterName = [IO.Path]::GetFileNameWithoutExtension($AfterPath)
    $ComparisonOutputPath = Join-Path $OutputDirectory "$BeforeName-to-$AfterName.json"
  }
  & $GuestScriptSource -Action Compare -BeforePath $BeforePath -AfterPath $AfterPath -OutputPath $ComparisonOutputPath -PassThru
  return
}

$null = Import-DumplingsHyperVModule
$GuestScriptPath = Copy-DumplingsCollectorToVM
if ($Action -eq 'Stage') {
  [pscustomobject]@{ VMName = $VMName; GuestScriptPath = $GuestScriptPath }
  return
}

$VMCredential = Get-DumplingsVMCredential -SuppliedCredential $Credential -SuppliedUserName $UserName -PermitEmptyPassword:$AllowEmptyPassword
if ($Action -eq 'CollectLogs') {
  if ($null -eq $InstallerStartedAtUtc) { throw 'InstallerStartedAtUtc is required for CollectLogs.' }
  $GuestLogDirectory = Join-Path (Join-Path $GuestDirectory 'Logs') $Phase
  $GuestLogResultPath = Join-Path $GuestDirectory "$Phase.InstallerLogs.json"
  $Session = $null
  try {
    $Json = Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock {
      param($CollectorPath, $ResultPath, $EvidenceDirectory, $RequestedLogPath, $StartedAtUtc, $ExitCode, $Mode, $TimedOut, $IncludeTemp, $MaximumFiles, $MaximumFileBytes, $MaximumTotalBytes, $TailLineCount)
      $Parameters = @{
        Action               = 'CollectLogs'
        OutputPath           = $ResultPath
        LogOutputDirectory   = $EvidenceDirectory
        LogPath              = $RequestedLogPath
        SinceUtc             = $StartedAtUtc
        InstallerMode        = $Mode
        InstallerTimedOut    = $TimedOut
        IncludeTemporaryLogs = $IncludeTemp
        MaximumLogFiles      = $MaximumFiles
        MaximumLogFileBytes  = $MaximumFileBytes
        MaximumTotalLogBytes = $MaximumTotalBytes
        LogTailLineCount     = $TailLineCount
      }
      if ($null -ne $ExitCode) { $Parameters['InstallerExitCode'] = [int]$ExitCode }
      & $CollectorPath @Parameters
      Get-Content -LiteralPath $ResultPath -Raw
    } -ArgumentList $GuestScriptPath, $GuestLogResultPath, $GuestLogDirectory, $LogPath, ([datetime]$InstallerStartedAtUtc).ToUniversalTime(), $InstallerExitCode, $InstallerMode, ([bool]$InstallerTimedOut), $IncludeTemporaryLogs, $MaximumLogFiles, $MaximumLogFileBytes, $MaximumTotalLogBytes, $LogTailLineCount
    $Evidence = ConvertFrom-DumplingsVMLogEvidenceJson -Json ([string]$Json)
    $HostLogDirectory = Join-Path (Join-Path $OutputDirectory 'Logs') $Phase
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($HostLogDirectory))
    $TransferredLogFiles = $false
    if (-not $SkipLogFileTransfer -and @($Evidence.Files | Where-Object Copied).Count -gt 0) {
      $Session = New-PSSession -VMName $VMName -Credential $VMCredential
      foreach ($EvidenceFile in @($Evidence.Files | Where-Object Copied)) {
        Copy-Item -FromSession $Session -LiteralPath (Join-Path $GuestLogDirectory $EvidenceFile.EvidenceFileName) -Destination $HostLogDirectory -Force
      }
      $TransferredLogFiles = $true
    }
    $HostOutputPath = Write-DumplingsHostJson -InputObject $Evidence -LiteralPath (Join-Path $OutputDirectory "$Phase.InstallerLogs.json")
    [pscustomobject]@{
      VMName              = $VMName
      Phase               = $Phase
      GuestOutputPath     = $GuestLogResultPath
      GuestLogDirectory   = $GuestLogDirectory
      HostOutputPath      = $HostOutputPath
      HostLogDirectory    = [IO.Path]::GetFullPath($HostLogDirectory)
      InstallerExitCode   = $Evidence.InstallerExitCode
      InstallerTimedOut   = $Evidence.InstallerTimedOut
      FileCount           = @($Evidence.Files).Count
      LogFilesTransferred = $TransferredLogFiles
      Warnings            = @($Evidence.Warnings)
    }
  } finally {
    if ($null -ne $Session) { Remove-PSSession -Session $Session -ErrorAction SilentlyContinue }
  }
  return
}

$GuestOutputPath = Join-Path $GuestDirectory "$Phase.json"
$Json = Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock {
  param($CollectorPath, $SnapshotPhase, $SnapshotPath)
  & $CollectorPath -Action Capture -Phase $SnapshotPhase -OutputPath $SnapshotPath
  Get-Content -LiteralPath $SnapshotPath -Raw
} -ArgumentList $GuestScriptPath, $Phase, $GuestOutputPath
$Snapshot = ConvertFrom-DumplingsVMSnapshotJson -Json ([string]$Json)

$HostOutputPath = Join-Path $OutputDirectory "$Phase.json"
$HostOutputPath = Write-DumplingsHostJson -InputObject $Snapshot -LiteralPath $HostOutputPath
[pscustomobject]@{
  VMName          = $VMName
  Phase           = $Phase
  GuestOutputPath = $GuestOutputPath
  HostOutputPath  = $HostOutputPath
}
