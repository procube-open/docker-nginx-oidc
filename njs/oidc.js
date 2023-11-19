import qs from "querystring";
import jwt from "jwt.js";

const postlogin_uri = "http://localhost:80/auth/postlogin";
const postlogout_uri = "http://localhost:80/auth/postlogout";

function validate_id_token(token, issuer, audience) {
    let payload = jwt.decode(token).payload;
    if( payload.iss != issuer ) throw new Error("invalid token");
    if( payload.aud != audience ) throw new Error("invalid token");
    if( payload.exp < Math.floor(Date.now()/1000) ) throw new Error("invalid token");
}

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
    let session_data = r.variables.cookie_OIDC_SESSION;
    let valid = await jwt.verify(session_data, secret_key);
    if( valid ) {
        r.return(200);
    } else {
        r.return(401);
    }
}

async function session(r) {
    let session_data = r.variables.cookie_OIDC_SESSION;
    r.return(200, jwt.decode(session_data).payload);
}

function login(r) {
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

        let redirect_uri = postlogin_uri + "?" + qs.stringify({p: referer});
        let tokens = await get_token(r.args.code, redirect_uri);

        validate_id_token(tokens.id_token, process.env.OIDC_ISSUER, process.env.OIDC_CLIENT_ID);

        let claims = await get_userinfo(tokens.access_token);

        let secret_key = process.env.JWT_GEN_KEY;
        let session_data = await jwt.encode(claims, secret_key);

        r.headersOut["Set-Cookie"] = [
            "OIDC_SESSION=" + session_data + "; Path=/",
        ];
        r.return(302, referer);
    }  catch (e) {
        r.error(e.message);
        r.return(403);  // Forbidden
    }
}

function logout(r) {
    let params = qs.stringify({
        client_id : process.env.OIDC_CLIENT_ID,
        post_logout_redirect_uri : postlogout_uri,
    });
    let url = process.env.OIDC_LOGOUT_ENDPOINT + "?" + params;
    r.return(302, url);
}

function postlogout(r) {
    r.headersOut['Set-Cookie'] = ["OIDC_SESSION=; Path=/; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT"];
    r.internalRedirect("@bye");
}

export default {validate, login, logout, postlogin, postlogout}
