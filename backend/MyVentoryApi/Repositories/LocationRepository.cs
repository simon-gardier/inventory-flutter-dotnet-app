using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Models;
using MyVentoryApi.Data;

namespace MyVentoryApi.Repositories;

public class LocationRepository(MyVentoryDbContext context, ILogger<UserRepository> logger) : ILocationRepository
{
    private readonly MyVentoryDbContext _context = context ?? throw new ArgumentNullException(nameof(context));
    private readonly ILogger<UserRepository> _logger = logger ?? throw new ArgumentNullException(nameof(logger));

    public async Task<Location> CreateLocationAsync(Location location)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(location);

            // Add the location
            await _context.Locations.AddAsync(location);

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Location created successfully. ID: {LocationId}", location.LocationId);

            return location;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while creating the location", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while creating the location");
            throw;
        }
    }


    public async Task<Location> GetLocationByIdAsync(int locationId)
    {
        try
        {
            var location = await _context.Locations
                .Include(l => l.Images)
                .Include(l => l.ItemLocations)
                    .ThenInclude(il => il.Item)
                .FirstOrDefaultAsync(l => l.LocationId == locationId) ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            _logger.LogInformation("🔎  Location retrieved successfully. ID: {LocationId}", locationId);
            return location;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogError(ex, "Location not found");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving the location");
            throw;
        }
    }

    public async Task SetParentLocationAsync(int locationId, int parentLocationId)
    {
        if (locationId == parentLocationId)
        {
            throw new InvalidOperationException("  You cannot move a location into itself");
        }
        try
        {
            var location = await _context.Locations.FindAsync(locationId)
                ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            if (parentLocationId != 0)
            {
                var parentLocation = await _context.Locations.FindAsync(parentLocationId) ?? throw new KeyNotFoundException($"Parent location with ID {parentLocationId} not found.");
                location.ParentLocationId = parentLocationId;
            }
            else
                location.ParentLocationId = null;
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Parent location set successfully. Location ID: {LocationId}, Parent Location ID: {ParentLocationId}", locationId, parentLocationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while setting the parent location", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  Location or parent location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while setting the parent location");
            throw;
        }
    }


    public async Task DeleteLocationAsync(int locationId)
    {
        try
        {
            // Find the existing location
            var existingLocation = await _context.Locations
                .Include(l => l.Images)
                .FirstOrDefaultAsync(l => l.LocationId == locationId)
                ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            // Remove the location
            _context.Locations.Remove(existingLocation);

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Location deleted successfully. ID: {LocationId}", locationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while deleting the location", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  Location not found: {Message}", ex.Message);
            throw new KeyNotFoundException($"Error in GetItemsByLocationIdAsync: {ex.Message}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while deleting the location");
            throw;
        }
    }
    public async Task<Location> UpdateLocationAsync(int locationId, Location updatedLocation)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(updatedLocation);

            // Find the existing location
            var existingLocation = await _context.Locations.FindAsync(locationId) ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            // Update the location properties
            existingLocation.Name = updatedLocation.Name;
            existingLocation.Capacity = updatedLocation.Capacity;
            existingLocation.Description = updatedLocation.Description;
            existingLocation.OwnerId = updatedLocation.OwnerId;

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Location updated successfully. ID: {LocationId}", locationId);

            return existingLocation;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while updating the location", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  Location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while updating the location");
            throw;
        }
    }
    public async Task AddImageToLocationAsync(LocationImage image)
    {
        try
        {
            ArgumentNullException.ThrowIfNull(image);
            await _context.LocationImages.AddAsync(image);
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Image added successfully to location: {LocationId}", image.LocationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogError(ex, "Location not found");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while adding the image to the location");
            throw;
        }
    }
    public async Task RemoveImageFromLocationAsync(int locationId, int imageId)
    {
        try
        {
            // Find the existing location
            var existingLocation = await _context.Locations
                .Include(l => l.Images)
                .FirstOrDefaultAsync(l => l.LocationId == locationId) ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            // Remove the specified image from the location
            var locationImage = existingLocation.Images.FirstOrDefault(li => li.ImageId == imageId);
            if (locationImage == null)
            {
                throw new KeyNotFoundException($"Image with ID {imageId} not found in location with ID {locationId}.");
            }
            _context.LocationImages.Remove(locationImage);

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Images removed successfully from location ID: {LocationId}", locationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while removing image from the location", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogError("❌Location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while removing image from the location");
            throw;
        }
    }
    public async Task<IEnumerable<LocationImage>> GetImagesByLocationIdAsync(int locationId)
    {
        try
        {
            var images = await _context.LocationImages
                .Where(li => li.LocationId == locationId)
                .ToListAsync();

            _logger.LogInformation("🔎  Images retrieved successfully for location ID: {LocationId}", locationId);
            return images;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogError(ex, "Location not found");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving images for the location");
            throw;
        }
    }
    public async Task RemoveItemFromLocationAsync(int locationId, Item item)
    {
        try
        {
            ArgumentNullException.ThrowIfNull(item);

            var existingLocation = await _context.Locations
                .Include(l => l.ItemLocations)
                .FirstOrDefaultAsync(l => l.LocationId == locationId) ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            var itemLocation = existingLocation.ItemLocations.FirstOrDefault(il => il.ItemId == item.ItemId);
            if (itemLocation == null)
            {
                throw new KeyNotFoundException($"Item with ID {item.ItemId} not found in location with ID {locationId}.");
            }

            _context.ItemLocations.Remove(itemLocation);
            await _context.SaveChangesAsync();
            _logger.LogInformation("🔎  Item removed successfully from location ID: {LocationId}", locationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new InvalidOperationException("  An error occurred while interacting with the database during the operation.", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogError(ex, "Item or location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while removing the item from the location");
            throw;
        }
    }
    public async Task<IEnumerable<Item>> GetItemsByLocationIdAsync(int locationId)
    {
        try
        {
            var itemsLocations = await GetLocationItemLocationsAsync(locationId);

            if (itemsLocations == null || itemsLocations.Count == 0)
            {
                return new List<Item>();
            }
            var items = itemsLocations.Select(il => il!.Item).ToList();

            if (items.Count == 0)
            {
                throw new KeyNotFoundException($"No items found for location with ID {locationId}.");
            }

            _logger.LogInformation("🔎  Items retrieved successfully for location ID: {LocationId}", locationId);
            return items;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  Location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving items for the location");
            throw;
        }
    }

    public async Task<IEnumerable<Location>> GetSublocationsByParentIdAsync(int parentId)
    {
        try
        {
            var sublocations = await _context.Locations
                .Where(l => l.ParentLocationId == parentId)
                .Include(l => l.Owner)
                .ToListAsync();
            _logger.LogInformation("🔎  Sublocations retrieved successfully for parent location ID: {ParentId}", parentId);
            return sublocations;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogError(ex, "Parent location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving sublocations for the parent location");
            throw;
        }
    }

    public async Task MoveItemToLocationAsync(int locationId, Item item)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(item);

            // Find the existing location
            var existingLocation = await _context.Locations.FindAsync(locationId) ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            // Add the item to the location
            var itemLocation = new ItemLocation(item, existingLocation);
            await _context.ItemLocations.AddAsync(itemLocation);

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Item added successfully to location ID: {LocationId}", locationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while adding the item to the location", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  Location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while adding the item to the location");
            throw;
        }
    }

    public async Task<bool> UserHasAccessToLocationAsync(int locationId, int userId, IUserRepository userRepository)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(locationId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);
            ArgumentNullException.ThrowIfNull(userRepository);

            var location = await _context.Locations
                .FirstOrDefaultAsync(l => l.LocationId == locationId);

            if (location == null)
            {
                _logger.LogWarning("⚠️  Location with ID {LocationId} not found while checking if user {UserId} has access",
                    locationId, userId);
                return false;
            }

            // Check if the user is the owner of this location
            bool hasAccess = await userRepository.UserHasAccessAsync(location.OwnerId, userId);

            _logger.LogInformation("🔎  User {UserId} has access to location {LocationId}: {HasAccess}",
                userId, locationId, hasAccess);

            return hasAccess;
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid parameters while checking location access. Location ID: {LocationId}, User ID: {UserId}",
                locationId, userId);
            throw;
        }
        catch (ArgumentNullException ex)
        {
            _logger.LogError(ex, "Required dependency missing while checking if user has access to location");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking if user {UserId} has access to location {LocationId}", userId, locationId);
            throw new Exception($"An error occurred while checking if user has access to location ID {locationId}", ex);
        }
    }

    public async Task AddItemToLocationAsync(int locationId, Item item)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(item);

            // Find the existing location
            var existingLocation = await _context.Locations.FindAsync(locationId) ?? throw new KeyNotFoundException($"Location with ID {locationId} not found.");

            // Add the item to the location
            var itemLocation = new ItemLocation(item, existingLocation);
            await _context.ItemLocations.AddAsync(itemLocation);

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Item added successfully to location ID: {LocationId}", locationId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while adding the item to the location", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  Location not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while adding the item to the location");
            throw;
        }
    }

    public async Task<List<ItemLocation?>> GetLocationItemLocationsAsync(int locationId)
    {
        try
        {
            var groupedItemLocations = await _context.ItemLocations
                .Include(il => il.Item)
                .GroupBy(il => il.ItemId)
                .ToListAsync();

            return groupedItemLocations
                .Select(g => g.OrderByDescending(il => il.AssignmentDate).FirstOrDefault())
                .Where(il => il != null && il.LocationId == locationId)
                .ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving items for location ID: {LocationId}", locationId);
            throw;
        }
    }

    public async Task<int> GetUsedCapacityByLocationIdAsync(int locationId)
    {
        try
        {
            var locationItemLocations = await GetLocationItemLocationsAsync(locationId);
            var totalQuantity = locationItemLocations.Sum(il => il!.Item.Quantity);
            return totalQuantity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving total item quantity for location ID: {LocationId}", locationId);
            throw;
        }
    }
}
