using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Models;
using MyVentoryApi.Data;
using Attribute = MyVentoryApi.Models.Attribute;
using System.Security.Claims;

namespace MyVentoryApi.Extensions;

public class DbSeederException : Exception
{
    public DbSeederException(string message) : base(message) { }

    public DbSeederException(string message, Exception innerException) : base(message, innerException) { }
}

public static class DbSeeder
{
    private static readonly List<(string UserName, string FirstName, string LastName, string Email, string Password, string Role)> Users = new()
    {
        ("alexander", "Alexander", "Smith", "alexander.smith@example.com", "Alexander123!", "User"),
        ("emily", "Emily", "Johnson", "emily.johnson@example.com", "Emily123!", "User"),
        ("michael", "Michael", "Williams", "michael.williams@example.com", "Michael123!", "User"),
        ("adminUser", "admin", "user", "admin.user@example.com", "Admin123!", "Admin")
    };

    public static void Seed(MyVentoryDbContext context, ILogger logger, UserManager<User> userManager, RoleManager<UserRole> roleManager)
    {
        SeedAsync(context, logger, userManager, roleManager).Wait();
    }
    public static async Task SeedAsync(MyVentoryDbContext context, ILogger logger, UserManager<User> userManager, RoleManager<UserRole> roleManager)
    {
        logger.LogInformation("🔎  Starting database seeding...");
        try
        {
            // Execute seed data operations in correct order
            await SeedRolesAsync(roleManager, logger);
            await SeedUsersAsync(userManager, logger);
            await SeedUserGroupsAsync(context, logger);
            await SeedItemsAsync(context, logger);
            await SeedAttributesAsync(context, logger);
            await SeedItemAttributesAsync(context, logger);
            await SeedItemImagesAsync(context, logger);
            await SeedLocationsAsync(context, logger);
            await SeedLocationImagesAsync(context, logger);
            await SeedLendingsAsync(context, logger);
            logger.LogInformation("🔎  Database seeding completed successfully.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "An error occurred while seeding the database.");
            throw;
        }
    }

    // Helper method to ensure all dates are in UTC
    private static DateTime EnsureUtc(DateTime dateTime)
    {
        if (dateTime.Kind == DateTimeKind.Unspecified)
        {
            return DateTime.SpecifyKind(dateTime, DateTimeKind.Utc);
        }
        else if (dateTime.Kind == DateTimeKind.Local)
        {
            return dateTime.ToUniversalTime();
        }
        return dateTime;
    }

    private static async Task SeedRolesAsync(RoleManager<UserRole> roleManager, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding roles...");

        if (roleManager == null) throw new InvalidOperationException("⚠️  RoleManager is null");
        if (logger == null) throw new InvalidOperationException("⚠️  Logger is null");

        string[] roleNames = ["Admin", "User"];

        foreach (var roleName in roleNames)
        {
            if (!await roleManager.RoleExistsAsync(roleName))
            {
                var role = new UserRole(roleName)
                {
                    Description = $"Standard {roleName} role"
                };

                await roleManager.CreateAsync(role);
                logger.LogInformation("🔎  Added role: {Role}", roleName);
            }
        }
    }

    private static async Task SeedUsersAsync(UserManager<User> userManager, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding users...");

        if ((await userManager.GetUsersInRoleAsync("User")).Count == 0)
        {
            foreach (var user in Users)
            {
                // check if user already exists
                if (await userManager.FindByNameAsync(user.UserName!) == null)
                {
                    var newUser = new User
                    {
                        UserName = user.UserName,
                        FirstName = user.FirstName,
                        LastName = user.LastName,
                        Email = user.Email
                    };
                    var result = await userManager.CreateAsync(newUser, user.Password);

                    if (result.Succeeded)
                    {
                        await userManager.AddToRoleAsync(newUser, user.Role);
                        await userManager.AddClaimAsync(newUser, new Claim("FirstName", user.FirstName));
                        await userManager.AddClaimAsync(newUser, new Claim("LastName", user.LastName));
                        // Confirm user email
                        User userFromDb = await userManager.FindByNameAsync(newUser.UserName) ?? throw new DbSeederException($"User {newUser.UserName} not found");
                        userFromDb.EmailConfirmed = true;
                        await userManager.UpdateAsync(userFromDb);
                        logger.LogInformation("🔎  Created user: {UserName} with role: {Role}", user.UserName, user.Role);
                    }
                    else
                    {
                        var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                        logger.LogWarning("⚠️  Failed to create user {UserName}: {Errors}", user.UserName, errors);
                    }
                }
            }

            logger.LogInformation("🔎  Added {Count} users.", Users.Count);
        }
        else
        {
            logger.LogInformation("🔎  Users already exist, skipping seeding.");
        }
    }

    private static async Task SeedUserGroupsAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding user groups...");

        if (!await context.UserGroups.AnyAsync())
        {
            var userGroups = new List<UserGroup>
            {
                new("Friends", Privacy.Private, "Friends group"),
            };

            await context.UserGroups.AddRangeAsync(userGroups);
            await context.SaveChangesAsync();

            var users = await context.Users.ToListAsync();
            var userGroup = await context.UserGroups.ToListAsync();
            var memberships = users
                .Select(user => new UserGroupMembership(
                    user,
                    userGroup.First(ug => ug.Name == "Friends"),
                    user.UserName == "alexander" ? Role.Founder : Role.Member))
                .ToList();

            await context.UserGroupMemberships.AddRangeAsync(memberships);
            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added user group and memberships.");
        }
        else
        {
            logger.LogInformation("🔎  User groups already exist, skipping seeding.");
        }
    }

