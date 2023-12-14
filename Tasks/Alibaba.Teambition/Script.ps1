# Download
$Object1 = Invoke-RestMethod -Uri 'https://www.teambition.com/site/client-config'
$Version1 = [regex]::Match($Object1.download_links.pc, 'Teambition-([\d\.]+)-win\.exe').Groups[1].Value
# Upgrade
$Object2 = Invoke-RestMethod -Uri 'https://im.dingtalk.com/manifest/dtron/Teambition/win32/ia32/latest.yml' | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Object2.Version) -gt 0) {
  $Task.CurrentState = $Object2
} else {
  # Version
  $Task.CurrentState.Version = $Version1

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.download_links.pc
  }

  if ($Version1 -eq $Object2.Version) {
    # ReleaseTime
    $Task.CurrentState.ReleaseTime = $Object2.ReleaseTime
  }
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
