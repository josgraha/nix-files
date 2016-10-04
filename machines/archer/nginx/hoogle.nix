ztip: ''
  server {
    listen ${ztip}:80;
    server_name hoogle.zero.monster.cat;

    location / {
      proxy_pass  http://localhost:8080;
      proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
      proxy_redirect off;
      proxy_buffering off;
      proxy_set_header        Host            $host;
      proxy_set_header        X-Real-IP       $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  }
''