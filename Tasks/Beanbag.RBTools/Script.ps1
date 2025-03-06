$Prefix = 'https://downloads.reviewboard.org/releases/RBTools/'

$Object1 = Invoke-WebRequest -Uri $Prefix

# Include alphanums in regex just in case of weird folder name like "5.x"
$Prefix += $Object1.Links.Where({ try { $_.href -match '^(\d+(?:\.[0-9a-zA-Z]+)+)/' } catch {} }, 'Last')[0].href

$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
# Assume the latest version is the first one
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix ($InstallerName = $Object2.Links.Where({ try { $_.href.Contains('.exe#') } catch {} }, 'First')[0].href) | Split-Uri -LeftPart Path
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.reviewboard.org/docs/releasenotes/rbtools/'
      }

      $Object2 = Invoke-WebRequest -Uri "https://www.reviewboard.org/docs/releasenotes/rbtools/$($this.CurrentState.Version)/" | ConvertFrom-Html

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.reviewboard.org/docs/releasenotes/rbtools/$($this.CurrentState.Version)/"
      }

      # Remove link marks
      $Object2.SelectNodes('//article/section//a[@class="headerlink"]').ForEach({ $_.Remove() })

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//article/section/section[not(@id="installation")]').SelectNodes('.|./following-sibling::node()') | Get-TextContent | Format-Text
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//article/section').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
