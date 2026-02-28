$Object1 = Invoke-RestMethod -Uri 'https://www.hwinfo.com/ver.txt' | Split-LineEndings

# Version
$this.CurrentState.Version = $Object1[0]

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('-')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.hwinfo.com/files/hwi64_$($this.CurrentState.RealVersion.Replace('.', '')).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.hwinfo.com/version-history/' | Join-String -Separator "`n" | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='tab3']//div[contains(@class, 'version-released') and contains(., 'v$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
