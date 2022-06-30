name: Report an issue with Home Assistant Add-On Cloudflared
description: Report an issue with Home Assistant Add-On Cloudflared.
body:

- type: markdown
  attributes:
  value: |
  This issue form is for reporting bugs only!
- type: textarea
  validations:
  required: true
  attributes:
  label: The problem
  description: >-
  Describe the issue you are experiencing here, to communicate to the
  maintainers. Tell us what you were trying to do and what happened.

      Provide a clear and concise description of what the problem is.

- type: markdown
  attributes:
  value: | ## Environment
- type: input
  id: version
  validations:
  required: true
  attributes:
  label: What version of Cloudflared has the issue?
  placeholder: 2.x.x
  description: >
  Can be found in: [Settings -> Add-Ons -> Cloudflared](https://my.home-assistant.io/redirect/supervisor_addon/?addon=9074a9fa_cloudflared).
- type: input
  attributes:
  label: What was the last working version of Cloudflared?
  placeholder: 2.x.x
  description: >
  If known, otherwise leave blank.
- type: dropdown
  validations:
  required: true
  attributes:
  label: What type of installation are you running?
  description: >
  Can be found in: [Settings -> System -> System Health](https://my.home-assistant.io/redirect/system_health/).
  options: - Home Assistant OS - Home Assistant Supervised - Other
- type: markdown
  attributes:
  value: | # Details
- type: textarea
  attributes:
  label: Add-on YAML Configuration
  description: |
  Please provide your whole add-on configuration as YAML, you can hide any sensitive information.
  render: yaml
- type: textarea
  attributes:
  label: Anything in the logs that might be useful for us?
  description: Copy and paste the complete log.
  render: txt
- type: textarea
  validations:
  required: true
  attributes:
  label: Steps to reproduce the issue
  description: |
  Please tell us exactly how to reproduce your issue.
  Provide clear and concise step by step instructions and add code snippets if needed.
  value: | 1. 2. 3.
  ...
- type: textarea
  attributes:
  label: Additional information
  description: >
  If you have any additional information for us, use the field below.
