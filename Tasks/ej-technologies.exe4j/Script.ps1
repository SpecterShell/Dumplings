$Prefix = 'https://download.ej-technologies.com/exe4j/'
$MajorVersion = [int]$this.Config.WinGetIdentifier.Split('.')[2]
if ((Invoke-WebRequest -Uri "${Prefix}updates${MajorVersion}.xml.nextAvailable" -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) {
  $this.Config.WinGetIdentifier = $this.Config.WinGetIdentifier -replace $MajorVersion, (++$MajorVersion)
  $this.Log("Next major version ${MajorVersion} available", 'Warning')
}
$Object1 = Invoke-RestMethod -Uri "${Prefix}updates${MajorVersion}.xml"

# x64
$Object2 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '55' }, 'First')[0]
# arm64
$Object3 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '311' }, 'First')[0]

if ($Object2.newVersion -ne $Object3.newVersion) {
  $this.Log("x64 version: $($Object2.newVersion)")
  $this.Log("arm64 version: $($Object3.newVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = Join-Uri $Prefix $Object2.fileName
  InstallerSha256 = $Object2.sha256sum.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerUrl    = Join-Uri $Prefix $Object3.fileName
  InstallerSha256 = $Object3.sha256sum.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.ej-technologies.com/feeds/exe4j').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
