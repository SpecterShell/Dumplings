$Object1 = Invoke-RestMethod -Uri 'https://api.nanome.ai/versions/latest'

# Version
$this.CurrentState.Version = $Object1.results.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.results.windowsSetupUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.results.releaseDate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = @"
New Features and Improvements
$($Object1.results.features | ConvertTo-UnorderedList)

Optimizations and Fixes
$($Object1.results.fixes | ConvertTo-UnorderedList)
"@ | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @(
        [ordered]@{
          RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\')
        }
      )
      $ZipFile.Dispose()
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
