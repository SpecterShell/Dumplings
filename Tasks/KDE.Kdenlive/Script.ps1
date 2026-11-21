$Object1 = Invoke-WebRequest -Uri 'https://kdenlive.org/download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('standalone') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'kdenlive-([\d\.]+(?:-\d+)?).*?\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://docs.kdenlive.org/more_information/whats_new.html'
      }
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://docs.kdenlive.org/zh_CN/more_information/whats_new.html'
      }

      $Object2 = Invoke-WebRequest -Uri 'https://docs.kdenlive.org/en/more_information/whats_new.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='versionadded' and contains(./p, '$($this.CurrentState.Version -replace '(\.0)+$')')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./p[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-RestMethod -Uri 'https://kdenlive.org/news/index.xml').Where({ $_.link.Contains($this.CurrentState.Version) }, 'First')

      if ($Object3) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $Object3[0].link
        }

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $Object3.SelectSingleNode('//article/div[@class="content-width"]').ChildNodes[0]; $Node -and -not ($Node.Attributes.Contains('id') -and $Node.Attributes['id'].Value -eq 'comments'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      foreach ($Installer in $this.CurrentState.Installer) {
        # InstallerSha256
        $Installer['InstallerSha256'] = (Invoke-RestMethod -Uri "$($Installer.InstallerUrl).sha256").Split()[0].ToUpper()
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
