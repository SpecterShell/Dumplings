$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['iFlyNote2'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['iFlyNote2'] = $OldReleaseNotes = [ordered]@{}
}

$Prefix = 'https://bj.openstorage.cn/v1/yuji/public/release/'

$this.CurrentState = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime = $this.CurrentState.ReleaseTime
    }
    if ($this.Preference.Contains('EnableWrite') -and $this.Preference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
}
