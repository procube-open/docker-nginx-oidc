import qs from "querystring";
import jwt from "jwt.js";
import userinfo from "userinfo.js";

const scheme = (typeof process.env.OIDC_REDIRECT_SCHEME === 'undefined')? 'http': process.env.OIDC_REDIRECT_SCHEME;

async function get_token(code, redirect_uri) {
    let reply = await ngx.fetch(process.env.OIDC_TOKEN_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: qs.stringify({
            grant_type    : "authorization_code",
            client_id     : process.env.OIDC_CLIENT_ID,
            client_secret : process.env.OIDC_CLIENT_SECRET,
            redirect_uri  : redirect_uri,
            code          : code,
        }),
    });
    return await reply.json();
}

async function get_userinfo(access_token) {
    let reply = await ngx.fetch(process.env.OIDC_USER_INFO_ENDPOINT, {
        method: "GET",
        headers: { "Authorization": "Bearer " + access_token },
    });
    return await reply.json();
}

async function validate(r) {
    let secret_key = process.env.JWT_GEN_KEY;
    let session_data = r.variables.cookie_MY_ACCESS_TOKEN;
    let valid = await jwt.verify(session_data, secret_key);
    if( valid ) {
        r.return(200);
    } else {
        r.return(401);
    }
}

async function session(r) {
    let session_data = r.variables.cookie_MY_ACCESS_TOKEN;
    r.headersOut['Content-Type'] = 'text/html'
    r.return(200, JSON.stringify(jwt.decode(session_data).payload));
}

function login(r) {
    let postlogin_uri = scheme + "://" + r.variables.host + "/auth/postlogin";
    let referer = r.variables.uri;
    let params = qs.stringify({
        response_type : "code",
        scope         : process.env.OIDC_SCOPE,
        client_id     : process.env.OIDC_CLIENT_ID,
        redirect_uri  : postlogin_uri + "?" + qs.stringify({p: referer}),
    });
    let url = process.env.OIDC_AUTH_ENDPOINT + "?" + params;
    r.return(302, url);
}

async function postlogin(r) {
    try {
        let referer = r.args.p;
        let postlogin_uri = scheme + "://" + r.variables.host + "/auth/postlogin";

        let redirect_uri = postlogin_uri + "?" + qs.stringify({p: referer});
        let tokens = await get_token(r.args.code, redirect_uri);

        // let claims = await get_userinfo(tokens.access_token);
        let claims = jwt.decode(tokens.access_token).payload;

        let secret_key = process.env.JWT_GEN_KEY;
        let my_access_token = await jwt.encode(userinfo.convert(claims), secret_key);

        r.headersOut["Set-Cookie"] = [
            "OIDC_ACCESS_TOKEN=" + tokens.access_token + "; Path=/; Secure; HttpOnly",
            "OIDC_SESSION=" + tokens.refresh_token + "; Path=/; Secure; HttpOnly",
            "MY_ACCESS_TOKEN=" + my_access_token + "; Path=/; Secure; HttpOnly"
        ];
        r.return(302, referer);
    }  catch (e) {
        r.error(e.message);
        r.return(403);  // Forbidden
    }
}

function logout(r) {
    let postlogout_uri = scheme + "://" + r.variables.host + "/auth/postlogout";
    let params = qs.stringify({
        client_id : process.env.OIDC_CLIENT_ID,
        post_logout_redirect_uri : postlogout_uri,
    });
    let url = process.env.OIDC_LOGOUT_ENDPOINT + "?" + params;
    r.return(302, url);
}

function postlogout(r) {
    r.headersOut['Set-Cookie'] = [
        "OIDC_ACCESS_TOKEN=; Path=/; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        "OIDC_SESSION=; Path=/; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        "MY_ACCESS_TOKEN=; Path=/; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
    ];
    r.headersOut['Content-Type'] = 'text/html'
    r.internalRedirect("@bye");
}

export default {validate, login, logout, postlogin, postlogout, session}
