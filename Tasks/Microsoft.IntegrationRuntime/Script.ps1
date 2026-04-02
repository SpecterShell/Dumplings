$Object1 = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=39717').Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
$Object2 = $Object1.dlcDetailsView.downloadFile | Where-Object -FilterScript { $_.name.EndsWith('.msi') } | Sort-Object -Property { [regex]::Match($_.name, '(\d+(?:\.\d+)+)').Groups[1].Value -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.url
}

# Version
$this.CurrentState.Version = [regex]::Match($Object2.name, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
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
