using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using MyVentoryApi.Utilities;
using MyVentoryApi.DTOs;
using Google.Api;
using System.Security.Claims;

namespace MyVentoryApi.Endpoints;

public static class UserEndpoints
{
    private static readonly string[] userRequiredFields = ["UserName", "FirstName", "LastName", "Email", "Password"];

    public static void MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/users");
        string groupTag = "Users";
        string adminTag = "Admin";

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/
        group.MapPost("/", CreateUserAsync)
            .WithName("CreateUser")
            .WithTags(groupTag)
            .Produces<UsersCreationResponseDto>(StatusCodes.Status201Created)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Creates a new user. Returns the created user with a JWT token and a 201 status code if successful.")
            .WithSummary("Create a new user")
            .Accepts<UserCreationRequestDto>("multipart/form-data")
            .AllowAnonymous(); // The user is not authenticated before creating an account

        group.MapPost("/login", LoginUserAsync)
            .WithName("LoginUser")
            .WithTags(groupTag)
            .Produces<UsersLoginResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Logs in a user. Returns the user with an updated JWT token and a 200 status code if successful.")
            .WithSummary("Login a user")
            .AllowAnonymous(); // The user is not authenticated before logging in

        group.MapPost("/login-without-password", LoginUserWithoutPasswordAsync)
            .WithName("LoginUserWithoutPassword")
            .WithTags(groupTag)
            .Produces<UsersLoginWithoutPasswordResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Logs in a user without password for account connected with SSO. Returns the user and a 200 status code if successful.")
            .WithSummary("Login a user connected with SSO")
            .RequireAuthorization(); // The user must be authenticated via SSO before logging in

