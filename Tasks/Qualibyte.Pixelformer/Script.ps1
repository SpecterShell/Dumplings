$Object1 = Invoke-WebRequest -Uri 'https://www.qualibyte.com/pixelformer/download.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Current version: (.+?)<').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.qualibyte.com/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//table[@class='news']/tr[contains(./td[@class='content'], '$($this.CurrentState.Version)')]")
      # Remove download button
      $ReleaseNotesNode.SelectNodes('./td[@class="content"]//a[contains(text(), "Download")]').ForEach({ $_.Remove() })

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($ReleaseNotesNode.SelectSingleNode('./td[@class="date"]').InnerText, '(\d{1,2}\.\d{1,2}\.\d{4})').Groups[1].Value,
        'dd.MM.yyyy',
        $null
      ).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNode.SelectSingleNode('./td[@class="content"]') | Get-TextContent | Format-Text
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
