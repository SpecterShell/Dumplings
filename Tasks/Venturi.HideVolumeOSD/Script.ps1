$Object1 = Invoke-WebRequest -Uri 'http://wordpress.venturi.de/?feed=atom&s=HideVolumeOSD' -UserAgent $DumplingsBrowserUserAgent | Read-ResponseContent | ConvertFrom-Xml

# The search feed is unordered, so take the newest post that still exposes a download link
$Entry = @($Object1.feed.entry | Where-Object { $_.content.InnerText.Contains('sdm_process_download') } | Sort-Object { [datetime]$_.updated } -Descending)[0]
$Object2 = $Entry.content.InnerText | ConvertFrom-Html

$RedirectChain = @(Get-RedirectedUrls -Uri $Object2.SelectNodes('//a[@href]').Where({ $_.Attributes['href'].Value.Contains('sdm_process_download') }, 'First')[0].Attributes['href'].Value -Method GET)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $RedirectChain[-1]
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'HideVolumeOSD-(\d+(?:\.\d+)+)\.exe').Groups[1].Value

# PackageUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'PackageUrl'
  Value = $Entry.content.base
}

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
