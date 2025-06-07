using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using MyVentoryApi.Auth;
using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using MyVentoryApi.Services;
using MyVentoryApi.Utilities;
using System.Security.Claims;

namespace MyVentoryApi.Endpoints;

public static class GoogleAuthEndpoints
{
    public static void MapGoogleAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth");

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/

        /* POST Endpoint here */

        /********************************************************/
        /*                      GET Endpoints                   */
        /********************************************************/

        group.MapGet("login/google", GoogleLoginAsync)
            .WithName("GoogleLogin")
            .WithTags("Authentication")
            .Produces(StatusCodes.Status302Found)
            .Produces(StatusCodes.Status400BadRequest)
            .WithDescription("Initiates Google OAuth login flow. Redirects to Google for authentication.")
            .WithSummary("Start Google authentication flow")
            .AllowAnonymous();

        group.MapGet("callback/google/{platform?}", GoogleCallbackAsync)
            .WithName("GoogleCallback")
            .WithTags("Authentication")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status302Found)
            .Produces(StatusCodes.Status400BadRequest)
            .WithDescription("Handles the callback from Google OAuth. Returns user information and token or redirects for mobile clients.")
            .WithSummary("Process Google authentication callback")
            .AllowAnonymous();

        group.MapGet("link/google", LinkGoogle)
            .WithName("LinkGoogle")
            .WithTags("Authentication")
            .Produces(StatusCodes.Status302Found)
            .Produces(StatusCodes.Status401Unauthorized)
            .WithDescription("Initiates flow to link a Google account to an existing authenticated user.")
            .WithSummary("Link Google account to user")
            .RequireAuthorization();

        group.MapGet("link/callback/google", LinkGoogleCallbackAsync)
            .WithName("LinkGoogleCallback")
            .WithTags("Authentication")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .WithDescription("Processes the callback for linking a Google account to an existing user.")
            .WithSummary("Process Google account linking callback")
            .RequireAuthorization();

        group.MapGet("google-logins", GetGoogleLoginsAsync)
            .WithName("GetGoogleLogins")
            .WithTags("Authentication")
            .Produces<IEnumerable<object>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .WithDescription("Returns all Google logins associated with the authenticated user.")
            .WithSummary("Get user's Google logins")
            .RequireAuthorization();

        /********************************************************/
        /*                      PUT Endpoints                   */
        /********************************************************/

        /* PUT endpoints here */

        /********************************************************/
        /*                    DELETE Endpoints                  */
        /********************************************************/

        group.MapDelete("google-login/{providerKey}", RemoveGoogleLoginAsync)
            .WithName("RemoveGoogleLogin")
            .WithTags("Authentication")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .WithDescription("Removes a Google login from the authenticated user's account.")
            .WithSummary("Unlink Google account")
            .RequireAuthorization();
    }

    /********************************************************/
    /*                Endpoints implementation              */
    /********************************************************/

    /*
    To test API endpoints, Swagger UI can't be used because of the redirect to Google login page.
    Instead, can use directly the browser or Postman to test the endpoints.
    For the login endpoint, use the URL: http://localhost/api/auth/login/google?provider=GoogleWeb
    */

    private static Task<IResult> GoogleLoginAsync(
    GoogleAuthService.GoogleProvider provider,
    string? returnUrl,
    [FromServices] GoogleAuthService authService,
    HttpContext httpContext)
    {
        try
        {
            if (authService == null)
            {
                return Task.FromResult(Results.Problem("Internal server error. Please contact support.", statusCode: 500));
            }

            // Validate the provider to ensure it is a valid Google provider
            if (!Enum.IsDefined(provider))
            {
                return Task.FromResult(Results.BadRequest(new { error = "Invalid Google provider specified." }));
            }

            // Construct the base callback path
            string callbackPath = httpContext.Request.PathBase + "/api/auth/callback/google";

            // Determine the platform (web or android) and append it to the callback path
            string platform = provider switch
            {
                GoogleAuthService.GoogleProvider.GoogleAndroid => "Android",
                GoogleAuthService.GoogleProvider.GoogleWeb => "Web",
                _ => throw new NotImplementedException("Unsupported Google provider.")
            };

            callbackPath += $"/{platform}";

            // Build the full callback URL (e.g., https://localhost/api/auth/callback/google/web)
            string callbackUrl = $"{httpContext.Request.Scheme}://{httpContext.Request.Host}{callbackPath}";

            // Add the returnUrl parameter to the callback URL if specified
            if (!string.IsNullOrEmpty(returnUrl))
            {
                try
                {
                    callbackUrl = QueryHelpers.AddQueryString(callbackUrl, "returnUrl", returnUrl);
                }
                catch (ArgumentException ex)
                {
                    // Handle invalid returnUrl parameter
                    return Task.FromResult(Results.BadRequest(new { error = "Invalid returnUrl parameter.", detail = ex.Message }));
                }
            }

            // Configure the authentication properties for Google
            var properties = authService.ConfigureGoogleProperties(provider, callbackUrl);

            // Add an anti-forgery state parameter to the authentication properties
            properties.Items["platform"] = platform;

            // Redirect the user to Google's authentication page
            return Task.FromResult(Results.Challenge(properties, [$"Google-{platform}"]));
        }
        catch (NotImplementedException ex)
        {
            // Handle cases where the provider is not supported
            return Task.FromResult(Results.BadRequest(new { error = ex.Message }));
        }
        catch (Exception ex)
        {
            // Handle unexpected errors
            return Task.FromResult(Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An unexpected error occurred while initiating Google login."
            ));
        }
    }

    private static async Task<IResult> GoogleCallbackAsync(
    [FromRoute] string? platform,
    [FromQuery] string? returnUrl,
    [FromServices] GoogleAuthService authService,
    [FromServices] IUserRepository userRepository,
    HttpContext httpContext)
    {
        try
        {

            if (authService == null)
            {
                return Results.Problem("Internal server error. Please contact support.", statusCode: 500);
            }
            // Handle login callback by processing the Google authentication response
            var (success, errorMessage, token, user) = await authService.ProcessGoogleLoginCallback();

            // Check if the authentication process failed
            if (!success || token == null)
            {
                return Results.BadRequest(new { error = errorMessage });
            }

            // Prepare the user data to be returned in the response
            var userData = new
            {
                UserId = user?.Id,
                Username = user?.UserName,
                FirstName = user?.FirstName,
                LastName = user?.LastName,
                Email = user?.Email,
                Token = token
            };

            var refreshToken = await userRepository.GenerateAndAssignRefreshTokenAsync(user!.Id);


            var responseJson = Uri.EscapeDataString(System.Text.Json.JsonSerializer.Serialize(new { token, refreshToken, user = userData }));

            // For Android: redirect using a deeplink with serialized response
            if ((platform?.ToLower() == "android") && !string.IsNullOrEmpty(returnUrl))
            {
                // Security: Only allow trusted deeplink schemes
                var allowedScheme = Environment.GetEnvironmentVariable("SSO_CALLBACK_URL_MOBILE_ANDROID")?.Split("://")[0];
                if (!string.IsNullOrEmpty(allowedScheme) && returnUrl.StartsWith($"{allowedScheme}://"))
                {
                    var redirectUrl = QueryHelpers.AddQueryString(returnUrl, "response", responseJson);
                    return Results.Redirect(redirectUrl);
                }
                else
                {
                    return Results.BadRequest(new { error = "Invalid or untrusted returnUrl for Android SSO." });
                }
            }

            // Handle web platforms (Web) by redirecting to the frontend with the token
            string? websiteBaseUrl = Environment.GetEnvironmentVariable("WEBSITE_BASE_URL");
            if (string.IsNullOrEmpty(websiteBaseUrl))
            {
                return Results.Problem("Internal server error. Please contact support.", statusCode: 500);
            }

            var websiteUrl = websiteBaseUrl + "/#/login/callback?token=" + token;

            var redirectUrlWeb = QueryHelpers.AddQueryString(websiteUrl, "response", responseJson);

            return Results.Redirect(redirectUrlWeb);

        }
        catch (UnauthorizedAccessException)
        {
            // Handle unauthorized access errors
            return Results.Unauthorized();
        }
        catch (Exception ex)
        {
            // Handle unexpected errors
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An unexpected error occurred while processing the Google callback."
            );
        }
    }

    /*
    To test API endpoints, Swagger UI can't be used because of the redirect to Google login page.
    Instead, can use directly the browser or Postman to test the endpoints.
    For the login endpoint, use the URL: http://localhost/api/auth/link/google?provider=GoogleWeb

    To add JWT token for authentication in browser:
    1. Open browser DevTools (F12 or Ctrl+Shift+I)
    2. Go to Network tab
    3. Make a normal request 
    4. Click on the request in the network list
    5. In Headers tab, add custom header:
       Authorization: Bearer <your_token>
    */
    private static IResult LinkGoogle(
        GoogleAuthService.GoogleProvider provider,
        [FromServices] GoogleAuthService authService,
        UserManager<User> userManager,
        HttpContext httpContext)
    {

        if (authService == null || userManager == null)
        {
            return Results.Problem("Internal server error. Please contact support.", statusCode: 500);
        }

        var userId = userManager.GetUserId(httpContext.User);
        if (string.IsNullOrEmpty(userId))
        {
            return Results.Unauthorized();
        }

        // Determine the platform (web or android) and append it to the callback path
        string platform = provider switch
        {
            GoogleAuthService.GoogleProvider.GoogleAndroid => "Android",
            GoogleAuthService.GoogleProvider.GoogleWeb => "Web",
            _ => throw new NotImplementedException("Unsupported Google provider.")
        };

        string callbackUrl = $"{httpContext.Request.Scheme}://{httpContext.Request.Host}/api/auth/link/callback/google";

        var properties = authService.ConfigureGoogleProperties(
            provider, callbackUrl, userId);

        return Results.Challenge(properties, [$"Google-{platform}"]);
    }

    private static async Task<IResult> LinkGoogleCallbackAsync(
        [FromServices] GoogleAuthService authService,
        UserManager<User> userManager,
        HttpContext httpContext)
    {

        if (authService == null || userManager == null)
        {
            return Results.Problem("Internal server error. Please contact support.", statusCode: 500);
        }
        var userId = userManager.GetUserId(httpContext.User);
        if (string.IsNullOrEmpty(userId))
        {
            return Results.Unauthorized();
        }

        var user = await userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return Results.NotFound(new { error = "User not found" });
        }

        var info = await authService.GetExternalLoginInfoAsync();
        if (info == null)
        {
            return Results.BadRequest(new { error = "Error loading Google login information" });
        }

        var (success, errorMessage) = await authService.LinkGoogleAccount(user, info);
        if (!success)
        {
            return Results.BadRequest(new { error = errorMessage });
        }

        return Results.Ok(new { message = "Successfully linked Google account" });
    }

    private static async Task<IResult> GetGoogleLoginsAsync(
        [FromServices] GoogleAuthService authService,
        UserManager<User> userManager,
        HttpContext httpContext)
    {

        if (authService == null || userManager == null)
        {
            return Results.Problem("Internal server error. Please contact support.", statusCode: 500);
        }
        var userId = userManager.GetUserId(httpContext.User);
        if (string.IsNullOrEmpty(userId))
        {
            return Results.Unauthorized();
        }

        var user = await userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return Results.NotFound(new { error = "User not found" });
        }

        var logins = await authService.GetUserGoogleLogins(user);
        var result = logins.Select(l => new
        {
            provider = l.LoginProvider,
            providerKey = l.ProviderKey
        });

        return Results.Ok(result);
    }

    private static async Task<IResult> RemoveGoogleLoginAsync(
        string providerKey,
        [FromServices] GoogleAuthService authService,
        UserManager<User> userManager,
        HttpContext httpContext)
    {

        if (authService == null || userManager == null)
        {
            return Results.Problem("Internal server error. Please contact support.", statusCode: 500);
        }

        var userId = userManager.GetUserId(httpContext.User);
        if (string.IsNullOrEmpty(userId))
        {
            return Results.Unauthorized();
        }

        var user = await userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return Results.NotFound(new { error = "User not found" });
        }

        var (success, errorMessage) = await authService.RemoveGoogleLogin(
            user, providerKey);

        if (!success)
        {
            return Results.BadRequest(new { error = errorMessage });
        }

        return Results.Ok(new { message = "Successfully removed Google login" });
    }
}