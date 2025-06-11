{{ if not .auto_https }}
{
	# Disable automatic generation of Let's Encrypt certificates
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

{{ range $i, $e := .additional_hosts }}
{{ $e.hostname }} {
	{{ if $e.internalOnly }}
	# Block connections from Cloudflared as service is internal only
	@cloudflared remote_ip 127.0.0.1
	handle @cloudflared {
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
{{ end }}

# Catch-all service for any unmatched requests
:80 {
	{{ if .catch_all_service }}
	{{ if hasPrefix "https://" .catch_all_service }}
	reverse_proxy {{ .catch_all_service }} {
		transport http {
			tls_insecure_skip_verify
		}
	}
	{{ else }}
	reverse_proxy {{ .catch_all_service }}
	{{ end }}
	{{ else }}
	respond "This service was not found." 404
	{{ end }}
}

{{ if .auto_https }}
# Only used during automatic Let's Encrypt certificate generation
https://{{ .ha_external_hostname }}.localhost {{ range $i, $e := .additional_hosts }}https://{{ $e.hostname }}.localhost {{ end }} {
    tls internal
    respond 407
}
{{ end }}
