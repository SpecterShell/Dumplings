$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['Teambition'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['Teambition'] = $OldReleaseNotes = [ordered]@{}
}

$this.CurrentState = Invoke-RestMethod -Uri 'https://im.dingtalk.com/manifest/dtron/Teambition/win32/ia32/latest.yml' | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = @{
      ReleaseTime = $this.CurrentState.ReleaseTime
    }
    if (-not $this.Preference.NoWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
