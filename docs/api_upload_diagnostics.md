# Diagnosing generation uploads

## Observed on Android, 2026-08-27

Read-only inspection of the running app found two `POST /users/gen-i2v`
requests with a complete 625,851-byte multipart body. The body matched
Content-Length, ended with the correct boundary, and contained `prompt`,
`is_hd`, `is_long_time`, and a JPEG `source_image`.
The two starts were approximately 21:13:57 and 21:15:49 (UTC+07:00).

The exception retained by the failed form was a Dio `unknown` error wrapping
`HttpException: Connection reset by peer`, with no HTTP response/status.
Both IPv4 and IPv6 connections were represented in the failed requests.
This is not evidence of a 60-second timeout, missing upload fields, or a
successful server-side generation. It does not identify which network hop
reset the connection.

The SDK's dart:io profiler starts the response record only after receiving
response headers; its response-future error handler does not create that
record. Thus DevTools can continue displaying Pending after Dio has failed.
Do not infer that the app still has an active request from that label alone.

No paid generation POST was replayed during diagnosis. A read-only history
check did not show new generations corresponding to these two attempts.
This snapshot does not guarantee that retrying an interrupted POST is safe.

## Debug console

Only image-generation uploads (`/users/gen-i2v`, `/users/gen-theme`) emit
redacted `[API <id>]` diagnostics in debug builds. They use a separate Dio
client, sharing only the authentication session with the regular API client.
Sign-in, profile, packages, purchases, themes, history, polling and text-to-video
retain the original client, auth-retry behavior and error handling. They do not
install upload diagnostics or upload progress callbacks. Regular APIs and
sign-in keep 60-second timeouts. The upload client alone has a five-minute
send timeout; its connect and receive timeouts remain 60 seconds.

Perform a **Hot Restart**, not only Hot Reload, after applying this change:
the ApiClient singleton must be reconstructed to separate the clients.

- `start`: request method/path and multipart body size, before auth handling.
- `body_sent`: the body was handed to the transport; **not** confirmation that
  the server received or accepted it.
- `response`: HTTP status and total elapsed milliseconds.
- `error`: Dio type, safe underlying reason, elapsed milliseconds, and time
  after body submission when available. This is terminal even if Network
  still says Pending.

Tokens, headers, query strings, prompts, local image paths and image contents
are not logged. Release/profile builds disable these logs.

## Comparing with Postman

Compare the same image, prompt, `is_hd`, `is_long_time`, account and network.
Let Postman generate Content-Length and the multipart boundary. A copied
headers-only cURL is not the full upload request. Compare both HTTP status and
the JSON success/request_id, not just elapsed time: a fast validation error is
not equivalent to an accepted generation.

Use the request timestamp and endpoint to correlate backend/reverse-proxy
logs with the device log. The reset itself remains a transport/backend
investigation; no unverified HTTP-stack replacement, TLS bypass or forced IP
version is applied. A longer upload send timeout allows slow body transfers,
but does not resolve a connection reset or a server that never responds.

Image-upload generation network failures show an unconfirmed outcome and direct the user
to check History, rather than offering a one-tap duplicate submission.
Only explicit HTTP 401/403 triggers the existing bounded auth retry; on the
upload client, multipart bodies are cloned for that retry. Connection resets/timeouts never
automatically replay a paid generation POST.

Multipart retry reference: [Dio: reuse of FormData/MultipartFile](https://pub.dev/packages/dio#reuse-formdatas-and-multipartfiles).

## Local wire-level upload verification

The exact image bytes and form values from the failed device request were
sent to a loopback-only TCP receiver, using the unchanged
`I2VGenerationService` on the Mac, then cURL with the same image and values.
Both requests used HTTP/1.1 and the receiver read exactly Content-Length bytes.

- Both receivers extracted the same 625,325-byte JPEG (identical SHA-256).
- `source_image`, MIME `image/jpeg`, Unicode prompt, and both boolean strings
  were intact; each body had a complete closing boundary.
- The app's service completed with the local receiver's synthetic response in
  35 ms. This is a local transport check, **not** a production latency claim.
- Dio sent text fields before the file; cURL sent the file before text fields.
  That is a concrete wire-level difference, not proof of a backend parser bug.
- The probe used a shorter temporary filename, so total multipart sizes
  differed from the captured device body. Image bytes and field values did not.

An attempted isolated probe on the running Android VM could not compile
because its debugger compilation service was unavailable. No real-server
generation request was sent. The temporary USB reverse mapping was removed,
the local receiver stopped, and the temporary image copy was deleted.
This test therefore does **not** rule out Android-specific behavior, the
phone's network path, TLS/proxy behavior, or the real server's multipart parser.

`test/multipart_upload_transport_test.dart` now checks real local sockets for
I2V, theme upload, repeated file streams, and a receiver that consumes the full
image but never responds (reproducing receiveTimeout without a broken upload).
