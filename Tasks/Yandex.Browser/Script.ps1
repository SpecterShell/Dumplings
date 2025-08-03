$Object1 = Invoke-RestMethod -Uri 'https://api.browser.yandex.com/update-info/browser/int/win-int.rss' -Body @{
  version = $this.Status.Contains('New') ? '24.4.4.1168' : $this.LastState.Version
  custo   = 'yes'
  manual  = 'yes'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.cdn.yandex.net/browser/int/$([regex]::Match($Object1.guid, '/(\d+_\d+_\d+_\d+_\d+)').Groups[1].Value)/en/Yandex.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.pubDate, 'ddd, dd MMM yyyy HH:mm:ss "UTC"', (Get-Culture -Name 'en-US')) | ConvertTo-UtcDateTime -Id 'UTC'
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
