$Object = Invoke-RestMethod -Uri 'https://lf3-beecdn.bytetos.com/obj/ies-fe-bee/bee_prod/biz_80/bee_prod_80_bee_publish_3563.json'

# Installer
$InstallerUrl = $Object.windows_download_pkg.channel_default
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'Jianying_([\d_]+)_jianyingpro_0\.exe').Groups[1].Value.Replace('_', '.')

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object.windows_version_and_update_date, '(\d{4}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
