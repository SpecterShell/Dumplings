$Object1 = Invoke-RestMethod -Uri 'http://download.easeus.com/api2/index.php/Apicp/Drwdl202004/index/' -Method Post -Body @{
  exeNumber = 100000
  pid       = 5
  version   = 'free'
}

# Version
$this.CurrentState.Version = $Version = $Object1.data.curNum

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download
}

switch -Regex ($this.Check()) {
  'New|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('PartitionMaster') -and $Global:DumplingsStorage.PartitionMaster.Contains($Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.PartitionMaster.$Version.ReleaseNotesEN
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.PartitionMaster.$Version.ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Updated' {
    $this.Message()
    $this.Submit()
  }
}
