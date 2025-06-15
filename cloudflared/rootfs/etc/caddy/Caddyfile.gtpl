{
	# We don't use the admin API
	admin off
	# There is no need to persist the generate json configuration
	persist_config off
	# There is no need to attempt installing the root CA
	skip_install_trust
	{{ if not .auto_https }}
	# Disable automatic generation of Let's Encrypt certificates
	local_certs
	{{ end }}
	log {
		# More friendly logging format than the default json
		format console
	}
}

# Used for communication between Cloudflared and Caddy
https://caddy.localhost {
    tls internal

	# Used to ensure Caddy is ready before starting Cloudflared
	respond /healthz 200

	respond 403
}

{{ .ha_external_hostname }} {
	@cloudflared remote_ip 127.0.0.1

	reverse_proxy @cloudflared {{ .ha_service_url }} {
		# https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/#caddy
		header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
		{{ if hasPrefix "https://" .ha_service_url }}
		transport http {
			tls_insecure_skip_verify
		}
		{{ end }}
	}

	reverse_proxy {{ .ha_service_url }} {{ if hasPrefix "https://" .ha_service_url }}{
		transport http {
			tls_insecure_skip_verify
		}
	}{{ end }}
}

{{ range $i, $e := .additional_hosts }}
{{ $e.hostname }} {
	@cloudflared remote_ip 127.0.0.1
	{{ if $e.internalOnly }}
	# Block connections from Cloudflared as service is internal only
	handle @cloudflared {
		respond 403
	}
	{{ else }}
	reverse_proxy @cloudflared {{ $e.service }} {
		header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
		{{ if hasPrefix "https://" $e.service }}
		transport http {
			tls_insecure_skip_verify
		}
		{{ end }}
	}
	{{ end }}
	reverse_proxy {{ $e.service }} {{ if hasPrefix "https://" $e.service }}{
		transport http {
			tls_insecure_skip_verify
		}
	}{{ end }}
}
{{ end }}

# Catch-all service for any unmatched requests within the same base domain coming from Cloudflared
{{ $baseDomain := splitList "." .ha_external_hostname }}
{{ $baseDomain = slice $baseDomain (sub (len $baseDomain) 2) | join "." }}
https://*.{{ $baseDomain }} {
	tls internal

	@cloudflared remote_ip 127.0.0.1
	handle @cloudflared {
		{{ if .catch_all_service }}
		reverse_proxy {{ .catch_all_service }} {
			header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
			{{ if hasPrefix "https://" .catch_all_service }}
			transport http {
				tls_insecure_skip_verify
			}
			{{ end }}
		}
		{{ else }}
		respond 404
		{{ end }}
	}

	handle {
    	abort
	}
}
