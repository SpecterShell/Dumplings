$RepoOwner = 'royqh1979'
$RepoName = 'RedPanda-CPP'
$ProjectName = 'redpanda-cpp'
$ProjectPath = ''

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${ProjectPath}"
$Assets = $Object1 | Where-Object -FilterScript { $_.title.'#cdata-section' -match "^$([regex]::Escape($ProjectPath))/v?[\d\.]+/RedPanda.+Setup\.exe$" }

# Version
$this.CurrentState.Version = $Assets[0].title.'#cdata-section' -replace "^$([regex]::Escape($ProjectPath))/v?([\d\.]+)/.+", '$1'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.Contains('win32') -and $_.title.'#cdata-section'.Contains('MinGW') }, 'First')[0].link | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.Contains('win64') -and $_.title.'#cdata-section'.Contains('MinGW') }, 'First')[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets.Where({ $_.title.'#cdata-section'.Contains('win64') -and $_.title.'#cdata-section'.Contains('MinGW') }, 'First')[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
  (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://sourceforge.net/projects/${ProjectName}/files" + [regex]::Match($Assets[0].title.'#cdata-section', '^(/v?[\d\.]+/)').Groups[1].Value
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/${RepoOwner}/${RepoName}/master/NEWS.md" | ConvertFrom-Markdown).Html | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("./p[text()='Red Panda C++ Version $($this.CurrentState.Version)']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'p' -and $Node.InnerText.Contains('Red Panda C++ Version')); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-RestMethod -Uri "https://gitee.com/royqh1979/redpandacpp/raw/master/sources/main/content/blog/version.$($this.CurrentState.Version).md" | ConvertFrom-Markdown).Html | ConvertFrom-Html
      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("/h4[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-RestMethod -Uri 'https://gitee.com/royqh1979/redpandacpp/raw/public/blog/index.xml'

      $ReleaseNotesUrlCNObject = $Object4.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesUrlCNObject) {
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrlCNObject[0].link
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://royqh1979.gitee.io/redpandacpp/blog/'
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
