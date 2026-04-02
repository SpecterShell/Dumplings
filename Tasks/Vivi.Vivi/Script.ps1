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
        Value  = $ReleaseNotesUrl = 'https://vivi.atlassian.net/wiki/spaces/VRB/overview'
      }

      $Query = @'
{
  macroBodyRenderer(
    adf: "{\"attrs\":{\"bodyType\":\"none\",\"extensionKey\":\"blog-posts\",\"extensionType\":\"com.atlassian.confluence.macro.core\",\"parameters\":{}},\"type\":\"extension\"}"
    contentId: "2949181"
  ) {
    value
  }
}
'@
      $Object1 = Invoke-RestMethod -Uri 'https://vivi.atlassian.net/cgraphql' -Method 'Post' -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json' -UserAgent $DumplingsBrowserUserAgent
      $ReleaseNotesObject = $Object1.data.macroBodyRenderer.value | ConvertFrom-Html
      if ($ReleaseNotesNode = $ReleaseNotesObject.SelectSingleNode("//div[@class='blog-post-listing' and contains(.//a[@class='blogHeading'], '$($this.CurrentState.Version)')]")) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesNode.SelectSingleNode('.//a[@class="blogHeading"]').Attributes['href'].Value
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectSingleNode('//div[@class="wiki-content"]') | Get-TextContent | Format-Text
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
