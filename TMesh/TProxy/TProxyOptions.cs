namespace TProxy;

public class TProxyOptions
{
    public string MqttAddress { get; set; } 
    public int MqttPort { get; set; }
    public string MqttUser { get; set; }
    public string MqttPassword { get; set; }

    public bool MqttAllowUntrustedCertificates { get; set; }
    public bool MqttUseTls { get; set; }
    public string MqttTelegramTopic { get; set; }
    public string MqttStatusTopic { get; set; }

    // Telegram webhook security
    public string TelegramWebhookSecret { get; set; } // expected header value
    public bool DisableTelegramTokenValidation { get; set; } // set true in development to skip validation

    // Telegram Bot API proxy
    /// <summary>
    /// Upstream Telegram Bot API base URL. Defaults to https://api.telegram.org when null/empty.
    /// </summary>
    public string TelegramApiBaseUrl { get; set; }

    /// <summary>
    /// Secret value that callers must supply in <see cref="ProxyAuthHeader"/> to use the
    /// Telegram API proxy. When null/empty the proxy auth check is disabled (dev/internal use).
    /// </summary>
    public string ProxyAuthSecret { get; set; }

    /// <summary>
    /// HTTP request header name checked for <see cref="ProxyAuthSecret"/>.
    /// Defaults to "X-Api-Key" when null/empty.
    /// </summary>
    public string ProxyAuthHeader { get; set; }
}
