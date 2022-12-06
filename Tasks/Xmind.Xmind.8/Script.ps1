$Object = Invoke-RestMethod -Uri 'https://www.xmind.net/_api/checkVersion/0?distrib=cathy_win32'

# Version
$Task.CurrentState.Version = [regex]::Match($Object.buildId, '([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.download
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.whatsNew.Split("`n`n")[1] | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
