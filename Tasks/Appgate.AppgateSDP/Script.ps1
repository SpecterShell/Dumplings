$Prefix = 'https://www.appgate.com/support/software-defined-perimeter-support'
$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href -match 'software-defined-perimeter-support/sdp[._-]v?\d+(?:[.-]\d+)+' } catch {} }, 'First')[0].href
$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = $Object2.Links.Where({ try { $_.href.Contains('.exe') -and $_.href.Contains('Installer') -and $_.href.Contains('Lite') } catch {} }, 'First')[0].href -replace '\.btn$'
}
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'machine'
  InstallerUrl = $Object2.Links.Where({ try { $_.href.Contains('.exe') -and $_.href.Contains('Installer') -and -not $_.href.Contains('Lite') } catch {} }, 'First')[0].href -replace '\.btn$'
}

# Version
$this.CurrentState.Version = [regex]::Matches($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)')[-1].Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
