$Headers = @{
  'Content-Type'     = 'application/json'
  'apipost-machine'  = '0'
  'apipost-platform' = 'Win'
  'apipost-terminal' = 'client'
  'apipost-version'  = $this.Status.Contains('New') ? '8.1.17' : $this.LastState.Version
}
# x86
$Object1 = (Invoke-WebRequest -Uri 'https://workspace.apipost.net/api/upgrade/check_update' -Method Post -Headers $Headers -Body '{"arch":"ia32"}' -ContentType 'application/json').Content | ConvertFrom-Json -AsHashtable
if ($Object1.data.Count -eq 0) {
  $this.Log("The version (x86) $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# x64
$Object2 = (Invoke-WebRequest -Uri 'https://workspace.apipost.net/api/upgrade/check_update' -Method Post -Headers $Headers -Body '{"arch":"x64"}' -ContentType 'application/json').Content | ConvertFrom-Json -AsHashtable
if ($Object2.data.Count -eq 0) {
  $this.Log("The version (x64) $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

if ($Object1.data.version.latest_version -ne $Object2.data.version.latest_version) {
  $this.Log("Inconsistent versions: x86: $($Object1.data.version.latest_version), x64: $($Object2.data.version.latest_version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.data.version.latest_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.version.download_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.version.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Object1.data.version.short_desc -match '(20\d{2}-\d{1,2}-\d{1,2})') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($Object1.data.version.short_desc -split '20\d{2}-\d{1,2}-\d{1,2}')[1] | Format-Text
        }
      } else {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.data.version.short_desc | Format-Text
        }

        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
