$Object1 = $Global:DumplingsStorage.CardExchangeDownloadPage.SelectSingleNode('//tr[contains(@class, "fs-table-row") and contains(./td[contains(@class, "fs-table-title")]//div[contains(@class, "el-title")], "CardExchange® Press")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('./td[contains(@class, "fs-table-text_1")]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri $Object1.SelectSingleNode('.//a[contains(@class, "el-link")]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('./td[contains(@class, "fs-table-text_3")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $this.Log('Failed to parse release date', 'Warning')
    }

    try {
      $ReleaseNotesPage = Invoke-WebRequest -Uri 'https://cardexchangeid.com/support/information/release-notes' | ConvertFrom-Html
      $ReleaseNotesNode = $ReleaseNotesPage.SelectSingleNode("//div[contains(@id, 'module-') and contains(.//strong, 'CardExchange® PRESS')]//div[contains(@class, 'fs-changelog') and contains(.//h3[contains(@class, 'el-version')], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./ul/li').ForEach({ "[$($_.SelectSingleNode('.//div[contains(@class, "el-label")]').InnerText)] $($_.SelectSingleNode('.//div[contains(@class, "el-content")]').InnerText)" }) | Format-Text
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
