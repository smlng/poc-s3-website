-- s3-proxy.lua (debug-ready)
local http = require "resty.http"
local sha256 = require "resty.sha256"
local str = require "resty.string"
local hmac = require "resty.hmac"

local function getenv(name) return os.getenv(name) or ngx.var[name] or "" end

-- URL-encode einzelne path segments but keep slashes
local function uri_encode_segment(s)
    -- ngx.escape_uri escapes more; use it per segment
    return ngx.escape_uri(tostring(s))
end

-- SHA256 hex
local function sha256_hex(data)
    local sh = sha256:new()
    sh:update(tostring(data))
    return str.to_hex(sh:final())
end

-- HMAC returning binary
local function hmac_sha256_bin(key, msg)
    key = tostring(key)
    msg = tostring(msg)
    local hm, err = hmac:new(key, hmac.ALGOS.SHA256)
    if not hm then
        ngx.log(ngx.ERR, "HMAC init failed: ", tostring(err))
        return nil, err
    end
    hm:update(msg)
    return hm:final()  -- binary
end

-- AWS sig v4 (returns hex signature)
local function aws_sign_v4(secret_key, date_stamp, region, service, string_to_sign)
    local k_date, err = hmac_sha256_bin("AWS4" .. secret_key, date_stamp)
    if not k_date then return nil, "k_date nil: "..tostring(err) end
    local k_region = hmac_sha256_bin(k_date, region)
    local k_service = hmac_sha256_bin(k_region, service)
    local k_signing = hmac_sha256_bin(k_service, "aws4_request")
    local sig_bin = hmac_sha256_bin(k_signing, string_to_sign)
    return str.to_hex(sig_bin)
end

-- config
local bucket     = getenv("MINIO_BUCKET")
local region     = getenv("MINIO_REGION") ~= "" and getenv("MINIO_REGION") or "us-east-1"
local access_key = getenv("MINIO_ACCESS_KEY")
local secret_key = getenv("MINIO_SECRET_KEY")
local minio      = getenv("MINIO_ENDPOINT")  -- e.g. http://minio:9000

-- request details
local key = ngx.var.uri:gsub("^/", "")
if key == "" then key = "index.html" end

-- Build canonical_uri as /bucket/encoded(key)  (path-style)
local canonical_uri = "/" .. uri_encode_segment(bucket) .. "/" .. uri_encode_segment(key)

-- host (keep port)
local parsed = ngx.re.match(minio, [[https?://([^/]+)]], "jo")
local host = parsed and parsed[1] or minio

-- payload hash: use SHA256 of empty body
local payload_hash = sha256_hex("")

local method = "GET"
local amz_date = os.date("!%Y%m%dT%H%M%SZ")
local date_stamp = amz_date:sub(1,8)
local service = "s3"

local canonical_headers = table.concat({
    "host:" .. host,
    "x-amz-content-sha256:" .. payload_hash,
    "x-amz-date:" .. amz_date
}, "\n") .. "\n"

local signed_headers = "host;x-amz-content-sha256;x-amz-date"

local canonical_request = table.concat({
    method,
    canonical_uri,
    "",  -- querystring
    canonical_headers,
    signed_headers,
    payload_hash
}, "\n")

local algorithm = "AWS4-HMAC-SHA256"
local credential_scope = date_stamp .. "/" .. region .. "/" .. service .. "/aws4_request"
local string_to_sign = table.concat({
    algorithm,
    amz_date,
    credential_scope,
    sha256_hex(canonical_request)
}, "\n")

-- compute signature
local signature, err = aws_sign_v4(secret_key, date_stamp, region, service, string_to_sign)
if not signature then
    ngx.log(ngx.ERR, "aws_sign_v4 failed: ", tostring(err))
    ngx.status = 500
    ngx.say("signature failure")
    return
end

local authorization_header = string.format(
    "%s Credential=%s/%s, SignedHeaders=%s, Signature=%s",
    algorithm, access_key, credential_scope, signed_headers, signature
)

-- DEBUG: print canonical_request etc (remove in prod)
ngx.log(ngx.ERR, "canonical_request=\n" .. canonical_request)
ngx.log(ngx.ERR, "string_to_sign=\n" .. string_to_sign)
ngx.log(ngx.ERR, "authorization_header=" .. authorization_header)
ngx.log(ngx.ERR, "Final URL: " .. minio .. canonical_uri)
ngx.log(ngx.ERR, "Host header: " .. host)
ngx.log(ngx.ERR, "x-amz-content-sha256: " .. payload_hash)

-- Make request (explicit Host header)
local httpc = http.new()
local res, req_err = httpc:request_uri(minio .. canonical_uri, {
    method = method,
    headers = {
        ["Host"] = host,
        ["x-amz-date"] = amz_date,
        ["x-amz-content-sha256"] = payload_hash,
        ["Authorization"] = authorization_header
    },
    ssl_verify = false, -- if using https with self-signed in dev
    keepalive = false
})

if not res then
    ngx.log(ngx.ERR, "HTTP request failed: " .. tostring(req_err))
    ngx.status = 502
    ngx.say("upstream error: ", tostring(req_err))
    return
end

-- If upstream returned error body, show it for debugging
if res.status >= 400 then
    ngx.log(ngx.ERR, "MinIO returned status: "..res.status.." body: "..tostring(res.body))
    ngx.status = res.status
    ngx.say("MinIO error: ", res.body)
    return
end

-- forward response
ngx.status = res.status
for k, v in pairs(res.headers) do
    if k:lower() ~= "transfer-encoding" then ngx.header[k] = v end
end
ngx.print(res.body)
