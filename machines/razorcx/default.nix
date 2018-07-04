extra:
{ config, lib, pkgs, ... }:
let gitExtra = {
      git = {projectroot = "/var/git";};
      host = "git.razorcx.com";
    };
    gitCfg = extra.git-server { inherit config pkgs; extra = extra // gitExtra; };
    myemail = "will@razorcx.com";

    endpoints = {
      backend =
        { host = "backend.razorcx.com";
          port = "5852";
        };

      backend-staging =
        { host = "backend-staging.razorcx.com";
          port = "6721";
        };

      stagingapi =
        { host = "apistaging.razorcx.com";
          port = "5000";
        };

      assets =
        { host = "assets.razorcx.com";
        };

      bostaging = rec
        { host = "bostaging.razorcx.com";
          repo = pkgs.fetchgit {
            url = "http://git.razorcx.com/backoffice";
            rev = "9e218c66bd436dd2ad5b0d35316968ae977b2dd6";
            sha256 = "1xhyz11zk2xbkk0s6xgh0xy26pzvslmvryp45p387h9n77jbnvan";
          };
          pkg  = import "${repo}/release.nix";
        };
    };

    razorcx-api-staging = (pkgs.callPackage /home/jb55/RazorCX { }).razorcx-api-staging;

    razorrec-dotnet-json = lib.importJSON /var/git/razorrec-dotnet/deploy.json;
    razorrec-dotnet = (pkgs.callPackage (import (pkgs.fetchgit razorrec-dotnet-json)) {}).razorcx-recommender;

    certGroup = "certs";
    node-processor-json = lib.importJSON /var/git/razorrec/deploy.json;
    node-processor = (import (pkgs.fetchgit node-processor-json) {}).package;
    httpipePort = "8899";
    httpiped = (import (pkgs.fetchgit {
      url = https://github.com/jb55/httpipe;
      rev = "05d97c628e3be08db83dc29a80c7ea02a78bbf81";
      sha256 = "0iy5wdb1jjx9xz90hpnrxk3h7nq0fnv5dqvmg1ac6cxs1823yh7c";
    }) {}).package;
in
{
  imports = [
    ./networking
    ./hardware
  ];

  networking.domain = endpoints.backend.host;
  networking.search = [ endpoints.backend.host ];
  networking.extraHosts = ''
    127.0.0.1 ${endpoints.backend.host}
    ::1 ${endpoints.backend.host}
  '';

  networking.firewall.allowedTCPPorts = [ 22 443 80 ];
  networking.firewall.trustedInterfaces = ["zt0"];

  users.extraGroups.certs.members = [ "nginx" ];

  security.acme.certs."${endpoints.backend.host}" = {
    webroot = "/var/www/challenges";
    allowKeysForGroup = true;
    group = "certs";
    email = myemail;
  };

  security.acme.certs."${endpoints.backend-staging.host}" = {
    webroot = "/var/www/challenges";
    allowKeysForGroup = true;
    group = "certs";
    email = myemail;
  };

  security.acme.certs."${endpoints.stagingapi.host}" = {
    webroot = "/var/www/challenges";
    allowKeysForGroup = true;
    group = "certs";
    email = myemail;
  };

  #security.acme.certs."${endpoints.assets.host}" = {
  #  webroot = "/var/www/challenges";
  #  allowKeysForGroup = true;
  #  group = "certs";
  #  email = myemail;
  #};

  security.acme.certs."${endpoints.bostaging.host}" = {
    webroot = "/var/www/challenges";
    allowKeysForGroup = true;
    group = "certs";
    email = myemail;
  };

  security.acme.certs."clientstaging.razorcx.com" = {
    webroot = "/var/www/challenges";
    allowKeysForGroup = true;
    group = "certs";
    email = myemail;
  };

  services.fcgiwrap.enable = true;
  services.postgresql = {
    dataDir = "/var/db/postgresql/10/";
    enable = true;
    package = pkgs.postgresql100;
    authentication = ''
      # type db  user address          method
      local  all all                            trust
      host   all all 127.0.0.1/32               trust
      host   all all ${extra.machine.zt.ip}/8  trust
    '';
    extraConfig = ''
      listen_addresses = '127.0.0.1,${extra.machine.zt.ip},${extra.machine.zt.ipv6}'
    '';
  };

  systemd.services.node-processor = {
    description = "node-processor";
    wantedBy = [ "multi-user.target" ];
    after    = [ "multi-user.target" ];
    path = with pkgs; [ node-processor ];
    environment = {
      RAZORCX_JWT_SECRET = "RazorCx_8CFB2EC534E14D56";
      NODEPROCPORT = endpoints.backend.port;
      PGDATABASE = "razorcx";
      DEBUG = "razorrec:sql";
      PGUSER = "jb55";
      # WARNING: development turns off authentication
      NODE_ENV = "production";
    };
    serviceConfig.Restart = "always";
    serviceConfig.ExecStart = "${node-processor}/bin/node-processor";
  };

  systemd.services.backend-staging = {
    description = "backend-staging";
    wantedBy = [ "multi-user.target" ];
    after    = [ "multi-user.target" ];
    path = with pkgs; [ razorrec-dotnet ];
    environment = {
      PORT = endpoints.backend-staging.port;
      PGHOST = "localhost";
      PGDATABASE = "razorcx";
      PGUSER = "jb55";
    };
    serviceConfig.Restart = "always";
    serviceConfig.ExecStart = "${razorrec-dotnet}/bin/RazorCx.Recommender.API-Release";
  };

  systemd.services.razorcx-api-staging = {
    description = "RazorCx.Api-Staging";
    wantedBy = [ "multi-user.target" ];
    after    = [ "multi-user.target" ];
    #serviceConfig.Restart = "always";
    serviceConfig.ExecStart = "${razorcx-api-staging}/bin/RazorCx.Api-Staging";
    serviceConfig.WorkingDirectory = "${razorcx-api-staging}/bin";
  };

  systemd.services.httpiped = {
    description = "httpiped";
    wantedBy = [ "multi-user.target" ];
    after    = [ "multi-user.target" ];
    environment = {
      PORT = httpipePort;
    };
    serviceConfig.Restart = "always";
    serviceConfig.ExecStart = "${httpiped}/bin/httpiped";
  };


  # TODO: update to security programs
  #security.wrappers = {
  #  sendmail =
  #}

  services.nginx.enable = true;
  services.zerotierone.enable = true;

  services.nginx.httpConfig = ''
    server {
        listen       80  default_server;
        server_name  _;
        return 301   http://razorcx.com;
    }

    server {
      listen       ${extra.machine.zt.ip}:80;
      listen       [${extra.machine.zt.ipv6}]:80;
      server_name  ${endpoints.assets.host};

      location /.well-known/acme-challenge {
        root /var/www/challenges;
      }

      location /  {
        autoindex on;
        root /home/assets/files;
      }
    }

    # server {
    #   listen       443 ssl;
    #   server_name  ${endpoints.assets.host};
    #   location /  {
    #     autoindex on;
    #     root /home/assets/files;
    #   }
    #   ssl_certificate /var/lib/acme/${endpoints.assets.host}/fullchain.pem;
    #   ssl_certificate_key /var/lib/acme/${endpoints.assets.host}/key.pem;
    # }

    server {
      listen 80;
      server_name ${endpoints.bostaging.host};

      location /.well-known/acme-challenge {
        root /var/www/challenges;
      }

      location / {
        return 301 https://${endpoints.bostaging.host}$request_uri;
      }
    }

    server {
      listen 80;
      server_name ${endpoints.backend-staging.host};

      location /.well-known/acme-challenge {
        root /var/www/challenges;
      }

      location / {
        return 301 https://${endpoints.backend-staging.host}$request_uri;
      }
    }


    server {
      listen 80;
      server_name ${endpoints.backend.host};

      location /.well-known/acme-challenge {
        root /var/www/challenges;
      }

      location / {
        return 301 https://${endpoints.backend.host}$request_uri;
      }
    }

    server {
      listen 80;
      server_name ${endpoints.stagingapi.host};

      location /.well-known/acme-challenge {
        root /var/www/challenges;
      }

      location / {
        return 301 https://${endpoints.stagingapi.host}$request_uri;
      }
    }

    server {
      listen       ${extra.machine.zt.ip}:80;
      listen       [${extra.machine.zt.ipv6}]:80;
      server_name  logs.razorcx.com;


      location / {
        proxy_max_temp_file_size 0;
        client_max_body_size 0;
        proxy_request_buffering off;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_pass http://localhost:${httpipePort};

        add_header X-Content-Type-Options nosniff;
      }
    }

    server {
      listen       443 ssl;
      server_name  ${endpoints.stagingapi.host};

      gzip on;
      gzip_min_length 1000;
      gzip_proxied no-cache no-store private expired auth;
      gzip_types text/plain application/json;

      location / {
        proxy_pass http://localhost:${endpoints.stagingapi.port};
      }

      ssl_certificate /var/lib/acme/${endpoints.stagingapi.host}/fullchain.pem;
      ssl_certificate_key /var/lib/acme/${endpoints.stagingapi.host}/key.pem;
    }

    server {
      listen       80;
      server_name  clientstaging.razorcx.com;

      location /.well-known/acme-challenge {
        root /var/www/challenges;
      }

      location / {
        return 301 https://clientstaging.razorcx.com$request_uri;
      }
    }

    server {
      listen       443 ssl;
      server_name  clientstaging.razorcx.com;

      location / {
        return 301 https://${endpoints.bostaging.host}$request_uri;
      }

      ssl_certificate /var/lib/acme/clientstaging.razorcx.com/fullchain.pem;
      ssl_certificate_key /var/lib/acme/clientstaging.razorcx.com/key.pem;
    }

    server {
      listen       443 ssl;
      server_name  ${endpoints.bostaging.host};

      gzip on;
      gzip_min_length 1000;
      gzip_proxied no-cache no-store private expired auth;
      gzip_types text/plain application/json;

      location / {
        root ${endpoints.bostaging.pkg}/bin;

        try_files \'\' /index.html =404;
      }

      location ~ \..*$ {
        root ${endpoints.bostaging.pkg}/bin;
      }

      ssl_certificate /var/lib/acme/${endpoints.bostaging.host}/fullchain.pem;
      ssl_certificate_key /var/lib/acme/${endpoints.bostaging.host}/key.pem;
    }

    server {
      listen       443 ssl;
      server_name  ${endpoints.backend-staging.host};

      gzip on;
      gzip_min_length 1000;
      gzip_proxied no-cache no-store private expired auth;
      gzip_types text/plain application/json;

      location / {
        proxy_pass http://localhost:${endpoints.backend-staging.port}/;
      }

      ssl_certificate /var/lib/acme/${endpoints.backend-staging.host}/fullchain.pem;
      ssl_certificate_key /var/lib/acme/${endpoints.backend-staging.host}/key.pem;
    }

    server {
      listen       443 ssl;
      server_name  ${endpoints.backend.host};

      gzip on;
      gzip_min_length 1000;
      gzip_proxied no-cache no-store private expired auth;
      gzip_types text/plain application/json;

      location = / {
        return 301  http://razorcx.com;
      }

      location = /np {
        return 302 /np/;
      }

      location /np/  {
        proxy_pass http://localhost:${endpoints.backend.port}/;
      }

      ssl_certificate /var/lib/acme/${endpoints.backend.host}/fullchain.pem;
      ssl_certificate_key /var/lib/acme/${endpoints.backend.host}/key.pem;
    }

    ${gitCfg}
  '';

}