    private static async Task SeedItemsAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding items...");

        if (!await context.Items.AnyAsync())
        {
            var users = await context.Users.ToListAsync();

            var alexander = users.FirstOrDefault(u => u.UserName == "alexander");
            var emily = users.FirstOrDefault(u => u.UserName == "emily");
            var michael = users.FirstOrDefault(u => u.UserName == "michael");

            if (alexander == null || emily == null || michael == null)
            {
                logger.LogWarning("⚠️  Users not found, skipping seeding items.");
                return;
            }

            // Create items using the specified constructor
            var items = new List<Item>
            {
                // Alexander's items
                new ("Projector", 1, alexander, "HD projector"),
                new ("Keyboard", 1, alexander, "Mechanical keyboard"),
                new ("Mouse", 2, alexander, "Wireless mouse"),
                new ("Microphone", 1, alexander, "Studio microphone"),
                new ("Tablet", 3, alexander, "10-inch tablet"),
                new ("E-reader", 4, alexander, "E-ink e-reader"),

                // Emily's items
                new ("Headphones", 1, emily, "Wireless headphones"),
                new ("Smartwatch", 1, emily, "Fitness smartwatch"),
                new ("Bluetooth Speaker", 1, emily, "Portable Bluetooth speaker"),
                new ("External Hard Drive", 1, emily, "1TB external hard drive"),
                new ("Monitor", 1, emily, "27-inch 4K monitor"),
                new ("Printer", 1, emily, "Wireless printer"),
                new ("VR Headset", 1, emily, "Virtual reality headset"),

                // Micheal's items
                new ("Backpack", 1, michael, "Travel backpack"),
                new ("Laptop", 1, michael, "15-inch laptop"),
                new ("Smartphone", 1, michael, "Latest model smartphone"),
                new ("Camera", 1, michael, "DSLR camera"),
                new ("Gaming Console", 1, michael, "Next-gen gaming console"),
                new ("Drone", 1, michael, "Quadcopter drone"),
                new ("Power Bank", 1, michael, "20000mAh power bank")
            };
            // Add items to the context
            await context.Items.AddRangeAsync(items);

            var friendsGroup = await context.UserGroups.FirstOrDefaultAsync(ug => ug.Name == "Friends");
            if (friendsGroup == null)
            {
                logger.LogWarning("⚠️  Friends group not found, skipping seeding items.");
                return;
            }

            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} items.", items.Count);
        }
        else
        {
            logger.LogInformation("🔎  Items already exist, skipping seeding.");
        }
    }

    private static async Task SeedAttributesAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding attributes...");

        if (!await context.Attributes.AnyAsync())
        {
            var attributes = new List<Attribute>
            {
                new("Category", "Book"),
                new("Category", "Game"),
                new("Category", "Electronics"),
                new("Category", "Clothing"),
                new("Category", "Furniture"),
                new("Category", "Tool"),
                new("Category", "Food"),
                new("Category", "Drink"),
                new("Category", "Vehicle"),
                new("Category", "Accessory"),
                new("Category", "Travel Gear"),

                new("Link", "Product Page"),
                new("Link", "User Manual"),
                new("Link", "Support Page"),
                new("Link", "Purchase Link"),
                new("Link", "Video Tutorial"),

                new("Date", "Purchase Date"),
                new("Date", "Warranty Expiry"),
                new("Date", "Release Date"),
                new("Date", "Event Date"),
                new("Date", "Maintenance Due"),

                new("Text", "Brand"),
                new("Text", "Model"),
                new("Text", "Serial Number"),
                new("Text", "Description"),
                new("Text", "Notes"),
                new("Text", "Manufacturer"),
                new("Text", "Location"),
                new("Text", "Condition"),
                new("Text", "Material"),
                new("Text", "Style"),
                new("Text", "Storage"),
                new("Text", "Color"),
                new("Text", "GPU"),
                new("Text", "Size"),
                new("Text", "Lens Type"),
                new("Text", "Resolution"),
                new("Text", "Brightness"),

                new("Number", "Weight"),
                new("Number", "Price"),
                new("Number", "Quantity"),
                new("Number", "Rating"),
                new("Number", "Capacity"),
                new("Number", "Length"),
                new("Number", "Width"),
                new("Number", "Height"),
                new("Number", "Power Consumption"),
                new("Number", "Battery Life"),

                new("Currency", "Purchase Price"),
                new("Currency", "Resale Value"),
                new("Currency", "Shipping Cost"),
                new("Currency", "Tax Amount"),
                new("Currency", "Discount Amount")
            };

            await context.Attributes.AddRangeAsync(attributes);
            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} attributes.", attributes.Count);
        }
        else
        {
            logger.LogInformation("🔎  Attributes already exist, skipping seeding.");
        }
    }

    private static async Task SeedItemAttributesAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding item attributes...");

        if (!await context.ItemAttributes.AnyAsync())
        {
            var items = await context.Items.ToListAsync();
            var attributes = await context.Attributes.ToListAsync();

            var itemAttributes = new List<ItemAttribute>
            {
                new(item: items.First(i => i.Name == "Backpack"), attribute: attributes.First(a => a.Name == "Color"), value: "Green"),
                new(item: items.First(i => i.Name == "Backpack"), attribute: attributes.First(a => a.Name == "Size"), value: "Medium"),
                new(item: items.First(i => i.Name == "Backpack"), attribute: attributes.First(a => a.Name == "Material"), value: "Nylon"),
                new(item: items.First(i => i.Name == "Backpack"), attribute: attributes.First(a => a.Name == "Travel Gear"), value: String.Empty),

                new(item: items.First(i => i.Name == "Tablet"), attribute: attributes.First(a => a.Name == "Color"), value: "Silver"),
                new(item: items.First(i => i.Name == "Tablet"), attribute: attributes.First(a => a.Name == "Brand"), value: "Apple"),
                new(item: items.First(i => i.Name == "Tablet"), attribute: attributes.First(a => a.Name == "Model"), value: "iPad Pro"),
                new(item: items.First(i => i.Name == "Tablet"), attribute: attributes.First(a => a.Name == "Storage"), value: "256GB"),
                new(item: items.First(i => i.Name == "Tablet"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),

                new(item: items.First(i => i.Name == "Headphones"), attribute: attributes.First(a => a.Name == "Color"), value: "Blue"),
                new(item: items.First(i => i.Name == "Headphones"), attribute: attributes.First(a => a.Name == "Brand"), value: "Sony"),
                new(item: items.First(i => i.Name == "Headphones"), attribute: attributes.First(a => a.Name == "Battery Life"), value: "20"),

                new(item: items.First(i => i.Name == "Laptop"), attribute: attributes.First(a => a.Name == "Color"), value: "Gray"),
                new(item: items.First(i => i.Name == "Laptop"), attribute: attributes.First(a => a.Name == "Brand"), value: "Dell"),
                new(item: items.First(i => i.Name == "Laptop"), attribute: attributes.First(a => a.Name == "Model"), value: "XPS 15"),

                new(item: items.First(i => i.Name == "Smartphone"), attribute: attributes.First(a => a.Name == "Color"), value: "Midnight Green"),
                new(item: items.First(i => i.Name == "Smartphone"), attribute: attributes.First(a => a.Name == "Brand"), value: "Apple"),
                new(item: items.First(i => i.Name == "Smartphone"), attribute: attributes.First(a => a.Name == "Model"), value: "iPhone 11 Pro"),
                new(item: items.First(i => i.Name == "Smartphone"), attribute: attributes.First(a => a.Name == "Storage"), value: "256GB"),
                new(item: items.First(i => i.Name == "Smartphone"), attribute: attributes.First(a => a.Name == "Battery Life"), value: "18"),

                new(item: items.First(i => i.Name == "Camera"), attribute: attributes.First(a => a.Name == "Color"), value: "Black"),
                new(item: items.First(i => i.Name == "Camera"), attribute: attributes.First(a => a.Name == "Brand"), value: "Canon"),
                new(item: items.First(i => i.Name == "Camera"), attribute: attributes.First(a => a.Name == "Model"), value: "EOS R5"),
                new(item: items.First(i => i.Name == "Camera"), attribute: attributes.First(a => a.Name == "Lens Type"), value: "RF Mount"),

                new(item: items.First(i => i.Name == "Smartwatch"), attribute: attributes.First(a => a.Name == "Color"), value: "Space Gray"),
                new(item: items.First(i => i.Name == "Smartwatch"), attribute: attributes.First(a => a.Name == "Brand"), value: "Apple"),
                new(item: items.First(i => i.Name == "Smartwatch"), attribute: attributes.First(a => a.Name == "Model"), value: "Watch Series 6"),
                new(item: items.First(i => i.Name == "Smartwatch"), attribute: attributes.First(a => a.Name == "Battery Life"), value: "18"),

                new(item: items.First(i => i.Name == "Gaming Console"), attribute: attributes.First(a => a.Name == "Color"), value: "White"),
                new(item: items.First(i => i.Name == "Gaming Console"), attribute: attributes.First(a => a.Name == "Brand"), value: "Sony"),
                new(item: items.First(i => i.Name == "Gaming Console"), attribute: attributes.First(a => a.Name == "Model"), value: "PlayStation 5"),
                new(item: items.First(i => i.Name == "Gaming Console"), attribute: attributes.First(a => a.Name == "Storage"), value: "825GB"),

                new(item: items.First(i => i.Name == "Bluetooth Speaker"), attribute: attributes.First(a => a.Name == "Color"), value: "Red"),
                new(item: items.First(i => i.Name == "Bluetooth Speaker"), attribute: attributes.First(a => a.Name == "Brand"), value: "JBL"),
                new(item: items.First(i => i.Name == "Bluetooth Speaker"), attribute: attributes.First(a => a.Name == "Model"), value: "Flip 5"),
                new(item: items.First(i => i.Name == "Bluetooth Speaker"), attribute: attributes.First(a => a.Name == "Battery Life"), value: "12"),

                new(item: items.First(i => i.Name == "E-reader"), attribute: attributes.First(a => a.Name == "Color"), value: "Black"),
                new(item: items.First(i => i.Name == "E-reader"), attribute: attributes.First(a => a.Name == "Brand"), value: "Amazon"),
                new(item: items.First(i => i.Name == "E-reader"), attribute: attributes.First(a => a.Name == "Model"), value: "Kindle Paperwhite"),
                new(item: items.First(i => i.Name == "E-reader"), attribute: attributes.First(a => a.Name == "Storage"), value: "8GB"),

                new(item: items.First(i => i.Name == "External Hard Drive"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "External Hard Drive"), attribute: attributes.First(a => a.Name == "Brand"), value: "Seagate"),
                new(item: items.First(i => i.Name == "External Hard Drive"), attribute: attributes.First(a => a.Name == "Model"), value: "Backup Plus"),
                new(item: items.First(i => i.Name == "External Hard Drive"), attribute: attributes.First(a => a.Name == "Storage"), value: "1TB"),
                new(item: items.First(i => i.Name == "External Hard Drive"), attribute: attributes.First(a => a.Name == "Color"), value: "Black"),

                new(item: items.First(i => i.Name == "Monitor"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Monitor"), attribute: attributes.First(a => a.Name == "Brand"), value: "LG"),
                new(item: items.First(i => i.Name == "Monitor"), attribute: attributes.First(a => a.Name == "Model"), value: "UltraFine 27UL500"),
                new(item: items.First(i => i.Name == "Monitor"), attribute: attributes.First(a => a.Name == "Size"), value: "27 inches"),
                new(item: items.First(i => i.Name == "Monitor"), attribute: attributes.First(a => a.Name == "Resolution"), value: "4K"),

                new(item: items.First(i => i.Name == "Printer"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Printer"), attribute: attributes.First(a => a.Name == "Brand"), value: "HP"),
                new(item: items.First(i => i.Name == "Printer"), attribute: attributes.First(a => a.Name == "Model"), value: "OfficeJet Pro 9015"),
                new(item: items.First(i => i.Name == "Printer"), attribute: attributes.First(a => a.Name == "Color"), value: "White"),

                new(item: items.First(i => i.Name == "Drone"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Drone"), attribute: attributes.First(a => a.Name == "Brand"), value: "DJI"),
                new(item: items.First(i => i.Name == "Drone"), attribute: attributes.First(a => a.Name == "Model"), value: "Mavic Air 2"),
                new(item: items.First(i => i.Name == "Drone"), attribute: attributes.First(a => a.Name == "Battery Life"), value: "1"),
                new(item: items.First(i => i.Name == "Drone"), attribute: attributes.First(a => a.Name == "Weight"), value: "570g"),

                new(item: items.First(i => i.Name == "VR Headset"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "VR Headset"), attribute: attributes.First(a => a.Name == "Brand"), value: "Oculus"),
                new(item: items.First(i => i.Name == "VR Headset"), attribute: attributes.First(a => a.Name == "Model"), value: "Quest 2"),
                new(item: items.First(i => i.Name == "VR Headset"), attribute: attributes.First(a => a.Name == "Resolution"), value: "1832x1920 per eye"),
                new(item: items.First(i => i.Name == "VR Headset"), attribute: attributes.First(a => a.Name == "Battery Life"), value: "2"),

                new(item: items.First(i => i.Name == "Projector"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Projector"), attribute: attributes.First(a => a.Name == "Brand"), value: "Epson"),
                new(item: items.First(i => i.Name == "Projector"), attribute: attributes.First(a => a.Name == "Model"), value: "Home Cinema 2250"),
                new(item: items.First(i => i.Name == "Projector"), attribute: attributes.First(a => a.Name == "Resolution"), value: "1080p"),
                new(item: items.First(i => i.Name == "Projector"), attribute: attributes.First(a => a.Name == "Brightness"), value: "2700 lumens"),

                new(item: items.First(i => i.Name == "Keyboard"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Keyboard"), attribute: attributes.First(a => a.Name == "Brand"), value: "Corsair"),
                new(item: items.First(i => i.Name == "Keyboard"), attribute: attributes.First(a => a.Name == "Model"), value: "K95 RGB Platinum"),
                new(item: items.First(i => i.Name == "Keyboard"), attribute: attributes.First(a => a.Name == "Color"), value: "Black"),

                new(item: items.First(i => i.Name == "Mouse"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Mouse"), attribute: attributes.First(a => a.Name == "Brand"), value: "Logitech"),
                new(item: items.First(i => i.Name == "Mouse"), attribute: attributes.First(a => a.Name == "Model"), value: "MX Master 3"),
                new(item: items.First(i => i.Name == "Mouse"), attribute: attributes.First(a => a.Name == "Color"), value: "Graphite"),

                new(item: items.First(i => i.Name == "Microphone"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Microphone"), attribute: attributes.First(a => a.Name == "Brand"), value: "Blue"),
                new(item: items.First(i => i.Name == "Microphone"), attribute: attributes.First(a => a.Name == "Model"), value: "Yeti"),
                new(item: items.First(i => i.Name == "Microphone"), attribute: attributes.First(a => a.Name == "Color"), value: "Silver"),
                new(item: items.First(i => i.Name == "Microphone"), attribute: attributes.First(a => a.Name == "Condition"), value: "New"),

                new(item: items.First(i => i.Name == "Power Bank"), attribute: attributes.First(a => a.Name == "Electronics"), value: String.Empty),
                new(item: items.First(i => i.Name == "Power Bank"), attribute: attributes.First(a => a.Name == "Brand"), value: "Anker"),
                new(item: items.First(i => i.Name == "Power Bank"), attribute: attributes.First(a => a.Name == "Model"), value: "PowerCore 20000"),
                new(item: items.First(i => i.Name == "Power Bank"), attribute: attributes.First(a => a.Name == "Capacity"), value: "20000mAh"),
                new(item: items.First(i => i.Name == "Power Bank"), attribute: attributes.First(a => a.Name == "Color"), value: "Black")
            };

            await context.ItemAttributes.AddRangeAsync(itemAttributes);
            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} item attributes.", itemAttributes.Count);
        }
        else
        {
            logger.LogInformation("🔎  Item attributes already exist, skipping seeding.");
        }
    }

    private static async Task<List<byte[]>> SafeReadMultipleImagesAsync(string baseDirectory, string itemName)
    {
        var sanitizedBase = new string([.. itemName.Where(c => char.IsLetterOrDigit(c) || c == '_')]);

        var basePath = Path.GetFullPath(baseDirectory);

        var images = new List<byte[]>();
        int index = 1;

        while (true)
        {
            string filename = $"{sanitizedBase}_{index}.jpg";
            string fullPath = Path.GetFullPath(Path.Combine(baseDirectory, filename));

            if (!fullPath.StartsWith(basePath, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Attempted Path traversal detected");

            if (!File.Exists(fullPath))
                break;

            var data = await File.ReadAllBytesAsync(fullPath);
            images.Add(data);

            index++;
        }

        return images;
    }

    private static async Task SeedItemImagesAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding item images...");

        if (!await context.ItemImages.AnyAsync())
        {
            var items = await context.Items.ToListAsync();

            var itemImages = new List<ItemImage>();
            var baseDir = AppContext.BaseDirectory;
            var imagesFolder = Path.Combine(baseDir, "Images");

            foreach (var item in items)
            {
                try
                {
                    var images = await SafeReadMultipleImagesAsync(imagesFolder, item.Name);
                    foreach (var img in images)
                    {
                        itemImages.Add(new ItemImage(item, img));
                    }
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "⚠️ Failed to create item images {ItemName}", item.Name);
                }
            }

            await context.ItemImages.AddRangeAsync(itemImages);
            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} images.", itemImages.Count);
        }
        else
        {
            logger.LogInformation("🔎  Item images already exist, skipping seeding.");
        }
    }

    private static async Task SeedLocationsAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding locations...");

        if (!await context.Locations.AnyAsync())
        {
            var alexander = await context.Users.FirstOrDefaultAsync(u => u.UserName == "alexander");
            var emily = await context.Users.FirstOrDefaultAsync(u => u.UserName == "emily");
            var michael = await context.Users.FirstOrDefaultAsync(u => u.UserName == "michael");

            if (alexander == null || emily == null || michael == null)
            {
                logger.LogWarning("⚠️  Users not found.");
                return;
            }

            // Alexander's locations
            var warehouse = new Location(name: "Warehouse", capacity: 500, owner: alexander, description: "Storage warehouse");
            var bathroom = new Location(name: "Bathroom", capacity: 4, owner: alexander, description: "Warehouse bathroom", parentLocation: warehouse);
            var office = new Location(name: "Office", capacity: 30, owner: alexander, description: "Home office");
            // Emily's locations
            var garage = new Location(name: "Garage", capacity: 200, owner: emily, description: "Home garage");
            var bedroom = new Location(name: "Bedroom", capacity: 20, owner: emily, description: "Master bedroom");
            // Michael's locations
            var livingRoom = new Location(name: "Living Room", capacity: 50, owner: michael, description: "Main living area");

            var locations = new List<Location> { warehouse, bathroom, garage, livingRoom, office, bedroom };
            var items = await context.Items.ToListAsync();

            var itemLocations = new List<ItemLocation>
            {
                //Alexander's items
                new(item: items.First(i => i.Name == "Projector"), location: office),
                new(item: items.First(i => i.Name == "Keyboard"), location: office),
                new(item: items.First(i => i.Name == "Mouse"), location: office),
                new(item: items.First(i => i.Name == "Microphone"), location: office),
                new(item: items.First(i => i.Name == "Tablet"), location: office),
                new(item: items.First(i => i.Name == "E-reader"), location: warehouse),
                // Emily's items
                new(item: items.First(i => i.Name == "Backpack"), location: livingRoom),
                new(item: items.First(i => i.Name == "Laptop"), location: livingRoom),
                new(item: items.First(i => i.Name == "Smartphone"), location: livingRoom),
                new(item: items.First(i => i.Name == "Camera"), location: livingRoom),
                new(item: items.First(i => i.Name == "Gaming Console"), location: livingRoom),
                new(item: items.First(i => i.Name == "Drone"), location: livingRoom),
                new(item: items.First(i => i.Name == "Power Bank"), location: livingRoom),
                // Michael's items
                new(item: items.First(i => i.Name == "Headphones"), location: bedroom),
                new(item: items.First(i => i.Name == "Smartwatch"), location: bedroom),
                new(item: items.First(i => i.Name == "Bluetooth Speaker"), location: garage),
                new(item: items.First(i => i.Name == "External Hard Drive"), location: garage),
                new(item: items.First(i => i.Name == "Monitor"), location: bedroom),
                new(item: items.First(i => i.Name == "Printer"), location: garage),
                new(item: items.First(i => i.Name == "VR Headset"), location: bedroom)
            };

            await context.Locations.AddRangeAsync(locations);

            await context.ItemLocations.AddRangeAsync(itemLocations);

            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} locations.", locations.Count);
        }
        else
        {
            logger.LogInformation("🔎  Locations already exist, skipping seeding.");
        }
    }

    private static async Task SeedLocationImagesAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding location images...");

        if (!await context.LocationImages.AnyAsync())
        {
            var locations = await context.Locations.ToListAsync();

            var locationImages = new List<LocationImage>();
            var baseDir = AppContext.BaseDirectory;
            var imagesFolder = Path.Combine(baseDir, "Images");

            foreach (var loc in locations)
            {
                try
                {
                    var images = await SafeReadMultipleImagesAsync(imagesFolder, loc.Name);
                    foreach (var img in images)
                    {
                        locationImages.Add(new LocationImage(loc, img));
                    }
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "⚠️ Failed to create item images {LocationName}", loc.Name);
                }
            }

            await context.LocationImages.AddRangeAsync(locationImages);
            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} images.", locationImages.Count);
        }
        else
        {
            logger.LogInformation("🔎  Location images already exist, skipping seeding.");
        }
    }

    private static async Task SeedLendingsAsync(MyVentoryDbContext context, ILogger logger)
    {
        logger.LogInformation("🔎  Seeding lendings...");

        if (!await context.ItemLendings.AnyAsync())
        {
            var alexander = await context.Users.FirstOrDefaultAsync(u => u.UserName == "alexander");
            var emily = await context.Users.FirstOrDefaultAsync(u => u.UserName == "emily");
            var michael = await context.Users.FirstOrDefaultAsync(u => u.UserName == "michael");

            if (alexander == null || emily == null || michael == null)
            {
                logger.LogWarning("⚠️  Users not found.");
                return;
            }

            var now = EnsureUtc(DateTime.UtcNow);
            var returnDate1 = EnsureUtc(now.AddDays(50));
            var returnDate2 = EnsureUtc(now.AddDays(100));
            var returnDate3 = EnsureUtc(now.AddDays(25));

            var lendings = new List<Lending>
            {
                new(emily, alexander, returnDate1),
                new(alexander, emily, returnDate2),
                new(alexander, emily, returnDate3),
                new("John Doe", alexander, returnDate1),
                new("Jane Smith", alexander, returnDate2)
            };

            await context.Lendings.AddRangeAsync(lendings);
            await context.SaveChangesAsync();

            var allLendings = await context.Lendings.ToListAsync();
            var items = await context.Items.ToListAsync();
            var itemLendings = new List<ItemLending>
            {
                new(item: items.First(i => i.Name == "Tablet"), lending: allLendings.First(l => l.BorrowerId == 2 && l.LenderId == 1), quantity: 1),
                new(item: items.First(i => i.Name == "Headphones"), lending: allLendings.First(l => l.BorrowerId == 1 && l.LenderId == 2), quantity: 1),
                new(item: items.First(i => i.Name == "Laptop"), lending: allLendings.First(l => l.BorrowerId == 1 && l.LenderId == 2), quantity: 1),
                new(item: items.First(i => i.Name == "Smartphone"), lending: allLendings.First(l => l.BorrowerId == 2 && l.LenderId == 1), quantity: 1),
                new(item: items.First(i => i.Name == "Camera"), lending: allLendings.First(l => l.BorrowerId == 1 && l.LenderId == 2), quantity: 1),
                new(item: items.First(i => i.Name == "Smartwatch"), lending: allLendings.First(l => l.BorrowerName == "John Doe" && l.LenderId == 1), quantity: 1),
                new(item: items.First(i => i.Name == "Gaming Console"), lending: allLendings.First(l => l.BorrowerName == "Jane Smith" && l.LenderId == 1), quantity: 1)
            };

            await context.ItemLendings.AddRangeAsync(itemLendings);
            await context.SaveChangesAsync();
            logger.LogInformation("🔎  Added {Count} lendings.", lendings.Count);
        }
        else
        {
            logger.LogInformation("🔎  Lendings already exist, skipping seeding.");
        }
    }
}
