# User
$Object1 = Invoke-RestMethod -Uri 'https://cdn.posit.co/positron/releases/win/x86_64/user-releases.json'
# Machine
$Object2 = Invoke-RestMethod -Uri 'https://cdn.posit.co/positron/releases/win/x86_64/system-releases.json'

if ($Object1.version -ne $Object2.version) {
  $this.Log("User version: $($Object1.version)")
  $this.Log("Machine version: $($Object2.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'user'
  InstallerUrl    = $Object1.url
  InstallerSha256 = $Object1.sha256hash.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'machine'
  InstallerUrl    = $Object2.url
  InstallerSha256 = $Object2.sha256hash.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.pub_date, 'yyyy-MM-dd HH:mm:ss UTC', $null).ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $RepoOwner = 'posit-dev'
      $RepoName = 'positron'

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/$($Object1.version)"

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        $ReleaseNotesObject = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[text()='Release Notes']")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.html_url
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
