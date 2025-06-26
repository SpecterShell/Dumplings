$Object1 = (Invoke-RestMethod -Uri 'https://link.wacom.com/wdc/update.xml').root.win.files.ArrayElement[0]

# Version
$this.CurrentState.Version = $Object1.version.'#text'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object1.url.'#text' $Object1.file.'#text'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = "https://cdn.wacom.com/u/productsupport/drivers/win/professional/releasenotes/Windows_$($this.CurrentState.Version).html"

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//div[@class="description"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode("//div[@class='sectiontitle' and contains(text(), `"What's new`")]/following-sibling::div[@class='drivercontent'][1]") | Get-TextContent | Format-Text
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
