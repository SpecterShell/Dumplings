$Object1 = Invoke-WebRequest -Uri 'https://modao.cc/feature/downloads.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/main/section[2]/div/div[3]').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download-win32"]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download-win64"]').Attributes['href'].Value
}

if ($LocalStorage.Contains('MockittCN') -and $LocalStorage.MockittCN.Contains($Version)) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.MockittCN.$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.MockittCN.$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
