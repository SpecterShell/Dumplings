$Task.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 4622 -Version '1.0.0.0' -Locale 'en-US'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://download.wondershare.com/cbs_down/filmorapro_full4622.exe'
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://download.wondershare.com/cbs_down/filmora_64bit_full4622.exe'
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
