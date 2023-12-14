$Object = Invoke-RestMethod -Uri 'https://lf3-beecdn.bytetos.com/obj/ies-fe-bee/bee_prod/biz_80/bee_prod_80_bee_publish_3563.json'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.windows_download_pkg.channel_default
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+_\d+_\d+_\d+)_jianyingpro').Groups[1].Value.Replace('_', '.')

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object.windows_version_and_update_date, '(\d{4}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
