# Bounded process waits

Use this reference with [VM validation](vm-validation.md#capture-the-process-result). Run installer commands only inside the guest. The host controller stages [Wait-WinGetVMProcess.ps1](../../scripts/Wait-WinGetVMProcess.ps1) with the collector. Neither tool launches installers automatically.

## Wait for the actual installer

Start the verified installer explicitly with `-PassThru`, then pass its live process object to the waiter in the same guest session:

```powershell
$Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallerArguments -PassThru
try {
  $Result = & 'C:\DumplingsValidation\Wait-WinGetVMProcess.ps1' -Process $Process -TimeoutSeconds 900
  $Result | ConvertTo-Json | Set-Content -LiteralPath 'C:\DumplingsValidation\Silent.Process.json' -Encoding UTF8
} finally {
  $Process.Dispose()
}
```

Use one correctly quoted argument string for `$InstallerArguments`. `Start-Process` joins an argument array with spaces without preserving argument boundaries automatically.

The result identifies the observed PID and start time, elapsed wait, completion, timeout, and exit code. `WaitScope: Process` means that only this process was observed. The helper waits in short slices so PowerShell can handle interruption. It never kills the process, and its timeout leaves `ExitCode` null. Read live logs and inspect the interface before explicitly terminating a stalled installer.

Keep the returned process object whenever possible. The helper retains its handle and does not dispose a borrowed object. `Completed: true` records process completion, not installation success. Confirm the expected installed state and unattended behavior separately.

## Observe a known nested installer

If the outer launcher exits early, record its result separately and identify the actual installer from launch evidence, executable path, parent relationship, start time, or installer logs. Do not select every `msiexec` or another broad process-name match.

```powershell
$NestedResult = & 'C:\DumplingsValidation\Wait-WinGetVMProcess.ps1' -Id $ActualInstallerPid -TimeoutSeconds 900
```

The PID must still be running when lookup occurs. A terminated process's exit code cannot be recovered through a fresh PID lookup. Do not infer zero from its disappearance. Retain the original handle or use the installer's own final log or result file when it delegates work. A wrapper's exit code describes its child only when forwarding is verified.

## Deliberately wait for the process tree

Use this route when the launcher deliberately detaches its installer and the whole tree must finish. It also waits for launched applications and persistent helpers, so prefer the actual installer handle when those can remain running. The following guest-side example moves the tree wait into a process-based job and bounds the caller's wait. It collects live logs before stopping a timed-out job.

```powershell
$StartedAtUtc = [DateTime]::UtcNow
$Job = Start-Job -ScriptBlock {
  param($Path, $Arguments)
  $Process = $null
  try {
    $Process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    [pscustomobject]@{ WaitScope = 'ProcessTree'; TimedOut = $false; ExitCode = $Process.ExitCode }
  } finally {
    if ($null -ne $Process) { $Process.Dispose() }
  }
} -ArgumentList $InstallerPath, $InstallerArguments
try {
  if (-not (Wait-Job -Job $Job -Timeout 900)) {
    $null = & 'C:\DumplingsValidation\Get-WinGetVMInstalledState.ps1' -Action CollectLogs -LogPath $LogPath -SinceUtc $StartedAtUtc -LogOutputDirectory 'C:\DumplingsValidation\Logs\TreeTimeout' -OutputPath 'C:\DumplingsValidation\TreeTimeout.InstallerLogs.json' -InstallerMode silent -InstallerTimedOut
    [pscustomobject]@{ WaitScope = 'ProcessTree'; TimedOut = $true; ExitCode = $null }
  } else {
    Receive-Job -Job $Job -ErrorAction Stop
  }
} finally {
  if ($Job.State -notin @('Completed', 'Failed', 'Stopped')) { Stop-Job -Job $Job }
  Remove-Job -Job $Job -Force
}
```

Configure `$InstallerPath`, `$InstallerArguments`, and `$LogPath` from verified evidence before running this example. `Wait-Job -Timeout` bounds waiting without stopping the job. Stopping the job during cleanup may affect its native children. Inspect remaining guest processes explicitly, and do not treat job cleanup as proof that installation completed. Even after the whole tree exits, the returned code belongs to the outer process.

The bare `Start-ThreadJob` launch suggested in [PowerShell issue #15555](https://github.com/PowerShell/PowerShell/issues/15555) is not a reliable substitute for an explicit wait. In a local PowerShell 7.6.6 check, the job finished in about 0.2 seconds while its harmless native child continued running. The example above explicitly uses `Start-Process -Wait` inside the job.

## Keep the guest session available

Use a persistent PowerShell Direct session while launching, waiting, and collecting live evidence. Execute the helper inside the guest with `Invoke-Command -Session`; a deserialized process returned to the host is not a live process handle. Keep the session open after a timeout until logs and any nested-process evidence have been retrieved. Closing a remote session can terminate processes launched within it.

Dispose local process handles, stop and remove owned jobs, and remove the session after evidence collection. Restore the VM checkpoint through the canonical validation workflow.

## Sources

- [Start-Process process-tree waiting, argument quoting, and remoting behavior](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process)
- [Start-Job and process-based background jobs](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/start-job)
- [Wait-Job timeout semantics](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/wait-job)
