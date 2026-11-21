$Object1 = Invoke-RestMethod -Uri 'https://api.binaryfortress.com/UpdateCheck/' -Method Post -Headers @{'BFAPI-TargetProductID' = '104' } -Body (
  @{
    cpu = 64
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.update.version | ConvertFrom-Base64 -Encoding 'utf-16'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri ($Object1.update.urlDownloadInstaller | ConvertFrom-Base64 -Encoding 'utf-16')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.clipboardfusion.com/ChangeLog/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='row']/div[contains(.//div[@class='TableTitleText'], 'v$($this.CurrentState.Version -replace '(\.0+)+$')')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.SelectSingleNode('.//div[@class="TableTitleText"]').InnerText, '([a-zA-Z]+\W+\d+\W+\d+)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "TableTitleContent")]') | Get-TextContent | Format-Text
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
