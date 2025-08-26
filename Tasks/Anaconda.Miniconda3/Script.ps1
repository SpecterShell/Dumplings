$Prefix = 'https://repo.anaconda.com/miniconda/'

# Retry is disabled for this package as the Anaconda server may return 429 with a large Retry-After number (up to one day),
# which PowerShell will follow even if RetryIntervalSec is specified.
$Object1 = Invoke-WebRequest -Uri $Prefix -MaximumRetryCount 0

$InstallerName = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.EndsWith('.exe') -and $_.Contains('x86_64') -and $_.Contains('Miniconda3-py') } | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$VersionMatches = [regex]::Match($InstallerName, '(py\d+_([\d\.]+-\d+))')
$this.CurrentState.Version = $VersionMatches.Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${InstallerName}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # ProductCode / AppsAndFeaturesEntries (DisplayName)
    $PythonVersion = [regex]::Match(
      (7z.exe e -y -so $InstallerFile 'conda-meta\history' | Select-String -Pattern '::python-' -Raw | Select-Object -First 1),
      '::python-([\d\.]+)'
    ).Groups[1].Value
    $this.CurrentState.Installer[0]['ProductCode'] = "Miniconda3 $($this.CurrentState.Version) (Python ${PythonVersion} 64-bit)"
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName = "Miniconda3 $($this.CurrentState.Version) (Python ${PythonVersion} 64-bit)"
        ProductCode = "Miniconda3 $($this.CurrentState.Version) (Python ${PythonVersion} 64-bit)"
      }
    )

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://www.anaconda.com/docs/getting-started/miniconda/release-notes'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@id='miniconda-$($VersionMatches.Groups[2].Value.Replace('.', '-'))']")
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

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
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
