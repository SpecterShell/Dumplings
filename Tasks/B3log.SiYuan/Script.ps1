$RepoOwner = 'siyuan-note'
$RepoName = 'siyuan'

$Object1 = (Invoke-WebRequest -Uri 'https://siyuan-sync.b3logfile.com/apis/siyuan/version').Content | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.ver

$Prefix = "https://github.com/${RepoOwner}/${RepoName}/releases/download/v$($this.CurrentState.Version)/"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object1.checksums.Keys.Where({ $_.EndsWith('.exe') -and $_.Contains('win') }, 'First')[0]
}

# ReleaseNotesUrl (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotesUrl'
  Value  = $Object1.release_en_US
}

# # ReleaseNotesUrl (zh-CN)
# $this.CurrentState.Locale += [ordered]@{
#   Locale = 'zh-CN'
#   Key    = 'ReleaseNotesUrl'
#   Value  = $ReleaseNotesUrlCN = $Object1.release_zh_CN
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases.atom").Where({ $_.id.EndsWith("v$($this.CurrentState.Version)") }, 'First')[0]

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.updated | Get-Date -AsUTC

      if ($Object2.content.'#text' -ne 'No content.') {
        $ReleaseNotesObject = $Object2.content.'#text' | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) { $Node }
        if ($ReleaseNotesNodes) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if (Test-Path -Path Env:\LD246_TOKEN) {
        $Object3 = Invoke-RestMethod -Uri $Object1.release_zh_CN.Replace('ld246.com', 'ld246.com/api/v2') -Headers @{ Authorization = $Env:LD246_TOKEN }

        $ReleaseNotesCNObject = $Object3.data.article.articleContent | ConvertFrom-Html
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('下载')); $Node = $Node.NextSibling) { $Node }
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

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
