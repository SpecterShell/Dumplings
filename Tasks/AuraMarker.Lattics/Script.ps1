# International
$Object1 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=US&lang=en_us'
# Chinese
$Object2 = Invoke-RestMethod -Uri 'https://itunes.apple.com/lookup?id=1575605022&country=CN&lang=zh_cn'

# Version
$this.CurrentState.Version = $Object1.results[0].version

# Installer
$InstallerUrl = Get-RedirectedUrl -Uri 'https://mid.zineapi.com/to/get-lattics/win-installer-x64'
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = ($InstallerUrl | Split-Path -Leaf).Replace('.zip', '')
    }
  )
}

# Sometimes the installers do not match the version
if ($InstallerUrl.Contains($this.CurrentState.Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Object1.results[0].currentVersionReleaseDate

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Object1.results[0].releaseNotes | Format-Text
  }

  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object2.results[0].releaseNotes | Format-Text
  }
} else {
  $this.Logging('The installers do not match the version', 'Warning')

  # Version
  $this.CurrentState.Version = [regex]::Match($InstallerUrl, 'x64_([\d\.]+)').Groups[1].Value
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
