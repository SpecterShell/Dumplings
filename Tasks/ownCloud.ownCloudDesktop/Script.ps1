# x64
$Object1 = Invoke-RestMethod -Uri 'https://updates.owncloud.com/client/?version=2.10.1.7187&platform=win32&buildArch=x86_64&msi=true'
$Version1 = $Object1.owncloudclient.version
$InstallerUrl1 = $Object1.owncloudclient.downloadurl

# x86
$Object2 = Invoke-RestMethod -Uri 'https://updates.owncloud.com/client/?version=2.10.1.7187&platform=win32&buildArch=x86_64&msi=true'
$Version2 = $Object2.owncloudclient.version
$InstallerUrl2 = $Object2.owncloudclient.downloadurl

if ($Version1 -ne $Version2) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes += '检测到不同的版本'
} else {
  $Identical = $True
}

# Version
$Task.CurrentState.Version = $Version1

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl2
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $ReleaseNotesUrl = 'https://owncloud.com/changelog/desktop'
    $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[contains(@class, 'changelog')]/div/h1[contains(./a/text(), '$($Task.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\((\d{4}-\d{1,2}-\d{1,2})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]').NextSibling; $Node.Name -ne 'h1'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent
        }

        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl
        }

        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Identical }) {
    New-Manifest
  }
}
