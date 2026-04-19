$Object1 = Invoke-WebRequest -Uri 'https://rekordbox.com/en/download/' | ConvertFrom-Html

$InstallerUrl = $Object1.SelectSingleNode("//a[contains(@data-url, '.zip') and contains(@data-url, 'x64')]").Attributes['data-url'].Value | ConvertTo-UnescapedUri

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'x64_(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
  ProductCode  = "Pioneer rekordbox $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @(
      [ordered]@{
        RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\')
      }
    )
    $ZipFile.Dispose()
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://rekordbox.com/support/releasenote/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//li[contains(@class, 'rb-g-list-item') and contains(./h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./*[contains(@id, "content")]') | Get-TextContent | Format-Text
        }

        # ReleaseTime
        if ($ReleaseNotesNode.SelectSingleNode('./h2') -and [regex]::Match($ReleaseNotesNode.SelectSingleNode('./h2').InnerText, '(20\d{2}\W+\d{1,2}\W+\d{1,2})').Groups[1].Value) {
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
