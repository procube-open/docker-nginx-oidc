// JWTデコード
function decode(jot) {
    var parts = jot.split('.').slice(0,2)
        .map(v=>Buffer.from(v, 'base64url').toString())
        .map(JSON.parse);
    return { headers:parts[0], payload: parts[1] };
}

// JWTエンコード
async function encode(claims, key) {
    let header = { typ: "JWT",  alg: "HS256" };

    let s = [header, claims]
        .map(JSON.stringify)
        .map(v=>Buffer.from(v).toString('base64url'))
        .join('.');

    let wc_key = await crypto.subtle.importKey(
        'raw', key, {name: 'HMAC', hash: 'SHA-256'}, false, ['sign']);

    let sign = await crypto.subtle.sign({name: 'HMAC'}, wc_key, s);

    return s + '.' + Buffer.from(sign).toString('base64url');
}

// JWT署名検証
async function verify(jot, key) {
    if( !jot ) return false;

    let parts = jot.split('.');
    let data = parts.slice(0,2).join('.');
    let sign = Buffer.from(parts[2], 'base64url');
    let wc_key = await crypto.subtle.importKey(
        'raw', key, {name: 'HMAC', hash: 'SHA-256'}, false, ['verify']);

    return crypto.subtle.verify({name: 'HMAC'}, wc_key, sign, data);
}

export default {decode, encode, verify}
