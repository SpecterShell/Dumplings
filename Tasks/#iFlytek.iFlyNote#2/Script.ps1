$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['iFlyNote2'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['iFlyNote2'] = $OldReleaseNotes = [ordered]@{}
}

$Prefix = 'https://bj.openstorage.cn/v1/yuji/public/release/'

$this.CurrentState = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
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
