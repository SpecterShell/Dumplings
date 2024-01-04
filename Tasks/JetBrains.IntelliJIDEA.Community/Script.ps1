$Object1 = Invoke-RestMethod -Uri 'https://data.services.jetbrains.com/products/releases?latest=true&type=release&code=IIC'

# Version
$this.CurrentState.Version = $Object1.IIC[0].version

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = $Object1.IIC[0].downloads.windows.link
  ProductCode            = "IntelliJ IDEA Community Edition $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = "IntelliJ IDEA Community Edition $($this.CurrentState.Version)"
      DisplayVersion = $Object1.IIC[0].build
      ProductCode    = "IntelliJ IDEA Community Edition $($this.CurrentState.Version)"
    }
  )
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture           = 'arm64'
  InstallerUrl           = $Object1.IIC[0].downloads.windowsARM64.link
  ProductCode            = "IntelliJ IDEA Community Edition $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName    = "IntelliJ IDEA Community Edition $($this.CurrentState.Version)"
      DisplayVersion = $Object1.IIC[0].build
      ProductCode    = "IntelliJ IDEA Community Edition $($this.CurrentState.Version)"
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.IIC[0].date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.IIC[0].whatsnew | ConvertFrom-Html | Get-TextContent | Format-Text
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.IIC[0].notesLink
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.IIC[0].downloads.windows.checksumLink).Split()[0].ToUpper()
    $InstallerARM64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.IIC[0].downloads.windowsARM64.checksumLink).Split()[0].ToUpper()

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
