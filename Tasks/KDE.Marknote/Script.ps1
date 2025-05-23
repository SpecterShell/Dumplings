$Prefix = 'https://cdn.kde.org/ci-builds/office/marknote/master/windows/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href
$VersionMatches = [regex]::Match($InstallerName, 'master-(?<Build>\d+)')

# Version
$this.CurrentState.Version = $VersionMatches.Groups['Build'].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # RealVersion
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile -ArgumentList '/S' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $this.CurrentState.RealVersion = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\marknote' -Name 'DisplayVersion'

    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://apps.kde.org/marknote/index.xml').Where({ $_.title.Contains($this.CurrentState.RealVersion) }, 'First')

      if ($Object2) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description.InnerXml | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
