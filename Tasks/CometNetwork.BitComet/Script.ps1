$Object1 = Invoke-RestMethod -Uri 'https://update.bitcomet.com/client/bitcomet/'

# Version
$this.CurrentState.Version = $Object1.BitComet.AutoUpdate.UpdateGroupList.LatestDownload.file1.'#text'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://download.bitcomet.com/achive/BitComet_$($this.CurrentState.Version)_setup.exe"
  ProductCode  = 'BitComet'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://download.bitcomet.com/achive/BitComet_$($this.CurrentState.Version)_setup.exe"
  ProductCode  = 'BitComet_x64'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.bitcomet.com/en/changelog' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'changelog')]/dl/dt[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'dt'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.bitcomet.com/cn/changelog' | ConvertFrom-Html

      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("//div[contains(@class, 'changelog')]/dl/dt[contains(text(), 'v$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -ne 'dt'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # Patch manifests
      # PublisherSupportUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PublisherSupportUrl'
        Value  = 'https://wiki.bitcomet.com/'
      }
      # PrivacyUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PrivacyUrl'
        Value  = 'https://wiki.bitcomet.com/privacy_policy'
      }
      # Documentations (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = 'FAQ'
            DocumentUrl   = 'https://wiki.bitcomet.com/frequently_asked_questions'
          }
        )
      }
      # PublisherSupportUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'PublisherSupportUrl'
        Value  = 'https://wiki-zh.bitcomet.com/'
      }
      # PrivacyUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'PrivacyUrl'
        Value  = 'https://wiki-zh.bitcomet.com/软件隐私政策'
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
