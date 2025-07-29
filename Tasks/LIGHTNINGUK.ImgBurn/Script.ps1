$Object1 = Invoke-WebRequest -Uri 'https://download.imgburn.com/_imgburn_version.txt' | Split-LineEndings

# Version
$this.CurrentState.Version = $Object1[0].Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.imgburn.com/SetupImgBurn_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.imgburn.com/index.php?act=changelog' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//a[@name='$($this.CurrentState.Version)']/following-sibling::table[1]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesNode.SelectSingleNode('./tr[1]').InnerText, '(\d{1,2}[a-zA-Z]+\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "d'st' MMMM yyyy",
            "d'nd' MMMM yyyy",
            "d'rd' MMMM yyyy",
            "d'th' MMMM yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./tr[2]') | Get-TextContent | Format-Text
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
