{
  config,
  lib,
  pkgs,
  ...
}:

# NOTE: the actual loading of keys is done in the import scripts of
# nixos/modules/tasks/filesystems/zfs.nix

let
  cfg = config.boot.initrd.tzpfms;
  cfgZFS = config.boot.zfs;

  datasetToPool = x: lib.elemAt (lib.splitString "/" x) 0;

  pools = lib.unique (map datasetToPool cfg.datasets);

  # Only include initrd resources if datasets belong to pools that need initrd import.
  # A pool needs initrd import if it has neededForBoot filesystems OR is a tzpfms root pool.
  needsInitrd = cfg.enable && pools != [ ];
in
{
  meta.maintainers = with lib.maintainers; [ toastal ];

  options = {
    boot.initrd.tzpfms = {
      enable = lib.mkEnableOption ''
        TPM-backed ZFS encryption using tzpfms.
        Supports both TPM 2.0 & TPM 1.x.
      '';

      package = lib.mkPackageOption pkgs "tzpfms" { };

      backends = lib.mkOption {
        type =
          with lib.types;
          nonEmptyListOf (enum [
            "TPM2"
            "TPM1.X"
          ]);
        default = [
          "TPM2"
        ];
        description = ''
          TPM backends to include in initrd.
        '';
      };

      datasets = lib.mkOption {
        # TODO: this could probably support a bool as well & try to autodetect
        # datasets similar to config.boot.zfs.requestEncryptionCredentials
        type = with lib.types; nonEmptyListOf str;
        example = [
          "tank/root"
          "tank/var"
        ];
        description = ''
          Explicit list of ZFS datasets to unlock with TPM at boot.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          config.boot.supportedFilesystems.zfs or config.boot.initrd.supportedFilesystems.zfs or false;
        message = "ZFS filesystem support needs to be enabled for boot.initrd.tzpfms to work";
      }
      {
        assertion =
          !(cfgZFS.requestEncryptionCredentials == true) || cfgZFS.requestEncryptionCredentials == [ ];
        message = ''
          boot.zfs.requestEncryptionCredentials = true would prompt for all
          encrypted dataset passphrases at boot, which conflicts with automatic
          TPM unlock via tzpfms. Either set it to false, or explicitly list the
          datasets that still need passphrase prompting.
        '';
      }
      (
        let
          intersected = lib.intersectLists cfg.datasets (
            if lib.isList cfgZFS.requestEncryptionCredentials then cfgZFS.requestEncryptionCredentials else [ ]
          );
        in
        {
          assertion = builtins.length intersected == 0;
          message = ''
            The following datasets are listed in both
            boot.initrd.tzpfms.datasets &
            boot.zfs.requestEncryptionCredentials, which would cause a
            passphrase prompt to block boot before tzpfms can unlock them via
            TPM:

            ${lib.concatMapStringsSep "\n" (d: "• ${d}") intersected}

            Remove them from boot.zfs.requestEncryptionCredentials to allow
            automatic TPM unlock.
          '';
        }
      )
    ];

    environment.systemPackages = [ cfg.package ];

    # Automatically register pools from tzpfms datasets as extraPools
    boot.zfs.extraPools = pools;

    # Tell zfs.nix which pools need initrd import for key unlock
    boot.zfs.tzpfmsRootPools = pools;

    boot.initrd = lib.mkMerge [
      (lib.mkIf cfg.enable {
        availableKernelModules = [
          "tpm_tis"
          "tpm_crb"
        ];
      })
      (lib.mkIf needsInitrd (
        lib.mkMerge [
          (lib.mkIf config.boot.initrd.systemd.enable {
            systemd.extraBin = {
              zfs-tpm-list = "${lib.getBin cfg.package}/bin/zfs-tpm-list";
            }
            // lib.optionalAttrs (lib.elem "TPM2" cfg.backends) {
              zfs-tpm2-load-key = "${lib.getBin cfg.package}/bin/zfs-tpm2-load-key";
            }
            // lib.optionalAttrs (lib.elem "TPM1.X" cfg.backends) {
              zfs-tpm1x-load-key = "${lib.getBin cfg.package}/bin/zfs-tpm1x-load-key";
            };
            systemd.storePaths =
              lib.optional (lib.elem "TPM2" cfg.backends) pkgs.tpm2-tss
              ++ lib.optional (lib.elem "TPM1.X" cfg.backends) pkgs.trousers;
          })
        ]
      ))
    ];
  };
}
