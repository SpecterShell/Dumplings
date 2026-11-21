$Object1 = (Invoke-RestMethod -Uri 'https://services.intralinks.com/ILClient/autoupdate/manifest.xml').UpdateData.Application_Hierarchy.ApplicationInfo.Where({ $_.ApplicationType -eq 'WORKBENCH' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.UpdateVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.UpdateSourceUrlMSI
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://services.intralinks.com/ILClient/autoupdate/releaseNotes_ILC-WSB.xml' | Read-ResponseContent | ConvertFrom-Xml
      if ($ReleaseNotesObject = $Object2.ReleaseNotes.Releases.Release.Where({ $_.Version -eq $this.CurrentState.Version }, 'First')) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].Notes.Where({ $_.Locale -eq 'en-US' }, 'First')[0].Note | ConvertTo-UnorderedList | Format-Text
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].Notes.Where({ $_.Locale -eq 'zh-CHS' }, 'First')[0].Note | ConvertTo-UnorderedList | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
