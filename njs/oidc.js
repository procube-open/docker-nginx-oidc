import qs from "querystring";
import jwt from "jwt.js";

const scheme = (typeof process.env.OIDC_REDIRECT_SCHEME === 'undefined')? 'http': process.env.OIDC_REDIRECT_SCHEME;

let regex_top_page_url_pattern = [null, null, null, null];

if (process.env.OIDC_TOP_PAGE_URL_PATTERN0) {
    regex_top_page_url_pattern[0] = new RegExp(process.env.OIDC_TOP_PAGE_URL_PATTERN0);
}

if (process.env.OIDC_TOP_PAGE_URL_PATTERN1) {
    regex_top_page_url_pattern[1] = new RegExp(process.env.OIDC_TOP_PAGE_URL_PATTERN1);
}

if (process.env.OIDC_TOP_PAGE_URL_PATTERN2) {
    regex_top_page_url_pattern[2] = new RegExp(process.env.OIDC_TOP_PAGE_URL_PATTERN2);
}

if (process.env.OIDC_TOP_PAGE_URL_PATTERN3) {
    regex_top_page_url_pattern[3] = new RegExp(process.env.OIDC_TOP_PAGE_URL_PATTERN3);
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

async function refresh_token(r) {
    let session = r.variables.cookie_OIDC_SESSION;
    if (!session) {
        r.log("OIDC validate: cookie OIDC_SESSION is not found.");
        return 401;
    }

    // cookie expire shoud be same as JWT exp, but client-side clock cannot be trusted
    let claims = await jwt.decode(session);
    if((!claims) || (!claims.payload) || (!claims.payload.exp)) {
        r.error("OIDC validate: fail to decode JWT:" + session);
        return 401;
    }
    if (claims.payload.exp < Math.floor(Date.now()/1000)) {
        r.log("OIDC validate: refresh token is expired: " + JSON.stringify(claims.payload));
        return 401;
    }

    try {
        let reply = await ngx.fetch(process.env.OIDC_TOKEN_ENDPOINT, {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: qs.stringify({
                grant_type    : "refresh_token",
                client_id     : process.env.OIDC_CLIENT_ID,
                client_secret : process.env.OIDC_CLIENT_SECRET,
                refresh_token : session
            }),
        });
        let tokens = await reply.json();
        if (!tokens.access_token) {
            r.error(`refresh_token: fail to get access_token: ${JSON.stringify(tokens)}`);
            return 401                
        }
        let new_claims = jwt.decode(tokens.access_token).payload;

        let secret_key = process.env.JWT_GEN_KEY;
        let my_access_token = await jwt.encode(new_claims, secret_key);
    
        r.headersOut["X-New-Access-Token-Cookie"] = `MY_ACCESS_TOKEN=${my_access_token}${process.env.OIDC_COOKIE_OPTIONS}`    
        if (tokens.refresh_token) {
            let session_claims = jwt.decode(tokens.refresh_token).payload;
            let expires = new Date(session_claims.exp * 1000).toUTCString();
            r.headersOut["X-New-Session-Token-Cookie"] = `OIDC_SESSION=${tokens.refresh_token};Expires=${expires}${process.env.OIDC_COOKIE_OPTIONS}`    
        }
        r.headersOut["X-Access-Token"] = my_access_token    
        if (process.env['OIDC_USER_CLAIM']) {
            r.headersOut["X-Remote-User"] = new_claims[process.env['OIDC_USER_CLAIM']]
        }
        if (process.env['OIDC_GROUP_CLAIM']) {
            r.headersOut["X-Remote-Group"] = new_claims[process.env['OIDC_GROUP_CLAIM']]
        }
        r.log(`OIDC refresh_token: succeeded: ${my_access_token}`);
    }  catch (e) {
        r.error(`OIDC refresh_token: error: ${e.stack || e}`);
        return 401
    }
    return 200;
}

async function validate(r) {
    try {
        // add_header cannot be ondemand, so always add Set-Cookie header but dummy is set when Set-Cookie is not required.
        r.headersOut["X-New-Access-Token-Cookie"] = `MY_DUMMY_ACCESS_TOKEN=; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT${process.env.OIDC_COOKIE_OPTIONS}`
        r.headersOut["X-New-Session-Token-Cookie"] = `OIDC_DUMMY_SESSION=; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT${process.env.OIDC_COOKIE_OPTIONS}`
        r.headersOut["X-Access-Token"] = "OIDC:NoAccessToken"    
        r.headersOut["X-Remote-User"] = "OIDC:UnknownUser"    
        r.headersOut["X-Remote-Group"] = "OIDC:UnknownGroup"    
        let secret_key = process.env.JWT_GEN_KEY;
        let my_access_token = r.variables.cookie_MY_ACCESS_TOKEN;
        if (!my_access_token) {
            r.log("OIDC validate: no access_token is found.");
            let status = await refresh_token(r);
            r.return(status);
            return
        }
        if (!await jwt.verify(my_access_token, secret_key)) {
            r.log("OIDC validate: token is invalid: " + my_access_token + " key:" + secret_key);
            r.return(401)
            return
        }
        let claims = jwt.decode(my_access_token);
        if( claims && claims.payload && claims.payload.exp ) {
            if (claims.payload.exp < Math.floor(Date.now()/1000)) {
                r.log("OIDC validate: token is expired: " + JSON.stringify(claims.payload));
                let status = await refresh_token(r);
                r.return(status);
            } else {
                r.headersOut["X-Access-Token"] = my_access_token
                if (process.env['OIDC_USER_CLAIM']) {
                    r.headersOut["X-Remote-User"] = claims.payload[process.env['OIDC_USER_CLAIM']]
                }
                if (process.env['OIDC_GROUP_CLAIM']) {
                    r.headersOut["X-Remote-Group"] = claims.payload[process.env['OIDC_GROUP_CLAIM']]
                }
                r.return(200);
            }
        } else {
            r.log(`OIDC validate: fail to decode: ${my_access_token} craims:${JSON.stringify(claims)}`);
            r.return(401);
        }    
    }  catch (e) {
        r.error(`OIDC validate: error: ${e.stack || e}`);
        r.return(401);
    }
}

async function session(r) {
    let session_data = r.variables.cookie_MY_ACCESS_TOKEN;
    r.headersOut['Content-Type'] = 'applicatoin/json'
    r.return(200, JSON.stringify(jwt.decode(session_data).payload));
}

function login(r) {
    if (r.variables.request_method != 'GET') {
        r.log(`OIDC validate: request method is not GET: method=${r.variables.request_method}`);
        r.return(401);
        return;
    }
    const pattern_index = Number(r.variables.regex_top_page_url_pattern_index　 || "0")
    if (regex_top_page_url_pattern[pattern_index]) {

        if (regex_top_page_url_pattern[pattern_index].test(r.variables.request_uri)) {
            r.log(`OIDC login: request uri match for OIDC_TOP_PAGE_URL_PATTERN:${process.env.OIDC_TOP_PAGE_URL_PATTERN} : ${r.variables.request_uri}`);
        } else {
            r.log(`OIDC login: request uri does not match for OIDC_TOP_PAGE_URL_PATTERN:${process.env.OIDC_TOP_PAGE_URL_PATTERN} : ${r.variables.request_uri}`);
            r.return(401);
            return;
        }
    } else {
        r.log(`OIDC login: OIDC_TOP_PAGE_URL_PATTERN${r.variables.regex_top_page_url_pattern_index} environment variable is not set`);
    }
    let postlogin_uri = scheme + "://" + r.variables.host + "/auth/postlogin";
    let referer = r.variables.uri;
    let params = {
        response_type : "code",
        scope         : process.env.OIDC_SCOPE,
        client_id     : process.env.OIDC_CLIENT_ID,
        redirect_uri  : postlogin_uri + "?" + qs.stringify({p: referer}),
    };
    if (r.variables.oidc_acr) {
        params["acr_values"] = r.variables.oidc_acr.split(' ')
    }
    let url = process.env.OIDC_AUTH_ENDPOINT + "?" + qs.stringify(params);
    r.return(302, url);
}

async function postlogin(r) {
    try {
        if (r.args.error) {
            r.error("OP returns error: " + r.args.error);
            r.return(401) // Unauthorized
            return
        }
        let referer = r.args.p;
        let postlogin_uri = `${scheme}://${r.variables.host}/auth/postlogin`;

        let redirect_uri = postlogin_uri + "?" + qs.stringify({p: referer});
        let tokens = await get_token(r.args.code, redirect_uri);
        r.log("OIDC postlogin: tokens: " + JSON.stringify(tokens));

        let claims = jwt.decode(tokens.access_token).payload;

        let secret_key = process.env.JWT_GEN_KEY;
        let my_access_token = await jwt.encode(claims, secret_key);

        let cookies = [`MY_ACCESS_TOKEN=${my_access_token}${process.env.OIDC_COOKIE_OPTIONS}`];
        if (tokens.refresh_token) {
            let session_claims = jwt.decode(tokens.refresh_token).payload;
            let expires = new Date(session_claims.exp * 1000).toUTCString();
            cookies.push(`OIDC_SESSION=${tokens.refresh_token};Expires=${expires}${process.env.OIDC_COOKIE_OPTIONS}`)
            r.log(`OIDC postlogin: refresh token is found: Expires=${expires}Set-Cookie=${JSON.stringify(cookies)}`);
        }
        r.headersOut["Set-Cookie"] = cookies;
        r.return(302, scheme + "://" + r.variables.host + referer);
    }  catch (e) {
        r.error(`OIDC postlogin: error: ${e.stack || e}`);
        r.return(403);  // Forbidden
    }
}

function logout(r) {
    let postlogout_uri = `${scheme}://${r.variables.host}/auth/postlogout`;
    let params = qs.stringify({
        client_id : process.env.OIDC_CLIENT_ID,
        post_logout_redirect_uri : postlogout_uri,
    });
    let url = process.env.OIDC_LOGOUT_ENDPOINT + "?" + params;
    r.return(302, url);
}

function postlogout(r) {
    r.headersOut['Set-Cookie'] = [
        `OIDC_SESSION=; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT${process.env.OIDC_COOKIE_OPTIONS}`,
        `MY_ACCESS_TOKEN=; Max-Age=-1; Expires=Wed, 21 Oct 2015 07:28:00 GMT${process.env.OIDC_COOKIE_OPTIONS}`,
    ];
    r.headersOut['Content-Type'] = 'text/html'
    r.internalRedirect(process.env.OIDC_POSTLOGOUT_CONTENT || "@bye");
}

export default {validate, login, logout, postlogin, postlogout, session}
