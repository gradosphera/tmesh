using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace TProxy
{
    public class Program
    {
        private const string DefaultProxyAuthHeader = "X-Api-Key";

        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services.AddControllers();

            // Add CORS
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowAll", policyBuilder =>
                {
                    policyBuilder.AllowAnyOrigin()
                                 .AllowAnyMethod()
                                 .AllowAnyHeader();
                });
            });

            // Bind options
            builder.Services.Configure<TProxyOptions>(builder.Configuration.GetSection("TProxy"));

            // MQTT publisher service
            builder.Services.AddSingleton<MqttService>();

            // HttpClient for Telegram Bot API proxy
            builder.Services.AddHttpClient("TelegramApiProxy", client =>
            {
                client.Timeout = TimeSpan.FromSeconds(30);
            });

            var app = builder.Build();

            // --- Stealth auth middleware for the Telegram API proxy ---
            // Applies only to /bot{token}/... paths.
            // On header mismatch returns plain 404 with no body — indistinguishable
            // from a non-existent route to anyone probing without the secret.
            app.Use(async (context, next) =>
            {
                var path = context.Request.Path.Value ?? string.Empty;
                if (path.StartsWith("/bot", StringComparison.OrdinalIgnoreCase))
                {
                    var options = context.RequestServices
                        .GetRequiredService<IOptions<TProxyOptions>>().Value;

                    // Auth is only enforced when a secret is configured
                    if (!string.IsNullOrWhiteSpace(options.ProxyAuthSecret))
                    {
                        var headerName = string.IsNullOrWhiteSpace(options.ProxyAuthHeader)
                            ? DefaultProxyAuthHeader
                            : options.ProxyAuthHeader;

                        var provided = context.Request.Headers[headerName].ToString();

                        if (!string.Equals(provided, options.ProxyAuthSecret, StringComparison.Ordinal))
                        {
                            context.Response.StatusCode = 404;
                            return; // do not call next — no body, no hints
                        }
                    }
                }

                await next();
            });
            // ----------------------------------------------------------

            // Configure the HTTP request pipeline.
            app.UseCors("AllowAll");
            app.UseHttpsRedirection();
            app.UseAuthorization();
            app.MapControllers();
            app.Run();
        }
    }
}
