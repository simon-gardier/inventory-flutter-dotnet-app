using Microsoft.AspNetCore.Mvc;
using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using MyVentoryApi.Utilities;
using MyVentoryApi.DTOs;
using SixLabors.ImageSharp;

namespace MyVentoryApi.Endpoints;
public static class ItemEndpoints
{
    public static void MapItemEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/items");
        string groupTag = "Users";

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/
        group.MapPost("/", CreateItemAsync)
            .WithName("CreateItem")
            .WithTags(groupTag)
            .Produces<ItemsCreationResponseDto>(StatusCodes.Status201Created)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Creates a new item. Returns the created item with a 201 status code if successful.")
            .WithSummary("Create a new item")
            .RequireAuthorization();

        group.MapPost("/{itemId}/image", AddItemImagesAsync)
            .Accepts<IFormFileCollection>("multipart/form-data")
            .DisableAntiforgery()
            .WithName("AddItemImage")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Add images to an item")
            .RequireAuthorization();

        group.MapPost("/{itemId}/attributes", AddItemAttributeAsync)
            .WithName("AddItemAttribute")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Adds an attribute to an item. Returns a 204 status code if successful. If the attribute already exists, we simply assign an occurence to the item. If the attribute does exists, we also create it.")
            .WithSummary("Add an attribute to an item")
            .RequireAuthorization();

        /********************************************************/
        /*                      GET Endpoints                   */
        /********************************************************/
        group.MapGet("/{itemId}", GetItemAsync)
            .WithName("GetItem")
            .WithTags(groupTag)
            .Produces<Item>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets an item by ID. Returns the item with a 200 status code if successful.")
            .WithSummary("Get an item by ID")
            .RequireAuthorization();

        group.MapGet("/{itemId}/attributes", GetItemAttributesAsync)
            .WithName("GetItemAttributes")
            .WithTags(groupTag)
            .Produces<IEnumerable<AttributeResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all attributes of an item. Returns the attributes with a 200 status code if successful.")
            .WithSummary("Get all attributes of an item")
            .RequireAuthorization();

        group.MapGet("/{itemId}/images", GetItemImagesAsync)
            .WithName("GetItemImages")
            .WithTags(groupTag)
            .Produces<IEnumerable<ItemImageResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all images of an item. Returns the images with a 200 status code if successful.")
            .WithSummary("Get all images of an item")
            .RequireAuthorization();

        /********************************************************/
        /*                      PUT Endpoints                   */
        /********************************************************/
        group.MapPut("/{itemId}", UpdateItemAsync)
            .WithName("UpdateItem")
            .WithTags(groupTag)
            .Accepts<ItemRequestDto>("application/json")
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Updates an existing item. Returns a 204 status code if successful.")
            .WithSummary("Update an existing item")
            .RequireAuthorization();

        /********************************************************/
        /*                    DELETE Endpoints                  */
        /********************************************************/
        group.MapDelete("/{itemId}", DeleteItemAsync)
           .WithName("DeleteItem")
            .WithTags(groupTag)
           .Produces(StatusCodes.Status204NoContent)
           .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
           .Produces(StatusCodes.Status404NotFound)
           .Produces(StatusCodes.Status500InternalServerError)
           .WithDescription("Deletes an existing item. Returns a 204 status code if successful.")
           .WithSummary("Delete an existing item")
           .RequireAuthorization();

        group.MapDelete("/{itemId}/image", RemoveItemImagesAsync)
            .WithName("RemoveItemImage")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Removes an image from an item. Returns a 204 status code if successful.")
            .WithSummary("Remove an image from an item")
            .RequireAuthorization();

