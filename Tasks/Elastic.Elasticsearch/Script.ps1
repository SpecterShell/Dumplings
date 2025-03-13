$RepoOwner = 'elastic'
$RepoName = 'elasticsearch'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$($this.CurrentState.Version)-windows-x86_64.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      # NestedInstallerFiles
      $Installer['NestedInstallerFiles'] = @(7z.exe l -ba -slt $InstallerFile '*\bin\*.exe' '*\bin\*.bat' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } })
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
      }

      $ReleaseNotesUrl = "https://www.elastic.co/guide/en/elasticsearch/reference/$($this.CurrentState.Version.Split('.')[0..1] -join '.')/release-notes-$($this.CurrentState.Version).html"

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      # Remove edit buttons
      $Object2.SelectNodes("//a[@class='edit_me']").ForEach({ $_.Remove() })
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode("//*[@class='chapter']") | Get-TextContent | Format-Text
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
