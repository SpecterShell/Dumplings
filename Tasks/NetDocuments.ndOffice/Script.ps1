$Prefix = 'https://apps.netdocuments.com/apps/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}appVersions.xml"
$Object2 = $Object1.GetElementsByTagName('InstallerPackageInfo').Where({ $_.id -eq 'ndOffice' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.url "ndOfficeSetup-$($this.CurrentState.Version.Split('.')[0..2] -join '.').zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://support.netdocuments.com/s/topic/0TOQj0000007YPyOAM/new-releases'
      }

      $Object3 = Invoke-RestMethod -Uri 'https://support.netdocuments.com/s/sfsites/aura' -Method Post -Body @{
        message        = @{
          actions = @(
            @{
              descriptor = 'serviceComponent://ui.self.service.components.controller.TopicArticleListDataProviderController/ACTION$loadMoreArticles'
              params     = @{
                limit    = 20
                offset   = 0
                topicIds = @('0TOQj0000007YPyOAM')
              }
            }
          )
        } | ConvertTo-Json -Compress -Depth 10
        'aura.context' = @{
          app = 'siteforce:communityApp'
        } | ConvertTo-Json -Compress -Depth 10
        'aura.pageURI' = '/s/topic/0TOQj0000007YPyOAM/new-releases?tabset-42c89=2'
        'aura.token'   = $null
      }
      $Object4 = $Object3.actions[0].returnValue.Where({ $_.article.title -match 'ndOffice' -and $_.article.title.Contains($this.CurrentState.Version.Split('.')[0..2] -join '.') }, 'First')
      if ($Object4) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "https://support.netdocuments.com/s/article/$($Object4[0].article.urlName)"
        }

        $Object5 = Invoke-RestMethod -Uri 'https://support.netdocuments.com/s/sfsites/aura' -Method Post -Body @{
          message        = @{
            actions = @(
              @{
                descriptor = 'serviceComponent://ui.force.components.controllers.recordGlobalValueProvider.RecordGvpController/ACTION$getRecord'
                params     = @{
                  recordDescriptor = "$($Object4[0].article.id).undefined.FULL.null.null.Summary.VIEW.true.null.Summary,LastModifiedDate,Content__c"
                }
              }
            )
          } | ConvertTo-Json -Compress -Depth 10
          'aura.context' = @{
            app = 'siteforce:communityApp'
          } | ConvertTo-Json -Compress -Depth 10
          'aura.pageURI' = $Object4[0].article.urlName
          'aura.token'   = $null
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object5.context.globalValueProviders.Where({ $_.type -eq '$Record' }, 'First')[0].values.records.($Object4[0].article.id).Knowledge__kav.record.fields.Content__c.value | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object5.context.globalValueProviders.Where({ $_.type -eq '$Record' }, 'First')[0].values.records.($Object4[0].article.id).Knowledge__kav.record.fields.LastModifiedDate.value.ToUniversalTime()
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
