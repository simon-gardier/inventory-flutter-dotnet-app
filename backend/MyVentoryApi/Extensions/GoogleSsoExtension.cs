using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.Extensions.Logging;
using System.Security.Claims;

namespace MyVentoryApi.Extensions
{
    public static class GoogleSsoExtension
    {
        public static AuthenticationBuilder AddGoogleSso(this AuthenticationBuilder authBuilder, ILogger logger)
        {
            // Web client configuration
            authBuilder.AddGoogle("Google-Web", options =>
            {
                options.ClientId = Environment.GetEnvironmentVariable("GOOGLE_WEB_CLIENT_ID") ?? "";
                options.ClientSecret = Environment.GetEnvironmentVariable("GOOGLE_WEB_CLIENT_SECRET") ?? "";
                options.CallbackPath = "/api/auth/callback/google";
                options.SaveTokens = true;

                // Add custom claims mapping (this step is optional)
                options.ClaimActions.MapJsonKey(ClaimTypes.NameIdentifier, "sub");
                options.ClaimActions.MapJsonKey(ClaimTypes.Name, "name");
                options.ClaimActions.MapJsonKey(ClaimTypes.GivenName, "given_name");
                options.ClaimActions.MapJsonKey(ClaimTypes.Surname, "family_name");
                options.ClaimActions.MapJsonKey(ClaimTypes.Email, "email");

                options.Events.OnTicketReceived = context =>
                {
                    // Log successful ticket reception
                    var userName = context.Principal?.Identity?.Name ?? "Unknown User";
                    logger.LogInformation("Received Google ticket for {UserName}", userName);
                    return Task.CompletedTask;
                };
            });

            // Android client configuration
            authBuilder.AddGoogle("Google-Android", options =>
            {
                options.ClientId = Environment.GetEnvironmentVariable("GOOGLE_ANDROID_CLIENT_ID") ?? "";
                options.ClientSecret = Environment.GetEnvironmentVariable("GOOGLE_ANDROID_CLIENT_SECRET") ?? "";
                options.CallbackPath = "/api/auth/callback/google/android";
                options.SaveTokens = true;
            });

            return authBuilder;
        }
    }
}