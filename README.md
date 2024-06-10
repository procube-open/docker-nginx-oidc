# OpenID Connect 対応 nginx

https://qiita.com/ydclab_P002/items/b49ed23ca7b2532fcce2 を参考にKeycloak と OpenID Connect で連携するリバースプロキシを開発した。

## 環境変数

|変数名|意味|指定例|
|--|--|--|
|OIDC_ISSUER|OPの発行者 ID|"http://localhost:8080/realms/develop"|
|OIDC_AUTH_ENDPOINT|OPの認証エンドポイント| "http://localhost:8080/realms/develop/protocol/openid-connect/auth"|
|OIDC_LOGOUT_ENDPOINT|OPのログアウトエンドポイント| "http://localhost:8080/realms/develop/protocol/openid-connect/logout"|
|OIDC_TOKEN_ENDPOINT|OPのトークンエンドポイント（内部連携）| "http://idp:8080/realms/develop/protocol/openid-connect/token"|
|OIDC_USER_INFO_ENDPOINT|OPのユーザ情報エンドポイント（内部連携）| "http://idp:8080/realms/develop/protocol/openid-connect/userinfo"|
|OIDC_CLIENT_ID| RP の登録名|"reverse-proxy" |
|OIDC_CLIENT_SECRET| RP のクライアントシークレット|"Your Secrets(must be replaced)" |
|OIDC_SCOPE| OpenID Connect のスコープ| "openid"|
|OIDC_REDIRECT_SCHEME|OP から戻ってくる時のURLの scheme。デフォルトは 'http' なので、https にリダイレクトする必要がある場合は 'https' を指定する。|
|OIDC_COOKIE_OPTIONS| Cookie に付与するオプション文字列である。デフォルトは ’; Path=/; secure; httpOnly' で https が前提となっている。|
|OIDC_USER_CLAIM|claim名を指定するとアクセストークンのその claim の値を user 属性としてログに出力する|username|
|OIDC_GROUP_CLAIM|claim名を指定するとアクセストークンのその claim の値を group 属性としてログに出力する|group|
|OIDC_ROLE1_CLAIM|claim名を指定するとアクセストークンのその claim の値を role1 属性としてログに出力する|userrole1|
|OIDC_ROLE2_CLAIM|claim名を指定するとアクセストークンのその claim の値を role2 属性としてログに出力する|userrole2|
|OIDC_TOP_PAGE_URL_PATTERN[0-3]|URLのpバスが指定されたパターンにマッチしない場合はAPI呼び出しとみなして、IdPへのリダイレクトを行わずに 401 を返す。nginx のの変数 $regex_top_page_url_pattern_index　に1,2,3の値を指定すると末尾の文字が一致する環境変数が使用される。デフォルトでは０が使用される|(^/$$\|^/app/.*)|
|OIDC_JWT_GEN_KEY| JWT 署名鍵 | "Your Secrets(must be replaced)"|
|NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE|ワーカプロセス数を自動的に調整する|"true"|
|NGINX_ENTRYPOINT_LOCAL_RESOLVERS|/etc/resolv.confに指定されているIPアドレスを環境変数 NGINX_LOCAL_RESOLVERS に展開する|"true"|
|NGINX_LOCAL_RESOLVERS|nginx の resolver ディレクティブに指定する値（NGINX_ENTRYPOINT_LOCAL_RESOLVERSがfalse の場合は必ず指定しなければならない|
|NGINX_CONFIGURE_FLUENTD|fluentd を組み込む場合 true を指定する|"true"|
|NGINX_LOG_LEVEL|nginx のログレベルを指定した値に設定する|debug|
|LOGDB_HOST|ログDBのホスト名|authz-db|
|LOGDB_PORT|ログDBのポート番号|27017|
|LOGDB_USERNAME|ログDBにアクセスするユーザ|fluentd|
|LOGDB_PASSWORD|ログDBにアクセス際のパスワード|fluentd|
|LOGDB_CAPPED_SIZE|ログ用の Capped Collection のサイズ（単位MByte, デフォルト 1024）|1024|


## td-agent(fluentd)

コンテナには fluentd がインストールされており、その設定ファイルは /etc/nginx/conf.d/ の下の nginx のコンフィグファイルのコメントから収集する。
nginx に以下のコメントがあると、ログの内容をmongodb に出力する。

```
# TAG: タグ名
```

## server コンテキストの設定

