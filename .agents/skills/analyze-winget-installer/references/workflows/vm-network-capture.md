# Capture VM network traffic

Use this workflow when a bootstrapper downloads its payload, an application exposes its update source only at runtime, or installer logs do not explain a network failure. Captured update metadata can supply a Dumplings task source or reveal a versioned or more stable `InstallerUrl` than the download page. Follow [VM validation](vm-validation.md) for checkpoints, explicit guest execution, logs, and exit codes. Capture only traffic from the validation VM and application under investigation.

## Prepare the host capture proxy

Choose an installed capture tool and check its license before use:

- [Fiddler Classic](https://www.telerik.com/fiddler/fiddler-classic), `Telerik.Fiddler.Classic`, is free for personal, non-commercial use. [FiddlerClassicCLI](https://github.com/SpecterShell/FiddlerClassicCLI) supplies a community CLI and MCP server.
- [Fiddler Everywhere](https://www.telerik.com/fiddler/fiddler-everywhere/documentation/agent-tools/fiddler-mcp-server), `Telerik.Fiddler.Everywhere`, is paid. Its official MCP server requires a Pro or higher subscription.
- [Reqable](https://reqable.com/), `Reqable.Reqable`, accepts HTTP/HTTPS and SOCKS4/4a/5 inbound proxy connections on its capture port. Its [community MCP integration](https://github.com/iambond50-svg/reqable-mcp) controls the running application's local API.

Enable the tool's remote-client listener and record its address and capture port. Fiddler Classic uses **Tools > Options > Connections > Allow remote clients to connect**, as described in [remote-machine capture](https://www.telerik.com/fiddler/fiddler-classic/documentation/configure-fiddler/capturing-traffic/monitorremotemachine). Restrict any host firewall exception to the guest address or validation subnet. Keep the CLI/MCP control endpoint local. Its port is separate from the traffic proxy port.

Leave Fiddler's **Capture Traffic** and Reqable's **System Proxy** toggles unchanged during guest capture. They change the **host's** system-proxy routing and do not configure the VM. Verify the listener and recording state separately, then route traffic from the guest. Do not use CLI/MCP actions that toggle the host proxy.

For FiddlerClassicCLI, start Fiddler with `app open` if needed, which uses `-noattach`. Avoid both `capture start` and `capture stop` because they attach or detach the host's Windows system proxy. An active Fiddler listener can accept explicitly proxied guest traffic without that attachment. Enable HTTPS decryption separately only when content inspection is needed.

## Set the guest proxy

Find an address of the host that the guest can reach. The VM's default gateway is a useful candidate on a Hyper-V NAT network, but an external switch may point at a router instead. Confirm the address against the host's virtual adapter and the capture listener. Run these commands **inside the VM**, with `$CaptureHost` set to the verified host IPv4 address and `$CapturePort` to the capture port:

```powershell
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer
Test-NetConnection -ComputerName $CaptureHost -Port $CapturePort
$InternetSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
New-ItemProperty -Path $InternetSettings -Name ProxyServer -PropertyType String -Value ('http={0}:{1};https={0}:{1}' -f $CaptureHost, $CapturePort) -Force | Out-Null
New-ItemProperty -Path $InternetSettings -Name ProxyOverride -PropertyType String -Value '<local>;localhost;127.*;10.*;192.168.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*' -Force | Out-Null
New-ItemProperty -Path $InternetSettings -Name ProxyEnable -PropertyType DWord -Value 1 -Force | Out-Null
```

These [Windows proxy registry settings](https://devblogs.microsoft.com/scripting/how-can-i-switch-between-using-a-proxy-server-and-not-using-a-proxy-server/) belong to the current guest user. Run them in the account that launches the application. A PowerShell Direct session under another credential changes that account's HKCU. Check the guest's proxy UI for an existing PAC script, automatic discovery, or policy that takes precedence, and restart the target application after changing settings. The bypass string above covers common IPv4 LAN ranges. Add actual local hostnames and IPv6 exceptions for the guest network.

WinHTTP applications and services may use separate proxy configuration or another account. Inspect `netsh winhttp show proxy` in the guest and follow the application's documented setting before changing service-wide configuration. Record changes and restore them with the checkpoint. Setting HKCU alone does not prove that every process uses the proxy.

Test a known HTTP endpoint and confirm its request appears in the capture tool. Then test HTTPS after configuring guest trust below. Do not disable TLS validation to make that test pass.

## Route proxy-unaware applications inside the VM

Use Proxifier or one TUN client in the **guest** when the application ignores system proxy settings. Choose one routing method per test. Remove conflicting guest application/system proxy settings when forcing the same traffic through another proxy layer, and bypass the host listener to prevent loops.

### Proxifier

Copy the user-provided `Sandbox.ppx` from `~/Repository/Sandbox` into the VM as a starting profile. It is a local example, not a repository dependency. Replace its proxy endpoint with the verified host address and port, inspect every rule, and remove saved credentials before retaining evidence.

Select Proxifier's **HTTPS** proxy type for a capture proxy that supports HTTP CONNECT. This label means CONNECT support, not necessarily TLS on the connection to the proxy. Put direct rules for the proxy endpoint, loopback, and LAN ahead of a rule for the target application and its child downloaders. Use a proxy default rule only when the whole guest's public TCP traffic is intentionally in scope. Check service/other-user handling if the installer launches a service. See [proxy settings](https://www.proxifier.com/docs/win-v4/proxy.html), [rule order](https://www.proxifier.com/docs/win-v4/rules.html), and [profiles](https://www.proxifier.com/docs/win-v4/profiles.html).

For Reqable, Proxifier can instead use **SOCKS5** with the same verified capture endpoint. The guest Windows HTTP/HTTPS proxy settings above still use Reqable's HTTP listener.

### mihomo / Clash TUN

Use a mihomo-based client with Windows TUN support. Run it elevated **inside the VM**. Replace `<HOST_IP>`, `<CAPTURE_PORT>`, and `<LAN_DNS_IP>` before validating this configuration. The port must become an integer. Select a reachable guest LAN DNS resolver. Add the host's `/32` or `/128` to the exclusions if it is outside the listed ranges.

```yaml
mode: rule
ipv6: true
log-level: info
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-detect-interface: true
  strict-route: true
  inet6-address: ['fdfe:dcba:9876::1/126']
  dns-hijack: ['any:53', 'tcp://any:53']
  route-exclude-address:
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
  - 127.0.0.0/8
  - 169.254.0.0/16
  - '::1/128'
  - 'fc00::/7'
  - 'fe80::/10'
dns:
  enable: true
  ipv6: true
  enhanced-mode: redir-host
  nameserver: ['<LAN_DNS_IP>']
proxies:
- name: capture
  type: http
  server: '<HOST_IP>'
  port: <CAPTURE_PORT>
rules:
- IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
- IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
- IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
- IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
- IP-CIDR,169.254.0.0/16,DIRECT,no-resolve
- IP-CIDR6,::1/128,DIRECT,no-resolve
- IP-CIDR6,fc00::/7,DIRECT,no-resolve
- IP-CIDR6,fe80::/10,DIRECT,no-resolve
- NETWORK,udp,DIRECT
- MATCH,capture
```

The example uses [TUN route exclusions](https://wiki.metacubex.one/en/config/inbound/tun/), a [plain HTTP proxy](https://wiki.metacubex.one/en/config/proxies/http/), [internal DNS](https://wiki.metacubex.one/en/config/dns/), and [ordered routing rules](https://wiki.metacubex.one/en/config/rules/). DNS uses the selected LAN resolver outside the capture proxy. Use a TUN subnet that does not overlap an existing guest network and verify IPv6 routing if the guest has IPv6 connectivity. Allow the client through the guest firewall as needed without disabling the firewall.

For Reqable's SOCKS inbound, change the `capture` proxy to [`type: socks5`](https://wiki.metacubex.one/en/config/proxies/socks/), retaining its server and port. Keep the DNS and direct-routing rules.

Validate before starting, then run from an elevated guest shell:

```powershell
mihomo.exe -t -f .\vm-capture.yaml
if ($LASTEXITCODE -ne 0) { throw 'Invalid mihomo capture configuration.' }
mihomo.exe -f .\vm-capture.yaml
```

### sing-box TUN

This example uses the sing-box 1.12+ typed DNS-server format and route actions. Replace the same endpoint placeholders. The quoted port placeholder must become a JSON number. Adjust the illustrative TUN addresses if they overlap an existing network.

```json
{
  "log": { "level": "info" },
  "dns": {
    "servers": [{ "type": "udp", "tag": "lan-dns", "server": "<LAN_DNS_IP>", "server_port": 53, "detour": "direct" }],
    "final": "lan-dns"
  },
  "inbounds": [{
    "type": "tun",
    "tag": "vm-capture",
    "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
    "auto_route": true,
    "strict_route": true,
    "stack": "mixed",
    "route_exclude_address": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "169.254.0.0/16", "::1/128", "fc00::/7", "fe80::/10"]
  }],
  "outbounds": [
    { "type": "http", "tag": "capture", "server": "<HOST_IP>", "server_port": "<CAPTURE_PORT>" },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      { "port": 53, "action": "hijack-dns" },
      { "ip_cidr": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "169.254.0.0/16", "::1/128", "fc00::/7", "fe80::/10"], "action": "route", "outbound": "direct" },
      { "network": "udp", "action": "route", "outbound": "direct" }
    ],
    "final": "capture"
  }
}
```

See [TUN fields](https://sing-box.sagernet.org/configuration/inbound/tun/), [HTTP CONNECT outbound](https://sing-box.sagernet.org/configuration/outbound/http/), [UDP DNS servers](https://sing-box.sagernet.org/configuration/dns/server/udp/), [route settings](https://sing-box.sagernet.org/configuration/route/), and [route actions](https://sing-box.sagernet.org/configuration/route/rule_action/). On sing-box 1.15+, add `"version": 1` to the `capture` HTTP outbound for a conventional HTTP/1.1 capture listener. Add explicit host exclusions if its address is outside the listed LAN ranges.

For Reqable's SOCKS inbound, use [`"type": "socks", "version": "5"`](https://sing-box.sagernet.org/configuration/outbound/socks/) in the `capture` outbound, retaining `server` and `server_port`. Remove any HTTP-specific fields. Keep the DNS and direct-routing rules.

Check the file, then run from an elevated guest shell:

```powershell
sing-box.exe check -c .\vm-capture.json
if ($LASTEXITCODE -ne 0) { throw 'Invalid sing-box capture configuration.' }
sing-box.exe run -c .\vm-capture.json
```

### Check coverage and protocol limits

These TUN examples send public TCP connections to the host HTTP CONNECT proxy, bypass local networks, handle DNS separately, and leave other UDP traffic on a direct guest route. Reqable's [UDP-capture request](https://github.com/reqable/reqable-app/issues/1264) is closed as not planned. Use guest packet capture for UDP, ICMP, or other traffic outside HTTP(S) inspection, and record capture coverage accurately.

Verify the target's requests in the host capture tool and the guest routing client's connection log. Include child processes and service contexts. Check IPv4 and IPv6 rather than assuming a successful browser request proves coverage of the installer. LAN destinations deliberately bypass capture in these examples.

## Trust the capture CA inside the guest

Export only the capture tool's **public root certificate**. Verify its fingerprint against the running tool before import. Obtain approval before changing guest trust, keep all changes in the checkpointed VM, and never export the root's private key. Ordinary CONNECT tunneling can show destinations without HTTPS decryption or a trusted interception CA.

For applications using the Windows certificate store, import the verified certificate under the account being tested:

```powershell
Import-Certificate -FilePath $CaptureCertificatePath -CertStoreLocation Cert:\CurrentUser\Root
```

Use `Cert:\LocalMachine\Root` only for a justified machine/service-context test, from an elevated guest shell. Follow the capture tool's [remote HTTPS trust procedure](https://www.telerik.com/fiddler/fiddler-classic/documentation/configure-fiddler/capturing-traffic/monitorremotemachine). Importing a CA into Windows does not update a bundled Java runtime or an application's private CA bundle.

### Java runtimes

Locate the Java runtime actually used by the application, often its installed `jre` directory. Do not assume the guest's environment variable `JAVA_HOME` points to it. Check for `javax.net.ssl.trustStore` or other configured overrides. With `$JavaHome` set to that runtime, the usual store is `lib\security\cacerts`. A JDK 8 layout can instead use `jre\lib\security\cacerts`.

Back up the selected guest store, inspect the certificate, and use [keytool](https://docs.oracle.com/en/java/javase/24/docs/specs/man/keytool.html) to import it without discarding existing roots:

```powershell
$TrustStore = Join-Path $JavaHome 'lib\security\cacerts'
$KeyTool = Join-Path $JavaHome 'bin\keytool.exe'
Copy-Item -LiteralPath $TrustStore -Destination "$TrustStore.before-capture" -ErrorAction Stop
& $KeyTool -printcert -file $CaptureCertificatePath
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the capture certificate.' }
& $KeyTool -importcert -alias dumplings-capture-ca -file $CaptureCertificatePath -keystore $TrustStore
if ($LASTEXITCODE -ne 0) { throw 'Cannot import the capture certificate.' }
& $KeyTool -list -alias dumplings-capture-ca -keystore $TrustStore
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify the imported capture certificate.' }
```

Verify the printed fingerprint before accepting the import prompt. Enter the store password interactively instead of placing it in command arguments or evidence. Preserve the actual JKS/PKCS12 store format. If the bundled runtime lacks keytool, use a compatible trusted JDK tool against the selected store inside the guest. Restart the Java process after changing trust.

### Text and binary CA bundles

Identify the format from content. `.crt` and `.cer` can contain either PEM text or DER binary. Prefer a documented application setting for an additional CA file. For an existing PEM bundle, back it up and append the verified PEM certificate with a newline boundary:

```powershell
Copy-Item -LiteralPath $CABundlePath -Destination "$CABundlePath.before-capture" -ErrorAction Stop
Add-Content -LiteralPath $CABundlePath -Value ("`n" + (Get-Content -LiteralPath $CapturePemPath -Raw).Trim() + "`n") -Encoding ascii
```

Check that `$CapturePemPath` contains a valid `BEGIN CERTIFICATE` / `END CERTIFICATE` block and that `$CABundlePath` is a PEM bundle before running the example. Use the store's import API or tool for binary JKS, PKCS12, NSS, or other containers. Do not concatenate certificates to binary files, overwrite the store with a single certificate, or patch embedded executable bytes. If no supported import or override exists, retain destination/TLS-failure evidence and report the limitation. Certificate pinning or mutual TLS can still prevent decryption after a correct CA import. Do not globally disable certificate checks.

## Discover the update source

Inspect readily available updater configuration and application source first. If the effective endpoint remains unclear, prepare capture before launching the application in the VM and follow this sequence.

1. Observe startup traffic for a bounded period. Some applications delay their automatic update check. Record the observation period and separate update requests from telemetry, advertisements, and unrelated API calls. An empty capture does not establish that the application has no updater.
2. If startup produces no useful request, use Computer Use on the guest's visible desktop to open **Check for updates** or its equivalent in settings, the Help menu, or the About dialog. Follow [VMConnect guidance](vm-validation.md#operate-the-guest-through-vmconnect), verify the selected application, and correlate the click with captured requests. If Computer Use cannot operate the guest, ask the user to trigger the check and record that limitation. Do not claim the action succeeded without observing it.
3. If checking for updates requires login, ask the user to sign in inside the VM or provide an approved test account. Do not bypass authentication, create an account without permission, or retain credentials in evidence. Record the login requirement and stop that discovery route if authorized access is unavailable.
4. Inspect the update request and response for the version, product, channel, architecture, download URLs, and redirects. Save only relevant redacted evidence, then test whether the candidate source and installer URL work independently without the application's login, cookies, or temporary tokens.

Compare the captured source with the official download page and apply [task source selection](../../../author-dumplings-task/references/sources/selection.md), including GitHub release priority and stale-source checks. A URL from an updater may identify a delta or update-only binary. Before adopting it as `InstallerUrl`, verify that it is a full initial-install artifact for the intended version, architecture, and scope, and follow [artifact selection](../../../author-winget-manifest/references/package/artifact-selection.md) for public access, URL stability, hashes, and WinGet download compatibility.

When configuration inspection and capture remain inconclusive, inspect or decompile the relevant application code as a last resort. For Electron, unpack `app.asar` or inspect `app/` JavaScript and trace updater configuration and runtime overrides. The actual electron-updater method is [`setFeedURL()`](https://github.com/electron-userland/electron-builder/blob/master/packages/electron-updater/src/AppUpdater.ts), which can override `app-update.yml`. Trace provider options, URL construction, and environment or channel inputs rather than accepting the first URL string. Verify recovered endpoints independently and label an unverified string as a candidate. Keep application execution inside the VM.

## Save evidence and restore the environment

Keep network evidence under `Sandbox/Evidence/<PackageIdentifier>/<UTC-run-id>/vm/network` using the [evidence workflow](evidence.md). Record tool/version, routing method, endpoint, CA fingerprint, process, timestamps, HTTP status, redirects, selected response fields, and downloaded payload hashes. Inspect response text locally and retain only the relevant redacted evidence. Capture files can contain credentials, authorization headers, cookies, signed URLs, and private data. Keep raw captures access-restricted for the investigation, never commit or upload them, and remove them when no longer needed.

Proxying and TLS interception can change server behavior and the connection fingerprint. Repeat the final silent-install test from a restored checkpoint without capture routing or the added CA before claiming ordinary WinGet behavior. Stop guest routing clients, remove temporary host listener/firewall changes while preserving prior settings, and restore the guest checkpoint. Capture preparation must not become an undocumented installation prerequisite.
