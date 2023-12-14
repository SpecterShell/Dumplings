$Prefix = 'https://logtalk.org/'

$Object = Invoke-WebRequest -Uri "${Prefix}download.html" | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//div[@class="article__content"]/p[1]/text()[1]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.SelectSingleNode('//h3[@id="windows"]/following-sibling::blockquote[1]/p/a[1]').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.SelectSingleNode('//div[@class="article__content"]/p[1]/text()[3]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/LogtalkDotOrg/logtalk3/master/RELEASE_NOTES.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h1[contains(text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h1'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://github.com/LogtalkDotOrg/logtalk3/blob/master/RELEASE_NOTES.md#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')

        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://github.com/LogtalkDotOrg/logtalk3/blob/master/RELEASE_NOTES.md'
        }
      }
    } catch {
      $Task.Logging($_, 'Warning')

      # ReleaseNotesUrl
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://github.com/LogtalkDotOrg/logtalk3/blob/master/RELEASE_NOTES.md'
      }
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
