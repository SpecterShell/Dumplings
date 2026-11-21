$Object1 = Invoke-RestMethod -Uri 'https://www.puredevsoftware.com/update.php'

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'php_output:(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  # InstallerUrl = "https://www.puredevsoftware.com/download.php?file=mempro_old_versions/MemPro_x64_setup_$($this.CurrentState.Version -replace '\.', '_').exe&type=exe" # Not available for the latest version
  InstallerUrl = 'https://www.puredevsoftware.com/download.php?file=MemPro_x64_setup.exe&type=exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.puredevsoftware.com/mempro/Download.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//table[@class='version_table']//tr[position()=1 and contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
          'dd/MM/yyyy',
          $null
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
