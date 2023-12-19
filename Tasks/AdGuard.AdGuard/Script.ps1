$Object = Invoke-RestMethod -Uri 'https://api.adguard.org/api/2.0/checkupdate.html?app_id=64dbc91754f34b0ebcc6eecadf83eb81&channel=Release&appname=adguard_ru&version=7.0.0.0&force=1'

# Version
$this.CurrentState.Version = $Object.response.version.'#cdata-section'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.response.'update-url'.'#cdata-section'
}

# ReleaseNotes (en-US)
# TODO: Select corresponding ReleaseNotes
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.response.'release-notes'.'#cdata-section' | Format-Text
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object.response.'more-info-url'.'#cdata-section'
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
