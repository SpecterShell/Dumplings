$Prefix = 'https://eurkey.steffen.bruentjen.eu/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}download.html"
$Installer = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('windows') -and -not $_.href.Contains('beta') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Installer.outerHTML, 'version (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $Installer.href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Installer.href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'eurkey_i386.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'eurkey_i386.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://eurkey.steffen.bruentjen.eu/changelog.html' | ConvertFrom-Html
      $Object3 = [System.IO.StringReader]::new($Object2.SelectSingleNode('//pre').InnerText)

      while ($Object3.Peek() -ne -1) {
        $String = $Object3.ReadLine()
        if ($String -match "^Version $([regex]::Escape($this.CurrentState.Version))$") {
          $null = $Object3.ReadLine()
          break
        }
      }
      if ($Object3.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String -notmatch '^Version \d+(\.\d+)+$') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object3.Close()
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
