$Object1 = Invoke-WebRequest -Uri 'https://turbo.net/download' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@class="download-product" and contains(., "Turbo Studio")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./following-sibling::div[@class="download-version"]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('./following-sibling::div[contains(@class, "download-link")]//a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('./following-sibling::div[contains(@class, "download-date")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://turbo.net/docs/releases/studio/' | ConvertFrom-Html
      $ReleaseNotesObject = $Object4.SelectSingleNode("//div[@class='release-section' and contains(.//h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectSingleNode('.//div[@class="vp-doc"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
