# qp001-infra

WordPress ブログ用インフラ（EC2 + RDS + EFS）を Terraform で管理するリポジトリ

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└──────────────┬──────────────────────────────────────────────┘
               │
       ┌───────▼────────┐
       │   Route 53     │  qp001.blog → Elastic IP
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │   EC2 (t4g.nano│  Apache + PHP + WordPress Core
       │   public subnet)│  EFSマウント (/wp-content)
       └───────┬────────┘
               │
       ┌───────▼────────┐      ┌──────────────┐
       │   RDS (private │◄────►│  EFS (private
       │   subnet)       │      │  subnet)      │
       │  db.t4g.micro   │      │  wp-content   │
       └─────────────────┘      └──────────────┘
```

## 前提条件

- AWS CLI インストール済み + 認証設定済み
- Terraform >= 1.5.0 インストール済み
- EC2 KeyPair を AWS Console で作成済み
- お名前.com で `qp001.blog` を取得済み

## デプロイ手順

### 1. Route53 ホストゾンを手動で作成

```bash
aws route53 create-hosted-zone \
  --name qp001.blog \
  --caller-reference $(date +%s) \
  --hosted-zone-config Comment="qp001 blog zone"
```

作成後、表示される **NS レコード（4つ）** をお名前.comの管理画面でネームサーバーに設定。

### 2. terraform.tfvars を作成

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集して自分の値を入れる
```

### 3. デプロイ

```bash
terraform init
terraform plan
terraform apply
```

### 4. WordPress初期設定

デプロイ完了後、ブラウザで `http://qp001.blog` にアクセスしてWordPressの初期セットアップを行う。

HTTPS（Let's Encrypt）は `user_data` 内の cron で自動的に設定される。初回はDNS伝播待ちで失敗する可能性があるが、翌日のcron実行で再試行される。

## モジュール構成

| モジュール | 役割 |
|---|---|
| `vpc` | VPC, パブリック/プライベートサブネット, IGW, ルートテーブル |
| `securityGroups` | EC2/RDS/EFS用セキュリティグループ |
| `iam` | EC2用Instance Profile（SSMアクセス） |
| `ec2` | t4g.nano, EBS gp3, Elastic IP, user_dataでWordPress自動構築 |
| `rds` | db.t4g.micro, プライベートサブネット, 自動バックアップ7日 |
| `efs` | wp-content永続化用EFS |
| `route53` | qp001.blog のAレコード管理 |
| `budgets` | 月額$35超過アラート |

## コスト見積もり（us-east-1, Free Tier終了後）

| リソース | 月額（概算） |
|---|---|
| EC2 t4g.nano | ~$3.3 |
| RDS db.t4g.micro | ~$12.5 |
| EFS（1GB想定） | ~$3.3 |
| EBS gp3 20GB | ~$1.6 |
| Elastic IP | $0（使用中） |
| Route53 ホストゾーン | ~$0.5 |
| データ転送 | ~$1-2 |
| **合計** | **~$22-23（約3,300円）** |

## 注意事項

- `terraform.tfvars` は Git にコミットしないこと
- `my_ip_cidr` は自宅IPが変わるたびに更新が必要
- t4g.nano（0.5GB RAM）は低トラフィックなら動作するが、管理画面の操作は遅くなる可能性あり
- Free Tier期間中は `t4g.micro` に変更して安定性を確保すること推奨
