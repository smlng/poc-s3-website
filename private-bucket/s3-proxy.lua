-- dependencies
-- luacheck: globals ngx
local aws_sign = require("resty.aws_signature")
local http     = require("resty.http")

-- helper function for environment variables
local function getenv(name) return os.getenv(name) or ngx.var[name] or "" end

-- set configuration
local access_key = getenv("S3_ACCESS_KEY")
local secret_key = getenv("S3_SECRET_KEY")
local region     = getenv("S3_REGION") ~= "" and getenv("S3_REGION") or "us-east-1"
local service    = "s3"
local bucket     = getenv("S3_BUCKET")
local endpoint   = getenv("S3_ENDPOINT")

-- fetch content from private bucket in S3
local function fetch_from_minio(object_path)
    if object_path == "" or object_path == "/" then
        object_path = "/index.html"
    end

    -- temp variables
    local date_str   = os.date("!%Y%m%dT%H%M%SZ")
    local date_stamp = os.date("!%Y%m%d")
    local host       = endpoint:gsub("https?://", "")
    local uri_path   = string.format("/%s%s", bucket, object_path)

    -- prepare opts for signature
    local opts = {
        method     = "GET",
        uri        = uri_path,
        service    = service,
        region     = region,
        headers     = {
            ["Host"] = host,
        },
        access_key = access_key,
        secret_key = secret_key,
        date_iso8601 = date_str,
        date_stamp   = date_stamp,
    }

    -- create signed header from opts
    local signed = aws_sign.sign_request(opts)

    -- create and send http request to S3
    local httpc = http.new()
    local res, err = httpc:request_uri(endpoint .. uri_path, {
        method     = "GET",
        ssl_verify = false,
        headers    = signed.headers,
    })

    -- if response empty
    if not res then
        ngx.status = 502
        ngx.say("Error: ", err)
        return ngx.exit(502)
    end

    -- if http status not 200
    if res.status ~= 200 then
        ngx.status = res.status
        ngx.say("Error: ", res.status)
        return ngx.exit(res.status)
    end

    -- all good
    ngx.header["Content-Type"] = res.headers["Content-Type"] or "application/octet-stream"
    ngx.status = 200
    ngx.print(res.body)
    return ngx.exit(200)
end

-- main
local path = ngx.var.uri
local ok, err = pcall(fetch_from_minio, path)
if not ok then
    ngx.log(ngx.ERR, "Fetch from S3 failed: ", err)
    ngx.status = 500
    ngx.say("Internal Server Error")
end
