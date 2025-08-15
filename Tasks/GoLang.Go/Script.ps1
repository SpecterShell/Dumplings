$Object1 = (Invoke-RestMethod -Uri 'https://go.dev/dl/?mode=json').Where({ $_.stable -eq $true }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version -replace '^go'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri 'https://go.dev/dl/' $Object1.files.Where({ $_.os -eq 'windows' -and $_.arch -eq '386' -and $_.kind -eq 'installer' }, 'First')[0].filename
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://go.dev/dl/' $Object1.files.Where({ $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'installer' }, 'First')[0].filename
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm'
#   InstallerUrl = Join-Uri 'https://go.dev/dl/' $Object1.files.Where({ $_.os -eq 'windows' -and $_.arch -eq 'arm' -and $_.kind -eq 'installer' }, 'First')[0].filename
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri 'https://go.dev/dl/' $Object1.files.Where({ $_.os -eq 'windows' -and $_.arch -eq 'arm64' -and $_.kind -eq 'installer' }, 'First')[0].filename
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://go.dev/doc/devel/release#' + $Object1.version
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://go.dev/doc/devel/release' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='go$($this.CurrentState.Version)']")
      if ($ReleaseNotesNode) {
        if ($ReleaseNotesNode.Name -eq 'h2') {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNode.SelectSingleNode('./following-sibling::p[1]') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
          }
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
