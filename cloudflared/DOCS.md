# Home Assistant Add-on: Cloudflared

Cloudflared connects your Home Assistant Instance via a secure tunnel to a domain
or subdomain at Cloudflare. Doing that, you can expose your Home Assitant to the
Internet without opening ports in your router. Additionally, you can utilize
Cloudflare Teams, their Zero Trust platform to further secure your Home Assistant
connection.

**To use this add-on you have to own a domain name (e.g. example.com) and use the
DNS servers of cloudflare.**

## Installation

The installation of this add-on is pretty straightforward but requires some prerequisites
and a manual step at the first set-up:

1. (Optional if you don't yet have a working Cloudflare set-up):
   Get a domain name and set-up Cloudflare. See section
   [Domain Name and Cloudlfare Set-Up](#domain-name-and-cloudlfare-set-up) for details.
1. Set the "external_hostname" add-on option with your domain name or a subdomain
   that you want to use to access Home Assistant.
1. (Optional) Change the "internal_ha_port" add-on option with the internal Port
   to reach Home Assistant in your network (default: 8123).
1. (Optional) Change the "tunnel_name" add-on option (default: homeassistant).
1. **Make sure that there is no DNS entry with your desired external hostname and
   no existing tunnel with your desired tunnel name at Cloudflare**.
1. Start the "Cloudflare" add-on.
1. Check the logs of the "Cloudflare" add-on and **follow the instruction to authenticate
   at cloudflare**.
   You need to copy a URL from the logs and visit it to authenticate.
1. A tunnel and a DNS entry will be created and show up in your cloudflare DNS /
   Teams dashboard.

## Configuration

**Note**: _Remember to restart the add-on when the configuration is changed._

Example add-on configuration:

```yaml
internal_ha_port: "8123"
external_hostname: "ha.example.com"
tunnel_name: homeassistant
```

**Note**: _This is just an example, don't copy and paste it! Create your own!_

### Configuration.yaml

Since HomeAssistant blocks requests via proxies or reverse proxies, you have to tell
your instance to allow requests from the Cloudflared Add-On. The add-on runs locally,
so HA hasto trust the docker network. In order to do so, add the following lines
to your /config/configuration.yaml (if you need assistance changing the config,
please follow the [Advanced Configuration Tutorial][advancedconfiguration]):

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

### Option: `reset_cloudflared_files`

In case you want to reset your cloudflared connection for some reason (e.g.
switch to another cloudflare account), you can reset all your local cloudflare
files by setting this option. After that, please start the app and check the logs.
The add-on should run through and let you know that all the files are deleted.
**After that, you have to unset the `reset_cloudflared_files` option again and restart
the add-on to start the onboarding process.**

### Option: `log_level`

The `log_level` option controls the level of log output by the addon and can
be changed to be more or less verbose, which might be useful when you are
dealing with an unknown issue. Possible values are:

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

## Domain Name and Cloudlfare Set-Up

To use this plugin, you need a domain name that is using Cloudflare for its
DNS entries.

### Domain Name

If you do not already have a domain name, get one. In case you dont want
to pay for a domain name, you can look for a free domain name at
[freenom][freenom].

### Cloudflare

Create a free Cloudflare Account at [cloudflare.com][cloudflare] and follow
the tutorial [Getting started with Cloudflare][cloudflaretutorial].

## Authors & contributors

The original setup of this repository is by [Tobias Brenner][tobias].

## License

MIT License

Copyright (c) 2021 Tobias Brenner

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
[freenom]: https://freenom.com
[tobias]: https://github.com/brenner-tobias
