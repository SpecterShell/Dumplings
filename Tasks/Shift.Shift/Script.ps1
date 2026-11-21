$Object1 = Invoke-RestMethod -Uri 'https://updates.tryshift.com/appcast/stable/windows-x64.xml'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'v(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://supportv9.shift.com/hc/sections/25073721770516'
      }

      $Object2 = Invoke-WebRequest -Uri 'https://supportv9.shift.com/hc/en-us/sections/25073721770516' | ConvertFrom-Html

      $ReleaseNotesUrlNode = $Object2.SelectSingleNode("//a[contains(@class, 'card') and contains(./h2/text(), 'Shift $($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri 'https://supportv9.shift.com/' ($ReleaseNotesUrlNode.Attributes['href'].Value -replace '/en-us/', '/' -replace '(?<=articles/\d+)-.+')
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesUrlNode.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectSingleNode('//*[@itemprop="articleBody"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl, ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
