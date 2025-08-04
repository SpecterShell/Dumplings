$Object1 = Invoke-WebRequest -Uri 'https://www.texteditor.pro/newversioncheck.php'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'inno'
  InstallerUrl  = 'https://www.texteditor.pro/downloads/TextEditorPro32.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = 'https://www.texteditor.pro/downloads/TextEditorPro64.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = 'https://www.texteditor.pro/downloads/TextEditorPro32.msi'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = 'https://www.texteditor.pro/downloads/TextEditorPro64.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://texteditor.pro/index.php?page=history' | ConvertFrom-Html
      $Object3 = [System.IO.StringReader]::new(($Object2.SelectSingleNode('//pre') | Get-TextContent))

      while ($Object3.Peek() -ne -1) {
        $String = $Object3.ReadLine()
        if ($String -match "^Version $([regex]::Escape($this.CurrentState.Version))") {
          if ($String -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if ($Object3.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String -notmatch '^Version \d+(?:\.\d+)+') {
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
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
