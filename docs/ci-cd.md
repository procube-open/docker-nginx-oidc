# CI/CD パイプライン

このプロジェクトは GitHub Actions を使用して自動的にバージョン管理とリリースを行います。

## バージョニング戦略

バージョニングは以下の 3 つのブランチ戦略に基づいています。

### 1. main ブランチ（最新リリース）

`main` ブランチへのプッシュ時に自動でバージョンを更新します。

- **デフォルト**：パッチバージョンを更新（例：v1.0.0 → v1.0.1）
- **`[[MINOR]]` コミットメッセージ**：マイナーバージョンを更新（例：v1.0.0 → v1.1.0）
- **`[[MAJOR]]` コミットメッセージ**：メジャーバージョンを更新（例：v1.0.0 → v2.0.0）

**ワークフロー**: `versioning-latest.yml`

### 2. stable-* ブランチ（安定版）

`stable-*` という名前のブランチへのプッシュ時に自動でパッチバージョンを更新します。

**ワークフロー**: `versioning-stable.yml`

### 3. フィーチャーブランチ（プリリリース）

`main` と `stable-*` 以外のブランチで `[[PRERELEASE]]` コミットメッセージを含むプッシュ時に、プリリリース版を生成します。

- バージョン形式：`v1.0.0-rc[ブランチ名ハッシュ].[プリリリース番号]`
- 例：`v1.0.0-rc12345678.1`

**ワークフロー**: `versioning-prerelease.yml`

## リリースプロセス

### 最新リリース（main ブランチ）

タグ `v[0-9]+.[0-9]+.[0-9]+` が作成されると、自動的に Docker イメージをビルドして Docker Hub にプッシュします。

**動作**:
- 最新バージョンの場合：`latest`、`major.minor`、`major` タグでも公開
- 以前のバージョンの場合：バージョンタグとマイナーバージョンタグのみで公開

**ワークフロー**: `release-default.yml`

### プリリリース（RC 版）

タグ `v[0-9]+.[0-9]+.[0-9]+-rc[a-f0-9]+.[0-9]+` が作成されると、Docker イメージをプリリリース版として Docker Hub にプッシュします。

**ワークフロー**: `release-prerelease.yml`

## 認証

GitHub Actions ワークフローは以下のシークレットを使用して GitHub Apps トークンを生成し、自動でコミットやタグを作成できるようにしています。

| シークレット | 説明 |
|--|--|
| `APP_ID` | GitHub App の ID |
| `PRIVATE_KEY` | GitHub App の秘密鍵 |
| `DOCKER_USERNAME` | Docker Hub のユーザ名 |
| `DOCKER_PASSWORD` | Docker Hub のパスワード（Personal Access Token 推奨） |

## 変数

| 変数 | 説明 |
|--|--|
| `BUILDER_GITHUB_USER` | コミット時に使用する Git ユーザ名 |
| `BUILDER_GITHUB_EMAIL` | コミット時に使用する Git メールアドレス |

## 使用しているツール

- **release-it**: バージョン管理とリリースの自動化
- **@release-it/bumper**: バージョン番号の更新
- **docker/build-push-action**: Docker イメージのビルドとプッシュ
