$Object1 = Invoke-WebRequest -Uri 'https://cloud.r-project.org/bin/windows/base/release.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/head/meta').Attributes['CONTENT'].Value,
  '-(\d+\.\d+\.\d+)[-.]'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cloud.r-project.org/bin/windows/base/old/${Version}/R-${Version}-win.exe"
  ProductCode  = "R for Windows ${Version}_is1"
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = "https://cloud.r-project.org/bin/windows/base/old/${Version}/NEWS.R-${Version}.html"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-WebRequest -Uri 'https://cran.r-project.org/bin/windows/base/').Content

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2, 'Last change: (\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@class='container']/h3[contains(text(), '${Version}')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent).Replace("`u{2060}", '') | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
