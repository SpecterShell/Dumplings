$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/alexazhou/TogoSpace/releases/latest'

# Version
$this.CurrentState.Version = $Version = $Object1.tag_name -replace '^v'

# Tauri NSIS in currentUser mode. The release also carries the macOS DMGs, so only the Windows
# x64 setup is packaged; the app is named Togobot while the repository is named TogoSpace.
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name -eq "Togobot_${Version}_x64-setup.exe" }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      # The same change list is published twice, Chinese first and English second, separated by a
      # horizontal rule. Split on the rule and let the script of each block pick its locale.
      $Groups = @()
      $Current = New-Object System.Collections.ArrayList
      foreach ($Node in $ReleaseNotesObject.ChildNodes) {
        if ($Node.Name -eq 'hr') {
          if ($Current.Count) { $Groups += ,$Current.ToArray(); $Current = New-Object System.Collections.ArrayList }
          continue
        }
        if ($Node.Name -eq '#text') { continue }
        [void]$Current.Add($Node)
      }
      if ($Current.Count) { $Groups += ,$Current.ToArray() }

      foreach ($Group in $Groups) {
        $Text = $Group | Get-TextContent | Format-Text
        if ($Text -match "[${CJK}]") {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Text
          }
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $Text
          }
        }
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
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
