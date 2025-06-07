using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Data;

namespace MyVentoryApi.Extensions;

public static class MigrationsExtensions
{
    public static void ApplyMigrations(this IApplicationBuilder app)
    {
        using IServiceScope serviceScope = app.ApplicationServices.CreateScope();

        using MyVentoryDbContext dbContext = serviceScope.ServiceProvider.GetRequiredService<MyVentoryDbContext>();

        dbContext.Database.Migrate();
    }
}
