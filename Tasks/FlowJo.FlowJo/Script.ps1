# $Object1 = Invoke-WebRequest -Uri 'http://www.flowjo.com/version.txt'
$Object1 = Invoke-WebRequest -Uri 'https://flowjo.com/flowjo/download'

$InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$RealVersion = [version]$this.CurrentState.Version
if ($RealVersion.Build -eq -1) { $RealVersion = [version]::new($RealVersion.Major, $RealVersion.Minor, 0, 0) }
if ($RealVersion.Revision -eq -1) { $RealVersion = [version]::new($RealVersion.Major, $RealVersion.Minor, $RealVersion.Build, 0) }
$this.CurrentState.RealVersion = $RealVersion.ToString()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
  ProductCode  = "FlowJo $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesUrl = "https://docs.flowjo.com/flowjo/getting-acquainted/$($this.CurrentState.Version.Split('.')[0..1] -join '-')-release-notes/$($this.CurrentState.Version.Split('.')[0..1] -join '-')-exhaustive-release-notes/"
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//section[@class="post_content"]') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
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
