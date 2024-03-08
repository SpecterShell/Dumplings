$Uri1 = Get-RedirectedUrl1st -Uri 'https://api-drive.mypikpak.com/package/v1/download/official_PikPak.exe?pf=windows'

$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head -Headers @{'If-Modified-Since' = $this.LastState.LastModified } -SkipHttpErrorCheck
if ($Object1.StatusCode -eq 304) {
  $this.Log("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

$Path = Get-TempFile -Uri $Uri1

# Version
$this.CurrentState.Version = $Version = Read-FileVersionFromExe -Path $Path

# RealVersion
$this.CurrentState.RealVersion = Read-ProductVersionFromExe -Path $Path

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Uri1
}

if ($Global:DumplingsStorage.Contains('PikPak') -and $Global:DumplingsStorage.PikPak.Contains($Version)) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage.PikPak.$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage.PikPak.$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
