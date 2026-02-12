$ProductId = 'ddc1adec-4b1e-4581-b5b0-504fe0d68fd2'
$PortalUrl = "https://apps.datev.de/myupdates/download/products/${ProductId}"

function Read-Installer {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # Version
    $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromBurn
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
        [ordered]@{
            UpgradeCode = $InstallerFile | Read-UpgradeCodeFromBurn
        }
    )
    Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# Discover version from the MyUpdates page title (e.g. "Download Detail - Belegtransfer 5.49 - DATEV MyUpdates")
$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl($PortalUrl)
Start-Sleep -Seconds 15

$PageTitle = $EdgeDriver.Title
if ($PageTitle -notmatch 'Belegtransfer\s+([\d.]+)') {
    throw "Failed to extract version from page title: ${PageTitle}"
}

$ShortVersion = $Matches[1]
$VersionSlug = $ShortVersion -replace '\.', ''

$this.CurrentState.Installer += [ordered]@{
    InstallerUrl = "https://download.datev.de/download/bedi/belegtransfer${VersionSlug}.exe"
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
    $this.Log('Skip checking states', 'Info')

    # ETag
    $this.CurrentState.ETag = @($ETag)

    Read-Installer

    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
    $this.Log('New task', 'Info')

    # ETag
    $this.CurrentState.ETag = @($ETag)

    Read-Installer

    $this.Print()
    $this.Write()
    return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
    $this.Log("The version $($this.LastState.Version) from the last state is the latest (Global)", 'Info')
    return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
    throw 'The current state has an invalid version'
}

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
    $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

    # ETag
    $this.CurrentState.ETag = $this.LastState.ETag + $ETag

    $this.Write()
    return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
    # Case 6: The ETag, the SHA256 and the version have changed
    'Updated|Rollbacked' {
        $this.Print()
        $this.Write()
        $this.Message()
        $this.Submit()
    }
    # Case 5: The ETag and the SHA256 have changed, but the version is not
    Default {
        $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
        $this.Config.IgnorePRCheck = $true
        $this.Print()
        $this.Write()
        $this.Message()
        $this.Submit()
    }
}