イメージの /etc/nginx/conf.d/default.conf は全てのアクセスに対して 400 Bad Request を返すように設定されている。
アクセスを受け入れる server コンテキストのテンプレートを /etc/nginx/templates/*.conf.template に置くことによって起動時に envsubst で内部の環境変数を置換して /etc/nginx/conf.d の下に展開させることができる。

### 設定例

```
server {
    listen 80;
    server_name www.example.com;

    location / {
        include /etc/nginx/conflib/oidc-proxy.conf;
        proxy_pass ${UPSTREAML_URL};
    }

    include /etc/nginx/conflib/oidc-server.conf;
}
```

このようなテンプレートを /etc/nginx/templates/example.conf.template　として置くことで、server コンテキストのコンフィグレーションファイルが /etc/nginx/conf.d/example.conf に生成される。このコンフィグレーションファイルでは HOST　ヘッダーの値が www.example.com に一致するリクエストのみを受け入れ、UPSTREAM_URL 環境変数で指定された Web サービスにプロキシ転送する。

### nginx.conf

/etc/nginx.conf はコンテナ起動時に生成され、以下の設定が埋め込まれる。

- NGINX_LOG_LEVEL に従って nginx のログレベルを設定する
- JSON形式のアクセスログのフォーマット　json を定義する
- OIDC連携のための JavaScript　オブジェクトをロードする

### コンフィグレーションライブラリ

上記の中で ```include /etc/nginx/conflib/oidc-proxy.conf;``` と　 ```include /etc/nginx/conflib/oidc-server.conf;``` の２行は OpenID　Connect　での認証機能を追加するコンフィグレーションライブラリである。

#### oidc-server.conf

OpenID Connect の RP として動作するための location を設定する。以下の location が設定される。

|パス|機能|
|--|--|
|/auth/validate|auth_request ディレクティブから呼び出され、アクセストークンの検証を行う。|
|@login|アクセストークンの検証に失敗した際に OIDC OP を呼び出す|
|/auth/postlogin|OPからリダイレクトで認証コードを受け取り、アクセストークン・リフレッシュトークンと交換し、 Cookie に設定する|
|/logout|OIDC SLO を呼び出す|
|/auth/postlogout|OIDC SLO 実行後、Cookie を削除する|
|/.session|クライアントに対してJSON形式でセッション情報を返す API|
|@bye|ログアウト後の表示を行う|

#### oidc-proxy.conf

リバースプロキシとして動作を行う location コンテキストで使用することができる。アクセストークンの検証を行った結果によって以下の動作を行う。

- Cookie のアクセストークンが有効である場合は、リクエストをプロキシ転送する
- Cookie のアクセストークンが無効あるいはない場合でもリフレッシュトークンが有効であれば、OPにアクセストークンとリフレッシュトークンの再発行を要求し、成功すればリクエストをプロキシ転送後、返しのパケットでアクセストークンとリフレッシュトークンを Cookie に設定する
- 未認証の場合でパスが環境変数 OIDC_TOP_PAGE_URL_PATTERN の正規表現にマッチする場合は OP にリダイレクトして認証を委譲する
- 未認証の場合でパスが環境変数 OIDC_TOP_PAGE_URL_PATTERN の正規表現にマッチしない場合は 401 のエラーになる

上記で Cookieに設定するアクセストークンは OP が発行するアクセストークンのペイロードに対してプロキシ自身のシークレットキーで署名をやり直したものである。

## セッションクッキー

このプロキシはOP から取得したアクセストークンの criam に署名し、セッションクッキー MY_ACCESS_TOKEN にセットする。

## アクセスログ

以下のように設定することで、アクセスログがJSON形式で出力される。また、fluentd が有効である場合は mongoDB にも書き込まれる。

```
# TAG: idp
access_log /var/log/nginx/access.idp.log json;
```

ログの項目は以下の通り。

|項目名|意味|値の例|
|:----|:----|:----|
|time |アクセスした日時|2024-05-21T00:33:30+09:00|
|vhost |アクセスしたホスト名|procube.jp|
|xff |アクセス元グローバルIP|112.78.125.94|
|user |アクセスしたユーザのID|test-admin|
|group |アクセスしたユーザのグループ|developers|
|role1|アクセスしたユーザのロール1|IDM_ACCOUNT_MANAGER|
|role2|アクセスしたユーザのロール2|VIEWER|
|status |クライアントに返されたHTTPステータスコード|200|
|protocol |HTTPリクエストのプロトコル|HTTP/1.1|
|method |HTTPリクエストのメソッド| GET|
|path |HTTPリクエストのパス| /|
|size |HTTPレスポンスのサイズ|5731|
|reqtime |レスポンスを返すまでにかかった時間(ms)|0.030|
|ua |ユーザエージェントの値|Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML|
|origin |アクセスしたアプリケーションのロード元|upstreamaddr |アップストリームのアドレス|10.12.21.248:80|
|upstreamtime |アプストリームで消費した時間|0.028|
|upstreamstatus |アップストリームから返されたHTTPステータスコード|200|
|referrer |リファラ|https://procube.jp/dummy/|


## エラーログ

nginx のエラーログはコンテナの標準出力に出力される。
このため、バックグラウンドで実行されている場合、 docker logs で参照することが可能である。

## 脆弱性対応テスト

以下のテストを実行して問題がないことを確認している。

```
docker run -d --name test -e NGINX_ENTRYPOINT_LOCAL_RESOLVERS=yes procube/nginx-oidc
docker exec test sh -c "apt install -y python3.11-venv;python3 -m venv gixy; /gixy/bin/pip install gixy-ng; /gixy/bin/gixy /etc/nginx/nginx.conf"
```
ここで出力の最後に以下のように表示されれば ok である。

```
==================== Results ===================
No issues found.

==================== Summary ===================
Total issues:
    Unspecified: 0
    Low: 0
    Medium: 0
    High: 0
```

不要となったコンテナを捨てるためには以下を実行する。

```
docker stop test
docker rm test
```

