{
  bootstrapTestData,
  pkgs,
}:

let
  inherit (bootstrapTestData) deployKey macbookKey;
  remoteAddScript = pkgs.writeText "phase10-remote-nixbox-bootstrap-add.sh" (
    bootstrapTestData.remoteActionTexts.add
  );
  remoteRemoveScript = pkgs.writeText "phase10-remote-nixbox-bootstrap-remove.sh" (
    bootstrapTestData.remoteActionTexts.remove
  );
in
pkgs.testers.runNixOSTest {
  name = "phase10-nixbox-bootstrap";
  globalTimeout = 300;

  nodes.machine =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.openssh ];
      system.stateVersion = "26.05";
      virtualisation = {
        cores = 1;
        memorySize = 512;
      };
    };

  testScript = ''
    import shlex

    deploy_key = ${builtins.toJSON deployKey}
    macbook_key = ${builtins.toJSON macbookKey}
    raw_remote_script = ${builtins.toJSON "${../../tools/phase-10/remote-nixbox-bootstrap.sh}"}
    remote_add_script = ${builtins.toJSON "${remoteAddScript}"}
    remote_remove_script = ${builtins.toJSON "${remoteRemoveScript}"}
    ssh_directory = "/root/.ssh"
    authorized_keys = f"{ssh_directory}/authorized_keys"
    newline = chr(10)

    def quoted(value):
        return shlex.quote(value)

    def initialize(lines, trailing_newline=False):
        machine.succeed(f"rm -rf {quoted(ssh_directory)}")
        machine.succeed(f"install -d -m 700 -o root -g root {quoted(ssh_directory)}")
        content = newline.join(lines)
        if trailing_newline:
            content += newline
        machine.succeed(
            f"printf %s {quoted(content)} > {quoted(authorized_keys)}"
        )
        machine.succeed(f"chmod 600 {quoted(authorized_keys)}")
        machine.succeed(f"chown root:root {quoted(authorized_keys)}")

    def run(action):
        script = {
            "add": remote_add_script,
            "remove": remote_remove_script,
        }[action]
        return machine.succeed(
            " ".join(
                [
                    "bash",
                    quoted(script),
                ]
            )
        )

    def fail(action, deploy=deploy_key, macbook=macbook_key):
        return machine.fail(
            " ".join(
                [
                    "bash",
                    quoted(raw_remote_script),
                    quoted(action),
                    quoted(deploy),
                    quoted(macbook),
                ]
            )
        )

    def exact_count(key):
        return machine.succeed(
            f"grep -Fxc -- {quoted(key)} {quoted(authorized_keys)} || true"
        ).strip()

    machine.start()
    machine.wait_for_unit("multi-user.target")

    with subtest("atomic add preserves the macbook key and file safety"):
        initialize([macbook_key], trailing_newline=False)
        output = run("add")
        assert "action=add changed=yes" in output
        assert exact_count(macbook_key) == "1"
        assert exact_count(deploy_key) == "1"
        machine.succeed(
            f"test \"$(stat -c %a:%U:%G {quoted(authorized_keys)})\" = 600:root:root"
        )
        machine.succeed(f"ssh-keygen -l -f {quoted(authorized_keys)} >/dev/null")

    with subtest("add is idempotent"):
        before = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        output = run("add")
        after = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        assert "action=add changed=no" in output
        assert before == after

    with subtest("rollback removes only the deploy key"):
        output = run("remove")
        assert "action=remove changed=yes" in output
        assert exact_count(macbook_key) == "1"
        assert exact_count(deploy_key) == "0"
        machine.succeed(
            f"test \"$(stat -c %a:%U:%G {quoted(authorized_keys)})\" = 600:root:root"
        )

    with subtest("rollback is idempotent"):
        before = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        output = run("remove")
        after = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        assert "action=remove changed=no" in output
        assert before == after

    with subtest("duplicate deploy keys fail without rewriting"):
        initialize([macbook_key, deploy_key, deploy_key], trailing_newline=True)
        before = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        fail("add")
        after = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        assert before == after

    with subtest("same payload with changed metadata fails without rewriting"):
        changed_comment = deploy_key.rsplit(" ", 1)[0] + " unexpected-comment"
        initialize([macbook_key, changed_comment], trailing_newline=True)
        before = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        fail("add")
        after = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        assert before == after

    with subtest("unsafe mode fails without rewriting"):
        initialize([macbook_key], trailing_newline=True)
        machine.succeed(f"chmod 644 {quoted(authorized_keys)}")
        before = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        fail("add")
        after = machine.succeed(f"base64 -w0 {quoted(authorized_keys)}")
        assert before == after
        machine.succeed(
            f"test \"$(stat -c %a {quoted(authorized_keys)})\" = 644"
        )

    with subtest("symlink target fails without replacing the link"):
        initialize([macbook_key], trailing_newline=True)
        real_file = f"{ssh_directory}/authorized_keys.real"
        machine.succeed(
            f"mv {quoted(authorized_keys)} {quoted(real_file)}"
        )
        machine.succeed(
            f"ln -s {quoted(real_file)} {quoted(authorized_keys)}"
        )
        fail("add")
        machine.succeed(f"test -L {quoted(authorized_keys)}")
        machine.succeed(
            f"test \"$(cat {quoted(real_file)})\" = {quoted(macbook_key)}"
        )
  '';
}
