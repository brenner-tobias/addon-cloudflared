server {

    listen 8321;

    set_real_ip_from 127.0.0.1;
    real_ip_header CF-Connecting-IP;

    include /etc/nginx/includes/server_params.conf;
    include /etc/nginx/includes/proxy_params.conf;



    location / {
        {{- if not .ssl }}
        proxy_pass http://homeassistant:{{ .port }};
        {{- else }}
        proxy_pass https://homeassistant:{{ .port }};
        proxy_ssl_verify        off;
        {{- end }}
        # proxy_set_header X-Forwarded-Host $http_host;
    }

    location ~ /api/hassio/.*/logs.*/follow {
        {{- if not .ssl }}
        proxy_pass http://homeassistant:{{ .port }};
        {{- else }}
        proxy_pass https://homeassistant:{{ .port }};
        proxy_ssl_verify        off;
        {{- end }}
        # proxy_set_header X-Forwarded-Host $http_host;
        proxy_read_timeout 1d;
        proxy_cache off;
        proxy_hide_header Content-Type;
        add_header Content-Type "text/event-stream";
    }
}
