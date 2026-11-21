$Object1 = Invoke-WebRequest -Uri 'https://turbo.net/download' | ConvertFrom-Html

# EXE
$Object2 = $Object1.SelectSingleNode('//div[@class="download-product" and contains(., "Turbo for Windows") and not(contains(., "MSI"))]')
$VersionEXE = [regex]::Match($Object2.SelectSingleNode('./following-sibling::div[@class="download-version"]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# MSI
$Object3 = $Object1.SelectSingleNode('//div[@class="download-product" and contains(., "Turbo for Windows (MSI)")]')
$VersionMSI = [regex]::Match($Object3.SelectSingleNode('./following-sibling::div[@class="download-version"]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionEXE -ne $VersionMSI) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("MSI version: ${VersionMSI}")
  throw 'Inconsistent versions detected'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = $Object2.SelectSingleNode('./following-sibling::div[contains(@class, "download-link")]//a').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Object3.SelectSingleNode('./following-sibling::div[contains(@class, "download-link")]//a').Attributes['href'].Value
}

# Version
$this.CurrentState.Version = $VersionEXE

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('./following-sibling::div[contains(@class, "download-date")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://turbo.net/docs/releases/client/' | ConvertFrom-Html
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
