# Home Assistant Add-on: Cloudflared

Cloudflared connects your Home Assistant Instance via a secure tunnel to a domain
or subdomain at Cloudflare. Doing that, you can expose your Home Assitant to the
Internet without opening ports in your router. Additionally, you can utilize
Cloudflare Teams, their Zero Trust platform to further secure your Home Assistant
connection.

**To use this add-on, you have to own a domain name (e.g. example.com) and use the
DNS servers of Cloudflare. If you do not have one, you can get one for free at
[Freenom][freenom] following [this article][domainarticle].**

## Disclaimer

Please make sure to be compliant with the
[Cloudflare Self-Serve Subscription Agreement][cloudflare-sssa] when using this
add-on. Especially [section 2.8][cloudflare-sssa-28] could be breached when
mainly streaming videos or other Non-HTML content.

## Installation

The installation of this add-on is pretty straightforward but requires some prerequisites
and a manual step at the first set-up.

### Prerequisites

1. Before starting, please make sure to remove all other add-ons or configuration
   entries handling SSL certificates, domain names and so on (e.g. DuckDNS) and
   restart your Home Assistant instance.
1. If you don't yet have a working Cloudflare set-up:
   Get a domain name and set-up Cloudflare. See section
   [Domain Name and Cloudflare Set-Up](#domain-name-and-cloudflare-set-up) for details.
1. **Decide whether to use a [local or managed tunnel][addon-remote-or-local].**

### Initial Add-on Setup for local tunnels

The following instructions describe the minimum necessary steps to use this add-on:

1. Add the `http` integration settings to your HA-config as described [below](#configurationyaml).
1. Set the `external_hostname` add-on option with your domain name or a subdomain
   that you want to use to access Home Assistant.
1. (Optional) Change the `tunnel_name` add-on option (default: homeassistant).
1. Start the "Cloudflared" add-on. **Any existing DNS entries matching your defined
   `external_hostname` and `additional_hosts` will be overridden at Cloudflare**.
1. Check the logs of the "Cloudflared" add-on and **follow the instruction to authenticate
   at Cloudflare**.
   You need to copy a URL from the logs and visit it to authenticate.
1. A tunnel and a DNS entry will be created and show up in your Cloudflare DNS /
   Teams dashboard.

Please review the rest of this documentation for further information and more
advanced configuration options.

## Configuration

There are more advanced configuration options this add-on provides.
Please check the index below for further information.

- [`additional_hosts`](#option-additional_hosts)
- [`catch_all_service`](#option-catch_all_service)
- [`nginx_proxy_manager`](#option-nginx_proxy_manager)
- [`data_folder`](#option-data_folder)
- [`custom_config`](#option-custom_config-advanced-option)
- [`warp_enable`](#option-warp_enable-advanced-option)
- [`warp_routes`](#option-warp_routes)
- [`log_level`](#option-log_level)
- [`warp_reset`](#option-warp_reset)
- [`tunnel_token`](#option-tunnel_token)

### Overview: Add-on Configuration

**Note**: _Remember to restart the add-on when the configuration is changed._

Example basic add-on configuration:

```yaml
external_hostname: "ha.example.com"
tunnel_name: "homeassistant"
additional_hosts: []
```

Example extended add-on configuration:

```yaml
external_hostname: "ha.example.com"
tunnel_name: "homeassistant"
additional_hosts:
  - hostname: "router.example.com"
    service: "http://192.168.1.1"
  - hostname: "diskstation.example.com"
    service: "https://192.168.1.2:5001"
  - hostname: "website.example.com"
    service: "http://192.168.1.3:8080"
    disableChunkedEncoding: true
nginx_proxy_manager: true
log_level: "debug"
warp_enable: true
warp_routes:
  - 192.168.1.0/24
```

**Note**: _This is just an example, don't copy and paste it! Create your own!_

### Option: `additional_hosts`

You can use the internal reverse proxy of Cloudflare Tunnel to define additional
hosts next to Home Assistant. That way, you can use the tunnel to also access
other systems like a diskstation, router or anything else.

Like with the `external_hostname` of Home Assistant, DNS entries will be
automatically created at Cloudflare.

Add the (optional) `disableChunkedEncoding` option to a hostname, to disable
chunked transfer encoding. This is useful if you are running a WSGI server,
like Proxmox for example. Visit [Cloudflare Docs][disablechunkedencoding] for
further information.

Please find below an examplary entry for three additional hosts:

```yaml
additional_hosts:
  - hostname: "router.example.com"
    service: "http://192.168.1.1"
  - hostname: "diskstation.example.com"
    service: "https://192.168.1.2:5001"
  - hostname: "website.example.com"
    service: "http://192.168.1.3:8080"
    disableChunkedEncoding: true
```

**Note**: _If you delete a hostname from the list, it will not be served
anymore. Nevertheless, you should also manually delete the DNS entry from
Cloudflare since it can not be deleted by the Add-on._

### Option: `catch_all_service`

If you want to forward all requests from any hostnames not defined in the
`external_hostname` or the `additional_hosts`, you can use this option and
define a URL to forward to. For example, this can be used for reverse proxies.

**Note**: _If you want to use the HA add-on [Nginx Proxy Manager][nginx_proxy_manager]
as reverse proxy, you should set the flag `nginx_proxy_manager` (see
[below](#option-nginx_proxy_manager)) and not use this option._

```yaml
catch_all_service: "http://192.168.1.100"
```

**Note**: _This will still route your defined `external_hostname`to Home Assistant
as well as any potential `additional_hosts` to where you defined in the config.
Any other incoming traffic will be routed to the defined service._

In order to route hostnames through the tunnel, you have to create individual
CNAME records in Cloudflare for all of them, pointing to your `external_hostname`
or directly to the tunnel URL that you can get from the CNAME entry of
`external_hostname`.

### Option: `nginx_proxy_manager`

If you want to use Cloudflare Tunnel with the Add-on
[Nginx Proxy Manager][nginx_proxy_manager], you can do so by setting this option.
It will automatically set the catch_all_service to the internal URL of Nginx Proxy
Manager. You do not have to add the option `catch_all_service` to your config (if
you add it anyways, it will be ignored).

```yaml
nginx_proxy_manager: true
```

**Note**: _As with `catch_all_service`, this will still route your defined
`external_hostname`to Home Assistant as well as any potential `additional_hosts`
to where you defined in the config. Any other incoming traffic will be routed
to Nginx Proxy Manager._

In order to route hostnames through the tunnel, you have to create individual
CNAME records in Cloudflare for all of them, pointing to your `external_hostname`
or directly to the tunnel URL that you can get from the CNAME entry of
`external_hostname`.

Finally, you have to set-up your proxy hosts in Nginx Proxy Manager and forward
them to wherever you like.

### Option: `data_folder`

The `data_folder` option allows to change the default storage
location (`/data`) for the automatically created `cert.pem` and
`tunnel.json` file.

Possible values are:

- `config`: Files will be stored in /config/cloudflared.
- `share`: Files will be stored in /share/cloudflared.
- `ssl`: Files will be stored in /ssl/cloudflared.

```yaml
data_folder: ssl
```

The add-on takes care of moving the created files from the default location
to the custom `data_folder` when adding the option after initial add-on setup.

**Note**: There are currently no automations in place when changing
from custom data folder to another custom data folder or back to default.
You have to take care of moving the files accordingly.

### Option: `custom_config` (advanced option)

The `custom_config` option can be used to create a custom `config.yml`
file to create more complex ingress configurations.

The option can only be used in combination with the `data_folder` option.

See [cloudflared documentation][cloudflared-ingress] for further details on
the needed file structure and content options.

For example: if you set `data_folder: ssl` the add-on will search for
`/ssl/cloudflared/config.yml` when `custom_config: true`.

Your file will be validated on add-on startup and all errors will be logged.

For your custom config.yml you have to add values for `tunnel` and the tunnel
credentials file. The tunnel credentials file is located in your
`data_folder/cloudflared` and is named `tunnel.json`.

The `tunnel.json` file contains your `<tunnel UUID>` as `TunnelID` attribute.

```yaml
---
tunnel: <tunnel UUID>
credentials-file: "/ssl/cloudflared/tunnel.json"
ingress:
  - hostname: homeassistant.example.com
    service: http://homeassistant:8123
    originRequest:
      noTLSVerify: true
```

**Note**: If you use a custom `config.yml` file, `additional_hosts` and
`external_hostname` options will be ignored. Make sure to add all needed
services (e.g. a homeassistant ingress rule) inside `config.yml`.

### Option: `warp_enable` (advanced option)

If you want to route your home network(s) you can set this option to
`true`. This will enable proxying network traffic through your tunnel.

Before setting this to `true` please have a look at the [cloudflared documentation][cloudflared-route].

This add-on will take care of setting up the Cloudflare Tunnel and routing
specific configuration. All other configuration is up to you.

An excerpt from the above documentation:

- Enable HTTP filtering by turning on the Proxy switch under Settings >
  Network > L7 Firewall.
- Create device enrollment rules to determine which devices can enroll
  to your Zero Trust organization.
- Install the WARP client on the devices you want to allow into your network.

### Option: `warp_routes`

This option controls which routes will be added to your tunnel.

This option is mandatory if `warp_enable` is set to `true`.

See the example below on how to specify networks (IP/CIDR) in
`warp_routes`.

```yaml
warp_enable: true
warp_routes:
  - 192.168.0.0/24
  - 192.168.10.0/24
```

**Note**: _By default, Cloudflare Zero Trust excludes traffic for private
address spaces (RFC 191), you need to adapt the
[Split Tunnel][cloudflared-route-st] configuration._

### Option: `tunnel_token`

If you created a Cloudflare Tunnel from the Zero Trust Dashboard, you can provide
your tunnel token to connect to your remote managed tunnel.
Keep in mind, when using this option, that you need to configure all
hosts (including Home Assistant) by yourself.
Set `tunnel_token` to your [tunnel token][create-remote-managed-tunnel],
all other configuration will be ignored. After starting the addon, check the
logs to see whether everything went as expected.

Check out [this how-to][addon-remote-tunnel] to get a step by step
guide on how to set up a remote managed tunnel with this add-on.

Please note that you still have to add the `http` integration settings to your
HA-config as described [here](#configurationyaml).

### Option: `log_level`

The `log_level` option controls the level of log output by the addon and can
be changed to be more or less verbose, which might be useful when you are
dealing with an unknown issue.

```yaml
log_level: debug
```

Possible values are:

- `trace`: Show every detail, like all called internal functions.
- `debug`: Shows detailed debug information.
- `info`: Normal (usually) interesting events.
- `warning`: Exceptional occurrences that are not errors.
- `error`: Runtime errors that do not require immediate action.
- `fatal`: Something went terribly wrong. Add-on becomes unusable.

Please note that each level automatically includes log messages from a
more severe level, e.g., `debug` also shows `info` messages. By default,
the `log_level` is set to `info`, which is the recommended setting unless
you are troubleshooting.

### Option: `warp_reset`

In case something went wrong or you no longer want to use this add-on to
route your networks, you can reset warp related settings by setting this option
to `true`.

```yaml
warp_reset: true
```

**Note**: _This will remove the routes assigned to your tunnel. The add-on
options `warp_reset`, `warp_enable` and `warp_routes` will automatically be
removed from the add-on configuration._

## Home Assistant configuration

### configuration.yaml

Since Home Assistant blocks requests from proxies / reverse proxies, you have to
tell your instance to allow requests from the Cloudflared add-on. The add-on runs
locally, so HA has to trust the docker network. In order to do so, add the
following lines to your `/config/configuration.yaml` (there is no need to adapt
anything in these lines since the IP range of the docker network is always the
same):

**Note**: _Remember to restart Home Assistant when the configuration is changed._

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

If you need assistance changing the config, please follow the
[Advanced Configuration Tutorial][advancedconfiguration].

## Troubleshooting

### 400: Bad Request error

Make sure to add the [trusted proxy setting](#configurationyaml) correctly.
Make sure to copy and paste the code snippet without adapting anything.
There is no need to adapt IP ranges as the add-on is working as proxy.

## Securing access to the Cloudflare account

The add-on downloads after authentication a `cert.pem` file to authenticate
your instance of cloudflared against your Cloudflare account.
You can not revoke access to this file from your Cloudflare account!
The [issue](https://github.com/cloudflare/cloudflared/issues/93)
still persists.

Workaround:

1. Create a new Cloudflare account and invite it to your Cloudflare account
   that manages your Domain:\
   Cloudflare Dashboard -> Manage Account -> Members -> Invite Member
1. Instead of using your primary account to authenticate the tunnel,
   use your secondary account.

If your `cert.pem` file is compromised, you can revoke your
secondary account from your primary account.

## Securing access to Home Assistant

After your tunnel is setup and working, you may wish to add additional security
measures.

For example you could add a [WAF rule](https://developers.cloudflare.com/waf/) in
Cloudflare which blocks requests outside your country.

You can also use Cloudflare Access to present an authentication page before users
are able to access Home Assistant, see the
[self-hosted applications][self-hosted-applications] docs.

## Domain Name and Cloudflare Set-Up

To use this plugin, you need a domain name that is using Cloudflare for its
DNS entries.

### Domain Name

If you do not already have a domain name, get one. You can get one at Freenom
following [this article][domainarticle].

### Cloudflare

Create a free Cloudflare account at [cloudflare.com][cloudflare] and follow
the tutorial [Getting started with Cloudflare][cloudflaretutorial].

## Authors & contributors

The original setup of this repository is by [Tobias Brenner][tobias].

## License

MIT License

Copyright (c) 2022 Tobias Brenner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[advancedconfiguration]: https://www.home-assistant.io/getting-started/configuration/
[cloudflare]: https://www.cloudflare.com/
[cloudflare-sssa]: https://www.cloudflare.com/en-gb/terms/
[cloudflare-sssa-28]: https://www.cloudflare.com/en-gb/terms/#:~:text=2.8%20Limitation%20on%20Serving%20Non%2DHTML%20Content
[cloudflaretutorial]: https://support.cloudflare.com/hc/en-us/articles/360027989951-Getting-Started-with-Cloudflare
[domainarticle]: https://www.linkedin.com/pulse/what-do-domain-name-how-get-one-free-tobias-brenner?trk=public_post-content_share-article
[freenom]: https://freenom.com
[nginx_proxy_manager]: https://github.com/hassio-addons/addon-nginx-proxy-manager
[tobias]: https://github.com/brenner-tobias
[disablechunkedencoding]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/configuration-file/ingress#disablechunkedencoding
[cloudflared-ingress]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/configuration-file/ingress
[cloudflared-route]: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/
[cloudflared-route-st]: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net#optional-ensure-that-traffic-can-reach-your-network
[remote-managed-tunnel]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/#set-up-a-tunnel-remotely-dashboard-setup
[create-remote-managed-tunnel]: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/#1-create-a-tunnel
[self-hosted-applications]: https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-apps/
[addon-remote-tunnel]: https://github.com/brenner-tobias/addon-cloudflared/blob/main/docs/remote-tunnel.md
[addon-remote-or-local]: https://github.com/brenner-tobias/addon-cloudflared/blob/main/docs/tunnels.md
