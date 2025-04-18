$ProjectName = 'redpanda-cpp'
$RootPath = ''
$PatternPath = 'v?(\d+(?:\.\d+)+)'
$PatternFilename = 'RedPanda.+Setup\.exe'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/${PatternPath}/${PatternFilename}$" })

# Installer
$Asset = $Assets.Where({ $_.title.'#cdata-section'.Contains('win32') -and $_.title.'#cdata-section'.Contains('MinGW') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Asset.link | ConvertTo-UnescapedUri
}
$VersionX86 = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value

$Asset = $Assets.Where({ $_.title.'#cdata-section'.Contains('win64') -and $_.title.'#cdata-section'.Contains('MinGW') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Asset.link | ConvertTo-UnescapedUri
}
$VersionX64 = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets.Where({ $_.title.'#cdata-section'.Contains('win64') -and $_.title.'#cdata-section'.Contains('MinGW') }, 'First')[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
  (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://sourceforge.net/projects/${ProjectName}/files" + [regex]::Match($Assets[0].title.'#cdata-section', '^(/v?[\d\.]+/)').Groups[1].Value
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/royqh1979/RedPanda-CPP/master/NEWS.md' | Convert-MarkdownToHtml

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
      $Object3 = Invoke-RestMethod -Uri "https://gitee.com/royqh1979/redpandacpp/raw/master/sources/main/content/blog/version.$($this.CurrentState.Version).md" | Convert-MarkdownToHtml

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
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'http://royqh.net/redpandacpp/blog/'
      }

      $Object4 = Invoke-RestMethod -Uri 'https://gitee.com/royqh1979/redpandacpp/raw/public/blog/index.xml'

      $ReleaseNotesUrlCNObject = $Object4.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesUrlCNObject) {
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrlCNObject[0].link
        }
      } else {
        $this.Log("No ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
