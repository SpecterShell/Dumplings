$Object1 = Invoke-RestMethod -Uri 'http://3dflow.net/zephyr-network/networkMessage.php' -Method Post -Body @{
  action       = 'getInstaller'
  architecture = 'x64'
  product      = '3DF Zephyr Free'
  ver          = $this.LastState.Contains('Version') ? $this.LastState.Version : '7.529'
}

if ($Object1.Contains('NO_UPDATE_AVAILABLE')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Trim() | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'http://3dflow.net/zephyr-network/networkMessage.php' -Method Post -Body @{
        action       = 'checkUpdates'
        architecture = 'x64'
        product      = '3DF Zephyr Free'
        ver          = $this.LastState.Contains('Version') ? $this.LastState.Version : '7.529'
      }

      if (-not $Object2.Contains('NO_UPDATE_AVAILABLE')) {
        $Object3 = [System.IO.StringReader]::new($Object2.Split('|')[2])

        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String.StartsWith('Version') -and $String.Contains($this.CurrentState.Version)) {
            break
          }
        }
        if ($Object3.Peek() -ne -1) {
          $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
          while ($Object3.Peek() -ne -1) {
            $String = $Object3.ReadLine()
            if (-not $String.StartsWith('Version')) {
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
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $Object2.Split('|')[2] | Format-Text
          }
        }

        $Object3.Close()
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.LastState.Version)", 'Warning')
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
