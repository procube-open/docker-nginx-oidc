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
|JWT_GEN_KEY| JWT 署名鍵 | "Your Secrets(must be replaced)"|
|NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE|ワーカプロセス数を自動的に調整する|"true"|
|NGINX_ENTRYPOINT_LOCAL_RESOLVERS|/etc/resolv.confに指定されているIPアドレスを環境変数 NGINX_LOCAL_RESOLVERS に展開する|"true"|
|NGINX_LOCAL_RESOLVERS|nginx の resolver ディレクティブに指定する値（NGINX_ENTRYPOINT_LOCAL_RESOLVERSがfalse の場合は必ず指定しなければならない|

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

このプロキシはOP から取得したユーザ情報を JWT として署名し、セッションクッキー OIDC_SESSION にセットする。
このとき、 /etc/nginx/njs/userinfo.js の convert 関数をカスタマイズすることでユーザ情報の値をカスタマイズできる。
デフォルトの userinfo.js は以下の通りであり、何も変換しない。

```javascript
function convert(userinfo) {
    return userinfo
}
```
