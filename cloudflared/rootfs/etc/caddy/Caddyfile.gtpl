{{ if not .auto_https }}
{
	local_certs
}
{{ end }}
{{ .ha_external_hostname }} {
	{{ if hasPrefix "https://" .ha_service_url }}
	reverse_proxy {{ .ha_service_url }} {
		transport http {
			tls_insecure_skip_verify
		}
	}
	{{ else }}
	reverse_proxy {{ .ha_service_url }}
	{{ end }}
}
https://{{ .ha_external_hostname }}.localhost {
    tls internal
	respond 407
}
{{ range $i, $e := .additional_hosts }}
{{ $e.hostname }} {
	{{ if $e.internalOnly }}
	# Block connections from Cloudflared as service is internal only
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
:80 {
	{{ if .catch_all_service }}
	reverse_proxy {{ .catch_all_service }}
	{{ else }}
	respond "This service was not found." 404
	{{ end }}
}
