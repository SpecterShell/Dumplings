# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
  Stage and invoke the WinGet installed-state collector in a Hyper-V VM.
.DESCRIPTION
  Uses Hyper-V Guest Service for staging and PowerShell Direct for capture.
  It never launches an installer or application. Run those explicitly between
  BeforeInstall, AfterInstall, and AfterFirstRun captures.
.PARAMETER Action
  Stage the guest collector, capture a VM phase, or compare host snapshots.
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
#>
[CmdletBinding()]
param (
  [ValidateSet('Stage', 'Capture', 'Compare')]
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

  [string]$ComparisonOutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$GuestScriptSource = Join-Path $PSScriptRoot 'Get-WinGetVMInstalledState.ps1'

function Import-DumplingsHyperVModule {
  $env:PSModulePath += ';C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
  Import-Module Hyper-V -UseWindowsPowerShell -PassThru
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
$GuestOutputPath = Join-Path $GuestDirectory "$Phase.json"
$Json = Invoke-Command -VMName $VMName -Credential $VMCredential -ScriptBlock {
  param($CollectorPath, $SnapshotPhase, $SnapshotPath)
  & $CollectorPath -Action Capture -Phase $SnapshotPhase -OutputPath $SnapshotPath
  Get-Content -LiteralPath $SnapshotPath -Raw
} -ArgumentList $GuestScriptPath, $Phase, $GuestOutputPath

$null = [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory))
$HostOutputPath = Join-Path $OutputDirectory "$Phase.json"
[IO.File]::WriteAllText([IO.Path]::GetFullPath($HostOutputPath), [string]$Json, (New-Object Text.UTF8Encoding($false)))
[pscustomobject]@{
  VMName          = $VMName
  Phase           = $Phase
  GuestOutputPath = $GuestOutputPath
  HostOutputPath  = [IO.Path]::GetFullPath($HostOutputPath)
}
