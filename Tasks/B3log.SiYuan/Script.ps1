$RepoOwner = 'siyuan-note'
$RepoName = 'siyuan'

$Object1 = (Invoke-WebRequest -Uri 'https://siyuan-sync.b3logfile.com/apis/siyuan/version').Content | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.ver

$Prefix = "https://github.com/${RepoOwner}/${RepoName}/releases/download/v$($this.CurrentState.Version)/"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object1.checksums.Keys.Where({ $_.EndsWith('.exe') -and $_.Contains('win') })[0]
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

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-RestMethod -Uri "https://github.com/${RepoOwner}/${RepoName}/releases.atom").Where({ $_.id.EndsWith("v$($this.CurrentState.Version)") })[0]

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.updated | Get-Date -AsUTC

      if ($Object2.content.'#text' -ne 'No content.') {
        $ReleaseNotesObject = $Object2.content.'#text' | ConvertFrom-Html
        $ReleaseNotesNodes = [System.Collections.Generic.List[System.Object]]::new()
        for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) {
          $ReleaseNotesNodes.Add($Node)
        }
        if ($ReleaseNotesNodes) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    # try {
    #   $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN | ConvertFrom-Html

    #   # ReleaseNotes (zh-CN)
    #   $this.CurrentState.Locale += [ordered]@{
    #     Locale = 'zh-CN'
    #     Key    = 'ReleaseNotes'
    #     Value  = $Object3.SelectSingleNode('//article[contains(@class, "article-content")]') | Get-TextContent | Format-Text
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Logging($_, 'Warning')
    # }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
