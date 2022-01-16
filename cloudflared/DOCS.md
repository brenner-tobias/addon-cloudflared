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

**Before starting, please make sure to remove all other add-ons or configuration
entries handling SSL certificates, domain names and so on (e.g. DuckDNS) and
restart your HomeAssistant instance.**

1. (Optional if you don't yet have a working Cloudflare set-up):
   Get a domain name and set-up Cloudflare. See section
   [Domain Name and Cloudlfare Set-Up](#domain-name-and-cloudlfare-set-up) for details.
1. Set the `additional_hosts` add-on option with your domain name or a subdomain
   that you want to use to access Home Assistant.
1. (Optional) Change the "tunnel_name" add-on option (default: homeassistant).
1. **Make sure that there is no DNS entry with your desired external hostname and
   no existing tunnel with your desired tunnel name at Cloudflare**.
1. Start the "Cloudflare" add-on.
1. Check the logs of the "Cloudflare" add-on and **follow the instruction to authenticate
   at Cloudflare**.
   You need to copy a URL from the logs and visit it to authenticate.
1. A tunnel and a DNS entry will be created and show up in your Cloudflare DNS /
   Teams dashboard.

## Configuration

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
  - hostname: "diskstation.example.com"
    service: "http://192.168.1.5"
  - hostname: "website.example.com"
    service: "http://192.168.1.2"
nginxproxymanager: true
log_level: "debug"
```

**Note**: _This is just an example, don't copy and paste it! Create your own!_

### Configuration.yaml

Since HomeAssistant blocks requests via proxies or reverse proxies, you have to tell
your instance to allow requests from the Cloudflared Add-On. The add-on runs locally,
so HA has to trust the docker network. In order to do so, add the following lines
to your /config/configuration.yaml and restart your HA instance.
(if you need assistance changing the config, please follow the
[Advanced Configuration Tutorial][advancedconfiguration]):

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

### Option: `additional_hosts`

You can use the internal reverse proxy of Cloudflare Tunnel to define additional
hosts next to home assistant. That way, you can use the tunnel to also access
other systems like a diskstation, router or anything else.

Like with the `external_hostname` of HomeAssistant, DNS entries at will be
automatically created at Cloudflare.

Please find below an examplary entry for two additional hosts:

```yaml
additional_hosts:
  - hostname: "diskstation.example.com"
    service: "http://192.168.1.2"
  - hostname: "router.example.com"
    service: "http://192.168.1.1"
```

**Note**: _If you delete a hostname from the list, it will not be served
anymore (the request will run agains the default route). Nevertheless,
you should also manually delete the DNS entry from Cloudflare since it can not
be deleted by the Add-On._

### Option: `nginxproxymanager`

If you want to use the Cloudflare Tunnel with the Add-On
[Nginx Proxy Manager][nginxproxymanager], you can do so by setting this option.

```yaml
nginxproxymanager: true
```

**Note**: _This will still route your defined `external_hostname`to HomeAssistant
as well as any potential `additional_hosts` to where you defined in the config.
Any other incoming traffic will be routed to Nginx Proxy Manager._

In order to route multiple sub-domains through the tunnel, you have to create individual
CNAME records in Cloudflare for all of them, pointing to your `external_hostname`
(or directly to the tunnel URL that you can get from the CNAME entry of
`external_hostname`).

Finally, you have to set-up your proxy hosts in Nginx Proxy Manager and forward
them to wherever you like.

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

## Domain Name and Cloudlfare Set-Up

To use this plugin, you need a domain name that is using Cloudflare for its
DNS entries.

### Domain Name

If you do not already have a domain name, get one.

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
[cloudflaretutorial]: https://support.cloudflare.com/hc/en-us/articles/360027989951-Getting-Started-with-Cloudflare
[domainarticle]: https://www.linkedin.com/pulse/what-do-domain-name-how-get-one-free-tobias-brenner?trk=public_post-content_share-article
[freenom]: https://freenom.com
[nginxproxymanager]: https://github.com/hassio-addons/addon-nginx-proxy-manager
[tobias]: https://github.com/brenner-tobias
