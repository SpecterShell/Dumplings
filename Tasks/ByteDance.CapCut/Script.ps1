$Object = Invoke-WebRequest -Uri 'https://www.capcut.com/' | ConvertFrom-Html

# Installer
$InstallerUrl = $Object.SelectSingleNode('//*[@id="root"]/div/div[3]/div[1]/div[3]/a[2]').Attributes['href'].Value
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'CapCut_([\d_]+)_capcutpc_0\.exe').Groups[1].Value.Replace('_', '.')

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
