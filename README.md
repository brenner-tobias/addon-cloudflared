# Home Assistant Add-on: Cloudflared

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE.md)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

[![Github Actions][github-actions-shield]][github-actions]
![Project Maintenance][maintenance-shield]

Connect remotely to your Home Assistant and other services, without opening ports
using Cloudflare Tunnel.

## About

Cloudflared connects your Home Assistant Instance via a secure tunnel to a domain
or subdomain at Cloudflare. This allows you to expose your Home Assistant
instance and other services to the Internet without opening ports on your router.
Additionally, you can utilize Cloudflare Zero Trust to further secure your
connection.

**To use this add-on, you have to own a domain name (e.g. example.com) that is
using Cloudflare for its DNS entries. You can find more information about that
in our [Wiki][wiki]**.

[:books: Read the full add-on documentation][docs]

## Disclaimer

Please make sure you comply with the
[Cloudflare Self-Serve Subscription Agreement][cloudflare-sssa] when using this
add-on.

## Installation

To install this add-on, manually add my HA-Addons repository to Home Assistant
using [this GitHub repository][ha-addons] or by clicking the button below.

[![Add Repository to HA][my-ha-badge]][my-ha-url]

## Support

Got questions?

Feel free to [open an issue here][issue] on GitHub.

## Author

[Tobias Brenner][tobias]

## License

MIT License

Copyright (c) 2023 Tobias Brenner

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

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-no-red.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[cloudflare-sssa]: https://www.cloudflare.com/terms/
[docs]: cloudflared/DOCS.md
[domainarticle]: https://www.linkedin.com/pulse/what-do-domain-name-how-get-one-free-tobias-brenner?trk=public_post-content_share-article
[github-actions-shield]: https://github.com/brenner-tobias/addon-cloudflared/workflows/CI/badge.svg
[github-actions]: https://github.com/brenner-tobias/addon-cloudflared//actions
[ha-addons]: https://github.com/brenner-tobias/ha-addons
[i386-shield]: https://img.shields.io/badge/i386-no-red.svg
[issue]: https://github.com/brenner-tobias/addon-cloudflared/issues
[license-shield]: https://img.shields.io/github/license/brenner-tobias/addon-cloudflared
[maintenance-shield]: https://img.shields.io/maintenance/yes/2023.svg
[project-stage-shield]: https://img.shields.io/badge/project%20stage-production%20ready-brightgreen.svg
[releases-shield]: https://img.shields.io/github/v/release/brenner-tobias/addon-cloudflared?include_prereleases
[releases]: https://github.com/brenner-tobias/addon-cloudflared/releases
[tobias]: https://github.com/brenner-tobias
[my-ha-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[my-ha-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fbrenner-tobias%2Fha-addons
[wiki]: https://github.com/brenner-tobias/addon-cloudflared/wiki/How-tos
