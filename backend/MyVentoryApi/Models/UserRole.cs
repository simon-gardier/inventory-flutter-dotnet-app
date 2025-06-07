using Microsoft.AspNetCore.Identity;

namespace MyVentoryApi.Models;

public class UserRole : IdentityRole<int>
{
    public UserRole() : base() { }

    public UserRole(string roleName) : base(roleName) { }

    public string? Description { get; set; }
}

public static class RoleInitializer
{
    public static async Task InitializeRolesAsync(this IApplicationBuilder app)
    {
        using var scope = app.ApplicationServices.CreateScope();
        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<UserRole>>();
        var roles = new[] { "Admin", "User" };

        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
                await roleManager.CreateAsync(new UserRole(role));
        }
    }
}
