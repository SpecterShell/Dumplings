enum LogLevel {
  Verbose
  Log
  Info
  Warning
  Error
}

class WinGetTask {
  [ValidateNotNullOrEmpty()][string]$Name

  [ValidateNotNullOrEmpty()][string]$Path
  [string]$ConfigPath
  [string]$ScriptPath

  [System.Collections.IDictionary]$Config = [ordered]@{}
  [System.Collections.IDictionary]$Preference = [ordered]@{}
  [string[]]$Log = [string[]]@()

  [System.Collections.IDictionary]$LastState = [ordered]@{}
  [System.Collections.IDictionary]$CurrentState = [ordered]@{
    Installer = @()
    Locale    = @()
  }

  WinGetTask([System.Collections.IDictionary]$Properties) {
    $this.Init($Properties)
  }

  WinGetTask([string]$Name, [string]$Path) {
    $this.Init(@{ Name = $Name; Path = $Path })
  }

  [void] Init([System.Collections.IDictionary]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }

    # Load config
    $this.ConfigPath ??= Join-Path $this.Path 'Config.yaml' -Resolve
    $this.Config ??= Get-Content -Path $this.ConfigPath -Raw | ConvertFrom-Yaml

    # Test script
    $this.ScriptPath ??= Join-Path $this.Path 'Script.ps1' -Resolve

    # Load last state
    $LastStatePath ??= Join-Path $this.Path 'State.yaml'
    if (Test-Path -Path $LastStatePath) {
      $this.LastState = Get-Content -Path $LastStatePath -Raw | ConvertFrom-Yaml
    }

