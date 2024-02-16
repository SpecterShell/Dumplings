$Object1 = $LocalStorage.JetBrainsApps.TC.release

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = $Object1.downloads.windows.link
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = "Build $($Object1.build)"
      ProductCode    = 'JetBrains TeamCity'
    }
  )
}
# $this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
#   Architecture           = 'arm64'
#   InstallerUrl           = $Object1.downloads.windowsARM64.link
#   AppsAndFeaturesEntries = @(
#     [ordered]@{
#       DisplayVersion = "Build $($Object1.build)"
#       ProductCode    = 'JetBrains TeamCity'
#     }
#   )
# }

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'

if ($Object1.whatsnew) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Object1.whatsnew | ConvertFrom-Html | Get-TextContent | Format-Text
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

if ($Object1.notesLink) {
  # ReleaseNotesUrl
  $this.CurrentState.Locale += [ordered]@{
    Key   = 'ReleaseNotesUrl'
    Value = $Object1.notesLink
  }
} else {
  # ReleaseNotesUrl
  $this.CurrentState.Locale += [ordered]@{
    Key   = 'ReleaseNotesUrl'
    Value = 'https://www.jetbrains.com/teamcity/whatsnew/'
  }
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotesUrl'
    Value  = 'https://www.jetbrains.com/zh-cn/teamcity/whatsnew/'
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.downloads.windows.checksumLink).Split()[0].ToUpper()
    # $InstallerARM64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.downloads.windowsARM64.checksumLink).Split()[0].ToUpper()

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
