function Get-ReleaseNotes {
  try {
    $RepoOwner = 'itchio'
    $RepoName = 'itch'

    $Object3 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/v$($this.CurrentState.Version)"

    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object3.published_at.ToUniversalTime()

    if (-not [string]::IsNullOrWhiteSpace($Object3.body)) {
      $ReleaseNotesObject = $Object3.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Invoke-RestMethod -Uri 'https://broth.itch.zone/itch/windows-amd64/versions'

# Version
$this.CurrentState.Version = $Object1.versions[0]

$Object2 = Invoke-RestMethod -Uri 'https://broth.itch.zone/install-itch/windows-amd64/versions'

# InstallerVersion
$this.CurrentState.InstallerVersion = $Object2.versions[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://broth.itch.zone/install-itch/windows-amd64/$($this.CurrentState.InstallerVersion)/archive/default"
}

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The version has changed
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    Get-ReleaseNotes

    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
}

# Case 3: The installer version has changed
if ($this.LastState.InstallerVersion -ne $this.CurrentState.InstallerVersion) {
  $this.Log('The installer version has changed', 'Info')

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 4: The version and the installer version have not changed
$this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
