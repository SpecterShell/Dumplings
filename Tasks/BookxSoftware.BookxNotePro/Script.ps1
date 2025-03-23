$Object1 = Invoke-WebRequest -Uri 'http://www.bookxnote.com/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@class="carousel-centered"]/div/p[2]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $InstallerUrl1 = $Object1.SelectSingleNode('//*[@class="carousel-centered"]/a[contains(./text(), "Win32")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = (Split-Path -Path $InstallerUrl1 -Leaf) -creplace '\.zip$', '.exe'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $InstallerUrl2 = $Object1.SelectSingleNode('//*[@class="carousel-centered"]/a[contains(./text(), "Win64")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = (Split-Path -Path $InstallerUrl2 -Leaf) -creplace '\.zip$', '.exe'
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@class="carousel-centered"]/div/p[2]').InnerText,
        '(\d{4}年\d{1,2}月\d{1,2}日)'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
      $InstallerFile2 = $InstallerFile | Expand-TempArchive | Join-Path -ChildPath $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
      $InstallerFile2Extracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 'readme.txt' | Out-Host
      $ReleaseNotesFile = Join-Path $InstallerFile2Extracted 'readme.txt'
      $ReleaseNotesObject = [System.IO.StreamReader]::new($ReleaseNotesFile, [System.Text.Encoding]::GetEncoding('gb18030'))

      while (-not $ReleaseNotesObject.EndOfStream) {
        if ($ReleaseNotesObject.ReadLine().StartsWith("V$($this.CurrentState.Version)")) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            $ReleaseNotesObject.ReadLine(),
            [string[]]@(
              'yyyyMMdd',
              'yyyy-MM-dd'
            ),
            (Get-Culture -Name 'en-US'),
            [System.Globalization.DateTimeStyles]::None
          ).ToString('yyyy-MM-dd')
          break
        }
      }
      if (-not $ReleaseNotesObject.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $ReleaseNotesObject.EndOfStream) {
          $String = $ReleaseNotesObject.ReadLine()
          if ($String -notmatch '^V\d+\.\d+\.\d+\.\d+') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    } finally {
      try {
        if ((Test-Path -Path Variable:\ReleaseNotesObject) -and $ReleaseNotesObject) {
          $ReleaseNotesObject.Close()
        }
        Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
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
