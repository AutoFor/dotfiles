# Azure SQL Database Serverless 構築計画

## 概要
Azure CLI を使って、コスト最小の Azure SQL Database (Serverless) を構築する。

## 構築パラメータ

| 項目 | 値 |
|------|-----|
| リージョン | Japan East (`japaneast`) |
| リソースグループ | `rg-dev-sqldb` |
| SQL Server 名 | `sql-dev-<ランダム文字列>` (グローバル一意) |
| DB 名 | `sqldb-dev-sandbox` |
| 管理者ユーザー名 | `sqladmin` |
| 管理者パスワード | 自動生成（ランダム） |
| エディション | GeneralPurpose |
| コンピュートモデル | Serverless |
| vCore | min 0.5 / max 1 |
| ストレージ | 5GB (最小) |
| Auto-pause | 60分 (最小値) |
| バックアップ冗長 | Local (コスト最小) |

## 実行ステップ

### Step 1: リソースグループ作成
```
az group create --name rg-dev-sqldb --location japaneast
```

### Step 2: SQL Server 作成
```
az sql server create \
  --name sql-dev-<random> \
  --resource-group rg-dev-sqldb \
  --location japaneast \
  --admin-user sqladmin \
  --admin-password <自動生成>
```

### Step 3: ファイアウォールルール追加
- 現在のクライアント IP を許可するルールを追加

```
az sql server firewall-rule create \
  --resource-group rg-dev-sqldb \
  --server sql-dev-<random> \
  --name AllowMyIP \
  --start-ip-address <current-ip> \
  --end-ip-address <current-ip>
```

### Step 4: Serverless データベース作成
```
az sql db create \
  --resource-group rg-dev-sqldb \
  --server sql-dev-<random> \
  --name sqldb-dev-sandbox \
  --edition GeneralPurpose \
  --compute-model Serverless \
  --family Gen5 \
  --min-capacity 0.5 \
  --capacity 1 \
  --max-size 5GB \
  --auto-pause-delay 60 \
  --backup-storage-redundancy Local
```

### Step 5: 接続情報の確認・表示
- サーバー FQDN、DB名、管理者ユーザー名、パスワードをまとめて表示

## 確認方法
- `az sql db show` で DB の状態を確認
- 接続文字列を使って sqlcmd や SSMS / Azure Data Studio 等から接続テスト

## コスト目安（先ほどの料金情報より）
- ほぼ放置: 数百円〜1,000円台/月
- 平日1〜2時間/日: 数千円〜1万円弱/月
- Auto-pause 60分で未使用時はストレージ代のみ
