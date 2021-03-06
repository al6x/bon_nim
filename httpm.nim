import supportm, sugar, httpclient, jsonm, uri, seqm, falliblem

let default_timeout_sec = 30

# parse_result -------------------------------------------------------------------------------------
# Parses JSON `data` into Nim type `R`, unless JSON is `{ is_error: true, error: "..." } then it
# rises the error
proc parse_result[R](data: string): R =
  let json = data.parse_json
  if json.kind == JObject and "is_error" in json:
    throw json["error"].get_str
  else:
    json.to R


# http_get -----------------------------------------------------------------------------------------
proc http_get*[R](url: string, timeout_sec = default_timeout_sec): R =
  let client = new_http_client(
    timeout = timeout_sec * 1000,
    headers = new_http_headers({ "Content-Type": "application/json" })
  )
  defer: client.close
  let r = client.get_content url
  parse_result[R] r


# http_post ----------------------------------------------------------------------------------------
proc http_post*[R](url: string, body: string, timeout_sec = default_timeout_sec): R =
  let client = new_http_client(
    timeout = timeout_sec * 1000,
    headers = new_http_headers({ "Content-Type": "application/json" })
  )
  defer: client.close
  let r = client.post_content(url, body)
  parse_result[R] r

proc http_post*[B, R](url: string, body: B, timeout_sec = default_timeout_sec): R =
  http_post(url, $(%body), timeout_sec)


# http_post_batch ----------------------------------------------------------------------------------
proc http_post_batch*[B, R](
  url: string, requests: seq[B], timeout_sec = default_timeout_sec
): seq[Fallible[R]] =
  let client = new_http_client(
    timeout = timeout_sec * 1000,
    headers = new_http_headers({ "Content-Type": "application/json" })
  )
  defer: client.close
  let data = client.post_content(url, $(%requests))
  let json = data.parse_json
  if json.kind == JObject and "is_error" in json:
    result = requests.map((_) => R.error(json["error"].get_str))
  else:
    for item in json:
      result.add if item.kind == JObject and "is_error" in item:
        R.error item["error"].get_str
      else:
        item.to(R).success


# build_url ----------------------------------------------------------------------------------------
proc build_url*(url: string, query: varargs[(string, string)]): string =
  if query.len > 0: url & "?" & query.encode_query
  else:            url

proc query_param_to_string(v: int | float | string | bool): string = $v

proc build_url*(url: string, query: tuple): string =
  var squery: seq[(string, string)] = @[]
  for k, v in query.field_pairs: squery.add((k, v.query_param_to_string))
  build_url(url, squery)

test "build_url":
  assert build_url("http://some.com") == "http://some.com"
  assert build_url("http://some.com", { "a": "1", "b": "two" }) == "http://some.com?a=1&b=two"

  assert build_url("http://some.com", (a: 1, b: "two")) == "http://some.com?a=1&b=two"