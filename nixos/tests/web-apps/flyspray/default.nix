{ lib, ... }:
let
  inherit (lib) mkDefault;
in
{
  name = "flyspray";

  nodes.machine =
    { config, ... }:
    {
      services.flyspray = {
        enable = true;
        domain = "localhost";
        database = {
          type = "postgresql";
          createLocally = true;
        };
        h2o = {
          acme.enable = mkDefault false;
        };
      };
    };

  testScript = /* python */ ''
    # Setup service runs quickly, so just wait for dependent services
    machine.wait_for_unit("phpfpm-flyspray.service")
    machine.wait_for_unit("h2o.service")
    machine.wait_for_open_port(80)

    # Verify setup created the directories
    machine.succeed("test -d /var/lib/flyspray/cache")
    machine.succeed("test -d /var/lib/flyspray/attachments")
    machine.succeed("test -d /var/lib/flyspray/avatars")

    # Test main page returns 200 and contains expected content
    response = machine.succeed("curl -sL -o /dev/null -w '%{http_code}' http://localhost/")
    assert response == "200", f"Expected 200, got {response}"

    page_content = machine.succeed("curl -sL http://localhost/")
    assert "Flyspray" in page_content, "Flyspray branding should be visible"

    # Test setup page is accessible (for first-time setup)
    response = machine.succeed("curl -sL -o /dev/null -w '%{http_code}' http://localhost/setup/")
    assert response == "200", f"Setup page should be accessible, got {response}"
  '';

  meta.maintainers = with lib.maintainers; [ toastal ];
}
