# x86
$Object1 = Invoke-WebRequest -Uri 'https://downloads.nomachine.com/download/?id=18'
# x64
$Object2 = Invoke-WebRequest -Uri 'https://downloads.nomachine.com/download/?id=17'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '(\d+(\.\d+)+_\d+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '(\d+(\.\d+)+_\d+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('_')[0]

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://kb.nomachine.com/software-updates'
      $ReleaseNotesLink = $Object3.Links.Where({ try { $_.outerHTML.Contains($this.CurrentState.RealVersion) } catch {} }, 'First')
      if ($ReleaseNotesLink) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $ReleaseNotesLink[0].href
        }

        $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
        $ReleaseNotesNode = $Object4.SelectSingleNode('//*[@id="kb-content"]')
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesNode.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('Supported Platforms'); $Node = $Node.NextSibling) {
          if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}[a-zA-Z]+\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
              $Matches[1],
              [string[]]@(
                "MMM d'st', yyyy", "MMMM d'st', yyyy",
                "MMM d'nd', yyyy", "MMMM d'nd', yyyy",
                "MMM d'rd', yyyy", "MMMM d'rd', yyyy",
                "MMM d'th', yyyy", "MMMM d'th', yyyy"
              ),
              (Get-Culture -Name 'en-US'),
              [System.Globalization.DateTimeStyles]::None
            ).ToString('yyyy-MM-dd')
          } else {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
