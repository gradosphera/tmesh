using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

namespace TProxy.Controllers
{
    /// <summary>
    /// Transparent proxy for the Telegram Bot API.
    /// Handles all requests matching /bot{token}/{method}[/{extra}]
    /// and forwards them verbatim to the upstream Telegram API,
    /// returning the same HTTP status code and response body.
    ///
    /// This lets you use your own domain as a drop-in replacement for
    /// https://api.telegram.org in any Telegram bot client.
    /// </summary>
    [ApiController]
    public class TelegramApiProxyController : ControllerBase
    {
        private readonly HttpClient _httpClient;
        private readonly TProxyOptions _options;
        private readonly ILogger<TelegramApiProxyController> _logger;

        private const string DefaultTelegramApiBaseUrl = "https://api.telegram.org";
        private const string DefaultProxyAuthHeader    = "X-Api-Key";

        // Headers that must not be forwarded upstream (hop-by-hop / host-specific)
        private static readonly HashSet<string> _excludedRequestHeaders = new(StringComparer.OrdinalIgnoreCase)
        {
            "Host", "Transfer-Encoding", "Connection", "Keep-Alive",
            "Proxy-Authenticate", "Proxy-Authorization", "TE", "Trailers", "Upgrade",
            "Content-Length", // HttpClient sets this automatically
        };

        private static readonly HashSet<string> _excludedResponseHeaders = new(StringComparer.OrdinalIgnoreCase)
        {
            "Transfer-Encoding", "Connection", "Keep-Alive",
        };

        public TelegramApiProxyController(
            IHttpClientFactory httpClientFactory,
            IOptions<TProxyOptions> options,
            ILogger<TelegramApiProxyController> logger)
        {
            _httpClient = httpClientFactory.CreateClient("TelegramApiProxy");
            _options = options.Value;
            _logger = logger;
        }

        // Matches:
        //   /bot{token}/{method}
        //   /bot{token}/{method}/{extra}   (e.g. /botTOKEN/sendMessage/... - rare but possible)
        [Route("bot{token}/{method}")]
        [Route("bot{token}/{method}/{**extra}")]
        public async Task<IActionResult> ProxyAsync(string token, string method, string extra = null)
        {
            var baseUrl = string.IsNullOrWhiteSpace(_options.TelegramApiBaseUrl)
                ? DefaultTelegramApiBaseUrl
                : _options.TelegramApiBaseUrl.TrimEnd('/');

            // Reconstruct the upstream path
            var upstreamPath = string.IsNullOrEmpty(extra)
                ? $"/bot{token}/{method}"
                : $"/bot{token}/{method}/{extra}";

            // Preserve query string
            var queryString = Request.QueryString.Value ?? string.Empty;
            var upstreamUrl = $"{baseUrl}{upstreamPath}{queryString}";

            _logger.LogDebug("Proxying {Method} {OriginalPath} -> {UpstreamUrl}",
                Request.Method, Request.Path, upstreamUrl);

            // Build upstream request
            var upstreamRequest = new HttpRequestMessage
            {
                Method = new HttpMethod(Request.Method),
                RequestUri = new Uri(upstreamUrl),
            };

            // Forward request body (POST, PUT, PATCH)
            if (Request.ContentLength > 0 || Request.Headers.ContainsKey("Transfer-Encoding"))
            {
                var memStream = new MemoryStream();
                await Request.Body.CopyToAsync(memStream, HttpContext.RequestAborted);
                memStream.Seek(0, SeekOrigin.Begin);

                upstreamRequest.Content = new StreamContent(memStream);

                if (Request.ContentType != null)
                    upstreamRequest.Content.Headers.TryAddWithoutValidation("Content-Type", Request.ContentType);
            }

            // Determine which header carries the proxy secret so we can strip it
            var authHeaderName = string.IsNullOrWhiteSpace(_options.ProxyAuthHeader)
                ? DefaultProxyAuthHeader
                : _options.ProxyAuthHeader;

            // Forward safe request headers, dropping hop-by-hop and the proxy auth header
            foreach (var header in Request.Headers)
            {
                if (_excludedRequestHeaders.Contains(header.Key))
                    continue;

                // Strip proxy auth — Telegram doesn't need it and shouldn't see it
                if (string.Equals(header.Key, authHeaderName, StringComparison.OrdinalIgnoreCase))
                    continue;

                // Try as request header first, then as content header
                if (!upstreamRequest.Headers.TryAddWithoutValidation(header.Key, (IEnumerable<string>)header.Value))
                {
                    upstreamRequest.Content?.Headers.TryAddWithoutValidation(header.Key, (IEnumerable<string>)header.Value);
                }
            }

            // Send to Telegram
            HttpResponseMessage upstreamResponse;
            try
            {
                upstreamResponse = await _httpClient.SendAsync(
                    upstreamRequest,
                    HttpCompletionOption.ResponseHeadersRead,
                    HttpContext.RequestAborted);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Upstream request to {UpstreamUrl} failed", upstreamUrl);
                return StatusCode(502, "Bad Gateway: upstream Telegram API unreachable");
            }

            // Mirror status code
            Response.StatusCode = (int)upstreamResponse.StatusCode;

            // Mirror response headers
            foreach (var header in upstreamResponse.Headers)
            {
                if (_excludedResponseHeaders.Contains(header.Key))
                    continue;
                Response.Headers[header.Key] = header.Value.ToArray();
            }
            foreach (var header in upstreamResponse.Content.Headers)
            {
                if (_excludedResponseHeaders.Contains(header.Key))
                    continue;
                Response.Headers[header.Key] = header.Value.ToArray();
            }

            // Stream response body back to caller
            await upstreamResponse.Content.CopyToAsync(Response.Body, HttpContext.RequestAborted);

            // Return an EmptyResult — we've already written to Response directly
            return new EmptyResult();
        }
    }
}
