# x86
$Object1 = $Global:DumplingsStorage.ArgenteX86.data.Where({ $_.name -eq 'Argente System Repair' -and $_.installer -eq 'systemrepairx86' }, 'First')[0]
# x64
$Object2 = $Global:DumplingsStorage.ArgenteX64.data.Where({ $_.name -eq 'Argente System Repair' -and $_.installer -eq 'systemrepairx64' }, 'First')[0]
# arm64
$Object3 = $Global:DumplingsStorage.ArgenteARM64.data.Where({ $_.name -eq 'Argente System Repair' -and $_.installer -eq 'systemrepairarm64' }, 'First')[0]

if (@(@($Object1.version, $Object2.version, $Object3.version) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: $($Object1.version), x64: $($Object2.version), arm64: $($Object3.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/systemrepairx86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/systemrepairx64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/systemrepairarm64'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object4 = Invoke-WebRequest -Uri 'https://argenteutilities.com/en/blog' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul').InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove download buttons
        $Object4.SelectNodes('//div[contains(@class, "more")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::ul[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
