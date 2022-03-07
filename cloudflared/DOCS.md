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

## Quick Tunnel for Testing

You can get started with zero setup by using
[Cloudflare Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/run-tunnel/trycloudflare).

See [below](#option-quick_tunnel) for the detailed configuration.

**Please note that it is not recommended to use the quick tunnel for production
use since the URL can change anytime.**

## Installation

The installation of this add-on is pretty straightforward but requires some prerequisites
and a manual step at the first set-up.

**Before starting, please make sure to remove all other add-ons or configuration
entries handling SSL certificates, domain names and so on (e.g. DuckDNS) and
restart your HomeAssistant instance.**

1. (Optional if you don't yet have a working Cloudflare set-up):
   Get a domain name and set-up Cloudflare. See section
   [Domain Name and Cloudlfare Set-Up](#domain-name-and-cloudlfare-set-up) for details.
1. Add the `http` integration settings to your HA-config as described [below](#Configuration.yaml).
1. Set the `external_hostname` add-on option with your domain name or a subdomain
   that you want to use to access Home Assistant.
1. (Optional) Change the `tunnel_name` add-on option (default: homeassistant).
1. (Optional) Add additional hosts to forward to in the `additional_hosts` array
   (see [detailed description below](#option-additional_hosts)).
1. **Any existing DNS entries matching your defined `external_hostname` and `additional_hosts`
   will be overridden at Cloudflare**.
1. (Optional) Add a `catch_all_service` to forward all other hosts to a URL
   (see [detailed description below](#option-catch_all_service)).
1. (Optional) Add the `nginx_proxy_manager` flag to use the Cloudflare tunnel with
   the Nginxproxymanager add-on (see
   [detailed description below](#option-nginx_proxy_manager)).
1. Start the "Cloudflare" add-on. **Any existing DNS entries matching your defined
   `external_hostname` and `additional_hosts` will be overridden at Cloudflare**.
1. Check the logs of the "Cloudflare" add-on and **follow the instruction to authenticate
   at Cloudflare**.
   You need to copy a URL from the logs and visit it to authenticate.
1. A tunnel and a DNS entry will be created and show up in your Cloudflare DNS /
   Teams dashboard.

## Configuration

### Configuration.yaml

Since HomeAssistant blocks requests from proxies / reverse proxies, you have to tell
your instance to allow requests from the Cloudflared Add-on. The add-on runs locally,
so HA has to trust the docker network. In order to do so, add the following lines
to your `/config/configuration.yaml` (there is no need to adapt anything in these
lines since the IP range of the docker network is always the same):

**Note**: _Remember to restart Home Assistance when the configuration is changed._

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

If you need assistance changing the config, please follow the
[Advanced Configuration Tutorial][advancedconfiguration].

### Add-on Configuration

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
```

**Note**: _This is just an example, don't copy and paste it! Create your own!_

### Option: `additional_hosts`

You can use the internal reverse proxy of Cloudflare Tunnel to define additional
hosts next to home assistant. That way, you can use the tunnel to also access
other systems like a diskstation, router or anything else.

Like with the `external_hostname` of HomeAssistant, DNS entries at will be
automatically created at Cloudflare.

Add the (optional) `disableChunkedEncoding` option to a hostname, to disable
chunked transfer encoding. This is useful if you are running a WSGI server,
like Proxmox for example. Visit [Cloudflare Docs][disablechunkedencoding] for
further information.

Please find below an examplary entry for two additional hosts:

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

**Note**: _This will still route your defined `external_hostname`to HomeAssistant
as well as any potential `additional_hosts` to where you defined in the config.
Any other incoming traffic will be routed to the defined service._

In order to route hostnames through the tunnel, you have to create individual
CNAME records in Cloudflare for all of them, pointing to your `external_hostname`
or directly to the tunnel URL that you can get from the CNAME entry of
`external_hostname`.

### Option: `nginx_proxy_manager`

If you want to use the Cloudflare Tunnel with the Add-on
[Nginx Proxy Manager][nginx_proxy_manager], you can do so by setting this option.
It will automatically set the catch_all_service to the internal URL of Nginx Proxy
Manager. You do not have to add the option `catch_all_service` to your config (if
you add it anyways, it will be ignored).

```yaml
nginx_proxy_manager: true
```

**Note**: _As with `catch_all_service`, this will still route your defined
`external_hostname`to HomeAssistant as well as any potential `additional_hosts`
to where you defined in the config. Any other incoming traffic will be routed
to Nginx Proxy Manager._

In order to route hostnames through the tunnel, you have to create individual
CNAME records in Cloudflare for all of them, pointing to your `external_hostname`
or directly to the tunnel URL that you can get from the CNAME entry of
`external_hostname`.

Finally, you have to set-up your proxy hosts in Nginx Proxy Manager and forward
them to wherever you like.

### Option: `quick_tunnel`

You can get started with zero setup by using
[Cloudflare Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/run-tunnel/trycloudflare).
Set `quick_tunnel` to `true` , all other configuration will be ignored. After
starting the addon check the logs for your unique randomly generated
`trycloudflare.com` URL.
Please note that you still have to add the `http` integration settings to your
HA-config as described [here](#Configuration.yaml).

Quick Tunnel add-on configuration:

```yaml
quick_tunnel: true
external_hostname: ""
tunnel_name: ""
additional_hosts: []
```

### Option: `data_folder`

The `data_folder` option allows to change default storage
location (`/data`) for the automatically created `cert.pem` and
`tunnel.json` file.`

Possible values are:

- `config`: Files will be stored in /config/cloudflared.
- `share`: Files will be stored in /share/cloudflared.
- `ssl`: Files will be stored in /ssl/cloudflared.

```yam
data_folder: ssl
```

The add-on takes care of moving the created files within the default location
to the custom `data_folder` when adding the option after initial add-on setup.

**Note**: There are currently no automations in place when changing
from custom data folder to another custom data folder or back to default.
You have to take care of moving the files accordingly.

### Option: `custom_config`

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

### Option: `warp_enable`

If you want to route your home network(s) you can set this option to
`true`. This will enable your cloudflared tunnel to proxy related traffic
through your tunnel.

Before setting this to `true` please have a look at the [cloudflared documentation][cloudflared-route].

This add-on will take care of setting up cloudflared tunnel and routing specific
configuration. All other configuration is up to you.

From the above documentation:

- Enable HTTP filtering by turning on the Proxy switch under Settings >
  Network > L7 Firewall.
- Create device enrollment rules to determine which devices can enroll
  to your Zero Trust organization.
- Install the WARP client on the devices you want to allow into your network.

### Option: `warp_routes`

This option controls which routes will be added to your tunnel.
The default setting (no `warp_routes` configured in add-on configuration) will
route all connected networks through your tunnel.

You can override this by setting specifing networks (IP/CIDR) in `warp_routes`.

```yaml
warp_routes:
  - 192.168.0.0/24
  - 192.168.10.0/24
```

**Note**: _By default, Cloudflare Zero Trust excludes traffic for private
address spaces (RFC 191), you need to adapt the
[Split Tunnel][cloudflared-route-st] configuration._

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

### Option: `reset_cloudflared_files`

In case something went wrong or you want to reset your Cloudflare tunnel
for some other reason (e.g., switch to another Cloudflare account), you can reset
all your local Cloudflare files by setting this option to `true`.

```yaml
reset_cloudflared_files: true
```

**Note**: _After deleting the files, the option `reset_cloudflared_files` will
automaticaly be removed from the add-on configuration._

### Option: `warp_reset`

In case something went wrong or you no longer want to use this add-on to
route your networks, you can reset warp related settings by setting this option
to `true`.

```yaml
warp_reset: true
```

**Note**: _This will delete the routes assigned to your tunnel. The add-on
options `warp_reset`, `warp_enable` and `warp_routes` will automatically be
removed from the add-on configuration._

## Domain Name and Cloudlfare Set-Up

To use this plugin, you need a domain name that is using Cloudflare for its
DNS entries.

### Domain Name

If you do not already have a domain name, get one. You can get one at Freenom
following [this article][domainarticle].

### Cloudflare

Create a free Cloudflare Account at [cloudflare.com][cloudflare] and follow
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
<<<<<<< HEAD
[cloudflared-route-st] https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net#optional-ensure-that-traffic-can-reach-your-network
=======

[cloudflared-route-st] https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/#optional-ensure-that-traffic-can-reach-your-network
>>>>>>> 64f2c70a09bde9e41b6520a724eb164c56f4a980
