# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://api.vivi.io/windows-msi'
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://api.vivi.io/windows-msi64'
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://vivi.atlassian.net/wiki/spaces/VRB/overview'
      }

      $Object1 = Invoke-RestMethod -Uri 'https://vivi.atlassian.net/wiki/rest/api/content?spaceKey=VRB&type=blogpost&limit=200' -UserAgent $DumplingsBrowserUserAgent
      $ReleaseNotesPost = $Object1.results.Where({ $_.title -match "(?<![\d.])$([regex]::Escape($this.CurrentState.Version))(?![\d.])" }, 'First')[0]
      if ($ReleaseNotesPost) {
        $Object2 = Invoke-RestMethod -Uri "https://vivi.atlassian.net/wiki/rest/api/content/$($ReleaseNotesPost.id)?expand=body.view" -UserAgent $DumplingsBrowserUserAgent

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "$($Object2._links.base)$($Object2._links.webui)"
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body.view.value | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