        group.MapPost("/forgot-password", ForgotPasswordAsync)
            .WithName("ForgotPassword")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status404NotFound)
            .WithDescription("Sends a password reset link to the user's email.")
            .WithSummary("Request password reset")
            .AllowAnonymous();

        group.MapPost("/reset-password", ResetPasswordAsync)
            .WithName("ResetPassword")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status404NotFound)
            .WithDescription("Resets the user's password using the token sent to their email.")
            .WithSummary("Reset user password")
            .AllowAnonymous();

        group.MapPost("/resend-verification-email", ResendVerificationEmailAsync)
            .WithName("ResendVerificationEmail")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Resends the email verification link to the user's email address.")
            .WithSummary("Resend verification email")
            .AllowAnonymous(); // The user is not authenticated before resending the verification email

        group.MapPost("/admin/unlock-account", UnlockAccountAsync)
            .WithName("UnlockAccount")
            .WithTags(adminTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Allows an admin to unlock a locked user account.")
            .WithSummary("Unlock a locked user account")
            .RequireAuthorization(); // Only admins can access this endpoint

        group.MapPost("/admin/verify-email", VerifyEmailWithoutCheckAsync)
            .WithName("VerifyEmailWithoutCheck")
            .WithTags(adminTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Allows an admin to verify a user's email without requiring the email verification process.")
            .WithSummary("Verify a user's email without email verification")
            .RequireAuthorization(); // Only admins can access this endpoint

        app.MapPost("/api/auth/refresh-token", RefreshTokenAsync)
            .WithName("RefreshToken")
            .WithTags(groupTag)
            .Produces<RefreshTokenResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Refreshes the JWT token and the refresh token using the current refresh token.")
            .WithSummary("Refresh JWT token")
            .AllowAnonymous();

        group.MapPost("/verify-password", VerifyPasswordAsync)
            .WithName("VerifyPassword")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Verifies a user's password. Returns 200 if the password is correct, 401 if incorrect.")
            .WithSummary("Verify user password")
            .RequireAuthorization();

        /********************************************************/
        /*                      GET Endpoints                   */
        /********************************************************/

        group.MapGet("/verify-email", VerifyEmailAsync)
        .WithName("VerifyEmail")
        .WithTags(groupTag)
        .Produces(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status404NotFound)
        .WithDescription("Verifies a user's email address using the token sent to their email.")
        .WithSummary("Verify user email address")
        .AllowAnonymous(); // The user is not authenticated before verifying their email

        group.MapGet("/{userId:int}/items", GetUserItemsAsync)
            .WithName("GetUserItems")
            .WithTags(groupTag)
            .Produces<IEnumerable<UserItemsResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all items of a user. Returns the items with a 200 status code if successful.")
            .WithSummary("Get all items of a user")
            .RequireAuthorization(); // The user must be authenticated to access the items

        group.MapGet("/{userId:int}/locations", GetUserLocationsAsync)
            .WithName("GetUserLocations")
            .WithTags(groupTag)
            .Produces<IEnumerable<LocationResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all locations of a user. Returns the locations with a 200 status code if successful.")
            .WithSummary("Get all locations of a user")
            .RequireAuthorization();

        group.MapGet("/{userId:int}/attributes", GetUserAttributesAsync)
            .WithName("GetUserAttributes")
            .WithTags(groupTag)
            .Produces<IEnumerable<AttributeResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all attributes of a user. Returns the attributes with a 200 status code if successful.")
            .WithSummary("Get all attributes of a user")
            .RequireAuthorization();

        group.MapGet("/{userId:int}/lendings", GetUserLendingsAsync)
            .WithName("GetUserLendings")
            .WithTags(groupTag)
            .Produces<UserLendingsResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all lendings of a user, both items lent by the user and items borrowed by the user.")
            .WithSummary("Get all lendings of a user")
            .RequireAuthorization();

        group.MapGet("/search", SearchUsersAsync)
            .WithName("SearchUsers")
            .WithTags(groupTag)
            .Produces<IEnumerable<UserSearchResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Returns all users in the system.")
            .WithSummary("Get all users")
            .RequireAuthorization();

        group.MapGet("/{userId:int}/items/searchByName", GetItemsByNameByUserAsync)
            .WithName("GetItemsByNameByUser")
            .WithTags(groupTag)
            .Produces<IEnumerable<Item>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all items of a user for which the item name contain the provided. Returns the items with a 200 status code if successful.")
            .WithSummary("Get items by user ID and name substring")
            .RequireAuthorization();

        group.MapPost("/{userId:int}/items/filter", GetItemsFilteredByUserAsync)
            .WithName("GetItemsFilteredByUser")
            .WithTags(groupTag)
            .Produces<IEnumerable<ItemInfoDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Searches for items in the user inventory based on one or multiple filters. Returns the matching items")
            .WithSummary("Search user inventory with filters")
            .RequireAuthorization();

        /********************************************************/
        /*                      PUT Endpoints                   */
        /********************************************************/

        group.MapPut("/{userId:int}", UpdateUserAsync)
            .Accepts<UserUpdateRequestDto>("multipart/form-data")
            .WithName("UpdateUser")
            .WithTags(groupTag)
            .Produces<UsersLoginResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Updates an existing user. Returns a 204 status code if successful.")
            .WithSummary("Update an existing user")
            .RequireAuthorization();

        /********************************************************/
        /*                    DELETE Endpoints                  */
        /********************************************************/

        group.MapDelete("/{userId:int}", DeleteUserAsync)
            .WithName("DeleteUser")
            .WithTags(groupTag)
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Deletes an existing user. Returns a 204 status code if successful.")
            .WithSummary("Delete an existing user")
            .RequireAuthorization();
    }

    /********************************************************/
    /*                Endpoints implementation              */
    /********************************************************/
    private static async Task<IResult> CreateUserAsync(HttpContext context, IUserRepository repo, bool verifyMailRequested = false)
    {
        try
        {
            var form = await context.Request.ReadFormAsync();

            // verify that all required fields are present
            var missingFields = userRequiredFields.Where(field => string.IsNullOrWhiteSpace(form[field])).ToList();
            if (missingFields.Any())
                return Results.BadRequest(new { message = $"The following fields are required: {string.Join(", ", missingFields)}" });

            // create the Dto for the user creation
            var registerRequest = new UserCreationRequestDto
            {
                UserName = form["UserName"]!,
                FirstName = form["FirstName"]!,
                LastName = form["LastName"]!,
                Email = form["Email"]!,
                Password = form["Password"]!,
                Image = form.Files.Count > 0 ? form.Files[0] : null
            };

            // create the user and get the token
            var user = await repo.CreateUserAsync(registerRequest, verifyMailRequested);

            // create the response Dto
            var response = new UsersCreationResponseDto
            {
                UserId = user.Id,
                UserName = user.UserName ?? string.Empty,
                Email = user.Email ?? string.Empty,
                FirstName = user.FirstName,
                LastName = user.LastName,
                CreatedAt = user.CreatedAt,
            };

            return Results.Created($"/api/users/{user.Id}", response);
        }
        catch (ArgumentNullException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "Une erreur est survenue lors de la création de l'utilisateur");
        }
    }

    private static async Task<IResult> LoginUserAsync(UsersLoginRequestDto request, IUserRepository repo)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.UsernameOrEmail) || string.IsNullOrWhiteSpace(request.Password))
                return Results.BadRequest(new { message = "Username or email and password are required" });

            var (user, token, refreshToken) = await repo.LoginUserAsync(request);

            var response = new UsersLoginResponseDto
            {
                UserId = user.Id,
                Username = user.UserName ?? string.Empty,
                FirstName = user.FirstName,
                LastName = user.LastName,
                Email = user.Email ?? string.Empty,
                ProfilePicture = user.ProfilePicture,
                Token = token,
                RefreshToken = refreshToken,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };

            return Results.Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 401, title: "Unauthorized");
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while logging in the user");
        }
    }

    private static async Task<IResult> LoginUserWithoutPasswordAsync(UserLoginWithoutPasswordRequestDto request, IUserRepository repo, HttpContext httpContext)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return Results.BadRequest(new { message = "email is required to get user information logged with SSO" });

            var userId = await repo.GetUserIdByEmailAsync(request.Email)
                ?? throw new KeyNotFoundException($"User with email {request.Email} not found.");

            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, repo);
            if (authResult != null)
                return authResult;

            var user = await repo.GetUserByIdAsync(userId)
                ?? throw new KeyNotFoundException($"User with ID {userId} not found.");

            var response = new UsersLoginWithoutPasswordResponseDto
            {
                UserId = user.Id,
                Username = user.UserName ?? string.Empty,
                FirstName = user.FirstName,
                LastName = user.LastName,
                Email = user.Email ?? string.Empty,
                ProfilePicture = user.ProfilePicture,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };

            return Results.Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 401, title: "Unauthorized");
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while logging in the user");
        }
    }

    private static async Task<IResult> ForgotPasswordAsync(ForgotPasswordRequestDto request, IUserRepository repo)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return Results.BadRequest(new { message = "Email is required" });

            await repo.SendPasswordResetEmailAsync(request.Email);

            // Always return OK to prevent email enumeration attacks
            return Results.Ok(new { message = "If the email exists, a password reset link has been sent" });
        }
        catch (Exception)
        {
            // Log the error but don't expose it to the client
            return Results.Ok(new { message = "If the email exists, a password reset link has been sent" });
        }
    }

    private static async Task<IResult> ResetPasswordAsync(ResetPasswordRequestDto request, IUserRepository repo)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Token) ||
                string.IsNullOrWhiteSpace(request.NewPassword))
                return Results.BadRequest(new { message = "Email, token and new password are required" });

            var result = await repo.ResetPasswordAsync(request.Email, request.Token, request.NewPassword);

            if (result)
                return Results.Ok(new { message = "Password reset successfully" });
            else
                return Results.BadRequest(new { message = "Password reset failed. This could be due to an invalid/expired token or password requirements not being met." });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while resetting password");
        }
    }

    private static async Task<IResult> ResendVerificationEmailAsync(ResendEmailVerificationRequestDto request, IUserRepository repo)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return Results.BadRequest(new { message = "Email is required" });

            await repo.ResendVerificationEmailAsync(request.Email);

            // Always return OK to prevent email enumeration attacks
            return Results.Ok(new { message = "If the email exists and is not already verified, a verification email has been sent" });
        }
        catch (Exception ex)
        {
            // Log the error but don't expose it to the client
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while sending verification email");
        }
    }

    private static async Task<IResult> UnlockAccountAsync(UnlockAccountRequestDto request, IUserRepository repo, HttpContext httpContext)
    {
        try
        {
            // Check if user is admin
            var adminAuthResult = await JwtAuthorizationHelper.CheckAdminAuthorizationAsync(httpContext, repo);
            if (adminAuthResult != null)
                return adminAuthResult;

            if (string.IsNullOrWhiteSpace(request.Email))
                return Results.BadRequest(new { message = "Email is required" });

            await repo.ClearLockoutAsync(request);
            return Results.Ok(new { message = "Account unlocked successfully" });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while unlocking the account");
        }
    }

    private static async Task<IResult> VerifyEmailWithoutCheckAsync(VerifyEmailWithoutCheckRequestDto request, IUserRepository repo, HttpContext httpContext)
    {
        try
        {
            // Check if the user is an admin
            var adminAuthResult = await JwtAuthorizationHelper.CheckAdminAuthorizationAsync(httpContext, repo);
            if (adminAuthResult != null)
                return adminAuthResult;

            if (string.IsNullOrWhiteSpace(request.Email))
                return Results.BadRequest(new { message = "Invalid email address" });

            // Find the user by email
            var userId = await repo.GetUserIdByEmailAsync(request.Email);
            if (userId == null)
            {
                return Results.NotFound(new { message = "User not found" });
            }

            // Verify the email without token check
            var result = await repo.VerifyEmailWithoutCheckAsync(userId.Value);

            if (result)
                return Results.Ok(new { message = "Email verified successfully" });
            else
                return Results.BadRequest(new { message = "Failed to verify email" });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while verifying the email");
        }
    }

    private static async Task<IResult> RefreshTokenAsync(RefreshTokenRequestDto request, IUserRepository repo, HttpContext httpContext)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
                return Results.BadRequest(new { message = "Refresh token is required" });

            var (user, newToken, newRefreshToken) = await repo.RefreshTokenAsync(request.RefreshToken);

            var response = new RefreshTokenResponseDto
            {
                UserId = user.Id,
                JwtToken = newToken,
                RefreshToken = newRefreshToken
            };

            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 401, title: "Unauthorized");
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while refreshing the token");
        }
    }

    private static async Task<IResult> VerifyEmailAsync(string token, string email, IUserRepository repo)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(email))
                return Results.BadRequest(new { message = "Token and email are required" });

            var result = await repo.VerifyEmailAsync(email, token);

            if (result)
            {
                var redirectUrl = Environment.GetEnvironmentVariable("WEBSITE_BASE_URL")
                ?? throw new InvalidOperationException("⚠️  WEBSITE_BASE_URL not found in environment variables");
                return Results.Redirect(redirectUrl);
            }
            else
                return Results.BadRequest(new { message = "Invalid or expired token" });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while verifying email");
        }
    }

    private static async Task<IResult> GetUserItemsAsync(int userId, IUserRepository repo, HttpContext httpContext)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, repo);
            if (authResult != null)
                return authResult;

            var (user, items) = await repo.GetUserWithItemsAsync(userId);

            var itemsInfo = new Dictionary<int, ItemInfoDto>();

            foreach (var item in items)
            {
                var itemInfo = new ItemInfoDto
                {
                    ItemId = item.ItemId,
                    Name = item.Name,
                    Quantity = item.Quantity,
                    Description = item.Description,
                    OwnerId = item.OwnerId,
                    OwnerName = item.Owner.UserName,
                    LendingState = item.GetLendingStates(item.OwnerId),
                    Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                    CreatedAt = item.CreatedAt,
                    UpdatedAt = item.UpdatedAt
                };
                itemsInfo[item.ItemId] = itemInfo;
            }

            var userItemsResponse = new UserItemsResponseDto
            {
                UserId = user.Id,
                Username = user.UserName ?? string.Empty,
                Items = [.. itemsInfo.Values]
            };

            return Results.Ok(userItemsResponse);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving items for the user");
        }
    }

    private static async Task<IResult> GetUserLocationsAsync(int userId, IUserRepository repo, ILocationRepository locationRepo, HttpContext httpContext)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, repo);
            if (authResult != null)
                return authResult;

            var locations = await repo.GetLocationsByUserIdAsync(userId);

            List<LocationResponseDto> locationsResponse = [];

            foreach (var location in locations)
            {
                var usedCapacity = await locationRepo.GetUsedCapacityByLocationIdAsync(location.LocationId);
                locationsResponse.Add(new LocationResponseDto
                {
                    LocationId = location.LocationId,
                    Name = location.Name,
                    Description = location.Description,
                    Capacity = location.Capacity,
                    UsedCapacity = usedCapacity,
                    OwnerId = location.OwnerId,
                    ParentLocationId = location.ParentLocationId,
                    FirstImage = location.Images.FirstOrDefault()?.ImageBin
                });
            }


            return Results.Ok(locationsResponse);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving locations for the user");
        }
    }

    private static async Task<IResult> GetUserAttributesAsync(int userId, IUserRepository repo, HttpContext httpContext)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, repo);
            if (authResult != null)
                return authResult;
            var attributes = await repo.GetAttributesByUserIdAsync(userId);

            List<AttributeResponseDto> attributesResponse = [];

            foreach (var (value, attribute) in attributes)
            {
                attributesResponse.Add(new AttributeResponseDto
                {
                    AttributeId = attribute.AttributeId,
                    Name = attribute.Name,
                    Type = attribute.Type,
                    Value = value
                });
            }

            return Results.Ok(attributesResponse);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving attributes for the user");
        }
    }

    private static async Task<IResult> GetUserLendingsAsync(int userId, ILendingRepository lendingRepo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, userRepo);
            if (authResult != null)
                return authResult;

            var user = await userRepo.GetUserByIdAsync(userId);
            if (user == null)
            {
                return Results.NotFound(new { message = $"User with ID {userId} not found." });
            }

            var (lentItems, borrowedItems) = await lendingRepo.GetLendingsByUserIdAsync(userId);

            var response = new UserLendingsResponseDto
            {
                UserId = userId,
                Username = user.UserName ?? string.Empty,
                LentItems = lentItems.Select(l => new LendingResponseDto
                {
                    TransactionId = l.TransactionId,
                    BorrowerId = l.BorrowerId,
                    BorrowerName = l.BorrowerName ?? l.Borrower?.UserName ?? string.Empty,
                    BorrowerEmail = l.Borrower?.Email,
                    LenderId = l.LenderId,
                    LenderName = user.UserName ?? string.Empty,
                    LenderEmail = user.Email,
                    DueDate = l.DueDate,
                    LendingDate = l.LendingDate,
                    ReturnDate = l.ReturnDate,
                    Items = l.LendItems.Select(i => new LendingItemResponseDto
                    {
                        ItemId = i.ItemId,
                        ItemName = i.Item.Name,
                        Quantity = i.Quantity
                    }).ToList()
                }).ToList(),
                BorrowedItems = borrowedItems.Select(l => new LendingResponseDto
                {
                    TransactionId = l.TransactionId,
                    BorrowerId = userId,
                    BorrowerName = user.UserName ?? string.Empty,
                    BorrowerEmail = user.Email,
                    LenderId = l.LenderId,
                    LenderName = l.Lender.UserName ?? string.Empty,
                    LenderEmail = l.Lender.Email,
                    DueDate = l.DueDate,
                    LendingDate = l.LendingDate,
                    ReturnDate = l.ReturnDate,
                    Items = l.LendItems.Select(i => new LendingItemResponseDto
                    {
                        ItemId = i.ItemId,
                        ItemName = i.Item.Name,
                        Quantity = i.Quantity
                    }).ToList()
                }).ToList()
            };

            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving lendings for the user");
        }
    }

    private static async Task<IResult> SearchUsersAsync(IUserRepository repo)
    {
        try
        {
            var users = await repo.GetUsersByUsernameSubstringAsync(null);

            var response = users.Select(u => new UserSearchResponseDto
            {
                UserId = u.Id,
                Username = u.UserName ?? string.Empty,
                FirstName = u.FirstName,
                LastName = u.LastName,
                Email = u.Email,
                CreatedAt = u.CreatedAt,
                UpdatedAt = u.UpdatedAt
            });

            return Results.Ok(response);
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving users");
        }
    }

    private static async Task<IResult> GetItemsByNameByUserAsync(int userId, string name, IUserRepository repository, HttpContext httpContext)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, repository);
            if (authResult != null)
                return authResult;

            var items = await repository.GetItemsByNameByUserAsync(userId, name);
            if (items == null || !items.Any())
            {
                return Results.NotFound($"No items found for: {name}");
            }
            var itemDtos = items.Select(item => new ItemInfoDto
            {
                ItemId = item.ItemId,
                Name = item.Name,
                Quantity = item.Quantity,
                Description = item.Description,
                OwnerId = item.OwnerId,
                OwnerName = item.Owner.UserName,
                LendingState = LendingState.None,
                Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                CreatedAt = item.CreatedAt,
                UpdatedAt = item.UpdatedAt
            }).ToList();

            return Results.Ok(itemDtos);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(ex.Message);
        }
        catch (Exception ex)
        {
            return Results.Problem(ex.Message);
        }
    }

    private static async Task<IResult> GetItemsFilteredByUserAsync(int userId, InventorySearchFiltersDto filters, IUserRepository repository, HttpContext httpContext)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, repository);
            if (authResult != null)
                return authResult;

            var items = await repository.GetItemsFilteredByUserAsync(userId, filters);
            if (items == null || !items.Any())
            {
                return Results.NotFound($"No items found for the provided filters");
            }
            var itemDtos = items.Select(item => new ItemInfoDto
            {
                ItemId = item.ItemId,
                Name = item.Name,
                Quantity = item.Quantity,
                Description = item.Description,
                OwnerId = item.OwnerId,
                OwnerName = item.Owner.UserName,
                LendingState = LendingState.None,
                Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                CreatedAt = item.CreatedAt,
                UpdatedAt = item.UpdatedAt
            }).ToList();

            return Results.Ok(itemDtos);
        }
        catch (Exception ex)
        {
            return Results.Problem(ex.Message);
        }
    }

    private static async Task<IResult> UpdateUserAsync(int userId, HttpContext context, IUserRepository repo)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(context, userId, repo);
            if (authResult != null)
                return authResult;

            var form = await context.Request.ReadFormAsync();

            // Create the Dto for the update
            var updateRequest = new UserUpdateRequestRepositoryDto
            {
                UserName = form["UserName"],
                FirstName = form["FirstName"],
                LastName = form["LastName"],
                Email = form["Email"],
                Image = form.Files.Count > 0 ? form.Files[0] : null
            };

            if (updateRequest.Image != null)
            {
                var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(updateRequest.Image);
                if (!isValid)
                    return Results.BadRequest(new { message = errorMessage });
            }

            var (user, token) = await repo.UpdateUserAsync(userId, updateRequest);

            var refreshToken = await repo.GetRefreshTokenByUserIdAsync(user.Id) ?? string.Empty;

            var response = new UsersLoginResponseDto
            {
                UserId = user.Id,
                RefreshToken = refreshToken,
                Username = user.UserName ?? string.Empty,
                Email = user.Email ?? string.Empty,
                FirstName = user.FirstName,
                LastName = user.LastName,
                ProfilePicture = user.ProfilePicture,
                Token = token,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };

            return Results.Ok(response);
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
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while updating the user");
        }
    }

    private static async Task<IResult> DeleteUserAsync(int userId, IUserRepository repo, HttpContext context)
    {
        try
        {
            // Check if the user is authorized to access the items
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(context, userId, repo);
            if (authResult != null)
                return authResult;

            await repo.DeleteUserAsync(userId);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while deleting the user");
        }
    }

    private static bool TryGetCurrentUserId(HttpContext context, out int userId)
    {
        var userIdClaim = context.User.FindFirst(ClaimTypes.NameIdentifier);
        if (userIdClaim != null && int.TryParse(userIdClaim.Value, out userId))
        {
            return true;
        }
        userId = 0;
        return false;
    }

    private static async Task<IResult> VerifyPasswordAsync(VerifyPasswordRequestDto request, IUserRepository repo, HttpContext context)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.Password))
                return Results.BadRequest(new { message = "Password is required" });

            // Check if the current user has access to verify this user's password
            if (!TryGetCurrentUserId(context, out int currentUserId))
                return Results.Unauthorized();

            if (!await repo.UserHasAccessAsync(request.UserId, currentUserId))
                return Results.Forbid();

            var result = await repo.VerifyPasswordAsync(request.UserId, request.Password);

            if (result)
                return Results.Ok(new { message = "Password verified successfully" });
            else
                return Results.Unauthorized();
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while verifying password");
        }
    }
}
