$Object1 = Invoke-WebRequest -Uri 'https://support.bluestacks.com/hc/en-us/articles/4402611273485'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('amd64') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      # $this.CurrentState.Locale += [ordered]@{
      #   Key   = 'ReleaseNotesUrl'
      #   Value = 'https://support.bluestacks.com/hc/sections/360012290292'
      # }
      # ReleaseNotesUrl (zh-CN)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'zh-CN'
      #   Key    = 'ReleaseNotesUrl'
      #   Value  = 'https://support.bluestacks.com/hc/zh-tw/sections/360012290292'
      # }

      $Object3 = Invoke-WebRequest -Uri 'https://support.bluestacks.com/hc/en-us/sections/360012290292' | ConvertFrom-Html

      $ReleaseNotesUrlNode = $Object3.SelectSingleNode("//ul[contains(@class, 'article-list')]//a[contains(text(),'BlueStacks $($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl
        # $this.CurrentState.Locale += [ordered]@{
        #   Key   = 'ReleaseNotesUrl'
        #   Value = $ReleaseNotesUrl = Join-Uri 'https://support.bluestacks.com/' ($ReleaseNotesUrlNode.Attributes['href'].Value -replace '/en-us/', '/' -replace '(?<=articles/\d+)-.+')
        # }
        $ReleaseNotesUrl = Join-Uri 'https://support.bluestacks.com/' ($ReleaseNotesUrlNode.Attributes['href'].Value -replace '/en-us/', '/' -replace '(?<=articles/\d+)-.+')
        $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//div[@itemprop='articleBody']//*[(self::h3 or self::h4) and contains(., 'BlueStacks $($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h3', 'h4'); $Node = $Node.NextSibling) {
            if ($Node.InnerText.Contains('Released on') -and $Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
              # ReleaseTime
              $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
            } elseif (-not $Node.SelectSingleNode('.//a[@class="btn-download"]')) {
              $Node
            }
          }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }

        # ReleaseNotesUrl (zh-CN)
        # $this.CurrentState.Locale += [ordered]@{
        #   Locale = 'zh-CN'
        #   Key    = 'ReleaseNotesUrl'
        #   Value  = $ReleaseNotesUrlCN = Join-Uri 'https://support.bluestacks.com/' ($ReleaseNotesUrlNode.Attributes['href'].Value -replace '/en-us/', '/zh-tw/' -replace '(?<=articles/\d+)-.+')
        # }
        $ReleaseNotesUrlCN = Join-Uri 'https://support.bluestacks.com/' ($ReleaseNotesUrlNode.Attributes['href'].Value -replace '/en-us/', '/zh-tw/' -replace '(?<=articles/\d+)-.+')
        $Object5 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN | ConvertFrom-Html

        $ReleaseNotesCNTitleNode = $Object5.SelectSingleNode("//div[@itemprop='articleBody']//*[(self::h3 or self::h4) and contains(., 'BlueStacks $($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
        if ($ReleaseNotesCNTitleNode) {
          $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -notin @('h3', 'h4'); $Node = $Node.NextSibling) {
            if ($Node.InnerText.Contains('發布日期：') -and $Node.InnerText -match '(20\d{2}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*日)') {
              # ReleaseTime
              $this.CurrentState['ReleaseTime'] ??= $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
            } elseif (-not $Node.SelectSingleNode('.//a[@class="btn-download"]')) {
              $Node
            }
          }
          $ReleaseNotesCN = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
          $Object6 = Invoke-RestMethod -Uri 'https://api.zhconvert.org/convert' -Method Post -Body @{ text = $ReleaseNotesCN; converter = 'China' }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Object6.data.text
          }
          $this.Log('Powered by zhconvert API: https://zhconvert.org/')
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl, ReleaseNotes (en-US), ReleaseNotesUrl (zh-CN) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
