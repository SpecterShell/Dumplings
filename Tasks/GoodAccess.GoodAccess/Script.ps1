$Object1 = Invoke-RestMethod -Uri 'https://api.goodaccess.com/v7/updates/app' -Method Post -Body @{
  channel    = ''
  os_version = '{}'
} -UserAgent "os=windows;app_version=$($this.Status.Contains('New') ? '4.7.7': $this.LastState.Version);device_uuid=00000000-0000-0000-0000-000000000000" -SkipHeaderValidation

if (-not $Object1.update_available) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object2 = Invoke-RestMethod -Uri $Object1.data.manifest_url

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.timestamp | ConvertFrom-UnixTimeSeconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.goodaccess.com/product-changelog/windows' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # Remove anchors
        $Object2.SelectNodes("//div[contains(@class, 'hash') and contains(./a/@aria-label, 'Direct link to heading')]").ForEach({ $_.Remove() })
        # Remove pseudoBefore
        $Object2.SelectNodes("//div[contains(./div/@style, '--pseudoBefore')]").ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://support.goodaccess.com/product-changelog/windows' + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
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
