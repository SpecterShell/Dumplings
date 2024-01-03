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

  [bool]$MessageEnabled = $false
  [int[]]$MessageID = [int[]]@()

  WinGetTask([System.Collections.IDictionary]$Properties) {
    $this.Init($Properties)
  }

  WinGetTask([string]$Name, [string]$Path) {
    $this.Init(@{ Name = $Name; Path = $Path })
  }

  # Initialize tasks
  [void] Init([System.Collections.IDictionary]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }

    # Load config
    $this.ConfigPath ??= Join-Path $this.Path 'Config.yaml' -Resolve
    $this.Config ??= Get-Content -Path $this.ConfigPath -Raw | ConvertFrom-Yaml -Ordered

    # Load script
    $this.ScriptPath ??= Join-Path $this.Path 'Script.ps1' -Resolve

    # Load last state
    $LastStatePath ??= Join-Path $this.Path 'State.yaml'
    if (Test-Path -Path $LastStatePath) {
      $this.LastState = Get-Content -Path $LastStatePath -Raw | ConvertFrom-Yaml -Ordered
    }

    # Log notes
    if ($this.Config.Contains('Notes')) {
      $this.Log += $this.Config.Notes
    }
  }

  # Log with template, without specifying log level
  [void] Logging([string]$Message) {
    Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m ${Message}"
    $this.Log += $Message
    if ($this.MessageEnabled) {
      $this.Message()
    }
  }

  # Log with template, specifying log level
  [void] Logging([string]$Message, [LogLevel]$Level) {
    Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m ${Message}" -Level $Level
    if ($Level -ne 'Verbose') {
      $this.Log += $Message
      if ($this.MessageEnabled) {
        $this.Message()
      }
    }
  }

  # Invoke script
  [void] Invoke() {
    if ($this.Preference.NoSkip -or -not $this.Config.Skip) {
      try {
        Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Run!"
        & $this.ScriptPath | Out-Null
      } catch {
        $this.Logging("An error occured while running the script: ${_}", 'Error')
        $_ | Out-Host
      }
    } else {
      $this.Logging('Skipped', 'Info')
    }
  }

  # Compare current state with last state
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

  # Convert current state to Markdown message
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

    # Standard Markdown use two line endings as newline
    return $Message.ToString().Trim().ReplaceLineEndings("`n`n")
  }

  # Convert current state to Markdown message in Telegram standard
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
    if (-not $this.MessageEnabled) {
      $this.ToMarkdown() | Show-Markdown | Write-Log
      $this.MessageEnabled = $true
    }
    if (-not $this.Preference.NoMessage) {
      try {
        $Response = Send-TelegramMessage -Message $this.ToTelegramMarkdown() -MessageID $this.MessageID
        $this.MessageID = $Response
      } catch {
        Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Failed to send default message: ${_}" -Level Error
        $this.Log += $_.ToString()
      }
    } else {
      Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Skip sending default message" -Level Info
    }
  }

  # Send custom message to Telegram
  [void] Message([string]$Message) {
    $Message | Write-Log
    if (-not $this.Preference.NoMessage) {
      try {
        Send-TelegramMessage -Message ($Message | ConvertTo-TelegramEscapedText) | Out-Null
      } catch {
        Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Failed to send custom message: ${_}" -Level Error
        $this.Log += $_.ToString()
      }
    } else {
      Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Skip sending custom message" -Level Info
    }
  }

  # Generate and upload manifests to origin repository and create pull request in upstream repository
  [void] Submit() {
    if (-not $this.Preference.NoSubmit) {
      $this.Logging('Submitting manifests', 'Info')

      $UpstreamOwner = 'microsoft'
      $UpstreamRepo = 'winget-pkgs'
      $UpstreamBranch = 'master'
      $OriginOwner = 'SpecterShell'
      $OriginRepo = 'winget-pkgs'

      $PackageIdentifier = $this.Config.Identifier
      $PackageVersion = $this.CurrentState['RealVersion'] ?? $this.CurrentState['Version']
      if (Test-Path Env:\GITHUB_WORKSPACE) {
        $ManifestsFolder = Join-Path $Env:GITHUB_WORKSPACE $UpstreamRepo 'manifests' -Resolve
      } else {
        $ManifestsFolder = Join-Path $PSScriptRoot '..' '..' $UpstreamRepo 'manifests' -Resolve
      }
      $OutFolder = (New-Item -Path $Global:LocalCache -Name $PackageIdentifier -ItemType Directory -Force).FullName

      # Check if there are existing pull requests in the upstream repository
      $this.Logging('Checking existing pull requests', 'Verbose')
      $PullRequests = Invoke-GitHubApi -Uri "https://api.github.com/search/issues?q=repo%3A${UpstreamOwner}%2F${UpstreamRepo}%20is%3Apr%20$($PackageIdentifier.Replace('.', '%2F'))%2F${PackageVersion}%20in%3Apath&per_page=1"
      if ($PullRequests.total_count -gt 0) {
        if (-not ($this.Preference.Contains('NoCheck') -and $this.Preference.NoCheck) -and -not ($this.Config.Contains('IgnorePRCheck') -and $this.Config.IgnorePRCheck)) {
          $this.Logging("Existing pull request found: $($PullRequests.items[0].title) - $($PullRequests.items[0].html_url)", 'Error')
          return
        } else {
          $this.Logging("Existing pull request found: $($PullRequests.items[0].title) - $($PullRequests.items[0].html_url)", 'Warning')
        }
      }

      # Use YamlCreate to create manifests
      $this.Logging('Creating manifests', 'Verbose')
      try {
        $Parameters = @{
          PackageIdentifier = $PackageIdentifier
          PackageVersion    = $PackageVersion
          PackageInstallers = $this.CurrentState.Installer
          Locales           = $this.CurrentState.Locale
          ManifestsFolder   = $ManifestsFolder
          OutFolder         = $OutFolder
        }
        if ($this.CurrentState.ReleaseTime) {
          if ($this.CurrentState.ReleaseTime -is [datetime]) {
            $Parameters.PackageReleaseDate = $this.CurrentState.ReleaseTime.ToUniversalTime().ToString('yyyy-MM-dd')
          } else {
            $Parameters.PackageReleaseDate = $this.CurrentState.ReleaseTime | Get-Date -Format 'yyyy-MM-dd'
          }
        }
        & (Join-Path $PSScriptRoot '..' 'Assets' 'YamlCreate.ps1') @Parameters
      } catch {
        $this.Logging("Failed to create manifests: ${_}", 'Error')
        $_ | Out-Host
        return
      }
      $this.Logging('Manifests created', 'Verbose')

      # Use WinGet client to validate the manifests generated in the last step
      $this.Logging('Validating manifests', 'Verbose')
      if (-not (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
        $this.Logging('Could not find WinGet client', 'Error')
        return
      }
      $WinGetOutput = ''
      winget validate $OutFolder | Out-String -OutVariable 'WinGetOutput'
      if ($LASTEXITCODE -notin @(0, -1978335192)) {
        $this.Logging("Validation failed: `n${WinGetOutput}", 'Error')
        return
      }
      $this.Logging('Validation passed', 'Verbose')

      # Upload new manifests, remove old ones if needed, and commit in the origin repository
      $this.Logging('Uploading manifests and committing', 'Verbose')
      try {
        $NewBranchName = "${PackageIdentifier}-${PackageVersion}-$((New-Guid).Guid.Split('-')[-1])" -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
        $NewCommitName = "New version: ${PackageIdentifier} version ${PackageVersion}"

        $UpstreamSha = $Global:LocalStorage['UpstreamSha'] ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/git/ref/heads/${UpstreamBranch}").object.sha
        $NewBranchSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs" -Method Post -Body @{
            ref = "refs/heads/${NewBranchName}"
            sha = $UpstreamSha
          }
        ).object.sha

        # Upload new manifests and obtain their SHA
        $NewFileNameSha = @()
        Get-ChildItem -Path $OutFolder -Include '*.yaml' -Recurse -File | ForEach-Object -Process {
          $NewFileNameSha += @{
            Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${PackageVersion}/$($_.Name)"
            Sha  = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/blobs" -Method Post -Body @{
                content  = Get-Content -Path $_ -Raw -Encoding utf8NoBOM
                encoding = 'utf-8'
              }
            ).sha
          }
        }

        # Find the latest version of manifests to remove in the upstream repo, if needed
        if ($this.Config.Contains('RemoveLastVersion') -and $this.Config.RemoveLastVersion) {
          $LastManifestVersion = Get-ChildItem -Path "${ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\*\${PackageIdentifier}.yaml" -File |
            Split-Path -Parent | Split-Path -Leaf |
            Sort-Object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } -Culture en-US | Select-Object -Last 1
          if ($LastManifestVersion -ne $PackageVersion) {
            $this.Logging("Manifests for last version ${LastManifestVersion} will be removed", 'Info')
            Get-ChildItem -Path "${ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\${LastManifestVersion}\*.yaml" -File | ForEach-Object -Process {
              $NewFileNameSha += @{
                Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${LastManifestVersion}/$($_.Name)"
                Sha  = $null
              }
            }
          } else {
            $this.Logging("Manifests for last version ${LastManifestVersion} will be overrided", 'Info')
          }
        }

        # Build a new tree with changes of creating new manifests and removing old manifests based on the branch, obtaining the SHA of the new tree
        $TreeSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/trees" -Method Post -Body @{
            tree      = @($NewFileNameSha | ForEach-Object -Process {
                @{
                  path = $_.Path
                  mode = '100644'
                  type = 'blob'
                  sha  = $_.Sha
                }
              })
            base_tree = $NewBranchSha
          }).sha

        # Commit with the new tree, obtaining the SHA of the commit
        $CommitSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/commits" -Method Post -Body @{
            tree    = $TreeSha
            message = $NewCommitName
            parents = @($NewBranchSha)
          }
        ).sha

        # Move the HEAD of the branch to the commit
        Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/${NewBranchName}" -Method Post -Body @{
          sha = $CommitSha
        } | Out-Null
      } catch {
        $this.Logging("Failed to upload manifests or commit: ${_}", 'Error')
        $_ | Out-Host
        return
      }
      $this.Logging('Manifests uploaded and committed', 'Verbose')

      # Create pull request in the upstream repository
      $this.Logging('Creating pull request', 'Verbose')
      try {
        if (Test-Path Env:\CI) {
          $NewPRBody = "This pull request is automatically generated by [🥟 Dumplings](https://github.com/SpecterShell/Dumplings) in [#${Env:GITHUB_RUN_NUMBER}](https://github.com/${OriginOwner}/Dumplings/actions/runs/${Env:GITHUB_RUN_ID})"
        } else {
          $NewPRBody = 'This pull request is automatically generated by [🥟 Dumplings](https://github.com/SpecterShell/Dumplings)'
        }
        $NewPRResponse = Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/pulls" -Method Post -Body @{
          title = $NewCommitName
          body  = $NewPRBody
          head  = "${OriginOwner}:${NewBranchName}"
          base  = 'master'
        }
      } catch {
        $this.Logging("Failed to create pull request: ${_}", 'Error')
        $_ | Out-Host
        return
      }
      $this.Logging("Pull request created: $($NewPRResponse.html_url)", 'Info')
    } else {
      $this.Logging('Skip submitting manifests', 'Info')
    }
  }
}
