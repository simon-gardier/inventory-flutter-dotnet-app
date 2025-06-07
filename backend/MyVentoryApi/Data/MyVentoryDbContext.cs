using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;

using MyVentoryApi.Models;

namespace MyVentoryApi.Data;

// To query the database, use the library Language-Integrated Query (LINQ)
public class MyVentoryDbContext(DbContextOptions<MyVentoryDbContext> options) : IdentityDbContext<
    User,
    UserRole,
    int,
    IdentityUserClaim<int>,
    IdentityUserRole<int>,
    IdentityUserLogin<int>,
    IdentityRoleClaim<int>,
    IdentityUserToken<int>
>(options)
{
    public required DbSet<UserGroup> UserGroups { get; set; }
    public required DbSet<UserGroupMembership> UserGroupMemberships { get; set; }
    public required DbSet<Lending> Lendings { get; set; }
    public required DbSet<ItemLending> ItemLendings { get; set; }
    public required DbSet<Item> Items { get; set; }
    public required DbSet<ItemImage> ItemImages { get; set; }
    public required DbSet<ItemLocation> ItemLocations { get; set; }
    public required DbSet<Location> Locations { get; set; }
    public required DbSet<LocationImage> LocationImages { get; set; }
    public required DbSet<ItemAttribute> ItemAttributes { get; set; }
    public required DbSet<Models.Attribute> Attributes { get; set; }
    public required DbSet<ItemUserGroup> ItemUserGroups { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.ApplyConfiguration(new UserConfiguration());
        builder.ApplyConfiguration(new UserGroupConfiguration());
        builder.ApplyConfiguration(new UserGroupMembershipConfiguration());
        builder.ApplyConfiguration(new LendingConfiguration());
        builder.ApplyConfiguration(new ItemLendingConfiguration());
        builder.ApplyConfiguration(new ItemConfiguration());
        builder.ApplyConfiguration(new ItemImageConfiguration());
        builder.ApplyConfiguration(new ItemLocationConfiguration());
        builder.ApplyConfiguration(new LocationConfiguration());
        builder.ApplyConfiguration(new LocationImageConfiguration());
        builder.ApplyConfiguration(new ItemAttributeConfiguration());
        builder.ApplyConfiguration(new AttributeConfiguration());
        builder.ApplyConfiguration(new ItemUserGroupConfiguration());

        // Add index on Value column for refresh token search performance
        builder.Entity<IdentityUserToken<int>>()
            .HasIndex(t => t.Value)
            .HasDatabaseName("IX_AspNetUserTokens_Value");
    }
}
