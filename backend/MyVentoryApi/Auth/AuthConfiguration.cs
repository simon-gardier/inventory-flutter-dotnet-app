using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using System.Text;

using MyVentoryApi.Data;
using MyVentoryApi.Models;

namespace MyVentoryApi.Auth;

public static class AuthConfiguration
{
    public static IServiceCollection AddAuthServices(this IServiceCollection services)
    {
        // Retrieve parameters from environment variables
        var jwtKey = Environment.GetEnvironmentVariable("JWT_SECRET_KEY") ??
                     throw new InvalidOperationException("⚠️  JWT_SECRET_KEY not found in environment variables");

        var jwtIssuer = Environment.GetEnvironmentVariable("JWT_ISSUER") ??
                        throw new InvalidOperationException("⚠️  JWT_ISSUER not found in environment variables");

        var jwtAudience = Environment.GetEnvironmentVariable("JWT_AUDIENCE") ??
                          throw new InvalidOperationException("⚠️  JWT_AUDIENCE not found in environment variables");

        // Configure Identity
        services.AddIdentity<User, UserRole>(options =>
        {
            // Password security configuration
            options.Password.RequiredLength = 8;
            options.Password.RequireDigit = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireUppercase = true;
            options.Password.RequireNonAlphanumeric = true;

            // Account lockout configuration
            options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            options.Lockout.MaxFailedAccessAttempts = 3;
            options.Lockout.AllowedForNewUsers = true;

            // User configuration
            options.User.RequireUniqueEmail = true;
            options.SignIn.RequireConfirmedEmail = true;

            // User configuration
            options.User.RequireUniqueEmail = true;
            options.User.RequireUniqueEmail = true; // Email uniqueness
            options.User.AllowedUserNameCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._@+";

            // Token configuration for email confirmation and password reset
            options.Tokens.EmailConfirmationTokenProvider = TokenOptions.DefaultEmailProvider;
            options.Tokens.PasswordResetTokenProvider = TokenOptions.DefaultProvider;
        })
        .AddEntityFrameworkStores<MyVentoryDbContext>()
        .AddDefaultTokenProviders();

        // Configure JWT authentication
        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
        })
        .AddJwtBearer(options =>
        {
            options.SaveToken = true;

            options.RequireHttpsMetadata = true;
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidIssuer = jwtIssuer,
                ValidAudience = jwtAudience,
                ClockSkew = TimeSpan.Zero
            };

            options.Events = new JwtBearerEvents
            {
                OnAuthenticationFailed = context =>
                {
                    if (context.Exception.GetType() == typeof(SecurityTokenExpiredException))
                    {
                        context.Response.StatusCode = 401;
                        context.Response.Headers.Append("Token-Expired", "true");
                    }
                    return Task.CompletedTask;
                }
            };
        });

        // Register the JWT service
        services.AddScoped<JwtTokenService>();


        // Configure token provider options
        services.Configure<DataProtectionTokenProviderOptions>(options =>
        {
            // Set token lifespan to 24 hours for security tokens like 
            // password reset links or email confirmation links
            options.TokenLifespan = TimeSpan.FromHours(24);
        });

        return services;
    }
}