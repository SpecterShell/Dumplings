$Prefix = 'https://install.launcher.omniverse.nvidia.com/installers/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri "https://docs.omniverse.nvidia.com/launcher/latest/release-notes/$($this.CurrentState.Version.Replace('.', '_')).html" | ConvertFrom-Html

      # Remove links
      $Object2.SelectNodes('//a[@class="headerlink"]').ForEach({ $_.Remove() })

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('//section[@id="id1"]/following-sibling::node()') | Get-TextContent | Format-Text
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
