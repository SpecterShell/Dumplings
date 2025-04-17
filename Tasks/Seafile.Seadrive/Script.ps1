# Global
$Object1 = Invoke-WebRequest -Uri 'https://www.seafile.com/en/download/'
# China
$Object2 = Invoke-WebRequest -Uri 'https://www.seafile.com/download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links.Where({ try { $_.href -match 'seadrive-\d+(?:\.\d+)+-en+\.msi$' } catch {} }, 'First')[0].href
}
$Version = [regex]::Match($InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $InstallerUrlCN = $Object2.Links.Where({ try { $_.href -match 'seadrive-\d+(?:\.\d+)+\.msi$' } catch {} }, 'First')[0].href
}
$VersionCN = [regex]::Match($InstallerUrlCN, '(\d+(\.\d+)+)').Groups[1].Value

if ($Version -ne $VersionCN) {
  $this.Log("Global version: ${Version}")
  $this.Log("China version: ${VersionCN}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Version

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/haiwen/seafile-admin-docs/HEAD/manual/changelog/drive-client-changelog.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h3[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        if ($ReleaseNotesTitleNode.InnerText -match '(20\d{2}/\d{1,2}/\d{1,2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h2', 'h3'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
