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
|OIDC_USER_CLAIM|claim名を指定すると、upstream に対して HTTP_REMOTEUSER ヘッダーでアクセストークンのその claim の値を送信する|username|
|OIDC_GROUP_CLAIM|claim名を指定すると、upstream に対して HTTP_REMOTEGROUP ヘッダーでアクセストークンのその claim の値を送信する|userrole|
|OIDC_TOP_PAGE_URL_PATTERN[0-3]|URLのpバスが指定されたパターンにマッチしない場合はAPI呼び出しとみなして、IdPへのリダイレクトを行わずに 401 を返す。nginx のの変数 $regex_top_page_url_pattern_index　に1,2,3の値を指定すると末尾の文字が一致する環境変数が使用される。デフォルトでは０が使用される|(^/$$\|^/app/.*)|
|JWT_GEN_KEY| JWT 署名鍵 | "Your Secrets(must be replaced)"|
|NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE|ワーカプロセス数を自動的に調整する|"true"|
|NGINX_ENTRYPOINT_LOCAL_RESOLVERS|/etc/resolv.confに指定されているIPアドレスを環境変数 NGINX_LOCAL_RESOLVERS に展開する|"true"|
|NGINX_LOCAL_RESOLVERS|nginx の resolver ディレクティブに指定する値（NGINX_ENTRYPOINT_LOCAL_RESOLVERSがfalse の場合は必ず指定しなければならない|
|NGINX_CONFIGURE_FLUENTD|fluentd を組み込む場合 true を指定する|"true"|
|LOGDB_HOST|ログDBのホスト名|authz-db|
|LOGDB_USERNAME|ログDBにアクセスするユーザ|fluentd|
|LOGDB_PASSWORD|ログDBにアクセス際のパスワード|fluentd|


## td-agent(fluentd)

コンテナには fluentd がインストールされており、その設定ファイルは /etc/nginx/conf.d/ の下の nginx のコンフィグファイルのコメントから収集する。
nginx に以下のコメントがあると、ログの内容をmongodb に出力する。

```
# TAG: タグ名
```

## デフォルトの設定

イメージには /etc/nginx/templates/default.conf.template がインストールされており、起動時に envsubst で内部の環境変数を置換して /etc/nginx/conf.d/default.conf に展開する。

```
server {
    http2 ${DEFAULT_HTTP2};
    listen 80 default;
    server_name ${DEFAULT_WEB_FQDN};

    if ($host != ${DEFAULT_WEB_FQDN}) {
        return 400;
    }
    location / {
        include /etc/nginx/conflib/oidc-proxy.conf;
        proxy_pass ${DEFAULT_WEB_UPSTREAML_URL};
    }

    include /etc/nginx/conflib/oidc-server.conf;
}
```

デフォルトのテンプレートでは以下の環境変数を指定しなければならない。

|変数名|意味|指定例|
|--|--|--|
|DEFAULT_WEB_FQDN|デフォルトのFQDN|"localhost"|
|DEFAULT_WEB_UPSTREAML_URL|デフォルトのアップストリームのURL|"http://backend"|
|DEFAULT_HTTP2|"on"を指定すると h2c 通信を受信する。http1.0 を使用する場合は "off" を指定する。|"off"|

## セッションクッキー

このプロキシはOP から取得したアクセストークンの criam に署名し、セッションクッキー MY_ACCESS_TOKEN にセットする。

## コンフィグレーションファイルテンプレート

環境変数を含んだコンフィグレーションファイルを /etc/nginx/templates におくことで、起動時に /etc/nginx/conf.d の下に展開できる。
このとき、 上記デフォルト設定のように server コンテキストで oidc-server.conf を include し、
プロキシするlocation コンテキストに oidc-proxy.conf を include することで、
keycloak と OpenID Connect で連携するリバースプロキシとすることができる。

## アクセスログ

以下のように設定することで、アクセスログがJSON形式で出力される。また、fluentd が有効である場合は mongoDB にも書き込まれる。

```
# TAG: idp
access_log /var/log/nginx/access.idp.log json;
```

