$Object1 = Invoke-WebRequest -Uri 'https://firealpaca.com/download/win64' -Method Head
$FileName = [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($Object1.Headers.'Content-Disposition'[0]).FileName

# Version
$this.CurrentState.Version = [regex]::Match($FileName, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri 'https://firealpaca.com/bin/' $FileName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://firealpaca.com/download/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='download-history__container' and contains(./div[@class='download-history__body'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.SelectSingleNode('./div[@class="download-history__body"]').InnerText, '(20\d{2}\W+\d{1,2}\W+\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./*[@class="download-history__lists"]') | Get-TextContent | Format-Text
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
