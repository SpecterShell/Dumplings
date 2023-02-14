$Object1 = Invoke-WebRequest -Uri 'https://www.capcut.com/' | ConvertFrom-Html

$Object2 = $Object1.SelectSingleNode('//*[@id="RENDER_DATA"]').InnerHtml.Trim() | ConvertTo-UnescapedUri | ConvertFrom-Json -AsHashtable

# Installer
$InstallerUrl = $Object2.values.tccData.download_link[0].windows_download_pkg.channel_default
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
