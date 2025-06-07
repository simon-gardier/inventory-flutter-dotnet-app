using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using MyVentoryApi.DTOs;
using MyVentoryApi.Utilities;

namespace MyVentoryApi.Endpoints;

public static class LocationEndpoints
{
    private const string locationNotFoundMessage = "Location not found";
    public static void MapLocationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/locations");
        string groupTag = "Locations";

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/
        group.MapPost("/", CreateLocationAsync)
            .WithName("CreateLocation")
            .WithTags(groupTag)
            .Produces<Location>(StatusCodes.Status201Created)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Creates a new location")
            .RequireAuthorization();

        group.MapPost("/{locationId}/image", AddImageToLocationAsync)
            .WithName("AddLocationImages")
            .WithTags(groupTag)
            .Accepts<IFormFile>("multipart/form-data")
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .DisableAntiforgery() //TODO enable antiforgery
            .WithSummary("Add an image to a location")
            .RequireAuthorization();

        group.MapPost("/{locationId}/items/{itemId}", MoveItemToLocationAsync)
            .WithName("MoveItemToLocation")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Move an item to a location. Returns a 204 status code if successful.")
            .WithSummary("Move an item to a location")
            .RequireAuthorization();

        /********************************************************/
        /*                      GET Endpoints                   */
        /********************************************************/
        group.MapGet("/{locationId}/images", GetImagesByIdAsync)
            .WithName("GetLocationImages")
            .WithTags(groupTag)
            .Produces<IEnumerable<ImageDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Get all images of a location")
            .RequireAuthorization();

        group.MapGet("/{locationId}/items", GetItemsByLocationIdAsync)
            .WithName("GetItemsByLocation")
            .WithTags(groupTag)
            .Produces<IEnumerable<ItemInfoDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Get all items from a location")
            .RequireAuthorization();

        group.MapGet("/{parentId}/sublocations", GetSublocationsByParentIdAsync)
            .WithName("GetSublocationsByParent")
            .WithTags(groupTag)
            .Produces<IEnumerable<LocationResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Get all sublocations of a parent location")
            .RequireAuthorization();

        group.MapGet("/{locationId}", GetLocationByIdAsync)
            .WithName("GetLocationById")
            .WithTags(groupTag)
            .Produces<LocationResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Get a location by ID")
            .RequireAuthorization();

        /********************************************************/
        /*                      PUT Endpoints                   */
        /********************************************************/
        group.MapPut("/{locationId}", UpdateLocationAsync)
            .WithName("UpdateLocation")
            .WithTags(groupTag)
            .Accepts<LocationRequestDto>("application/json")
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Update an existing location")
            .RequireAuthorization();

        group.MapPut("/{locationId}/parent/{parentLocationId}", SetParentLocationAsync)
            .WithName("SetParentLocation")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Set the parent location of a location. Use 0 as parentLocationId to get the location out of its current parent.")
            .RequireAuthorization();

        /********************************************************/
        /*                    DELETE Endpoints                  */
        /********************************************************/
        group.MapDelete("/{locationId}", DeleteLocationAsync)
            .WithName("DeleteLocation")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Deletes an existing location.")
            .RequireAuthorization();

        group.MapDelete("/{locationId}/image/{imageId}", RemoveImageFromLocationAsync)
            .WithName("RemoveImageFromLocation")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Remove an image from a location")
            .RequireAuthorization();

