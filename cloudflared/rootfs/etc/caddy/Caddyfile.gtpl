{
	# There is no need to attempt installing the root CA
	skip_install_trust
	{{ if not .auto_https }}
	# Disable automatic generation of Let's Encrypt certificates
	local_certs
	{{ end }}
}

# Allows to wait for Caddy to be ready before starting Cloudflared
https://healthcheck.localhost {
    tls internal
    respond "OK" 200
}

{{ .ha_external_hostname }} {
	@cloudflared remote_ip 127.0.0.1
	# https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/#caddy
	reverse_proxy @cloudflared {{ .ha_service_url }} {
		header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
		{{ if hasPrefix "https://" .ha_service_url }}
		transport http {
			tls_insecure_skip_verify
		}
		{{ end }}
	}
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
	@cloudflared remote_ip 127.0.0.1
	{{ if $e.internalOnly }}
	# Block connections from Cloudflared as service is internal only
	handle @cloudflared {
		respond "This service can only be accessed from local network." 403
	}
	{{ else }}
	# https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/#caddy
	reverse_proxy @cloudflared {{ $e.service }} {
		header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
		{{ if hasPrefix "https://" $e.service }}
		transport http {
			tls_insecure_skip_verify
		}
		{{ end }}
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
	@cloudflared remote_ip 127.0.0.1
	{{ if .catch_all_service }}
	# https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/#caddy
	reverse_proxy @cloudflared {{ .catch_all_service }} {
		header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
		{{ if hasPrefix "https://" .catch_all_service }}
		transport http {
			tls_insecure_skip_verify
		}
		{{ end }}
	}
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
