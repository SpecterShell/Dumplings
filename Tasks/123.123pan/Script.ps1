$Object = Invoke-RestMethod -Uri 'https://www.123pan.com/api/version_upgrade' -Headers @{
  'platform'    = 'pc'
  'app-version' = $this.LastState.Version.Split('.')[2] ?? 109
}

if (-not $Object.data.hasNewVersion) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

$Prefix = $Object.data.url + '/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

if ($Object.data.lastVersion -ne $this.CurrentState.Version) {
  $this.Logging('Distinct versions detected', 'Warning')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.data.lastVersionCreate | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.desc | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
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
