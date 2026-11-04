{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    generators
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    types
    ;

  cfg = config.services.flyspray;

  defaultPHPCfg = {
    "output_buffering" = 0;
    "error_reporting" = "E_ALL & ~E_DEPRECATED & ~E_STRICT";
    "opcache.enable_cli" = 1;
    "opcache.interned_strings_buffer" = 8;
    "opcache.max_accelerated_files" = 6144;
    "opcache.memory_consumption" = 128;
    "opcache.revalidate_freq" = 2;
    "opcache.fast_shutdown" = 1;
  };

  phpCfg = generators.toKeyValue { mkKeyValue = generators.mkKeyValueDefault { } " = "; } (
    defaultPHPCfg // cfg.phpCfg
  );

  package =
    let
      p = cfg.package.override (
        {
          inherit phpCfg;
        }
        // lib.optionalAttrs (cfg.database.type == "postgresql") {
          withPostgreSQL = true;
        }
        // lib.optionalAttrs (cfg.database.type == "mariadb") {
          withMariaDB = true;
        }
      );
    in
    p.overrideAttrs (
      finalAttrs: prevAttrs:
      let
        flysprayDir = "$out/share/php/flyspray";
        stateDirectories = # sh
          ''
            rm -rf ${flysprayDir}/{cache,attachments,avatars,flyspray.conf.php}
            ln -s ${cfg.dataDir}/cache ${flysprayDir}/cache
            ln -s ${cfg.dataDir}/attachments ${flysprayDir}/attachments
            ln -s ${cfg.dataDir}/avatars ${flysprayDir}/avatars
            ln -s ${cfg.dataDir}/flyspray.conf.php ${flysprayDir}/flyspray.conf.php
            ln -s ${cfg.logDir} ${flysprayDir}/log
          '';
      in
      {
        postInstall = (prevAttrs.postInstall or "") + "\n" + stateDirectories;
      }
    );

  pool = "flyspray";
  fpm = config.services.phpfpm.pools.${pool};

  dbUnit =
    {
      "postgresql" = "postgresql.target";
      "mariadb" = "mysql.service";
    }
    .${cfg.database.type};

  webServerService =
    if cfg.h2o != null then
      "h2o.service"
    else if cfg.nginx != null then
      "nginx.service"
    else
      null;

  socketOwner =
    if cfg.h2o != null then
      config.services.h2o.user
    else if cfg.nginx != null then
      config.services.nginx.user
    else
      cfg.user;

  flysprayDir = "${package}/share/php/flyspray";