        group.MapDelete("/{itemId}/attributes", RemoveItemAttributesAsync)
            .WithName("RemoveItemAttribute")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Removes an attribute from an item. Returns a 204 status code if successful.")
            .WithSummary("Remove an attribute from an item")
            .RequireAuthorization();
    }

    /********************************************************/
    /*                Endpoints implementation              */
    /********************************************************/
    private static async Task<IResult> CreateItemAsync(ItemRequestDto request, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (request.OwnerId <= 0)
            {
                // before auth so trigger BadRequest instead forbidden if invalid ownerID
                return Results.BadRequest(new { message = "OwnerId is required" });
            }

            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, request.OwnerId, userRepository);
            if (authResult != null)
                return authResult;

            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return Results.BadRequest(new { message = "Name is required" });
            }

            if (request.Quantity < 0)
            {
                return Results.BadRequest(new { message = "Quantity must be >= 0" });
            }

            var now = DateTime.UtcNow;
            var item = new Item
            {
                Name = request.Name,
                Quantity = request.Quantity,
                Description = request.Description ?? string.Empty,
                OwnerId = request.OwnerId,
                CreatedAt = now,
                UpdatedAt = now
            };

            var newItem = await itemRepository.CreateItemAsync(item);

            var itemDto = new ItemsCreationResponseDto
            {
                ItemId = newItem.ItemId,
                Name = newItem.Name,
                Quantity = newItem.Quantity,
                Description = newItem.Description,
                OwnerId = newItem.OwnerId,
                CreatedAt = newItem.CreatedAt,
                UpdatedAt = newItem.UpdatedAt
            };

            return Results.Created($"/api/items/{itemDto.ItemId}", itemDto);
        }
        catch (ArgumentNullException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while creating the item");
        }
    }

    private static async Task<IResult> AddItemImagesAsync(string itemId, IFormFileCollection images, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID" });
            }
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            if (images == null || images.Count == 0)
            {
                return Results.BadRequest(new { message = "No image uploaded" });
            }

            List<byte[]> imagesData = [];

            foreach (var image in images)
            {
                var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(image);
                if (!isValid)
                    return Results.BadRequest(new { message = $"Image {image.FileName} is invalid: {errorMessage}" });

                var imageData = await ImageValidator.CompressImageAsync(image);
                imagesData.Add(imageData);
            }

            await itemRepository.AddImagesToItemAsync(parsedItemId, imagesData);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while adding the image to the item");
        }
    }

    private static async Task<IResult> AddItemAttributeAsync(string itemId, [FromBody] List<AttributeRequestDto> attributeRequests, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        if (!int.TryParse(itemId, out var parsedItemId))
        {
            return Results.BadRequest(new { message = "Invalid item ID" });
        }
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            if (attributeRequests == null || attributeRequests.Count == 0)
            {
                return Results.BadRequest(new { message = "At least one attribute is required" });
            }

            foreach (var request in attributeRequests)
            {
                if (string.IsNullOrWhiteSpace(request.Type))
                {
                    return Results.BadRequest(new { message = "Attribute type is required" });
                }

                if (string.IsNullOrWhiteSpace(request.Name))
                {
                    return Results.BadRequest(new { message = "Attribute name is required" });
                }
            }

            var attributesInfo = attributeRequests.Select(a => (a.Type, a.Name, a.Value)).ToList();

            await itemRepository.AddAttributesToItemAsync(parsedItemId, attributesInfo);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while adding the attribute to the item");
        }
    }

    private static async Task<IResult> GetItemAsync(string itemId, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID. It must be a number." });
            }
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            var item = await itemRepository.GetItemAsync(parsedItemId);
            return item != null ? Results.Ok(item) : Results.NotFound(new { message = $"Item with ID {parsedItemId} not found" });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while retrieving the item");
        }
    }

    private static async Task<IResult> GetItemAttributesAsync(string itemId, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID. It must be a number." });
            }
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            var attributesWithValues = await itemRepository.GetItemAttributesAsync(parsedItemId);

            var response = attributesWithValues.Select(a => new AttributeResponseDto
            {
                AttributeId = a.Attribute.AttributeId,
                Type = a.Attribute.Type,
                Name = a.Attribute.Name,
                Value = a.Value
            });

            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving the attributes for the item");
        }
    }

    private static async Task<IResult> GetItemImagesAsync(string itemId, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID. It must be a number." });
            }
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            var images = await itemRepository.GetItemImagesAsync(parsedItemId);

            // Convert to Dto to control the response format
            var imageResponseDtos = images.Select(img => new ItemImageResponseDto
            {
                ImageId = img.ImageId,
                ItemId = img.ItemId,
                ImageData = img.ImageBin
            });

            return Results.Ok(imageResponseDtos);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving the images for the item");
        }
    }

    private static async Task<IResult> UpdateItemAsync(string itemId, ItemRequestDto request, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (request.OwnerId <= 0)
            {
                return Results.BadRequest(new { message = "Owner Id is required." });
            }
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID. It must be a number." });
            }
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, request.OwnerId, userRepository);
            if (authResult != null)
                return authResult;

            var authResult2 = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult2 != null)
                return authResult2;

            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return Results.BadRequest(new { message = "Name is required" });
            }

            if (request.Quantity < 0)
            {
                return Results.BadRequest(new { message = "Quantity must be >= 0" });
            }

            var updatedItem = new Item
            {
                Name = request.Name,
                Quantity = request.Quantity,
                Description = request.Description ?? string.Empty,
                OwnerId = request.OwnerId
            };

            await itemRepository.UpdateItemAsync(parsedItemId, updatedItem);
            return Results.NoContent();
        }
        catch (ArgumentNullException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while updating the item");
        }
    }

    private static async Task<IResult> DeleteItemAsync(string itemId, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID. It must be a number." });
            }
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            await itemRepository.DeleteItemAsync(parsedItemId);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while deleting the item");
        }
    }

    private static async Task<IResult> RemoveItemImagesAsync(int itemId, [FromBody] List<int> ImageIds, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, itemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            if (ImageIds == null || ImageIds.Count == 0)
            {
                return Results.BadRequest(new { message = "At least one image ID is required" });
            }

            await itemRepository.RemoveImagesFromItemAsync(itemId, ImageIds);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while removing the image from the item");
        }
    }

    private static async Task<IResult> RemoveItemAttributesAsync(string itemId, [FromBody] List<int> AttributeIds, IItemRepository itemRepository, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(itemId, out var parsedItemId))
            {
                return Results.BadRequest(new { message = "Invalid item ID" });
            }
            var authResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, parsedItemId, itemRepository, userRepository, requireOwnership: true);
            if (authResult != null)
                return authResult;

            if (AttributeIds == null || AttributeIds.Count == 0)
            {
                return Results.BadRequest(new { message = "At least one attribute ID is required" });
            }

            await itemRepository.RemoveAttributesFromItemAsync(parsedItemId, AttributeIds);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while removing the attribute from the item");
        }
    }
}
