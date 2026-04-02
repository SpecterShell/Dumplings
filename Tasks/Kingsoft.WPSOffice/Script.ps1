$Object1 = (Invoke-RestMethod -Uri 'https://params.wps.com/api/map/web/newwpsapk?pttoken=newwinpackages').staticjs.website.wpsnewpackages.downloads | ConvertFrom-Base64 | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.'500.1001'.downloadurl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.wps.com/whatsnew/pc/'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://api-academy.wps.com/official/whatsnew?platform=pc'

      $ReleaseNotesListObject = $Object2.data.Where({ $_.post_excerpt.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesListObject) {
        $Object3 = Invoke-RestMethod -Uri "https://api-academy.wps.com/official/post/detail?slug=$($ReleaseNotesListObject[0].more.slug)"
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3.data.published_time | ConvertFrom-UnixTimeSeconds

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.data.post_content | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://www.wps.com/whatsnew$($ReleaseNotesListObject[0].more.slug)/"
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
