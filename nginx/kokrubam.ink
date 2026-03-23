server {
    listen 443 ssl;
    server_name kokrubam.ink www.kokrubam.ink;

    ssl_certificate     /etc/ssl/cloudflare/kokrubam.ink.pem;
    ssl_certificate_key /etc/ssl/cloudflare/kokrubam.ink-key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name kokrubam.ink www.kokrubam.ink;
    return 301 https://$host$request_uri;
}
