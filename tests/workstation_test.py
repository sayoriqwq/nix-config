"""用临时 Git 仓库与假工具验证更新入口；不访问真实软件或系统。"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bin/workstation"
CURRENT = "/nix/store/11111111111111111111111111111111-darwin-system-old"
CANDIDATE = "/nix/store/22222222222222222222222222222222-darwin-system-new"
FAKE_TOOL = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
state = pathlib.Path(os.environ["MOCK_STATE"])
repo = pathlib.Path.cwd()
scenario = os.environ.get("SCENARIO", "")
with (state / "calls").open("a") as out:
    out.write(json.dumps([name, *args]) + "\n")
def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)
if name == "uname":
    print("Darwin")
elif name == "nix":
    if args[:2] == ["flake", "update"]:
        assert args[2:] == ["nixpkgs-darwin", "--flake", str(repo)]
        lock = json.loads((repo / "flake.lock").read_text())
        if scenario != "unchanged":
            lock["nodes"]["nixpkgs-darwin"]["locked"]["rev"] = "new"
        if scenario == "extra_input":
            lock["nodes"]["nixpkgs"]["locked"]["rev"] = "unrelated"
        (repo / "flake.lock").write_text(json.dumps(lock, indent=2) + "\n")
        if scenario == "update_failure": fail("模拟输入更新失败")
    elif args[0] == "path-info":
        print((state / "current").read_text() if args[1] == "/run/current-system"
              else os.environ["CANDIDATE"])
    elif args[:2] == ["store", "diff-closures"]:
        if scenario == "diff_failure": fail("模拟包差异展示失败")
        print("示例工具: 1 -> 2")
        if scenario == "review_change": (repo / "flake.nix").write_text("审阅期间变化\n")
    elif args[0] == "eval":
        assert "--no-write-lock-file" in args
        print(json.dumps({"enable": True, "prefix": str(state / "tools"),
                          "casks": ["other/tap/qq"] if scenario == "third_party" else ["qq"]}))
    else:
        fail("未知 nix 调用：" + str(args))
elif name == "nh":
    assert args[0] == "darwin"
    if args[1] == "build":
        assert "--no-update-lock-file" in args and "--update-input" not in args
        if scenario == "build_failure": fail("模拟构建失败")
        pathlib.Path(args[args.index("--out-link") + 1]).symlink_to(os.environ["CANDIDATE"])
        if scenario == "build_change": (repo / "flake.nix").write_text("构建期间变化\n")
    elif args[1] == "switch":
        assert args[2:4] == ["--expr", '{ config.system.build.toplevel = builtins.storePath "' + os.environ["CANDIDATE"] + '"; }']
        assert "--impure" in args and str(repo) not in args
        if scenario == "activation_failure": fail("模拟激活失败，部分写入可能已发生")
        (state / "current").write_text(os.environ["CANDIDATE"])
    else:
        fail("未知 nh 调用")
elif name == "brew":
    assert os.environ["HOMEBREW_NO_AUTO_UPDATE"] == "1"
    assert os.environ["HOMEBREW_NO_INSTALL_CLEANUP"] == "1"
    assert os.environ["HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"] == "1"
    if args[0] != "outdated":
        assert not os.environ.get("HOMEBREW_FORCE_API_AUTO_UPDATE")
    if args == ["config"]:
        for setting in ("HOMEBREW_NO_AUTO_UPDATE", "HOMEBREW_NO_INSTALL_CLEANUP", "HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"):
            if scenario != "brew_env_override" or setting != "HOMEBREW_NO_AUTO_UPDATE": print(setting + ": set")
        if scenario == "brew_env_disabled": print("HOMEBREW_NO_INSTALL_FROM_API: set")
    elif args[0] == "info":
        print(json.dumps({"casks": [{"token": "qq", "tap": "wrong/tap" if scenario == "wrong_source" else "homebrew/cask",
            "installed": None if scenario == "not_installed" else ("2" if (state / "upgraded").exists() or scenario == "cask_unchanged" else "1"),
            "version": "2", "outdated": scenario not in ("cask_unchanged", "cask_skipped"), "disabled": False, "pinned": False,
            "depends_on": {"cask": ["other"]} if scenario == "dependency" else {}}]}))
    elif args == ["--caskroom", "qq"]:
        receipt = state / "caskroom/qq/.metadata/INSTALL_RECEIPT.json"
        version = "2" if (state / "upgraded").exists() or scenario == "cask_unchanged" else "1"
        receipt.write_text(json.dumps({"source": {"tap": "other/tap" if scenario == "wrong_receipt" else "homebrew/cask", "version": version}}))
        if scenario == "missing_receipt" and receipt.exists(): receipt.unlink()
        print(receipt.parent.parent)
    elif args == ["upgrade", "--cask", "--dry-run", "qq"]:
        if scenario in ("cask_unchanged", "cask_skipped"):
            print("Warning: Not upgrading qq, the latest version is already installed")
        else:
            print("==> Would upgrade 1 outdated package:\nqq 1 -> 2")
            if scenario == "extra_cask": print("other 1 -> 2")
    elif args == ["upgrade", "--cask", "--no-ask", "qq"]:
        (state / "upgraded").touch()
    elif args == ["outdated", "--cask", "--greedy", "--json=v2", "qq"]:
        assert os.environ["HOMEBREW_FORCE_API_AUTO_UPDATE"] == "1"
        assert os.environ["HOMEBREW_API_AUTO_UPDATE_SECS"] == "0"
        assert "HOMEBREW_API_UPDATED" not in os.environ
        if scenario == "api_failure": sys.exit(2)
        if scenario == "api_bad_json": print("无效结果"); sys.exit(1)
        print(json.dumps({"formulae": [], "casks": [] if scenario == "cask_unchanged" else
                          [{"name": "other" if scenario == "api_wrong_target" else "qq"}]}))
        sys.exit(0 if scenario == "cask_unchanged" else 1)
    else:
        fail("未知 brew 调用：" + str(args))
else:
    fail("未知假工具")
'''


class WorkstationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="workstation-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        (self.repo / "bin").mkdir()
        (self.repo / "docs").mkdir()
        shutil.copy2(SCRIPT, self.repo / "bin/workstation")
        (self.repo / "flake.nix").write_text("测试声明\n")
        (self.repo / "docs/note.md").write_text("原文档\n")
        lock = {"root": "root", "version": 7, "nodes": {
            "root": {"inputs": {"nixpkgs-darwin": "nixpkgs-darwin", "nixpkgs": "nixpkgs"}},
            "nixpkgs-darwin": {"original": {"ref": "unstable"}, "locked": {"rev": "old"}},
            "nixpkgs": {"original": {"ref": "release"}, "locked": {"rev": "old"}},
        }}
        (self.repo / "flake.lock").write_text(json.dumps(lock, indent=2) + "\n")
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "本地测试")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", str(self.repo / ".git/hooks"))
        self.git("add", ".")
        self.git("commit", "-qm", "测试基线")
        self.before = self.git("rev-parse", "HEAD").stdout.strip()
        self.state = self.root / "state"
        self.tools = self.state / "tools/bin"
        self.tools.mkdir(parents=True)
        receipt = self.state / "caskroom/qq/.metadata/INSTALL_RECEIPT.json"
        receipt.parent.mkdir(parents=True)
        receipt.write_text('{"source":{"tap":"homebrew/cask","version":"1"}}')
        (self.state / "current").write_text(CURRENT)
        for name in ("nix", "nh", "brew", "uname"):
            path = self.tools / name
            path.write_text(FAKE_TOOL)
            path.chmod(0o755)

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, check=True,
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def run_update(self, target="nix", scenario="", answers="y\ny\n", extra_env=None):
        env = dict(os.environ, PATH=f"{self.tools}:{os.environ['PATH']}",
                   MOCK_STATE=str(self.state), CANDIDATE=CANDIDATE, SCENARIO=scenario)
        env.update(extra_env or {})
        return subprocess.run(["bash", str(self.repo / "bin/workstation"), "update", target],
                              cwd=self.repo, env=env, input=answers, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def calls(self, tool):
        return [call for line in (self.state / "calls").read_text().splitlines()
                if (call := json.loads(line))[0] == tool]

    def assert_uncommitted(self):
        self.assertEqual(self.before, self.git("rev-parse", "HEAD").stdout.strip())

    def test_success_commits_only_lock_and_preserves_staged_and_unstaged_document(self):
        note = self.repo / "docs/note.md"
        note.write_text("已暂存文档\n")
        self.git("add", "docs/note.md")
        note.write_text("继续修改的文档\n")
        staged_before = self.git("show", ":docs/note.md").stdout
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("本地提交 成功", result.stdout)
        self.assertEqual(self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").stdout.strip(), "flake.lock")
        self.assertEqual(self.git("show", ":docs/note.md").stdout, staged_before)
        self.assertEqual(note.read_text(), "继续修改的文档\n")
        self.assertEqual((self.state / "current").read_text(), CANDIDATE)
        self.assertEqual(len(self.calls("nh")), 2)

    def test_dirty_configuration_and_lock_stop_before_update(self):
        for path in ("flake.nix", "flake.lock"):
            with self.subTest(path=path):
                original = (self.repo / path).read_text()
                (self.repo / path).write_text(original + "\n")
                result = self.run_update()
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertFalse(any(call[1:3] == ["flake", "update"] for call in self.calls("nix")))
                (self.repo / path).write_text(original)
        self.assert_uncommitted()

    def test_other_input_changes_are_retained_but_not_built(self):
        result = self.run_update(scenario="extra_input")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("以外的变化", result.stdout)
        self.assertEqual(self.calls("nh"), [])
        self.assertIn("unrelated", (self.repo / "flake.lock").read_text())
        self.assert_uncommitted()

    def test_failures_and_source_changes_never_activate_or_commit(self):
        for scenario in ("update_failure", "build_failure", "build_change", "review_change", "diff_failure"):
            with self.subTest(scenario=scenario):
                self.git("restore", "flake.lock", "flake.nix")
                result = self.run_update(scenario=scenario)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertFalse(any(call[1:3] == ["darwin", "switch"] for call in self.calls("nh")))
                self.assertEqual((self.state / "current").read_text(), CURRENT)
                self.assert_uncommitted()

    def test_cancellation_and_missing_acceptance_do_not_commit(self):
        result = self.run_update(answers="n\n")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertEqual((self.state / "current").read_text(), CURRENT)
        self.assert_uncommitted()
        self.git("restore", "flake.lock")
        result = self.run_update(answers="y\nn\n")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertEqual((self.state / "current").read_text(), CANDIDATE)
        self.assertIn("应用 成功", result.stdout)
        self.assert_uncommitted()

    def test_activation_failure_is_not_reported_as_unapplied(self):
        result = self.run_update(scenario="activation_failure")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("应用 已尝试但结果待核实", result.stdout)
        self.assert_uncommitted()

    def test_commit_hook_failure_keeps_successful_application_and_lock_change(self):
        (self.repo / "docs/note.md").write_text("保留已暂存文档\n")
        self.git("add", "docs/note.md")
        staged_before = self.git("show", ":docs/note.md").stdout
        hook = self.repo / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        result = self.run_update()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("应用 成功；功能 通过；本地提交 失败", result.stdout)
        self.assertEqual((self.state / "current").read_text(), CANDIDATE)
        self.assertIn('"rev": "new"', (self.repo / "flake.lock").read_text())
        self.assertEqual(self.git("show", ":docs/note.md").stdout, staged_before)
        self.assert_uncommitted()

    def test_unchanged_input_does_not_build_or_make_empty_commit(self):
        result = self.run_update(scenario="unchanged")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.calls("nh"), [])
        self.assertIn("无需提交", result.stdout)
        self.assert_uncommitted()

    def test_cask_success_is_targeted_and_does_not_use_nh_or_change_git(self):
        result = self.run_update(target="qq", extra_env={"HOMEBREW_API_UPDATED": "1", "HOMEBREW_FORCE_API_AUTO_UPDATE": "1"})
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("安装记录已核对；功能 通过", result.stdout)
        self.assertEqual(self.calls("nh"), [])
        self.assertIn(["brew", "upgrade", "--cask", "--no-ask", "qq"], self.calls("brew"))
        self.assertNotIn(["brew", "update"], self.calls("brew"))
        self.assertEqual(sum(call[1] == "outdated" for call in self.calls("brew")), 1)
        self.assertEqual(self.git("status", "--porcelain").stdout, "")
        self.assert_uncommitted()

    def test_cask_protection_conditions_never_upgrade(self):
        for scenario in ("not_installed", "wrong_source", "dependency", "extra_cask", "wrong_receipt", "missing_receipt", "cask_skipped", "third_party", "api_failure", "api_bad_json", "api_wrong_target"):
            with self.subTest(scenario=scenario):
                result = self.run_update(target="qq", scenario=scenario)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertFalse((self.state / "upgraded").exists())
                self.assertEqual(self.calls("nh"), [])
        result = self.run_update(target="undeclared")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertFalse((self.state / "upgraded").exists())

    def test_cask_requires_api_mode(self):
        result = self.run_update(target="qq", extra_env={"HOMEBREW_NO_INSTALL_FROM_API": "1"})
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertEqual(self.calls("brew"), [])
        for scenario in ("brew_env_disabled", "brew_env_override"):
            with self.subTest(scenario=scenario):
                result = self.run_update(target="qq", scenario=scenario)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertTrue(all(call == ["brew", "config"] for call in self.calls("brew")))

    def test_current_cask_finishes_without_upgrade(self):
        result = self.run_update(target="qq", scenario="cask_unchanged")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("无需升级", result.stdout)
        self.assertFalse((self.state / "upgraded").exists())


if __name__ == "__main__":
    unittest.main()
