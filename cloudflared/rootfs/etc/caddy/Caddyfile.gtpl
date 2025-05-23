{{ .ha_external_hostname }} {
  reverse_proxy http://homeassistant:{{ .ha_port }}
}
{{ range $i, $e := .additional_hosts -}}
{{ $e.hostname }} {
  {{ if $e.internalOnly -}}
  @localhost remote_ip 127.0.0.1
  handle @localhost {
    respond "This service can only be accessed from the local network." 403
  }
  {{- end }}
  reverse_proxy {{ $e.service }}
}
{{ end }}
