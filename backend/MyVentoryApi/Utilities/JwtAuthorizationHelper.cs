using MyVentoryApi.Repositories;
using System.Security.Claims;

namespace MyVentoryApi.Utilities;

public static class JwtAuthorizationHelper
{
    public static async Task<IResult?> CheckUserAuthorizationAsync(
        HttpContext httpContext,
        int targetUserId,
        IUserRepository userRepo)
    {
        // Base authentication check
        var authResult = CheckAuthenticated(httpContext);
        if (authResult != null)
            return authResult;

        // Get user ID from JWT token
        if (!TryGetCurrentUserId(httpContext, out int currentUserId))
            return Results.Unauthorized();

        // Check if user has access
        if (!await userRepo.UserHasAccessAsync(targetUserId, currentUserId))
            return Results.Forbid();

        return null;
    }

    public static async Task<IResult?> CheckAdminAuthorizationAsync(
        HttpContext httpContext,
        IUserRepository userRepo)
    {
        // Base authentication check
        var authResult = CheckAuthenticated(httpContext);
        if (authResult != null)
            return authResult;

        // Get user ID from JWT token
        if (!TryGetCurrentUserId(httpContext, out int currentUserId))
            return Results.Unauthorized();

        try
        {
            // Check if user is admin
            if (!await userRepo.HasRoleAsync(currentUserId, "Admin"))
                return Results.Forbid();

            return null;
        }
        catch (KeyNotFoundException)
        {
            return Results.NotFound(new { message = $"User with ID {currentUserId} not found" });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while checking admin authorization");
        }
    }

    public static async Task<IResult?> CheckItemAuthorizationAsync(
        HttpContext httpContext,
        int itemId,
        IItemRepository itemRepo,
        IUserRepository userRepo,
        bool requireOwnership = true)
    {
        // Base authentication check
        var authResult = CheckAuthenticated(httpContext);
        if (authResult != null)
            return authResult;

        // Get user ID from JWT token
        if (!TryGetCurrentUserId(httpContext, out int currentUserId))
            return Results.Unauthorized();

        try
        {
            // Get item information
            var item = await itemRepo.GetItemByIdAsync(itemId);

            if (item == null)
                return Results.NotFound(new { message = $"Item with ID {itemId} not found" });

            if (requireOwnership)
            {
                // Check if user has access
                if (!await userRepo.UserHasAccessAsync(item.OwnerId, currentUserId))
                    return Results.Forbid();
            }

            return null;
        }
        catch (KeyNotFoundException)
        {
            return Results.NotFound(new { message = $"Item with ID {itemId} not found" });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while checking item authorization");
        }
    }

    public static async Task<IResult?> CheckLenderAuthorizationAsync(
        HttpContext httpContext,
        int lendingId,
        ILendingRepository lendingRepo,
        IUserRepository userRepo)
    {
        // Base authentication check
        var authResult = CheckAuthenticated(httpContext);
        if (authResult != null)
            return authResult;

        // Get user ID from JWT token
        if (!TryGetCurrentUserId(httpContext, out int currentUserId))
            return Results.Unauthorized();

        try
        {
            // Check if lending exists
            var lending = await lendingRepo.GetLendingByIdAsync(lendingId);
            if (lending == null)
                return Results.NotFound(new { message = $"Lending with ID {lendingId} not found" });

            // Check if user is the lender
            if (!await lendingRepo.UserIsLenderAsync(lendingId, currentUserId, userRepo))
                return Results.Forbid();

            return null;
        }
        catch (ArgumentOutOfRangeException)
        {
            return Results.BadRequest(new { message = "Invalid lending or user ID" });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while checking lender authorization");
        }
    }

    public static async Task<IResult?> CheckBorrowerAuthorizationAsync(
        HttpContext httpContext,
        int lendingId,
        ILendingRepository lendingRepo,
        IUserRepository userRepo)
    {
        // Base authentication check
        var authResult = CheckAuthenticated(httpContext);
        if (authResult != null)
            return authResult;

        // Get user ID from JWT token
        if (!TryGetCurrentUserId(httpContext, out int currentUserId))
            return Results.Unauthorized();

        try
        {
            // Check if lending exists
            var lending = await lendingRepo.GetLendingByIdAsync(lendingId);
            if (lending == null)
                return Results.NotFound(new { message = $"Lending with ID {lendingId} not found" });

            // Check if user is the borrower
            if (!await lendingRepo.UserIsBorrowerAsync(lendingId, currentUserId, userRepo))
                return Results.Forbid();

            return null;
        }
        catch (ArgumentOutOfRangeException)
        {
            return Results.BadRequest(new { message = "Invalid lending or user ID" });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while checking borrower authorization");
        }
    }

    public static async Task<IResult?> CheckLocationAuthorizationAsync(
        HttpContext httpContext,
        int locationId,
        ILocationRepository locationRepo,
        IUserRepository userRepo)
    {
        // Base authentication check
        var authResult = CheckAuthenticated(httpContext);
        if (authResult != null)
            return authResult;


        // Get user ID from JWT token
        if (!TryGetCurrentUserId(httpContext, out int currentUserId))
            return Results.Unauthorized();

        try
        {
            // Get location information
            var location = await locationRepo.GetLocationByIdAsync(locationId);
            if (location == null)
                return Results.NotFound(new { message = $"Location with ID {locationId} not found" });

            // Check if user have access to location
            if (!await locationRepo.UserHasAccessToLocationAsync(locationId, currentUserId, userRepo))
                return Results.Forbid();

            return null;

        }
        catch (KeyNotFoundException)
        {
            return Results.NotFound(new { message = $"Location with ID {locationId} not found" });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while checking location authorization");
        }
    }

    public static int? GetUserIdFromToken(HttpContext httpContext)
    {
        // Try to get the userId claim from the authenticated user
        var userIdClaim = httpContext.User.FindFirst("userId")?.Value
            ?? httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? httpContext.User.FindFirst("sub")?.Value;

        if (int.TryParse(userIdClaim, out int userId))
            return userId;

        return null;
    }

    public static IResult? CheckAuthenticated(HttpContext httpContext)
    {
        if (!httpContext.User.Identity?.IsAuthenticated ?? false)
            return Results.Unauthorized();

        return null;
    }

    private static bool TryGetCurrentUserId(HttpContext httpContext, out int userId)
    {
        userId = -1;
        var userIdClaim = httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (string.IsNullOrEmpty(userIdClaim))
            return false;

        return int.TryParse(userIdClaim, out userId);
    }
}