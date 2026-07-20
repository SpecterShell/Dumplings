$Global:DumplingsStorage.SonicWallApps = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.sonicwall.com/products/remote-access/vpn-clients'
  Invoke-PlaywrightJavaScript -Page $Page -Expression @'
() => {
  self.__next_f = [];
  for (const marker of ['ConnectTunnel', 'GVCSetup', 'NetExtender for Windows']) {
    const script = [...document.scripts].find((item) => item.textContent.includes(marker));
    if (!script) throw new Error(`Next.js data script was not found for ${marker}`);
    self.eval(script.textContent);
  }
  return self.__next_f;
}
'@
}