in
{
  options.services = {
    flyspray = {
      enable = mkEnableOption "a Flyspray instance";
      package = mkPackageOption pkgs "flyspray" { };

      phpPackage = mkPackageOption pkgs "php" { };

      phpCfg = mkOption {
        type =
          with types;
          attrsOf (oneOf [
            int
            str
            bool
          ]);
        defaultText = literalExpression (generators.toPretty { } defaultPHPCfg);
        default = { };
        description = "Extra PHP INI options such as `memory_limit`, `max_execution_time`, & so on.";
      };

      user = mkOption {
        type = types.nonEmptyStr;
        default = "flyspray";
        description = "User running Flyspray service.";
      };

      group = mkOption {
        type = types.nonEmptyStr;
        default = "flyspray";
        description = "Group running Flyspray service.";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/flyspray";
        description = "State directory of the `flyspray` user which holds the application’s state & data.";
      };

      logDir = mkOption {
        type = types.path;
        default = "/var/log/flyspray";
        description = "Log directory of the `flyspray` user which holds the application’s logs.";
      };

      domain = mkOption {
        type = types.nonEmptyStr;
        description = "Fully-qualified domain name (FQDN) for the Flyspray instance.";
      };

      database = {
        type = mkOption {
          type = types.enum [
            "mariadb"
            "postgresql"
          ];
          example = "postgresql";
          default = "postgresql";
          description = "Database engine to use.";
        };

        name = mkOption {
          type = types.nonEmptyStr;
          default = "flyspray";
          description = "Database name.";
        };

        user = mkOption {
          type = types.nonEmptyStr;
          default = "flyspray";
          description = "Database username.";
        };

        createLocally = mkOption {
          type = types.bool;
          default = true;
          description = "Create local database using UNIX socket authentication.";
        };
      };

      nginx = mkOption {
        type = types.nullOr (
          types.submodule (import ../web-servers/nginx/vhost-options.nix { inherit config lib; })
        );
        default = null;
        example = lib.literalExpression /* nix */ ''
          {
            enableACME = true;
            forceHttps = true;
          }
        '';
        description = ''
          With this option, you can customize an Nginx virtual host which
          already has sensible defaults for Flyspray. Set to `{ }` if you do
          not need any customization to the virtual host. If enabled, then by
          default, the {option}`serverName` is `''${cfg.domain}`, If this is
          set to `null` (the default), no Nginx `virtualHost` will be
          configured.
        '';
      };

      h2o = mkOption {
        type = types.nullOr (
          types.submodule (import ../web-servers/h2o/vhost-options.nix { inherit config lib; })
        );
        default = null;
        example = lib.literalExpression /* nix */ ''
          {
            acme.enable = true;
            tls.policy = "force";
          }
        '';
        description = ''
          With this option, you can customize an H2O virtual host which already
          has sensible defaults for Flyspray. Set to `{ }` if you do not need
          any customization to the virtual host. If enabled, then by default,
          the {option}`serverName` is `''${cfg.domain}`, If this is set to
          `null` (the default), no H2O `hosts` will be configured.
        '';
      };

      poolConfig = mkOption {
        type =
          with types;
          attrsOf (oneOf [
            int
            str
            bool
          ]);
        default = { };
        description = "Options for Flyspray’s PHP-FPM pool.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (
        let
          webServers = [
            "h2o"
            "nginx"
          ];
          checkConfigs = lib.concatMapStringsSep ", " (ws: "services.flyspray.${ws}") webServers;
        in
        {
          assertion = builtins.length (lib.lists.filter (ws: cfg.${ws} != null) webServers) <= 1;
          message = ''
            At most 1 web server virtual host configuration should be enabled
            for Flyspray at a time. Check ${checkConfigs}.
          '';
        }
      )
    ];

    environment.systemPackages = [ package ];

    users = {
      users = {
        flyspray = mkIf (cfg.user == "flyspray") {
          isSystemUser = true;
          group = cfg.group;
        };
      }
      // lib.optionalAttrs (cfg.h2o != null) {
        "${config.services.h2o.user}".extraGroups = [ cfg.group ];
      }
      // lib.optionalAttrs (cfg.nginx != null) {
        "${config.services.nginx.user}".extraGroups = [ cfg.group ];
      };
      groups = {
        ${cfg.group} = { };
      };
    };

    services = {
      flyspray = {
        poolConfig = {
          "pm" = lib.mkDefault "dynamic";
          "php_admin_value[error_log]" = lib.mkDefault "stderr";
          "php_admin_flag[log_errors]" = lib.mkDefault true;
          "catch_workers_output" = lib.mkDefault true;
          "pm.max_children" = lib.mkDefault 32;
          "pm.start_servers" = lib.mkDefault 2;
          "pm.min_spare_servers" = lib.mkDefault 2;
          "pm.max_spare_servers" = lib.mkDefault 8;
          "pm.max_requests" = lib.mkDefault 500;
        };
      };

      h2o = mkIf (cfg.h2o != null) {
        enable = mkDefault true;
        hosts."${cfg.domain}" = mkMerge [
          {
            settings = {
              paths = {
                "/" = {
                  "file.dir" = flysprayDir;
                  "file.index" = [
                    "index.php"
                    "index.html"
                  ];
                  redirect = {
                    url = "/index.php/";
                    internal = "YES";
                    status = 307;
                  };
                };
              };
              "file.custom-handler" = {
                extension = [ ".php" ];
                "fastcgi.document_root" = flysprayDir;
                "fastcgi.connect" = {
                  port = fpm.socket;
                  type = "unix";
                };
              };
            };
          }
          cfg.h2o
        ];
      };

      nginx = mkIf (cfg.nginx != null) {
        enable = mkDefault true;
        recommendedOptimisation = mkDefault true;
        recommendedProxySettings = true;
        virtualHosts."${cfg.domain}" = mkMerge [
          cfg.nginx
          {
            root = lib.mkForce flysprayDir;
            locations = {
              "/favicon.ico" = {
                priority = 100;
                extraConfig = /* nginx */ ''
                  access_log off;
                  log_not_found off;
                '';
              };
              "/robots.txt" = {
                priority = 100;
                extraConfig = /* nginx */ ''
                  access_log off;
                  log_not_found off;
                '';
              };
              "~ /\\.(?!well-known).*" = {
                priority = 210;
                extraConfig = /* nginx */ ''
                  deny all;
                '';
              };
              "/" = {
                priority = 490;
                tryFiles = "$uri $uri/ /index.php$is_args$args";
              };
              "~ \\.php$" = {
                priority = 500;
                tryFiles = "$uri =404";
                extraConfig = /* nginx */ ''
                  include ${config.services.nginx.package}/conf/fastcgi.conf;
                  fastcgi_split_path_info ^(.+\.php)(/.+)$;
                  fastcgi_index index.php;
                  fastcgi_pass unix:${fpm.socket};
                '';
              };
            };
            extraConfig = /* nginx */ ''
              index index.php;
            '';
          }
        ];
      };

      mysql = mkIf (cfg.database.createLocally && cfg.database.type == "mariadb") {
        enable = mkDefault true;
        package = mkDefault pkgs.mariadb;
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensureDBOwnership = true;
          }
        ];
      };

      postgresql = mkIf (cfg.database.createLocally && cfg.database.type == "postgresql") {
        enable = mkDefault true;
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensureDBOwnership = true;
          }
        ];
        authentication = ''
          host ${cfg.database.name} ${cfg.database.user} localhost trust
        '';
      };

      phpfpm.pools.${pool} = {
        phpPackage = package.php;
        user = cfg.user;
        group = cfg.group;

        phpOptions = ''
          error_log = 'stderr'
          log_errors = on
        '';

        settings = {
          "listen.owner" = socketOwner;
          "listen.group" = cfg.group;
          "listen.mode" = "0660";
          "catch_workers_output" = true;
        }
        // cfg.poolConfig;
      };
    };

    systemd = {
      services.flyspray-setup = {
        description = "Flyspray setup: create state directories and set permissions";
        wantedBy = [ "multi-user.target" ];
        requiredBy = [ "phpfpm-flyspray.service" ];
        before = [ "phpfpm-flyspray.service" ];
        wants = [ "local-fs.target" ];
        requires = lib.optional cfg.database.createLocally dbUnit;
        after = lib.optional cfg.database.createLocally dbUnit;

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          UMask = "0077";
        };

        script = ''
          mkdir -p ${cfg.dataDir}/{cache,attachments,avatars}
          mkdir -p ${cfg.logDir}
          chmod 750 ${cfg.dataDir}
          chmod 750 ${cfg.dataDir}/cache
          chmod 750 ${cfg.dataDir}/attachments
          chmod 750 ${cfg.dataDir}/avatars
          chmod 700 ${cfg.logDir}
        '';
      };

      tmpfiles.settings."10-flyspray" = with cfg; {
        "${dataDir}".d = {
          inherit user group;
          mode = "0750";
        };
        "${dataDir}/cache".d = {
          inherit user group;
          mode = "0750";
        };
        "${dataDir}/attachments".d = {
          inherit user group;
          mode = "0750";
        };
        "${dataDir}/avatars".d = {
          inherit user group;
          mode = "0750";
        };
        "${logDir}".d = {
          inherit user group;
          mode = "0700";
        };
      };

      services.${"phpfpm-${pool}"} = {
        wantedBy = lib.optional (webServerService != null) webServerService;
        after =
          lib.optional cfg.database.createLocally dbUnit
          ++ lib.optional (webServerService != null) webServerService
          ++ [ "flyspray-setup.service" ];
        requires = [ "flyspray-setup.service" ];
      };
    };
  };
}