        group.MapDelete("/{locationId}/items/{itemId}", RemoveItemFromLocationAsync)
            .WithName("RemoveItemFromLocation")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithSummary("Remove an item from a location")
            .RequireAuthorization();
    }

    /********************************************************/
    /*                Endpoints implementation              */
    /********************************************************/
    private static async Task<IResult> CreateLocationAsync(LocationRequestDto request, ILocationRepository repo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            // Ensure the user is authenticated
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, request.OwnerId, userRepo);
            if (authResult != null)
                return authResult;

            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return Results.BadRequest(new { message = "Name is required" });
            }

            if (request.Capacity <= 0)
            {
                return Results.BadRequest(new { message = "Capacity must be greater than zero" });
            }

            var owner = await userRepo.GetUserByIdAsync(request.OwnerId);
            if (owner == null)
            {
                return Results.BadRequest(new { message = "Owner not found" });
            }

            Location? parentLocation = null;
            if (request.ParentLocationId.HasValue)
            {
                parentLocation = await repo.GetLocationByIdAsync(request.ParentLocationId.Value);
                if (parentLocation == null)
                {
                    return Results.BadRequest(new { message = "Parent location not found" });
                }
            }

            var location = new Location(
                name: request.Name,
                capacity: request.Capacity,
                owner: owner,
                description: request.Description ?? string.Empty,
                parentLocation: parentLocation
            );

            var newLocation = await repo.CreateLocationAsync(location);
            var usedCapacity = await repo.GetUsedCapacityByLocationIdAsync(location.LocationId);
            var newLocationDto = new LocationResponseDto
            {
                LocationId = location.LocationId,
                Name = location.Name,
                Capacity = location.Capacity,
                UsedCapacity = usedCapacity,
                Description = location.Description,
                OwnerId = location.Owner.Id,
                ParentLocationId = location.ParentLocation?.LocationId
            };

            return Results.Created($"/api/locations/{newLocation.LocationId}", newLocationDto);
        }
        catch (ArgumentNullException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while creating the location");
        }
    }

    private static async Task<IResult> DeleteLocationAsync(int locationId, ILocationRepository repo, HttpContext httpContext, IUserRepository userRepo)
    {
        try
        {
            // Check if the user is authorized to delete the location
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, repo, userRepo);
            if (authResult != null)
                return authResult;

            var location = await repo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = "Location to be deleted not found" });
            }

            await repo.DeleteLocationAsync(locationId);

            return Results.NoContent();
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while deleting the location");
        }
    }

    private static async Task<IResult> UpdateLocationAsync(int locationId, LocationUpdateDto request, ILocationRepository repo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            if (!request.OwnerId.HasValue)
            {
                return Results.BadRequest(new { message = "OwnerId is required" });
            }
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, request.OwnerId.Value, userRepo);
            if (authResult != null)
                return authResult;

            var authResult2 = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, repo, userRepo);
            if (authResult2 != null)
                return authResult2;

            var location = await repo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            var validationResult = await UpdateLocationDataAsync(request, location, repo, userRepo);
            if (validationResult != null)
                return validationResult;

            await repo.UpdateLocationAsync(locationId, location);

            return Results.Ok();
        }
        catch (ArgumentNullException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while updating the location");
        }
    }

    private static async Task<IResult?> UpdateLocationDataAsync(LocationUpdateDto request, Location location, ILocationRepository repo, IUserRepository userRepo)
    {
        if (!string.IsNullOrWhiteSpace(request.Name))
        {
            location.Name = request.Name;
        }

        if (request.Capacity.HasValue)
        {
            if (request.Capacity > 0)
            {
                location.Capacity = request.Capacity.Value;
            }
            else
            {
                return Results.BadRequest(new { message = "Capacity must be greater than zero" });
            }
        }

        if (!string.IsNullOrWhiteSpace(request.Description))
        {
            location.Description = request.Description;
        }

        if (request.OwnerId.HasValue)
        {
            var owner = await userRepo.GetUserByIdAsync(request.OwnerId.Value);
            if (owner == null)
            {
                return Results.BadRequest(new { message = "Owner not found" });
            }
            location.Owner = owner;
        }

        if (request.ParentLocationId.HasValue)
        {
            var parentLocation = await repo.GetLocationByIdAsync(request.ParentLocationId.Value);
            if (parentLocation == null)
            {
                return Results.BadRequest(new { message = "Parent location not found" });
            }
            location.ParentLocation = parentLocation;
        }

        return null;
    }
    private static async Task<IResult> AddImageToLocationAsync(int locationId, IFormFileCollection images, ILocationRepository repo, IUserRepository userRepository, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, repo, userRepository);
            if (authResult != null)
                return authResult;

            var location = await repo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            var addedImages = new List<string>();

            foreach (var image in images)
            {
                var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(image);
                if (!isValid)
                {
                    return Results.BadRequest(new { message = errorMessage });
                }
                var imageData = await ImageValidator.CompressImageAsync(image);
                var newImage = new LocationImage(location, imageData);
                await repo.AddImageToLocationAsync(newImage);
                addedImages.Add(image.FileName);
            }

            return Results.Ok(new { message = "Images added successfully", addedImages });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while adding the image");
        }
    }
    private static async Task<IResult> RemoveImageFromLocationAsync(int locationId, int imageId, ILocationRepository repo, HttpContext httpContext, IUserRepository userRepo)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, repo, userRepo);
            if (authResult != null)
                return authResult;

            var location = await repo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            await repo.RemoveImageFromLocationAsync(locationId, imageId);

            return Results.Ok(new { message = "Image removed successfully" });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while removing the image");
        }
    }

    private static async Task<IResult> GetImagesByIdAsync(int locationId, ILocationRepository repo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, repo, userRepo);
            if (authResult != null)
                return authResult;

            var location = await repo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            var locationImages = await repo.GetImagesByLocationIdAsync(locationId);
            var imagesWithIds = locationImages.Select(li => new ImageDto
            {
                ImageBin = li.ImageBin,
                ImageId = li.ImageId
            });
            return Results.Ok(imagesWithIds);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving the images");
        }
    }
    private static async Task<IResult> RemoveItemFromLocationAsync(int locationId, int itemId, ILocationRepository locationRepo, IItemRepository itemRepo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, locationRepo, userRepo);
            if (authResult != null)
                return authResult;

            var authResult2 = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, itemId, itemRepo, userRepo);
            if (authResult2 != null)
                return authResult2;

            var location = await locationRepo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            var item = await itemRepo.GetItemByIdAsync(itemId);
            if (item == null)
            {
                return Results.NotFound(new { message = "Item not found" });
            }

            await locationRepo.RemoveItemFromLocationAsync(locationId, item);
            return Results.Ok(new { message = "Item successfully removed from the location" });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while removing the item from the location");
        }
    }
    private static async Task<IResult> GetItemsByLocationIdAsync(int locationId, ILocationRepository locationRepo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, locationRepo, userRepo);
            if (authResult != null)
                return authResult;

            var location = await locationRepo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            var items = await locationRepo.GetItemsByLocationIdAsync(locationId);

            var itemDtos = items.Select(item => new ItemInfoDto
            {
                ItemId = item.ItemId,
                Name = item.Name,
                Quantity = item.Quantity,
                Description = item.Description,
                OwnerId = item.OwnerId,
                OwnerName = item.Owner.UserName,
                LendingState = item.GetLendingStates(item.OwnerId), //TODO update with the id of the user doing the request
                Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                CreatedAt = item.CreatedAt,
                UpdatedAt = item.UpdatedAt
            });

            return Results.Ok(itemDtos);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving the items");
        }
    }
    private static async Task<IResult> GetSublocationsByParentIdAsync(int parentId, ILocationRepository repo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, parentId, repo, userRepo);
            if (authResult != null)
                return authResult;

            var parentLocation = await repo.GetLocationByIdAsync(parentId);
            if (parentLocation == null)
            {
                return Results.NotFound(new { message = "Parent location not found" });
            }

            var sublocations = await repo.GetSublocationsByParentIdAsync(parentId);

            var sublocationDtos = sublocations.Select(sublocation => new LocationResponseDto
            {
                LocationId = sublocation.LocationId,
                Name = sublocation.Name,
                Capacity = sublocation.Capacity,
                Description = sublocation.Description,
                OwnerId = sublocation.Owner.Id,
                ParentLocationId = sublocation.ParentLocation?.LocationId,
                FirstImage = sublocation.Images.FirstOrDefault()?.ImageBin
            });

            if (!sublocationDtos.Any())
            {
                return Results.NotFound(new { message = "No sublocation found." });
            }

            return Results.Ok(sublocationDtos);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving the sublocations");
        }
    }
    private static async Task<IResult> GetLocationByIdAsync(string locationId, ILocationRepository repo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            if (!int.TryParse(locationId, out var parsedLocationId))
            {
                return Results.BadRequest(new { message = "Invalid Location ID." });
            }
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, parsedLocationId, repo, userRepo);
            if (authResult != null)
                return authResult;

            var location = await repo.GetLocationByIdAsync(parsedLocationId);
            if (location == null)
            {
                return Results.NotFound(new { message = locationNotFoundMessage });
            }

            var usedCapacity = await repo.GetUsedCapacityByLocationIdAsync(parsedLocationId);
            var locationDto = new LocationResponseDto
            {
                LocationId = location.LocationId,
                Name = location.Name,
                Capacity = location.Capacity,
                UsedCapacity = usedCapacity,
                Description = location.Description,
                OwnerId = location.OwnerId,
                ParentLocationId = location.ParentLocation?.LocationId,
                FirstImage = location.Images.FirstOrDefault()?.ImageBin
            };

            return Results.Ok(locationDto);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving the location");
        }
    }

    private static async Task<IResult> SetParentLocationAsync(int locationId, int parentLocationId, ILocationRepository repo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, repo, userRepo);
            if (authResult != null)
                return authResult;

            if (parentLocationId != 0)
            {
                var authResult2 = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, parentLocationId, repo, userRepo);
                if (authResult2 != null)
                    return authResult2;
            }

            await repo.SetParentLocationAsync(locationId, parentLocationId);

            return Results.Ok(new { message = "Parent location set successfully" });
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
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while setting the parent location");
        }
    }

    private static async Task<IResult> MoveItemToLocationAsync(int locationId, int itemId, IItemRepository itemRepo, ILocationRepository locationRepo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLocationAuthorizationAsync(httpContext, locationId, locationRepo, userRepo);
            if (authResult != null)
                return authResult;

            var authResult2 = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, itemId, itemRepo, userRepo);
            if (authResult2 != null)
                return authResult2;

            var item = await itemRepo.GetItemByIdAsync(itemId);
            if (item == null)
            {
                return Results.NotFound(new { message = $"Item with ID {itemId} not found." });
            }

            var location = await locationRepo.GetLocationByIdAsync(locationId);
            if (location == null)
            {
                return Results.NotFound(new { message = $"Location with ID {locationId} not found." });
            }

            await locationRepo.MoveItemToLocationAsync(locationId, item);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while adding the item to the location");
        }
    }
}
