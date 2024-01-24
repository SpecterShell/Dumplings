$Object1 = Invoke-WebRequest -Uri 'https://zoom.us/releasenotes' -Method Post -UserAgent 'Mozilla/5.0 (ZOOM.Win 10.0 x64)' -Form @{
  os           = 'win7'
  type         = 'manual'
  upgrade64Bit = 1
} | ConvertFrom-ProtoBuf
$Object2 = $Object1['12'].Split(';') | ConvertFrom-StringData

# Version
$this.CurrentState.Version = $Object2.'Real-version'
$DisplayVersion = $Object2.'Display-version'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerType          = 'exe'
  InstallerUrl           = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      Publisher      = 'Zoom Video Communications, Inc.'
      DisplayVersion = $DisplayVersion
      ProductCode    = 'ZoomUMX'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'exe'
  InstallerUrl           = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.exe?archType=x64"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      Publisher      = 'Zoom Video Communications, Inc.'
      DisplayVersion = $DisplayVersion
      ProductCode    = 'ZoomUMX'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'arm64'
  InstallerType          = 'exe'
  InstallerUrl           = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.exe?archType=winarm64"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      Publisher      = 'Zoom Video Communications, Inc.'
      DisplayVersion = $DisplayVersion
      ProductCode    = 'ZoomUMX'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.msi?archType=x64"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.msi?archType=winarm64"
}

$ReleaseNotesObject = ($Object1['11'] -split '(?=Release notes of \d+\.\d+\.\d+ \(\d+\))').Where({ $_.Contains($DisplayVersion) })[0]
if ($ReleaseNotesObject) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesObject -creplace 'Release notes of \d+\.\d+\.\d+ \(\d+\)' | Format-Text
  }
} else {
  $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
