$Object1 = $LocalStorage.JetBrainsApps.DS.release

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = $Object1.downloads.windows.link
  ProductCode            = "DataSpell $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = "DataSpell $($this.CurrentState.Version)"
      DisplayVersion = $Object1.build
      ProductCode    = "DataSpell $($this.CurrentState.Version)"
    }
  )
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture           = 'arm64'
  InstallerUrl           = $Object1.downloads.windowsARM64.link
  ProductCode            = "DataSpell $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = "DataSpell $($this.CurrentState.Version)"
      DisplayVersion = $Object1.build
      ProductCode    = "DataSpell $($this.CurrentState.Version)"
    }
  )
}

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
  $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
    Value = 'https://www.jetbrains.com/dataspell/whatsnew/'
  }
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotesUrl'
    Value  = 'https://www.jetbrains.com/zh-cn/dataspell/whatsnew/'
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.downloads.windows.checksumLink).Split()[0].ToUpper()
    $InstallerARM64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.downloads.windowsARM64.checksumLink).Split()[0].ToUpper()

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
