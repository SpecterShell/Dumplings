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
  Write-Host -Object "Task $($Task.Name): The installers do not match the version" -ForegroundColor Yellow

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'x64_([\d\.]+)').Groups[1].Value
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
