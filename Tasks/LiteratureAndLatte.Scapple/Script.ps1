$Object1 = Invoke-RestMethod -Uri 'https://www.literatureandlatte.com/scappleforwindows/AutoUpdate/updates-x64.xml'

# Version
$this.CurrentState.Version = $Object1.installerInformation.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.literatureandlatte.com/scappleforwindows/downloads/Scapple-$($this.CurrentState.Version.Replace('.', ''))-installer.exe"
  ProductCode  = "Scapple $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.literatureandlatte.com/scapple/release-notes?os=Windows' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(@class, 'accordion-title') and contains(., '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./div[@class="accordion-date"]').InnerText, '(\d{1,2}[a-zA-Z]+\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value,
          [string[]]@(
            "d'st' MMMM yyyy",
            "d'nd' MMMM yyyy",
            "d'rd' MMMM yyyy",
            "d'th' MMMM yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # Remove download button
        $Object2.SelectNodes('//a[contains(., "Download")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="accordion-content"]') | Get-TextContent | Format-Text
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
