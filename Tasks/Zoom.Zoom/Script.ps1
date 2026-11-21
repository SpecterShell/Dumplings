$Object1 = Invoke-WebRequest -Uri 'https://zoom.us/releasenotes' -Method Post -UserAgent 'Mozilla/5.0 (ZOOM.Win 10.0 x64)' -Form @{
  # channel      = '_zXODjj7SDia3m8DOuSc3w' # Slow
  # channel      = 'v0dhhyOtTJKlah6a3sTLpA' # Fast
  os           = 'win7'
  type         = 'manual'
  upgrade64Bit = 1
} | ConvertFrom-ProtoBuf
$Object2 = $Object1['12'].Replace(';', "`n") | ConvertFrom-StringData

# Version
$this.CurrentState.Version = $Object2.'Real-version'

# RealVersion
$VersionParts = $Object2.'Real-version'.Split('.')
$this.CurrentState.RealVersion = "$($VersionParts[0]).$($VersionParts[1]).$($VersionParts[3])"

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture  = 'x86'
#   InstallerType = 'msi'
#   InstallerUrl  = "https://zoom.us/client/$($Object2.'Real-version')/ZoomInstallerFull.msi"
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($Object2.'Real-version')/ZoomInstallerFull.msi?archType=x64"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($Object2.'Real-version')/ZoomInstallerFull.msi?archType=winarm64"
}


switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = ($Object1['11'] -split '(?=Release notes of \d+\.\d+\.\d+ \(\d+\))').Where({ $_.Contains($Object2.'Display-version') }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0] -creplace 'Release notes of \d+\.\d+\.\d+ \(\d+\)' | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
