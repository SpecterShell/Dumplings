$Object1 = Invoke-RestMethod -Uri 'https://www.gpu-z.com/gpuz/version_v2'

# Version
$this.CurrentState.Version = $Object1.latest

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://us1-dl.techpowerup.com/files/GPU-Z.$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.techpowerup.com/download/techpowerup-gpu-z/changes').result | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "MMMM d'st', yyyy",
            "MMMM d'nd', yyyy",
            "MMMM d'rd', yyyy",
            "MMMM d'th', yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
