{{ if not .auto_https }}
{
	local_certs
}
{{ end }}
{{ .ha_external_hostname }} {
	{{ if .ha_ssl }}
	reverse_proxy https://homeassistant:{{ .ha_port }} {
		transport http {
			tls_insecure_skip_verify
		}
	}
	{{ else }}
	reverse_proxy http://homeassistant:{{ .ha_port }}
	{{ end }}
}
https://{{ .ha_external_hostname }}.localhost {
    tls internal
	respond 407
}
{{ range $i, $e := .additional_hosts }}
{{ $e.hostname }} {
	{{ if $e.internalOnly }}
	@localhost remote_ip 127.0.0.1
	handle @localhost {
		respond "This service can only be accessed from local network." 403
	}
	{{ end }}
	{{ if hasPrefix "https://" $e.service }}
	reverse_proxy {{ $e.service }} {
		transport http {
			tls_insecure_skip_verify
		}
	}
	{{ else }}
	reverse_proxy {{ $e.service }}
	{{ end }}
}
https://{{ $e.hostname }}.localhost {
    tls internal
    respond 407
}
{{ end }}
