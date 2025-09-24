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

# -------- snippets --------
# SSE response headers (no cache, event-stream)
(sse_headers) {
	header {
		defer
		Content-Type "text/event-stream; charset=utf-8"
		Cache-Control "no-store, no-cache, must-revalidate, no-transform"
		Pragma "no-cache"
	}
}

# Helper: rp — generic reverse proxy
# Note: if target is https://, TLS verify is skipped.
{{ define "rp" -}}
reverse_proxy {{ . }} {{ if hasPrefix "https://" . -}}{
	transport http { tls_insecure_skip_verify }
}{{- end }}
{{- end }}

# Helper: rp_sse — reverse proxy for Server-Sent Events
# Disables compression and forces flush for SSE.
{{ define "rp_sse" -}}
reverse_proxy {{ . }} {
	flush_interval -1
	header_up -Accept-Encoding
	header_down -Content-Encoding
	{{ if hasPrefix "https://" . -}}
	transport http { tls_insecure_skip_verify }
	{{- end }}
}
{{- end }}

# Helper: rp_cf — reverse proxy behind Cloudflared
# Adds real client IP from CF-Connecting-IP.
{{ define "rp_cf" -}}
reverse_proxy {{ . }} {
	header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
	{{ if hasPrefix "https://" . -}}
	transport http { tls_insecure_skip_verify }
	{{- end }}
}
{{- end }}

# Helper: rp_sse_cf — SSE proxy behind Cloudflared
# Combines SSE settings with CF client IP forwarding.
{{ define "rp_sse_cf" -}}
reverse_proxy {{ . }} {
	flush_interval -1
	header_up -Accept-Encoding
	header_down -Content-Encoding
	header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
	{{ if hasPrefix "https://" . -}}
	transport http { tls_insecure_skip_verify }
	{{- end }}
}
{{- end }}

# ==================== Home Assistant host ====================
{{ .ha_external_hostname }} {
	route {
		@cf remote_ip 127.0.0.1
		@sse path_regexp sse ^/api/hassio/.+/logs/follow(?:/.*)?$
		@cf_sse {
			remote_ip 127.0.0.1
			path_regexp sse ^/api/hassio/.+/logs/follow(?:/.*)?$
		}
		@local_sse {
			not remote_ip 127.0.0.1
			path_regexp sse ^/api/hassio/.+/logs/follow(?:/.*)?$
		}

		# SSE via Cloudflare
		handle @cf_sse {
			reverse_proxy {{ .ha_service_url }} {
				flush_interval -1
				header_up -Accept-Encoding
				header_down -Content-Encoding
				header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
				{{ if hasPrefix "https://" .ha_service_url }}transport http { tls_insecure_skip_verify }{{ end }}
			}
			header {
				defer
				Content-Type "text/event-stream; charset=utf-8"
				Cache-Control "no-store, no-cache, must-revalidate, no-transform"
				Pragma "no-cache"
			}
		}

		# SSE (local/direct)
		handle @local_sse {
			reverse_proxy {{ .ha_service_url }} {
				flush_interval -1
				header_up -Accept-Encoding
				header_down -Content-Encoding
				{{ if hasPrefix "https://" .ha_service_url }}transport http { tls_insecure_skip_verify }{{ end }}
			}
			header {
				defer
				Content-Type "text/event-stream; charset=utf-8"
				Cache-Control "no-store, no-cache, must-revalidate, no-transform"
				Pragma "no-cache"
			}
		}

		# Other routes via Cloudflare
		handle @cf {
			reverse_proxy {{ .ha_service_url }} {
				header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
				{{ if hasPrefix "https://" .ha_service_url }}transport http { tls_insecure_skip_verify }{{ end }}
			}
		}

		# Fallback: direct proxy
		handle {
			reverse_proxy {{ .ha_service_url }} {{ if hasPrefix "https://" .ha_service_url }}{
				transport http { tls_insecure_skip_verify }
			}{{ end }}
		}
	}
}
