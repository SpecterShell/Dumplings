$Object1 = Invoke-RestMethod -Uri "https://api.iflynote.com/user/version/info?from=IFLYNOTE_PC_WINDOWS&clientVersion=$($this.LastState.Version ?? '3.1.1254')"

if ($Object1.code -eq 50002) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://download.iflynote.com/voicenote_pc_win'
}

# Sometimes the installer does not match the version
if ($InstallerUrl.Contains($this.CurrentState.Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object1.data.updateDetail | Format-Text
  }
} else {
  $this.Logging('The installer does not match the version', 'Warning')

  # Version
  $this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Prefix = 'https://bj.openstorage.cn/v1/yuji/public/release/'

    $Object2 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

    if ($Object2.Version -eq $this.CurrentState.Version) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.ReleaseTime
    } else {
      $this.Logging("No ReleaseNotes and ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
