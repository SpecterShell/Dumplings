$Object1 = Invoke-RestMethod -Uri "https://update.jellybox.com/check/jellybox/JellyBox/windows/x86_64/$($this.LastState.Contains('Version') ? $this.LastState.Version : '0.0.6')" -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Jellybox_$($this.CurrentState.Version)_x64-setup.exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.notes | Format-Text
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
