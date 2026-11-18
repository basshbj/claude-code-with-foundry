# デプロイガイド

## 事前準備

- Terraform 1.7 以上、2.0 未満
- Azure CLI
- Claude Code CLI または Claude Desktop をインストール
- Azure ロール: `Contributor` と `Role Based Access Control Administrator`
- Entra ID ロール: `Application Developer`

## 設定

このリポジトリのルートフォルダーで、次のコマンドを実行します。

```powershell
cd .\azure_infra
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

作成した `terraform.tfvars` ファイルで、次の項目を設定します。

| 項目 | 説明 | 設定例 |
| --- | --- | --- |
| `subscription_id`, `tenant_id` | 使用するサブスクリプションとテナントの ID。両方を実際の値に変更します | `REPLACE_WITH_SUBSCRIPTION_ID`, `REPLACE_WITH_TENANT_ID` |
| `name_prefix` | APIM と Foundry のホスト名に使う接頭辞。世界中で重複しない名前にします | `claude-demo-unique` |
| `location` | 選んだサービスとモデルを利用できるリージョン | `eastus2` |
| `publisher_name`, `publisher_email` | APIM の発行者名と連絡先メールアドレス | `Example organization`, `azure-admin@example.com` |
| `allowed_user_emails` | 既存ユーザーの Entra `mail` 属性の値。UPN や別名ではありません | `["developer@example.com"]` |
| `allowed_group_names` | 既存の Entra セキュリティグループの正確な表示名 | `[]` |
| `claude_organization_name` | Claude の Marketplace 利用規約に同意する組織の正式名称。実際の値に変更します | `REPLACE_WITH_COMPANY_NAME` |
| `claude_country_code` | Marketplace への申告に使う実際の国コード | `JP` |
| `claude_industry` | Marketplace への申告に使う実際の業種 | `technology` |
| `models` | デプロイする Claude モデルの ID。例では 6 つのモデルを選んでいます | `claude-opus-5-5`, `claude-haiku-4-5`, `claude-sonnet-5`, `claude-opus-5`, `claude-sonnet-5-5`, `claude-haiku-5-5` |
| `model_deployment_sku_name` | 選んだモデルとリージョンで使えるデプロイの種類 | `GlobalStandard` |
| `model_deployment_capacity` | モデルごとの容量。正の整数で指定します。単位はモデルと SKU によって異なります | `1` |

## 検証と計画

次のコマンドで Terraform テンプレートを検証し、デプロイします。

```powershell
az login --tenant <tenant-id>
az account set --subscription <subscription-id>

terraform init
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -out="deployment.tfplan"
terraform apply "deployment.tfplan"
terraform output -json > outputs.json
```

## デプロイ後の Claude Code の設定

Terraform のデプロイが完了したら、`Claude Code` と `Claude Desktop` の設定ファイルを作成します。

```powershell
cd ..
.\claude_config\prepare_claude_config.ps1
```

スクリプトは、`.\claude_config\output` フォルダーがなければ作成し、次のファイルを保存します。再実行すると、このフォルダー内の生成済みファイルを上書きします。

| ファイル名 | 説明 |
| - | - |
| `.\claude_config\output\claude_desktop_config.json` | Claude Desktop の設定ファイル。 |
| `.\claude_config\output\settings.json` | Claude Code の設定ファイル。 |
| `.\claude_config\output\get_entra_id_token.ps1` | Claude Code と Desktop が Entra ID の認証トークンを取得するための補助スクリプト。 |

### Claude Code の設定

1. `.\claude_config\output\settings.json` を `C:\Users\%USERPROFILE%\.claude` にコピーします。
2. `.\claude_config\output\get_entra_id_token.ps1` を `C:\Users\%USERPROFILE%\.claude` にコピーします。
3. PowerShell を開いて `claude` を実行し、動作を確認します。

### Claude Desktop の設定

1. Claude Desktop を開き、Help > Troubleshooting > Enable Developer Mode を選びます。
2. Developer > Configure third-party inference を選びます。
3. 右上の `Default` を選び、`Import configuration` を選びます。
4. `.\claude_config\output\claude_desktop_config.json` を選びます。
5. Claude Desktop を再起動し、動作を確認します。

## 推論とログの確認

Claude Code と Claude Desktop の設定が完了したら、次のクエリでログを確認します。

1. Azure Application Insights を開きます。
2. 左側のメニューで Monitoring > Logs を選びます。

```kusto
# Claude API へのリクエストを確認
requests
| where timestamp  > ago(24h)
| project timestamp, name, resultCode, success, url
```

```kusto
# ユーザー別・モデル別の合計トークン数を確認
customMetrics
| where timestamp > ago(24h)
| where name == "Total Tokens"
| extend UserId = tostring(customDimensions["UserId"]), Model = tostring(customDimensions["Model"])
| summarize Tokens = sum(value) by UserId, Model, bin(timestamp, 1d)
```

## Azure リソースの削除

```powershell
cd azure_infra
terraform plan -destroy -out="destroy.tfplan"
terraform apply "destroy.tfplan"
```
