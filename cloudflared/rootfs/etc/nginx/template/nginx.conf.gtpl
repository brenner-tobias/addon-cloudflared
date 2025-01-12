daemon off;
error_log stderr;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    map_hash_bucket_size 128;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    server_tokens off;

    server_names_hash_bucket_size 128;

    server {

        listen 8321;

        proxy_buffering off;

        location / {
            proxy_pass http://homeassistant:{{ .port }};
            proxy_set_header Host $http_host;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header X-Forwarded-Host $http_host;
        }

        location ~ /api/hassio/.*/logs {
            proxy_pass http://homeassistant:{{ .port }};
            proxy_set_header Host $http_host;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_cache off;
            proxy_buffering off;
            proxy_hide_header Content-Type;
            add_header Content-Type "text/event-stream";
        }
    }

}