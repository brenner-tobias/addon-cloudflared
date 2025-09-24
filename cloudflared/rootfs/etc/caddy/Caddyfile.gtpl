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

	# --- Special handling for log streams (SSE) via Cloudflare ---
	@hassioLogs {
		path_regexp hassioLogs ^/api/hassio/.+/logs/follow(?:/.*)?$
	}
	handle @hassioLogs {
		reverse_proxy {{ .ha_service_url }} {
			# Disable response buffering/aggregation to allow live log streaming
			flush_interval -1
			# Prevent upstream compression to keep stream intact
			header_up -Accept-Encoding
			header_down -Content-Encoding
			# Forward real client IP
			header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
			{{ if hasPrefix "https://" .ha_service_url }}
			# Allow self-signed certificates if needed
			transport http { tls_insecure_skip_verify }
			{{ end }}
		}
		# Set headers required for SSE log streaming
		header {
			defer
			Content-Type "text/event-stream; charset=utf-8"
			Cache-Control "no-store, no-cache, must-revalidate, no-transform"
			Pragma "no-cache"
			Connection "keep-alive"
		}
	}
	# --- End of special handling for log streams ---


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

		# --- Special handling for log streams (SSE) on internal hosts ---
		@hassioLogs {
			path_regexp hassioLogs ^/api/hassio/.+/logs/follow(?:/.*)?$
		}
		handle @hassioLogs {
			reverse_proxy {{ $e.service }} {
				# Disable response buffering/aggregation for real-time streaming
				flush_interval -1
				# Prevent upstream compression to maintain SSE stream integrity
				header_up -Accept-Encoding
				header_down -Content-Encoding
				# Forward real client IP
				header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
				{{ if hasPrefix "https://" $e.service }}
				# Allow self-signed certificates if necessary
				transport http { tls_insecure_skip_verify }
				{{ end }}
			}
			# Set required SSE headers after proxying
			header {
				defer
				Content-Type "text/event-stream; charset=utf-8"
				Cache-Control "no-store, no-cache, must-revalidate, no-transform"
				Pragma "no-cache"
				Connection "keep-alive"
			}
		}
		# --- End of special handling for log streams ---

	}
	{{ end }}
	reverse_proxy {{ $e.service }} {{ if hasPrefix "https://" $e.service }}{
		transport http {
			tls_insecure_skip_verify
		}
	}{{ end }}
}
{{ end }}
