# en
$Object1 = Invoke-RestMethod -Uri 'https://updates.wavemetrics.com/Updaters/PHP/igor9updatecheck.php?language=en&wantBeta=0' | ConvertFrom-Ini
# ja
$Object2 = Invoke-RestMethod -Uri 'https://updates.wavemetrics.com/Updaters/PHP/igor9updatecheck.php?language=ja&wantBeta=0' | ConvertFrom-Ini

if ($Object1.Contains('IgorExtraInfo') -and -not $Object1.IgorExtraInfo.InfoKeys.Contains('Beta')) {
  $this.Log('Next major version available', 'Warning')
}

if ($Object1.main.Version -ne $Object2.main.Version) {
  $this.Log("en version: $($Object1.main.Version)")
  $this.Log("ja version: $($Object2.main.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.main.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = $Object1.main.InstallerPath
  ProductCode     = $Object1.main.ProductCode
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale        = 'ja'
  InstallerUrl           = $Object2.main.InstallerPath
  ProductCode            = $Object2.main.ProductCode
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "$($Object2.main.DisplayName) $($this.CurrentState.Version)"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.main.DisplayVersion, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://www.wavemetrics.com/news'
      }

      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      if ($ReleaseNotesUrlObject = $Object3.SelectSingleNode("//a[contains(./h2, 'Igor Pro $('{0}.{1}{2}' -f $this.CurrentState.Version.Split('.')) Released')]")) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesUrlObject.Attributes['href'].Value
        }

        $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object4.SelectSingleNode("//span[@class='body']") | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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

    if (-not $this.Status.Contains('New')) {
      $this.CurrentState = $this.LastState
      $this.CurrentState.Installer = @(
        [ordered]@{
          InstallerLocale = 'en'
          InstallerUrl    = "https://www.wavemetrics.net/Downloads/Win/setupIgor$('{0}.{1}{2}' -f $this.CurrentState.Version.Split('.')).exe"
        }
        [ordered]@{
          InstallerLocale = 'ja'
          InstallerUrl    = "https://www.wavemetrics.net/Downloads/Win/setupIgor$('{0}.{1}{2}' -f $this.CurrentState.Version.Split('.'))J.exe"
        }
      )
      $this.ResetMessage()
      $this.Config.IgnorePRCheck = $true
      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
    }
  }
}
