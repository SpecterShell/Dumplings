# x86 EXE
$Object1 = $Global:DumplingsStorage.ArgenteX86.data.Where({ $_.name -eq 'Argente Utilities' -and $_.installer -eq 'utilitiesx86' }, 'First')[0]
# x64 EXE
$Object2 = $Global:DumplingsStorage.ArgenteX64.data.Where({ $_.name -eq 'Argente Utilities' -and $_.installer -eq 'utilitiesx64' }, 'First')[0]
# arm64 EXE
$Object3 = $Global:DumplingsStorage.ArgenteARM64.data.Where({ $_.name -eq 'Argente Utilities' -and $_.installer -eq 'utilitiesarm64' }, 'First')[0]
# x86 Portable
$Object4 = $Global:DumplingsStorage.ArgenteX86.data.Where({ $_.name -eq 'Argente Utilities' -and $_.installer -eq 'utilitiesx86portable' }, 'First')[0]
# x64 Portable
$Object5 = $Global:DumplingsStorage.ArgenteX64.data.Where({ $_.name -eq 'Argente Utilities' -and $_.installer -eq 'utilitiesx64portable' }, 'First')[0]
# arm64 Portable
$Object6 = $Global:DumplingsStorage.ArgenteARM64.data.Where({ $_.name -eq 'Argente Utilities' -and $_.installer -eq 'utilitiesarm64portable' }, 'First')[0]

if (@(@($Object1.version, $Object2.version, $Object3.version, $Object4.version, $Object5.version, $Object6.version) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86 EXE: $($Object1.version), x64 EXE: $($Object2.version), arm64 EXE: $($Object3.version), x86 Portable: $($Object4.version), x64 Portable: $($Object5.version), arm64 Portable: $($Object6.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/utilitiesx86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/utilitiesx64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://argenteutilities.com/en/download/utilitiesarm64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'zip'
  InstallerUrl  = 'https://argenteutilities.com/en/download/utilitiesx86portable'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'zip'
  InstallerUrl  = 'https://argenteutilities.com/en/download/utilitiesx64portable'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'zip'
  InstallerUrl  = 'https://argenteutilities.com/en/download/utilitiesarm64portable'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object7 = Invoke-WebRequest -Uri 'https://argenteutilities.com/en/blog' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object7.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul').InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove download buttons
        $Object7.SelectNodes('//div[contains(@class, "more")]').ForEach({ $_.Remove() })
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
