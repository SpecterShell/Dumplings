$Object1 = Invoke-RestMethod -Uri 'https://sourceforge.net/projects/pidgin/rss?path=/Pidgin'

# Version
$this.CurrentState.Version = [regex]::Match(
  ($Object1.title.'#cdata-section' -match '^/Pidgin/[\d\.]+/pidgin.+-offline\.exe$')[0],
  '^/Pidgin/([\d\.]+)/'
).Groups[1].Value

$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^/Pidgin/$([regex]::Escape($this.CurrentState.Version))/pidgin.+\.exe$" })

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') -and $_.title.'#cdata-section'.Contains('offline') }, 'First')[0].link | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') -and $_.title.'#cdata-section'.Contains('offline') }, 'First')[0].pubDate,
  'ddd, dd MMM yyyy HH:mm:ss "UT"',
  (Get-Culture -Name 'en-US')
) | ConvertTo-UtcDateTime -Id 'UTC'

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
