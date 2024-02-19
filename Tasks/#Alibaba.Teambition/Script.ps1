$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['Teambition'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['Teambition'] = $OldReleaseNotes = [ordered]@{}
}

$this.CurrentState = Invoke-RestMethod -Uri 'https://im.dingtalk.com/manifest/dtron/Teambition/win32/ia32/latest.yml' | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

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
