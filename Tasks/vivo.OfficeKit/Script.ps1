$Object = Invoke-WebRequest -Uri "https://pcsuite-api.vivo.com/version/upgrade/detail/windows/latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object.files.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Object.releaseData,
  "ddd MMM dd HH:mm:ss 'CST' yyyy",
  [cultureinfo]::GetCultureInfo('en-US')
).ToUniversalTime()

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.releaseNotes | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
