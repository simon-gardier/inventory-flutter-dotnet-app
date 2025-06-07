using System;
using System.IO;
using dotenv.net;
using DotNetEnv;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MyVentoryApi.Data;
using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using Microsoft.Extensions.Logging;

namespace MyVentoryApi.Tests.Utilities;

public class ApiFixture : IDisposable
{
    public static IServiceProvider? ServiceProvider { get; private set; }
    public WebApplicationFactory<Program> Factory { get; private set; }
    public MyVentoryDbContext? DbContext { get; private set; }

    public ApiFixture()
    {
        // Initialize the factory and start the backend
        var projectDir = Directory.GetCurrentDirectory();
        var envPath = Path.Combine(projectDir, ".env");
        Env.Load(envPath);

        Factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Staging");

            builder.ConfigureAppConfiguration((context, configBuilder) =>
            {
                configBuilder.AddEnvironmentVariables();
                var projectDir = Directory.GetCurrentDirectory();
                var configPath = Path.Combine(projectDir, ".env");
                Env.Load(configPath);
            });

            builder.ConfigureServices(services =>
            {
                var sp = services.BuildServiceProvider();
                var config = sp.GetRequiredService<IConfiguration>();

                var connStr = config["DATABASE_TESTS_CONNECTION_STRING"];
                services.AddDbContext<MyVentoryDbContext>(options =>
                    options.UseNpgsql(connStr));

                // Apply migrations once at the start
                using var scope = sp.CreateScope();
                DbContext = scope.ServiceProvider.GetRequiredService<MyVentoryDbContext>();
                DbContext.Database.EnsureDeleted();
                DbContext.Database.Migrate();
            });
            // Disable logging to avoid cluttering the test output
            builder.ConfigureLogging(logging =>
            {
                logging.ClearProviders();
            });
        });
        ServiceProvider = Factory.Services;
    }

    // Provide access to the UserManager and UserRepository services of MyVentoryApi. 
    // Usefull in the tests that need specific arrangement of the DB before doing the tests
    public static T GetService<T>() where T : notnull => ServiceProvider!.GetRequiredService<T>();
    public static UserManager<User> GetUserManager() => GetService<UserManager<User>>();
    public static MyVentoryDbContext GetDbContext() => GetService<MyVentoryDbContext>();
    public static IUserRepository GetUserRepository() => GetService<IUserRepository>();
    // Returns an HttpClient we can use in tests to query the backend API. Do not use the same http client for multiple users/tests 
    public HttpClient CreateClient() => Factory.CreateClient();

    public void Dispose()
    {
        DbContext?.Dispose();
        Factory?.Dispose();
    }
}
