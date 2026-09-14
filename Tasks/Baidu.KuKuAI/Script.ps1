$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://kuku.baidu.com/'

  # Wait until the app renders the download button
  $null = Read-PlaywrightLocator -Page $Page -Selector 'button:has-text("下载电脑版")' -State Visible -TimeoutMilliseconds 20000

  # Capture the download URL the page assigns to the clicked anchor
  $null = Invoke-PlaywrightJavaScript -Page $Page -Expression '() => { window.__downloadUrl = null; const originClick = HTMLAnchorElement.prototype.click; HTMLAnchorElement.prototype.click = function(...args) { window.__downloadUrl = this.href; return originClick.apply(this, args); }; const button = [...document.querySelectorAll("button")].find((element) => element.textContent.includes("下载电脑版")); if (button) { button.click(); return true; } return false; }'
  Start-Sleep -Seconds 4
  Invoke-PlaywrightJavaScript -Page $Page -Expression '() => window.__downloadUrl'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
