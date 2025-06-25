# For instance, the application of version 11.0.5.622 will read the file at http://www.dolphinuk.co.uk/updates/EasyReader/11622/file.cat
# If file.cat contains ED11622.exe, it means that there is a new version available
# ED11622.exe is actually the installer of new version, regardless of its file name
$ShortLastVersion = $this.Status.Contains('New') ? '11622' : ('{0}{3}' -f $this.LastState.Version.Split('.'))
$Prefix = "http://www.dolphinuk.co.uk/updates/EasyReader/${ShortLastVersion}/"
$PseudoInstallerName = "ED${ShortLastVersion}.exe"

$Object1 = Invoke-RestMethod -Uri (Join-Uri $Prefix 'file.cat')

if (-not $Object1.Contains($PseudoInstallerName)) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri (Join-Uri $Prefix $PseudoInstallerName)

# Version
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
$ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join ''

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://exdownloads.yourdolphin.com/software/EasyReader/${ShortVersion}/EasyReader_${ShortVersion}.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri (Join-Uri $Prefix 'Whatsnew.txt')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2 | Format-Text
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
