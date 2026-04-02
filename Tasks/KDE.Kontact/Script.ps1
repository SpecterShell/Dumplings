$Prefix = 'https://cdn.kde.org/ci-builds/pim/kontact/master/windows/'

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
    try {
      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'Handbook'
            DocumentUrl   = 'https://docs.kde.org/?application=kontact'
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '用户指南'
            DocumentUrl   = 'https://docs.kde.org/?application=kontact'
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # RealVersion
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile -ArgumentList '/S' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $this.CurrentState.RealVersion = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Kontact' -Name 'DisplayVersion'

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
