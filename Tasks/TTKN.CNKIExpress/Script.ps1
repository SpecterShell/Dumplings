$Prefix = 'https://download.cnki.net/cnkiexpress/'

$Object = Invoke-WebRequest -Uri "${Prefix}latest.yml" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.files[0].url
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.releaseDate.ToUniversalTime()

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.releaseNotes -csplit '(?m)^\s*[\d\.]+\s*$')[1] | Format-Text
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
