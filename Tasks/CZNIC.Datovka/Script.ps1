$Object1 = Invoke-WebRequest -Uri 'https://datovka.nic.cz/Version' | Read-ResponseContent

# Version
$this.CurrentState.Version = $Object1.Trim().TrimStart('_')

$Object2 = Invoke-RestMethod -Uri 'https://datovka.nic.cz/Packages' | ConvertFrom-StringData -Delimiter ','

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object2.WIN32_INST_EXE
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Object2.WIN32_INST_MSI
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object2.WIN64_INST_EXE
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object2.WIN64_INST_MSI
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://gitlab.nic.cz/datovka/datovka/-/raw/HEAD/ChangeLog').RawContentStream)

      while (-not $Object3.EndOfStream) {
        $String = $Object3.ReadLine()
        if ($String -match "^$([regex]::Escape($this.CurrentState.Version))") {
          if ($String -match '(20\d{2}-\d{1,2}-\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if (-not $Object3.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object3.EndOfStream) {
          $String = $Object3.ReadLine()
          if ($String -notmatch '^\d+(\.\d+)+ ') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (cs-CZ)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'cs-CZ'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $Prefix = 'https://www.datovka.cz/cs/'
      $Object4 = Invoke-WebRequest -Uri $Prefix
      if ($ReleaseNotesUrlLink = $Object4.Links.Where({ try { $_.href.Contains('datovka') -and $_.href.Contains($this.CurrentState.Version) } catch {} }, 'First')) {
        # ReleaseNotesUrl (cs-CZ)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'cs-CZ'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri $Prefix $ReleaseNotesUrlLink[0].href
        }

        $Object5 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
        # ReleaseNotes (cs-CZ)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'cs-CZ'
          Key    = 'ReleaseNotes'
          Value  = $Object5.SelectNodes('.//div[@role="main"]/p[@class="article-meta"]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (cs-CZ) and ReleaseNotesUrl (cs-CZ) for version $($this.CurrentState.Version)", 'Warning')
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
