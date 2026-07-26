---
name: rpa
description: rpa (UiPath用 Windows Server, Azure VM) の起動・停止・状態確認・接続を行う。「rpaを起動して」「rpa止めて」「rpaの状態は」「rpaに繋いで」などで呼び出す。
user-invocable: true
allowed-tools:
  - Bash
  - PowerShell
---

# rpa VM 操作スキル

Azure VM `rpa`（UiPath 用 Windows Server, リソースグループ `AUTOFOR-RG`）の起動・停止・状態確認を行う。
tmux は使わない。実体は `windows/bin/rpa.ps1`（dotfiles リポジトリ内）。

## 実行手順

### 1. dotfiles のパスを解決する

環境変数 `DOTFILES_DIR` → ghq 既定パス (`$env:USERPROFILE\ghq\github.com\AutoFor\dotfiles`) →
`$env:USERPROFILE\dotfiles` の順で存在するものを使う。

### 2. ユーザーの意図に応じて対応するアクションを実行する

```powershell
pwsh -File "<dotfiles>\windows\bin\rpa.ps1" <action>
```

| ユーザーの発言例 | action |
|---|---|
| 「rpaを起動して」「rpa使いたい」 | `up` |
| 「rpa止めて」「rpaを停止して」 | `down` |
| 「rpaの状態は」「rpa動いてる?」 | `status` |
| 「rpaに繋いで」「sshでrpaに入って」 | `connect`（対話 SSH。このスキル自体は非対話実行のツールから呼ばれるため、通常は先に `ensure` で起動だけ担保し、実際の接続はユーザーに `ssh rpa` を案内するか、以後の作業コマンドを `ssh rpa "<コマンド>"` 経由で個別に実行する） |
| 単に何か rpa 上で作業したい（起動確認だけしたい） | `ensure` |

### 3. 結果をそのまま日本語で報告する

起動に時間がかかる場合がある旨、停止すると課金がディスク代のみになる旨を必要に応じて添える。

## 補足

- 毎日 22:00 (JST) に自動シャットダウン、1時間アイドルで自動 deallocate される（rpa 上のタスク
  `rpa-idle-shutdown`、マネージド ID で自己 deallocate するためログイン切れが起きない）。
  手動で `down` しなくても放置で課金は止まる。
- 接続は Tailscale 経由（`rpa.tail7bb5be.ts.net` / SSH 22番）。RDP(3389) はグローバル非公開
  (NSG で Deny 済み、2026-07-26)。
