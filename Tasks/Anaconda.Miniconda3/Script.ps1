$Prefix = 'https://repo.anaconda.com/miniconda/'

# Retry is disabled for this package as the Anaconda server may return 429 with a large Retry-After number (up to one day),
# which PowerShell will follow even if RetryIntervalSec is specified.
$Object1 = Invoke-WebRequest -Uri $Prefix -MaximumRetryCount 0

$InstallerX64Name = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.EndsWith('.exe') -and $_.Contains('x86_64') -and $_.Contains('Miniconda3-py') } | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1
$VersionX64Matches = [regex]::Match($InstallerX64Name, '(py\d+_([\d\.]+-\d+))')
$VersionX64 = $VersionX64Matches.Groups[1].Value

$InstallerARM64Name = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.EndsWith('.exe') -and $_.Contains('arm64') -and $_.Contains('Miniconda3-py') } | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1
$VersionARM64Matches = [regex]::Match($InstallerARM64Name, '(py\d+_([\d\.]+-\d+))')
$VersionARM64 = $VersionARM64Matches.Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${InstallerX64Name}"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "${Prefix}${InstallerARM64Name}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://www.anaconda.com/docs/getting-started/miniconda/release-notes'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@id='miniconda-$($VersionX64Matches.Groups[2].Value.Replace('.', '-'))']")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./div[1]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove link marks
        $ReleaseNotesTitleNode.SelectNodes('.//a[starts-with(@href, "#")]').ForEach({ $_.Remove() })
        # Remove "Packages"
        $ReleaseNotesTitleNode.SelectNodes('.//details[contains(@class, "accordion")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./div[2]') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
