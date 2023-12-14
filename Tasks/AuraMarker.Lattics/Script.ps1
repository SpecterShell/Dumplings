# International
$Object1 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=US&lang=en_us'
# Chinese
$Object2 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=CN&lang=zh_cn'

# Version
$Task.CurrentState.Version = $Object1.results[0].version

# Installer
$InstallerUrl = Get-RedirectedUrl -Uri 'https://mid.zineapi.com/to/get-lattics/win-installer-x64'
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = ($InstallerUrl | Split-Path -Leaf).Replace('.zip', '')
    }
  )
}

# Sometimes the installers do not match the version
if ($InstallerUrl.Contains($Task.CurrentState.Version)) {
  # ReleaseTime
  $Task.CurrentState.ReleaseTime = $Object1.results[0].currentVersionReleaseDate

  # ReleaseNotes (en-US)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Object1.results[0].releaseNotes | Format-Text
  }

  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object2.results[0].releaseNotes | Format-Text
  }
} else {
  $Task.Logging('The installers do not match the version', 'Warning')

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'x64_([\d\.]+)').Groups[1].Value
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
