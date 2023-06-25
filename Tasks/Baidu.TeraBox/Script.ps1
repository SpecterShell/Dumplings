$Object1 = Invoke-RestMethod -Uri 'https://www.terabox.com/api/getsyscfg?clienttype=0&language_type=&cfg_category_keys=[]&version=0'

# Version
$Version = [regex]::Match($Object1.fe_web_guide_setting.cfg_list[0].version, 'v([\d\.]+)').Groups[1].Value
$Task.CurrentState.Version = [regex]::Match($Version, '(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fe_web_guide_setting.cfg_list[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.fe_web_guide_setting.cfg_list[0].update_time | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.terabox.com/autoupdate' -Headers @{
      Pragma = 'ver=1.20.0.6;channel=00000000000000000000000000000000;clienttype=8;update_type=manual;xp_sp3=1;win7_later=1'
    } -SkipHeaderValidation | Read-ResponseContent | ConvertFrom-Xml

    try {
      # ReleaseNotes (en-US)
      if ($Version -eq $Object2.AutoUpdate.Module.version) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ('"' + ($Object2.AutoUpdate.Module.FullPackage.hint_en ?? $Object2.AutoUpdate.Module.Upgrade.hint_en) + '"') | ConvertFrom-Json | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
