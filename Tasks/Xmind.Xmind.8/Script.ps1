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

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
