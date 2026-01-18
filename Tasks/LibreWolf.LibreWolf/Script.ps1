$Object1 = Invoke-RestMethod -Uri 'https://codeberg.org/api/v1/repos/librewolf/bsys6/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri $Object1.assets.links.Where({ $_.name -eq 'sha256sums.txt' }, 'First')[0].url | Split-LineEndings |
  Where-Object -FilterScript { $_.Contains('windows') -and $_.EndsWith('.exe') } |
  ForEach-Object -Process {
    $Entries = $_.Split('  ')
    $Object2[$Entries[1]] = $Entries[0].ToUpper()
  }

# Installer
$Asset = $Object1.assets.links.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('i686') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x86'
  InstallerType   = 'nullsoft'
  InstallerUrl    = $Asset.url | ConvertTo-UnescapedUri
  InstallerSha256 = $Object2[$Asset.name]
}
$Asset = $Object1.assets.links.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x86_64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerType   = 'nullsoft'
  InstallerUrl    = $Asset.url | ConvertTo-UnescapedUri
  InstallerSha256 = $Object2[$Asset.name]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.released_at.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1._links.self
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
