$Object1 = (Invoke-RestMethod -Uri 'https://asio4all.org/category/version-history/feed/atom/').Where({ $_.title.'#cdata-section' -match 'Version \d+(?:\.\d+)+' -and $_.title.'#cdata-section' -notmatch 'alpha|beta|rc' })[0]
# PackageUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'PackageUrl'
  Value = $Prefix = $Object1.link.Where({ $_.rel -eq 'alternate' }, 'First')[0].href
}

$Object2 = $Object1.content.'#cdata-section' | ConvertFrom-Html
$Prefix = Join-Uri $Prefix $Object2.SelectSingleNode('//a[contains(@class, "wp-block-button__link")]').Attributes['href'].Value
$Object3 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://asio4all.org/' $Object3.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
