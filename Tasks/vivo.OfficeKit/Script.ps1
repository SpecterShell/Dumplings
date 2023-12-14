$Object = Invoke-WebRequest -Uri "https://pcsuite-api.vivo.com/version/upgrade/detail/windows/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object.files.url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Object.releaseData,
  "ddd MMM dd HH:mm:ss 'CST' yyyy",
  [cultureinfo]::GetCultureInfo('en-US')
).ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.releaseNotes | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
