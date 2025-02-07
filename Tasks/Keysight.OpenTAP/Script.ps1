$Query = @'
query Query {
  objects(
    name: "OpenTAP",
    version: "",
    os: "Windows",
    architecture: "x64",
    directory: "/Packages/"
  ) {
    date
    version
  }
}
'@

$Object1 = (Invoke-RestMethod -Uri 'https://packages.opentap.io/4.0/Query' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json')

# Version
$this.CurrentState.Version = $Object1.data.objects[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://packages.opentap.io/4.0/Objects/www/OpenTAP.exe?format=full&version=$($this.CurrentState.Version.Split('+')[0])"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.objects[0].date.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://github.com/opentap/opentap/releases'
      }

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/opentap/opentap/releases/tags/v$($this.CurrentState.Version.Split('+')[0])"

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $Object2.published_at.ToUniversalTime()

        if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
          $ReleaseNotesObject = $Object2.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('Binaries are available from SourceForge'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2.html_url
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
