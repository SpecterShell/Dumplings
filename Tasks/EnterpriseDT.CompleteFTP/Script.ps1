$Object1 = Invoke-WebRequest -Uri 'https://enterprisedt.com/products/completeftp/doc/guide/html/history.html' | ConvertFrom-Html
$ReleaseNotesNode = $Object1.SelectSingleNode('//tr[position() > 1 and contains(./td[1], "Version")]')

# Version
$this.CurrentState.Version = [regex]::Match($ReleaseNotesNode.InnerText, 'Version (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://enterprisedt.com/scripts/getInstaller.php?type=trial'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNode.SelectSingleNode('./td[2]') | Get-TextContent | Format-Text
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
