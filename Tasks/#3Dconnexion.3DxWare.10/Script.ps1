$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['3DxWare10'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['3DxWare10'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'http://updatecheck.3dconnexion.com/AvailableSoftware_xml'

# Version
$this.CurrentState.Version = $Object1.AvailableSoftware.Software.Where({ $_.Id -eq '3DxWare64' }, 'First')[0].'_3DxWareVersion'

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $Object2 = Invoke-RestMethod -Uri ($Object1.AvailableSoftware.ProductNewsURL | Split-Uri -LeftPart Path)

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object2.News.ProductNews.en.Content | Format-Text
    }

    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object2.News.ProductNews.zh.Content | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotes   = $ReleaseNotes
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
