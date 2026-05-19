$Prefix = 'https://static.keet.io/downloads/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$FolderName = $Object1.Links.Where({ try { $_.href -match '^\d+(?:\.\d+)+/$' } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($FolderName, '(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix += $FolderName
$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msix') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMSIX

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
