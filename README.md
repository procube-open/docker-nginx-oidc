# OpenID Connect 対応 nginx

https://qiita.com/ydclab_P002/items/b49ed23ca7b2532fcce2 を参考にKeycloak と OpenID Connect で連携するリバースプロキシを開発した。

## カスタマイズ方法

/etc/nginx/templates の下に default.conf.template を置いて専用のイメージを作ることができる。
デフォルトでは以下の内容となっている。

```
resolver 127.0.0.11;                # Docker resolver

include /etc/nginx/conflib/oidc-init.conf;

server {
    http2 on;
    listen 80 default;
    server_name ${DEFAULT_WEB_FQDN};

    if ($host != ${DEFAULT_WEB_FQDN}) {
        return 400;
    }
    location / {
        auth_request /auth/validate;                   # /auth/validate でログイン有無を確認
        error_page 401 = @login;                       # 未ログインなら @login へ
        expires -1;
        proxy_set_header HTTP_REMOTEUSER $user_info;  # ヘッダーにユーザ情報を付加
        proxy_pass ${DEFAULT_WEB_UPSTREAML_URL};                     # WEBサーバへ転送
    }

    include /etc/nginx/conflib/oidc-server.conf;
}
```

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
|JWT_GEN_KEY| JWT 署名鍵 | "Your Secrets(must be replaced)"|
|NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE|ワーカプロセス数を自動的に調整する|"true"|
|NGINX_ENTRYPOINT_LOCAL_RESOLVERS|/etc/resolv.confに指定されているIPアドレスを環境変数 NGINX_LOCAL_RESOLVERS に展開する|"true"|
|DEFAULT_WEB_FQDN|デフォルトのFQDN|"localhost"|
|DEFAULT_WEB_UPSTREAML_URL|デフォルトのアップストリームのURL|"http://backend"|