    # Log notes
    if ($this.Config.Contains('Notes')) {
      $this.Log += $this.Config.Notes
    }
  }

  [void] Logging([string]$Message) {
    Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m ${Message}"
    $this.Log += $Message
  }

  [void] Logging([string]$Message, [LogLevel]$Level) {
    Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m ${Message}" -Level $Level
    $this.Log += $Message
  }

  [void] Invoke() {
    if ($this.Preference.NoSkip -or -not $this.Config.Skip) {
      try {
        Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Run!"
        & $this.ScriptPath | Out-Null
      } catch {
        $this.Logging('An error occured while running the script:', 'Error')
        $_ | Out-Host
      }
    } else {
      $this.Logging('Skipped', 'Info')
    }
  }

  # Compare version and installers between states
  [int] Check() {
    if (-not $this.Preference.Contains('NoCheck') -or -not $this.Preference.NoCheck) {
      if (-not $this.CurrentState.Contains('Version')) {
        throw "WinGetTask $($this.Name): The property Version in the current state does not exist"
      } elseif ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
        throw "WinGetTask $($this.Name): The property Version in the current state is empty or invalid"
      }

      if (-not $this.Config.Contains('CheckVersionOnly') -or -not $this.Config.CheckVersionOnly) {
        if (-not $this.CurrentState.Installer.InstallerUrl) {
          throw "WinGetTask $($this.Name): The property InstallerUrl in the current state is undefined or invalid"
        }
      }

      if (-not $this.LastState.Contains('Version')) {
        return 1
      }

      switch (Compare-Version -ReferenceVersion $this.LastState.Version -DifferenceVersion $this.CurrentState.Version) {
        1 {
          $this.Logging("Updated: $($this.LastState.Version) -> $($this.CurrentState.Version)", 'Info')
          return 3
        }
        0 {
          if (-not $this.Config.Contains('CheckVersionOnly') -or -not $this.Config.CheckVersionOnly) {
            if (Compare-Object -ReferenceObject $this.LastState -DifferenceObject $this.CurrentState -Property { $_.Installer.InstallerUrl }) {
              $this.Logging('Installers changed', 'Info')
              return 2
            }
          }
        }
        -1 {
          $this.Logging("Rollbacked: $($this.LastState.Version) -> $($this.CurrentState.Version)", 'Warning')
        }
      }

      return 0
    } else {
      $this.Logging('Skip checking states', 'Info')
      return 3
    }
  }

  # Write the state to a log file and a state file in YAML format
  [void] Write() {
    if (-not $this.Preference.NoWrite) {
      # Writing current state to log file
      $LogPath = Join-Path $this.Path "Log_$(Get-Date -AsUTC -Format "yyyyMMdd'T'HHmmss'Z'").yaml"
      Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Writing current state to log file ${LogPath}"
      $this.CurrentState | ConvertTo-Yaml -OutFile $LogPath -Force

      # Writing current state to state file
      $StatePath = Join-Path $this.Path 'State.yaml'
      Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Writing current state to state file ${StatePath}"
      Copy-Item -Path $LogPath -Destination $StatePath -Force
    } else {
      $this.Logging('Skip writing states to manifests', 'Info')
    }
  }

  [string] ToMarkdown() {
    $Message = [System.Text.StringBuilder]::new(2048)

    # Identifier
    if ($this.Config.Contains('Identifier') -and -not [string]::IsNullOrWhiteSpace($this.Config.Identifier)) {
      $Message.Append("*$($this.Config.Identifier)*`n")
    }

    # RealVersion / Version
    if ($this.CurrentState.Contains('RealVersion') -and -not [string]::IsNullOrWhiteSpace($this.CurrentState.RealVersion)) {
      $Message.Append("`n*版本:* $($this.CurrentState.RealVersion)")
    } elseif ($this.CurrentState.Contains('Version') -and -not [string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
      $Message.Append("`n*版本:* $($this.CurrentState.Version)")
    }

    # Installer
    $Message.Append("`n*地址:*`n`n$($this.CurrentState.Installer.InstallerUrl -join "`n")")

    # ReleaseTime
    if ($this.CurrentState.Contains('ReleaseTime')) {
      if ($this.CurrentState.ReleaseTime -is [datetime]) {
        $Message.Append("`n*日期:* $($this.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'))")
      } elseif (-not [string]::IsNullOrWhiteSpace($this.CurrentState.ReleaseTime)) {
        $Message.Append("`n*日期:* $($this.CurrentState.ReleaseTime)")
      }
    }
    # Locale
    foreach ($Entry in $this.CurrentState.Locale) {
      if ($Entry.Contains('Key') -and $Entry.Contains('Value') -and -not [string]::IsNullOrWhiteSpace($Entry.Key)) {
        $Key = $null
        switch ($Entry.Key) {
          'ReleaseNotes' { $Key = '说明' }
          'ReleaseNotesUrl' { $Key = '链接' }
          Default { $Key = $Entry.Key }
        }
        if ($Entry.Contains('Locale')) {
          $Key += " ($($Entry.Locale))"
        }
        $Message.Append("`n*${Key}:* `n$($Entry.Value)")
      }
    }

    # Log
    if ($this.Log.Count -gt 0) {
      $Message.Append("`n`n*日志:* `n$($this.Log -join "`n")")
    }

    return $Message.ToString().Trim().ReplaceLineEndings("`n`n")
  }

  [string] ToTelegramMarkdown() {
    $Message = [System.Text.StringBuilder]::new(2048)

    # Identifier
    if ($this.Config.Contains('Identifier') -and -not [string]::IsNullOrWhiteSpace($this.Config.Identifier)) {
      $Message.Append("*$($this.Config.Identifier | ConvertTo-TelegramEscapedText)*`n")
    }

    # RealVersion / Version
    if ($this.CurrentState.Contains('RealVersion') -and -not [string]::IsNullOrWhiteSpace($this.CurrentState.RealVersion)) {
      $Message.Append("`n*版本:* ``$(($this.CurrentState.RealVersion) | ConvertTo-TelegramEscapedCode)``")
    } elseif ($this.CurrentState.Contains('Version') -and -not [string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
      $Message.Append("`n*版本:* ``$(($this.CurrentState.Version) | ConvertTo-TelegramEscapedCode)``")
    }

    # Installer
    $Delimiter = '`' + "`n" + '`'
    $Message.Append("`n*地址:*`n``$(($this.CurrentState.Installer.InstallerUrl | ConvertTo-TelegramEscapedCode) -join $Delimiter)``")

    # ReleaseTime
    if ($this.CurrentState.Contains('ReleaseTime')) {
      if ($this.CurrentState.ReleaseTime -is [datetime]) {
        $Message.Append("`n*日期:* ``$($this.CurrentState.ReleaseTime.ToString('yyyy-MM-dd') | ConvertTo-TelegramEscapedCode)``")
      } elseif (-not [string]::IsNullOrWhiteSpace($this.CurrentState.ReleaseTime)) {
        $Message.Append("`n*日期:* ``$($this.CurrentState.ReleaseTime | ConvertTo-TelegramEscapedCode)``")
      }
    }
    # Locale
    foreach ($Entry in $this.CurrentState.Locale) {
      if ($Entry.Contains('Key') -and $Entry.Contains('Value') -and -not [string]::IsNullOrWhiteSpace($Entry.Key)) {
        $Key = $null
        switch ($Entry.Key) {
          'ReleaseNotes' { $Key = '说明' }
          'ReleaseNotesUrl' { $Key = '链接' }
          Default { $Key = $Entry.Key }
        }
        if ($Entry.Contains('Locale')) {
          $Key += " ($($Entry.Locale))"
        }
        $Message.Append("`n*$($Key | ConvertTo-TelegramEscapedText):* `n$($Entry.Value | ConvertTo-TelegramEscapedText)")
      }
    }

    # Log
    if ($this.Log.Count -gt 0) {
      $Message.Append("`n`n*日志:* `n$($this.Log -join "`n" | ConvertTo-TelegramEscapedText)")
    }

    return $Message.ToString().Trim()
  }

  # Send default message to Telegram
  [void] Message() {
    $this.ToMarkdown() | Show-Markdown | Write-Log
    if (-not $this.Preference.NoMessage) {
      Send-TelegramMessage -Message $this.ToTelegramMarkdown()
    } else {
      $this.Logging('Skip sending messages', 'Info')
    }
  }

  # Send specified message to Telegram
  [void] Message([string]$Message) {
    $Message | Write-Log
    if (-not $this.Preference.NoMessage) {
      Send-TelegramMessage -Message ($Message | ConvertTo-TelegramEscapedText)
    } else {
      $this.Logging('Skip sending messages', 'Info')
    }
  }

  [void] Submit() {
    if (-not $this.Preference.NoSubmit) {
      $UpstreamOwner = 'microsoft'
      $UpstreamRepo = 'winget-pkgs'
      $UpstreamBranch = 'master'
      $OriginOwner = 'SpecterShell'
      $OriginRepo = 'winget-pkgs'

      $this.Logging('Checking existing PRs', 'Verbose')
      if (-not $this.Config.Contains('SkipPRCheck') -or -not $this.Config.SkipPRCheck) {
        $PullRequests = Invoke-GitHubApi -Uri "https://api.github.com/search/issues?q=repo%3A${UpstreamOwner}%2F${UpstreamRepo}%20is%3Apr%20$($this.Config.Identifier -replace '\.', '%2F'))%2F$($this.CurrentState.Version)%20in%3Apath&per_page=1"
        if ($PullRequests.total_count -gt 0) {
          $this.Logging("Existing PR found: $($PullRequests.items[0].html_url) - $($PullRequests.items[0].title)", 'Error')
          return
        }
      } else {
        $this.Logging('Skip checking existing PR', 'Info')
      }

      $this.Logging('Creating manifests', 'Verbose')
      try {
        $Parameters = @{
          PackageIdentifier = $this.Config.Identifier
          PackageVersion    = $this.CurrentState['RealVersion'] ?? $this.CurrentState['Version']
          PackageInstallers = $this.CurrentState.Installer
          OutFolder         = (New-Item -Path $Global:LocalCache -Name (New-Guid).Guid -ItemType Directory -Force).FullName
        }
        if (Test-Path Env:\GITHUB_WORKSPACE) {
          $Parameters.ManifestsFolder = Join-Path $Env:GITHUB_WORKSPACE 'winget-pkgs' 'manifests' -Resolve
        } else {
          $Parameters.ManifestsFolder = Join-Path $PSScriptRoot '..' '..' 'winget-pkgs' 'manifests' -Resolve
        }
        if ($this.CurrentState.Locale.Count -gt 0) {
          $Parameters.Locales = $this.CurrentState.Locale
        }
        if ($this.CurrentState.ReleaseTime) {
          if ($this.CurrentState.ReleaseTime -is [datetime]) {
            $Parameters.PackageReleaseDate = $this.CurrentState.ReleaseTime.ToUniversalTime().ToString('yyyy-MM-dd')
          } else {
            $Parameters.PackageReleaseDate = $this.CurrentState.ReleaseTime | Get-Date -Format 'yyyy-MM-dd'
          }
        }
        & (Join-Path $PSScriptRoot '..' 'Assets' 'YamlCreate.ps1') @Parameters
        $this.Logging('Manifests created', 'Verbose')
      } catch {
        $this.Logging('Failed to create manifests', 'Error')
        $_ | Out-Host
        return
      }

      if (-not (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
        $this.Logging('WinGet not found', 'Error')
        return
      }

      $this.Logging('Validating manifests', 'Verbose')
      $WinGetOutput = ''
      winget validate $Parameters.OutFolder | Out-String -OutVariable 'WinGetOutput'
      if ($LASTEXITCODE -notin @(0, -1978335192)) {
        $this.Logging("Validation failed: `n${WinGetOutput}", 'Error')
        return
      }
      $this.Logging('Validation passed', 'Verbose')

      $this.Logging('Uploading manifests and committing', 'Verbose')
      try {
        $NewBranchName = "$($this.Config.Identifier)-$($this.CurrentState.Version)-$((New-Guid).Guid.Split('-')[-1])" -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
        $NewCommitName = "New version: $($this.Config.Identifier) version $($this.CurrentState.Version)"

        $Global:LocalStorage['UpstreamSha'] ??= (Invoke-RestMethod -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/git/ref/heads/${UpstreamBranch}").object.sha

        $NewBranchSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs" -Method Post -Body @{
            ref = 'refs/heads/' + $NewBranchName
            sha = $Global:LocalStorage.UpstreamSha
          }
        ).object.sha

        $ManifestsNameSha = Get-ChildItem -Path $Parameters.OutFolder -Include '*.yaml' -Recurse -File | ForEach-Object -Process {
          $this.Logging("Uploading $($_.Name)", 'Verbose')
          @{
            name = $_.Name
            sha  = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/blobs" -Method Post -Body @{
                content  = Get-Content -Path $_ -Raw -Encoding utf8NoBOM
                encoding = 'utf-8'
              }
            ).sha
          }
        }

        $TreeSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/trees" -Method Post -Body @{
            tree      = @($ManifestsNameSha | ForEach-Object -Process {
                @{
                  path = "manifests/$($this.Config.Identifier.ToLower().Chars(0))/$($this.Config.Identifier.Replace('.', '/'))/$($this.CurrentState.Version)/$($_.name)"
                  mode = '100644'
                  type = 'blob'
                  sha  = $_.sha
                }
              })
            base_tree = $NewBranchSha
          }).sha

        $CommitSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/commits" -Method Post -Body @{
            tree    = $TreeSha
            message = $NewCommitName
            parents = @($NewBranchSha)
          }
        ).sha

        Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/${NewBranchName}" -Method Post -Body @{
          sha = $CommitSha
        } | Out-Null
      } catch {
        $this.Logging('Failed to upload manifests or commit', 'Error')
        $_ | Out-Host
        return
      }
      $this.Logging('Manifests uploaded and committed', 'Verbose')

      $this.Logging('Creating PR', 'Verbose')
      try {
        $NewPRResponse = Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/pulls" -Method Post -Body @{
          title = $NewCommitName
          body  = 'This PR is automatically generated by 🥟 Dumplings'
          head  = "${OriginOwner}:${NewBranchName}"
          base  = 'master'
        }
        $this.Logging("PR created: $($NewPRResponse.html_url)", 'Verbose')
      } catch {
        $this.Logging('Failed to create PR', 'Error')
        $_ | Out-Host
        return
      }
    } else {
      $this.Logging('Skip submitting manifests', 'Info')
    }
  }
}
