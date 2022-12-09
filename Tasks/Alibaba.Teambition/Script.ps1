# Download
$Object1 = Invoke-RestMethod -Uri 'https://www.teambition.com/site/client-config'
$InstallerUrl1 = $Object1.download_links.pc
$Version1 = [regex]::Match($InstallerUrl1, 'Teambition-([\d\.]+)-win\.exe').Groups[1].Value
# Upgrade
$Object2 = Invoke-RestMethod -Uri 'https://im.dingtalk.com/manifest/dtron/Teambition/win32/ia32/latest.yml' | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Object2.Version) -gt 0) {
  $Task.CurrentState = $Object2
} else {
  # Version
  $Task.CurrentState.Version = $Version1

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $InstallerUrl1
  }
}

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
