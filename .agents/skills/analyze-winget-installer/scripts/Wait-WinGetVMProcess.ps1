# SPDX-License-Identifier: MIT
#requires -Version 5.1

<#
.SYNOPSIS
  Wait for one already-started guest process with a bounded timeout.
.DESCRIPTION
  Run inside the VM that owns the process. This script never starts or kills a
  process and does not wait for descendants. Short wait slices allow interruption
  without blocking PowerShell for the entire timeout. Keep the remoting session
  open if live logs or child-process evidence still need collection.
.PARAMETER Process
  Live System.Diagnostics.Process returned by the explicit installer launch.
  The caller retains ownership. A deserialized remoting object is not supported.
.PARAMETER Id
  ID of an already-running process in the current guest. Use this for a known
  nested installer. If it has already exited, its exit code cannot be recovered
  through ID lookup; retain the live Process object whenever possible.
.PARAMETER TimeoutSeconds
  Maximum wait in seconds, from 1 through 86400. The default is 900 seconds.
.OUTPUTS
  One object containing ProcessId, ProcessStartedAtUtc, WaitStartedAtUtc,
  ElapsedMilliseconds, WaitScope, Completed, TimedOut, and ExitCode. ExitCode is
  null on timeout. Completion describes this process only, not installed state.
#>
[CmdletBinding(DefaultParameterSetName = 'Process')]
param (
  [Parameter(Mandatory, ParameterSetName = 'Process')]
  [ValidateNotNull()]
  [Diagnostics.Process]$Process,

  [Parameter(Mandatory, ParameterSetName = 'Id')]
  [ValidateRange(1, 2147483647)]
  [int]$Id,

  [ValidateRange(1, 86400)]
  [int]$TimeoutSeconds = 900
)

$OwnProcess = $PSCmdlet.ParameterSetName -eq 'Id'
if ($OwnProcess) { $Process = Get-Process -Id $Id -ErrorAction Stop }

try {
  # Retain a handle before waiting so an exited process or reused PID does not
  # change which process supplies the result.
  $null = $Process.Handle
  $ProcessId = $Process.Id
  $ProcessStartedAtUtc = $Process.StartTime.ToUniversalTime().ToString('o')
  $WaitStartedAtUtc = [DateTime]::UtcNow.ToString('o')
  $Clock = [Diagnostics.Stopwatch]::StartNew()
  $MaximumMilliseconds = [long]$TimeoutSeconds * 1000
  $Completed = $false

  # WaitForExit(timeout) observes only this handle. Never call the unbounded
  # overload or Start-Process -Wait, which would change the wait contract.
  do {
    $RemainingMilliseconds = $MaximumMilliseconds - $Clock.ElapsedMilliseconds
    if ($RemainingMilliseconds -le 0) { break }
    $Completed = $Process.WaitForExit([int][Math]::Min(250, $RemainingMilliseconds))
  } while (-not $Completed)

  [pscustomobject][ordered]@{
    ProcessId           = $ProcessId
    ProcessStartedAtUtc  = $ProcessStartedAtUtc
    WaitStartedAtUtc     = $WaitStartedAtUtc
    ElapsedMilliseconds  = $Clock.ElapsedMilliseconds
    WaitScope           = 'Process'
    Completed           = $Completed
    TimedOut            = -not $Completed
    ExitCode            = $(if ($Completed) { $Process.ExitCode } else { $null })
  }
} finally {
  # Dispose only the lookup handle. The original caller owns a supplied object,
  # and a timeout leaves the process alive for logs and interface inspection.
  if ($OwnProcess) { $Process.Dispose() }
}
