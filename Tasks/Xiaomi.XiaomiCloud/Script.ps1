# Download
$Object1 = Invoke-RestMethod -Uri 'https://update-server.micloud.xiaomi.net/api/v1/releases'
$InstallerUrl1 = $Object1.data.winx64
$Version1 = [regex]::Match($InstallerUrl1, 'XiaomiCloud-(\d+\.\d+\.\d+)').Groups[1].Value

# Upgrade
$Prefix = 'https://cdn.cnbj1.fds.api.mi-img.com/archive/update-server/public/win32/x64/'
$Object2 = Invoke-RestMethod -Uri "https://update-server.micloud.xiaomi.net/api/v1/latest.yml?channel=public&platform=win32&arch=x64&machine_id=$((New-Guid).Guid)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

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
