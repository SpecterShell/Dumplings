$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://inkscape.org/release/all/windows/?pre=0'
  Read-PlaywrightPageContent -Page $Page
} | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@id="content"]/div/table/tbody/tr[not(contains(./td[2], "dev"))][last()]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./td[1]').InnerText, 'Inkscape (\d+(?:\.\d+)+)').Groups[1].Value

$Prefix = 'https://inkscape.org'
$Object3 = $Object2.SelectNodes('.//a[@href]') | ForEach-Object -Process { $_.Attributes['href'].Value }

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Get-RedirectedUrl -Uri (Join-Uri $Prefix $Object3.Where({ $_.EndsWith('.msi') }, 'First')[0])
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Get-RedirectedUrl -Uri (Join-Uri $Prefix $Object3.Where({ $_.EndsWith('.exe') }, 'First')[0])
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $Object4 = Use-PlaywrightPage -Stealth -Headless {
        param($Page)
        $null = Open-PlaywrightPage -Page $Page -Uri "https://inkscape.org/release/inkscape-$($this.CurrentState.Version)/"
        Read-PlaywrightPageContent -Page $Page
      } | ConvertFrom-Html

      # Remove release date
      $Object4.SelectNodes('//div[@class="notes"]//*[contains(text(), "Released on")]').ForEach({ $_.Remove() })
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectNodes('//div[@class="notes"]/h1[1]/following-sibling::node()') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://inkscape.org/release/inkscape-$($this.CurrentState.Version)/"
      }
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://inkscape.org/zh-hans/release/inkscape-$($this.CurrentState.Version)/"
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
