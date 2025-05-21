{{ .ha_external_hostname }}.internal {
    tls internal
	reverse_proxy http://homeassistant:{{ .ha_port }}
}
{{ .ha_external_hostname }} {
	reverse_proxy http://homeassistant:{{ .ha_port }}
}
{{ range $i, $e := .additional_hosts }}
{{ $e.hostname }}.internal {
    tls internal
    reverse_proxy {{ $e.service }}
}
{{ $e.hostname }} {
    reverse_proxy {{ $e.service }}
}
{{ end }}
