using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Data;
using MyVentoryApi.Endpoints;
using MyVentoryApi.Repositories;
using MyVentoryApi.Extensions;
using DotNetEnv;
using Microsoft.OpenApi.Models;
using Microsoft.AspNetCore.Identity;
using MyVentoryApi.Utilities;
using MyVentoryApi.Auth;
using MyVentoryApi.Models;
using System.Text.Json.Serialization;
using MyVentoryApi.Services;

Env.Load();

var builder = WebApplication.CreateBuilder(args);

// Logger configuration
var logger = LoggerFactory.Create(loggingBuilder =>
{
    loggingBuilder.AddConsole();
    loggingBuilder.AddDebug();
    loggingBuilder.SetMinimumLevel(LogLevel.Information);
}).CreateLogger<Program>();

if (builder.Environment.IsProduction())
{
    builder.Logging.SetMinimumLevel(LogLevel.Warning);
    builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.None);
    builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Migrations", LogLevel.None);
}
if (builder.Environment.IsDevelopment())
{
    builder.Logging.SetMinimumLevel(LogLevel.Information);
}
if (builder.Environment.IsStaging())
{
    builder.Logging.SetMinimumLevel(LogLevel.Information);
    builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.None);
    builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Migrations", LogLevel.None);
}

// Add services to the dependency container
builder.Services.AddScoped<UserManager<User>>();
builder.Services.AddScoped<RoleManager<UserRole>>();

// Configure PostgreSQL database context
if (builder.Environment.IsProduction() || builder.Environment.IsDevelopment())
{
    var connectionString = Environment.GetEnvironmentVariable("DATABASE_CONNECTION_STRING")
    ?? throw new InvalidOperationException("⚠️  You need to add a DATABASE_CONNECTION_STRING in your environment variables (e.g. in a .env file).");
    builder.Services.AddDbContext<MyVentoryDbContext>(opt => opt.UseNpgsql(connectionString));
}
else if (builder.Environment.IsStaging())
{
    var connectionString = Environment.GetEnvironmentVariable("DATABASE_TESTS_CONNECTION_STRING")
    ?? throw new InvalidOperationException("⚠️  You need to add a DATABASE_TESTS_CONNECTION_STRING in your environment variables (e.g. in a .env file).");
    builder.Services.AddDbContext<MyVentoryDbContext>(opt => opt.UseNpgsql(connectionString));
}

// Personalized configuration for authentication and Identity
builder.Services.AddAuthServices();

// Add Google SSO authentication
builder.Services.AddAuthentication()
    .AddGoogleSso(logger);

// Add logging
builder.Services.AddLogging(loggingBuilder =>
{
    // Add console logging
    loggingBuilder.AddConsole();
    // Add debug logging
    loggingBuilder.AddDebug();
    // Set the minimum log level to Information
    loggingBuilder.SetMinimumLevel(LogLevel.Information);
});

builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.Preserve;
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

// Add custom repositories to access data from the database
builder.Services.AddAllMyVentoryRepositories();

// Enable developer exceptions for database-related errors
builder.Services.AddDatabaseDeveloperPageExceptionFilter();

// Add services for API doc
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Version = "v1",
        Title = "MyVentory API",
        Description = "A Dotnet Web API for managing your belongings"
    });

    options.OperationFilter<SwaggerFileOperationFilter>();

    // JWT security configuration for Swagger
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Description = "Enter 'Bearer' [space] and your token"
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Enable anti-forgery services
builder.Services.AddAntiforgery(options =>
{
    options.Cookie.Name = "X-CSRF-TOKEN"; // Optionally, set a custom name for the cookie
    options.HeaderName = "X-XSRF-TOKEN"; // Set the header name if necessary
});

var backendBaseUrl = Environment.GetEnvironmentVariable("BACKEND_BASE_URL") ?? throw new InvalidOperationException("⚠️  You need to add a BACKEND_BASE_URL in your environment variables (e.g. in a .env file).");
var websiteBaseUrl = Environment.GetEnvironmentVariable("WEBSITE_BASE_URL") ?? throw new InvalidOperationException("⚠️  You need to add a WEBSITE_BASE_URL in your environment variables (e.g. in a .env file).");

// Allow frontend and backend cross-origin requests
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontendAndBackend",
        policy =>
        {
            if (builder.Environment.IsDevelopment())
            {
                policy.AllowAnyOrigin()
                      .AllowAnyHeader()
                      .AllowAnyMethod();
            }
            else
            {
                policy.SetIsOriginAllowed(origin =>
                    origin.StartsWith(backendBaseUrl, StringComparison.OrdinalIgnoreCase) ||
                    origin.StartsWith(websiteBaseUrl, StringComparison.OrdinalIgnoreCase))
                      .AllowAnyHeader()
                      .AllowAnyMethod();
            }
        });
});

// Add HttpClient services to the container to make HTTP requests for external APIs
builder.Services.AddHttpClient();

// Add email services (for sending confirmation emails and password reset links) 
builder.Services.AddScoped<IEmailService, SendGridEmailService>();

// Register GoogleAuthService
builder.Services.AddScoped<GoogleAuthService>();

builder.Services.AddScoped<IUserRepository, UserRepository>();

builder.Services.AddHostedService<LendingDueDateNotifier>();

var app = builder.Build();

app.UseRouting();
app.UseCors("AllowFrontendAndBackend");

// Generation of the API documentation
app.UseOpenApi();
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "v1");
    options.RoutePrefix = string.Empty;
});

app.UseAntiforgery();

// Add authentication and authorization middleware
app.UseAuthentication();
app.UseAuthorization();

// Update database tables
app.ApplyMigrations();
logger = app.Services.GetRequiredService<ILogger<Program>>();
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<MyVentoryDbContext>();
        var userManager = services.GetRequiredService<UserManager<User>>();
        var roleManager = services.GetRequiredService<RoleManager<UserRole>>();

        // Seed data asynchronously
        await DbSeeder.SeedAsync(context, logger, userManager, roleManager);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred while seeding the database.");
    }
}

app.MapAllMyVentoryEndpoints();

await app.InitializeRolesAsync();

logger.LogInformation("Running in {EnvironmentName} mode...", app.Environment.EnvironmentName);

await app.RunAsync();

public partial class Program { }
