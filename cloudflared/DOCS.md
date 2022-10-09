# Home Assistant Add-on: Cloudflared

Cloudflared connects your Home Assistant Instance via a secure tunnel to a domain
or subdomain at Cloudflare. This allows you to expose your Home Assistant
instance and other services to the Internet without opening ports on your router.
Additionally, you can utilize Cloudflare Zero Trust to further secure your
connection.

## Disclaimer

Please make sure you comply with the
[Cloudflare Self-Serve Subscription Agreement][cloudflare-sssa] when using this
add-on. For example [section 2.8][cloudflare-sssa-28] could be breached when
streaming videos (e.g. Plex) or other non-HTML content.

## Initial setup

### Prerequisites

1. A domain name (e.g. example.com) using Cloudflare for DNS. If you don't have
   one see [Domain name and Cloudflare set up](#domain-name-and-cloudflare-set-up).
1. Decide between a local tunnel (managed by the add-on) or a remote tunnel
   (managed in Cloudflare's interface). [Learn more][addon-remote-or-local].
1. This add-on should be [installed][addon-installation] but not started yet.

After completing the prerequisites, proceed below based on the type of tunnel you
chose.

### Local tunnel add-on setup (recommended)

In the following steps a Cloudflare Tunnel will be automatically created by the
add-on to expose your Home Assistant instance.

If you only want to expose other services, you can leave `external_hostname`
empty and set `additional_hosts` as [shown below](#configuration).

1. Add the `http` integration settings to your Home Assistant config as
   [described below](#configurationyaml).
1. Set the `external_hostname` add-on option to the domain name or subdomain
   that you want to use to access Home Assistant.
1. (Optional) Change the `tunnel_name` add-on option (default: `homeassistant`).
1. Start the "Cloudflared" add-on. **This will overwrite any existing DNS entries
   matching `external_hostname` or `additional_hosts`**.
1. Check the logs of the "Cloudflared" add-on and **follow the instruction to
   authenticate with Cloudflare**.
   You need to copy a URL from the logs and visit it to authenticate.

A tunnel will now have been created and show up in your Cloudflare Teams
dashboard. Please review the additional configuration options listed below.

### Remote tunnel add-on setup (advanced setups only)

In the following steps you will manually create a Cloudflare Tunnel in the Zero
Trust Dashboard and provide the token to the add-on.

1. Add the `http` integration settings to your Home Assistant config as
   [described below](#configurationyaml).
1. Create a Cloudflare Tunnel in the Cloudflare Teams dashboard following
   [this how-to][addon-remote-tunnel].
1. Set `tunnel_token` add-on option to your [tunnel token][create-remote-managed-tunnel]
   (all other configuration will be ignored).
1. Start the "Cloudflared" add-on, check the logs to see whether everything went
   as expected.

The tunnel you created should now be associated with the Cloudflared add-on.
The configuration options listed below are ignored when using a remote tunnel.

## Configuration

**These configuration options only apply to the local tunnel setup**. More
advanced configurations can be achieved using the remote tunnel setup.

- [`tunnel_name`](#option-tunnel_name)
- [`additional_hosts`](#option-additional_hosts)
- [`catch_all_service`](#option-catch_all_service)
- [`nginx_proxy_manager`](#option-nginx_proxy_manager)
- [`data_folder`](#option-data_folder)
- [`custom_config (Deprecated)`](#option-custom_config-advanced-option)
- [`log_level`](#option-log_level)

### Overview: Add-on configuration

**Note**: _Remember to restart the add-on when the configuration is changed._

Example basic add-on configuration:

```yaml
external_hostname: "ha.example.com"
additional_hosts: []
```

Example extended add-on configuration:

```yaml
external_hostname: "ha.example.com"
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
```

**Note**: _This is just an example, don't copy and paste it! Create your own!_

### Option: `tunnel_name`

If you want to change the default tunnel name to something different than
"homeassistant", you can do so by using this option.

**Note**: _The tunnel name needs to be unique in your Cloudflare account._

```yaml
tunnel_name: "myHomeAssistant"
```

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

Please find below an example entry for three additional hosts:

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
Cloudflare since it can not be deleted by the add-on._

### Option: `catch_all_service`

If you want to forward all requests from any hostnames not defined in the
`external_hostname` or the `additional_hosts`, you can use this option and
define a URL to forward to. For example, this can be used for reverse proxies.

**Note**: _If you want to use the HA add-on [Nginx Proxy Manager][nginx_proxy_manager]
as reverse proxy, you should set the flag `nginx_proxy_manager` ([see
below](#option-nginx_proxy_manager)) and not use this option._

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

If you want to use Cloudflare Tunnel with the add-on
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

**Deprecated**: Please note that this option is deprecated and will be
removed soon. We strongly suggest to migrate to Cloudflare Managed Tunnels
in your Zero Trust dashboard.

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

## Home Assistant configuration

### configuration.yaml

Since Home Assistant blocks requests from proxies/reverse proxies, you need to
tell your instance to allow requests from the Cloudflared add-on. The add-on runs
locally, so HA has to trust the docker network. In order to do so, add the
following lines to your `/config/configuration.yaml`:

**Note**: _There is no need to adapt anything in these lines since the IP range
of the docker network is always the same._

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

Remember to restart Home Assistant when the configuration is changed.

If you need assistance changing the config, please follow the
[Advanced Configuration Tutorial][advancedconfiguration].

## Troubleshooting

### 400: Bad Request error

Make sure to add the [trusted proxy setting](#configurationyaml) correctly.
Make sure to copy and paste the code snippet without adapting anything.
There is no need to adapt IP ranges as the add-on is working as proxy.

### Securing access to your Cloudflare account

The add-on downloads after authentication a `cert.pem` file to authenticate
your instance of cloudflared against your Cloudflare account.
You can not revoke access to this file from your Cloudflare account!
The [issue](https://github.com/cloudflare/cloudflared/issues/93)
still persists.

Workaround:

1. Create a new Cloudflare account and invite it to your Cloudflare account
   that manages your domain:\
   `Cloudflare Dashboard -> Manage Account -> Members -> Invite Member`
1. Instead of using your primary account to authenticate the tunnel,
   use your secondary account.

If your `cert.pem` file is compromised, you can revoke your
secondary account from your primary account.

## Securing access to Home Assistant

After your tunnel is setup and working, you may wish to add additional security
measures.

For example you could add a [WAF rule](https://developers.cloudflare.com/waf/) in
Cloudflare which blocks requests outside your country.

You can also use Cloudflare Access to present an authentication page before users
are able to access Home Assistant, see the
[self-hosted applications][self-hosted-applications] docs.

## Domain name and Cloudflare set up

To use this plugin, you need a domain name that is using Cloudflare for its
DNS entries.

### Domain name

If you do not already have a domain name, get one. You can get one at
[Freenom][freenom] following [this article][domainarticle].

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

[addon-installation]: https://github.com/brenner-tobias/addon-cloudflared#installation
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
