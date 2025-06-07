using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Models;
using MyVentoryApi.Data;
using Attribute = MyVentoryApi.Models.Attribute;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;
public class ItemRepositoryException : Exception
{
    public ItemRepositoryException() { }

    public ItemRepositoryException(string message) : base(message) { }

    public ItemRepositoryException(string message, Exception innerException) : base(message, innerException) { }
}
public class ItemRepository(MyVentoryDbContext context, ILogger<UserRepository> logger) : IItemRepository
{
    private readonly MyVentoryDbContext _context = context ?? throw new ArgumentNullException(nameof(context));
    private readonly ILogger<UserRepository> _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    private readonly string dbErrorMessage = "Error while saving to the database";
    private readonly string itemNotFoundMessage = "⚠️  Item not found";
    public async Task<Item> CreateItemAsync(Item item)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(item);

            // Check if the owner exists
            var owner = await _context.Users.FindAsync(item.OwnerId) ?? throw new KeyNotFoundException($"User with ID {item.OwnerId} not found.");

            // Set the owner navigation property
            item.Owner = owner;

            // Add the item
            await _context.Items.AddAsync(item);

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎Item created successfully. ID: {ItemId}", item.ItemId);

            return item;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, dbErrorMessage);
            throw new ItemRepositoryException("  An error occurred while creating the item", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "⚠️  User not found: {Message}", ex.Message);
            throw new KeyNotFoundException("  User not found", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while creating the item");
            throw new ItemRepositoryException("  An error occurred while creating the item", ex);
        }
    }

    public async Task<ItemInfoDto> GetItemAsync(int itemId)
    {
        try
        {
            var itemDto = await _context.Items
                .Where(i => i.ItemId == itemId)
                .Select(i => new ItemInfoDto
                {
                    ItemId = i.ItemId,
                    Name = i.Name,
                    Quantity = i.Quantity,
                    Description = i.Description,
                    OwnerId = i.OwnerId,
                    OwnerName = i.Owner.UserName,
                    LendingState = i.GetLendingStates(i.OwnerId), //TODO update with the id of the user doing the request
                    Location = i.ItemLocations.OrderByDescending(il => il.AssignmentDate).Select(il => il.Location != null ? il.Location.Name : null).FirstOrDefault() ?? string.Empty,
                    CreatedAt = i.CreatedAt,
                    UpdatedAt = i.UpdatedAt
                })
                .FirstOrDefaultAsync() ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");
            _logger.LogInformation("🔎Item retrieved successfully. ID: {ItemId}", itemId);
            return itemDto;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage, ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving the item");
            throw new ItemRepositoryException("  An error occurred while retrieving the item", ex);
        }
    }

    public async Task UpdateItemAsync(int itemId, Item updatedItem)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(updatedItem);

            if (string.IsNullOrWhiteSpace(updatedItem.Name))
            {
                throw new ArgumentException("  Item name cannot be empty", nameof(updatedItem));
            }

            if (updatedItem.Quantity < 0)
            {
                throw new ArgumentException("  Item quantity cannot be negative", nameof(updatedItem));
            }

            // Find the existing item
            var existingItem = await _context.Items.FindAsync(itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            // Update the item properties
            existingItem.Name = updatedItem.Name;
            existingItem.Description = updatedItem.Description;
            existingItem.Quantity = updatedItem.Quantity;

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎Item updated successfully. ID: {ItemId}", itemId);

        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, dbErrorMessage);
            throw new ItemRepositoryException("  An error occurred while updating the item", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while updating the item");
            throw new ItemRepositoryException("  An error occurred while updating the item", ex);
        }
    }

    public async Task AddImagesToItemAsync(int itemId, IEnumerable<byte[]> images)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(images);

            // Find the existing item
            var existingItem = await _context.Items.FindAsync(itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            // Add images to the item
            foreach (var image in images)
            {
                var itemImage = new ItemImage(existingItem, image);
                await _context.ItemImages.AddAsync(itemImage);
            }

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎Images added successfully to item ID: {ItemId}", itemId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, dbErrorMessage);
            throw new ItemRepositoryException("  An error occurred while adding images to the item", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while adding images to the item");
            throw new ItemRepositoryException("  An error occurred while adding images to the item", ex);
        }
    }

    public async Task<IEnumerable<ItemImage>> GetItemImagesAsync(int itemId)
    {
        try
        {
            // Find the existing item
            var existingItem = await _context.Items
                .Include(i => i.Images)
                .FirstOrDefaultAsync(i => i.ItemId == itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            _logger.LogInformation("🔎Images retrieved successfully for item ID: {ItemId}", itemId);
            return existingItem.Images ?? Enumerable.Empty<ItemImage>();
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving images for the item");
            throw new ItemRepositoryException("  An error occurred while retrieving images for the item", ex);
        }
    }

    public async Task RemoveImagesFromItemAsync(int itemId, IEnumerable<int> imageIds)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(imageIds);

            // Find the existing item
            var existingItem = await _context.Items
                .Include(i => i.Images)
                .FirstOrDefaultAsync(i => i.ItemId == itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            if (existingItem.Images == null || existingItem.Images.Count == 0)
            {
                throw new KeyNotFoundException($"No images found for the item ID {itemId}");
            }

            if (!imageIds.Any())
            {
                throw new ArgumentException("  No image IDs provided to remove", nameof(imageIds));
            }

            if (imageIds.Count() > existingItem.Images.Count)
            {
                throw new ArgumentException("  The number of images to remove exceeds the total number of images associated with the item", nameof(imageIds));
            }

            // Remove the specified images from the item
            foreach (var imageId in imageIds)
            {
                var itemImage = existingItem.Images.FirstOrDefault(ii => ii.ImageId == imageId);
                if (itemImage != null)
                {
                    _context.ItemImages.Remove(itemImage);
                }
                else
                {
                    _logger.LogWarning("⚠️  Image ID {ImageId} not found for item ID {ItemId}", imageId, itemId);
                    throw new KeyNotFoundException($"Image with ID {imageId} not found for the item ID {itemId}");
                }
            }

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎Images removed successfully from item ID: {ItemId}", itemId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "An error occurred while removing images from the item");
            throw new ItemRepositoryException("  An error occurred while removing images from the item", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while removing images from the item");
            throw new ItemRepositoryException("  An error occurred while removing images from the item", ex);
        }
    }

    public async Task DeleteItemAsync(int itemId)
    {
        try
        {
            // find the existing item to delete
            var item = await _context.Items
                .Include(i => i.ItemAttributes)
                .Include(i => i.ItemLendings)
                .Include(i => i.ItemLocations)
                .Include(i => i.Images)
                .FirstOrDefaultAsync(i => i.ItemId == itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            // Transaction to make sure all the related data is deleted / rollback if needed
            using var transaction = await _context.Database.BeginTransactionAsync();

            try
            {
                _context.ItemLendings.RemoveRange(item.ItemLendings);
                await _context.SaveChangesAsync();

                _context.ItemAttributes.RemoveRange(item.ItemAttributes);
                await _context.SaveChangesAsync();

                _context.ItemLocations.RemoveRange(item.ItemLocations);
                await _context.SaveChangesAsync();

                _context.ItemImages.RemoveRange(item.Images);
                await _context.SaveChangesAsync();

                // finally, delete the item itself
                _context.Items.Remove(item);
                await _context.SaveChangesAsync();

                await transaction.CommitAsync();
                _logger.LogInformation("🔎Item with ID {ItemId} successfully deleted along with related data", itemId);
            }
            catch (Exception ex)
            {
                // In case of an error, rollback the transaction
                await transaction.RollbackAsync();
                _logger.LogError(ex, "Transaction rolled back while deleting item {ItemId}", itemId);
                throw new ItemRepositoryException("  An error occurred while deleting the item and its related data", ex);
            }
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "⚠️  Delete failed: {Message}", ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while deleting item {ItemId}", itemId);
            throw new ItemRepositoryException("  An error occurred while deleting the item", ex);
        }
    }

    public async Task<IEnumerable<(Attribute Attribute, string Value)>> GetItemAttributesAsync(int itemId)
    {
        try
        {
            var item = await _context.Items.FindAsync(itemId);
            if (item == null)
                throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            // Retrieve the attributes associated with the item with their values
            var itemAttributes = await _context.ItemAttributes
                .Where(ia => ia.ItemId == itemId)
                .Include(ia => ia.Attribute)
                .ToListAsync();

            var result = itemAttributes.Select(ia => (ia.Attribute, ia.Value ?? string.Empty)).ToList();

            _logger.LogInformation("🔎Retrieved {Count} attributes successfully for item ID: {ItemId}", result.Count, itemId);

            return result;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving attributes for the item");
            throw new ItemRepositoryException("  An error occurred while retrieving attributes for the item", ex);
        }
    }

    public async Task AddAttributesToItemAsync(int itemId, IEnumerable<(string Type, string Name, string Value)> attributes)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(attributes);

            // Find the existing item
            var existingItem = await _context.Items.FindAsync(itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            // Add attributes to the database associated with the item
            foreach (var (type, name, value) in attributes)
            {
                // Check if the attribute with the same type and name already exists
                var existingAttribute = await _context.Attributes.FirstOrDefaultAsync(a => a.Type == type && a.Name == name);

                int attributeId;

                if (existingAttribute == null)
                {
                    // The attribute does not exist, create a new one
                    var newAttribute = new Attribute(type, name);
                    await _context.Attributes.AddAsync(newAttribute);
                    await _context.SaveChangesAsync(); // Save changes to get the new attribute ID
                    attributeId = newAttribute.AttributeId;

                    _logger.LogInformation("🔎Attribute created successfully. Type: {Type}, Name: {Name}, Value: {AttributeId}", type, name, attributeId);
                }
                else
                {
                    attributeId = existingAttribute.AttributeId;
                }

                // check if the attribute is already associated with the item with the same value
                var existingItemAttribute = await _context.ItemAttributes.FirstOrDefaultAsync(ia => ia.ItemId == itemId && ia.AttributeId == attributeId && ia.Value == value);

                if (existingItemAttribute == null)
                {
                    // Associate the attribute with the item
                    var attribute = await _context.Attributes.FindAsync(attributeId) ?? throw new KeyNotFoundException($"Internal Error while adding the Attribute.");
                    var itemAttribute = new ItemAttribute
                    {
                        Item = existingItem,
                        Attribute = attribute,
                        Value = value
                    };
                    await _context.ItemAttributes.AddAsync(itemAttribute);
                }
                else
                {
                    _logger.LogWarning("⚠️  Skipped duplicate item-attribute association. Item ID: {ItemId}, Attribute ID: {AttributeId}, Value : {Value}", itemId, attributeId, value);
                }

            }

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎Attributes processing completed successfully for item ID: {ItemId}", itemId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, dbErrorMessage);
            throw new ItemRepositoryException("  An error occurred while adding attributes to the item", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while adding attributes to the item");
            throw new ItemRepositoryException("  An error occurred while adding attributes to the item", ex);
        }
    }

    public async Task RemoveAttributesFromItemAsync(int itemId, IEnumerable<int> attributeIds)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(attributeIds);

            // Find the existing item
            var existingItem = await _context.Items
                .Include(i => i.ItemAttributes)
                .FirstOrDefaultAsync(i => i.ItemId == itemId) ?? throw new KeyNotFoundException($"Item with ID {itemId} not found.");

            // Remove the specified attributes from the item
            foreach (var attributeId in attributeIds)
            {
                var itemAttribute = existingItem.ItemAttributes.FirstOrDefault(ia => ia.AttributeId == attributeId);
                if (itemAttribute != null)
                {
                    _context.ItemAttributes.Remove(itemAttribute);

                    // Check if the attribute is not associated with any other items
                    var isAttributeUsed = await _context.ItemAttributes.AnyAsync(ia => ia.AttributeId == attributeId);
                    if (!isAttributeUsed)
                    {
                        var attribute = await _context.Attributes.FindAsync(attributeId);
                        if (attribute != null)
                        {
                            _context.Attributes.Remove(attribute);
                        }
                    }
                }
                else
                {
                    _logger.LogWarning("⚠️  Attribute ID {AttributeId} not found for item ID {ItemId}", attributeId, itemId);
                    throw new KeyNotFoundException($"Attribute with ID {attributeId} not found for the item ID {itemId}");
                }
            }

            // Save changes
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎Attributes removed successfully from item ID: {ItemId}", itemId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, dbErrorMessage);
            throw new ItemRepositoryException("  An error occurred while removing attributes from the item", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, itemNotFoundMessage, ex.Message);
            throw new KeyNotFoundException(itemNotFoundMessage);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while removing attributes from the item");
            throw new ItemRepositoryException("  An error occurred while removing attributes from the item", ex);
        }
    }

    public async Task<Item?> GetItemByIdAsync(int itemId)
    {
        return await _context.Items.FindAsync(itemId);
    }
}
