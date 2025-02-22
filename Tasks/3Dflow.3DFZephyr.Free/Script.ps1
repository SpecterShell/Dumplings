$Object1 = Invoke-RestMethod -Uri 'http://3dflow.net/zephyr-network/networkMessage.php' -Method Post -Body @{
  action       = 'checkUpdates'
  architecture = 'x64'
  product      = '3DF Zephyr Free'
  ver          = $this.LastState.Contains('Version') ? $this.LastState.Version : '7.529'
}

if ($Object1.Contains('NO_UPDATE_AVAILABLE')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'Version (\d+(?:\.\d+)+)').Groups[1].Value

$Object2 = Invoke-RestMethod -Uri 'http://3dflow.net/zephyr-network/networkMessage.php' -Method Post -Body @{
  action       = 'getInstaller'
  architecture = 'x64'
  product      = '3DF Zephyr Free'
  ver          = $this.LastState.Contains('Version') ? $this.LastState.Version : '7.529'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Trim() | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1 | Split-LineEndings | Select-Object -Skip 2 | Format-Text
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
