$Object1 = Invoke-RestMethod -Uri 'https://xstudio-singer.xiaoice.com/version/update' -Headers @{
  'architecture-abi'      = 'x86_64'
  'platform-with-version' = 'Windows'
}

# Version
$this.CurrentState.Version = $Object1.latest.name

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object1.latest.release.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.latest.release.date | ConvertTo-UtcDateTime -Id 'UTC'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.latest.release.content | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
