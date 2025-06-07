using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using MyVentoryApi.Models;
using System.Security.Claims;
using MyVentoryApi.Auth;

namespace MyVentoryApi.Services
{
    public class GoogleAuthService(
        UserManager<User> userManager,
        SignInManager<User> signInManager,
        ILogger<GoogleAuthService> logger,
        JwtTokenService jwtService)
    {
        private readonly UserManager<User> _userManager = userManager;
        private readonly SignInManager<User> _signInManager = signInManager;
        private readonly ILogger<GoogleAuthService> _logger = logger;
        private readonly JwtTokenService _jwtService = jwtService;

        /// <summary>
        /// Enum representing the allowed Google providers.
        /// </summary>
        public enum GoogleProvider
        {
            GoogleWeb,
            GoogleAndroid
        }

        /// <summary>
        /// Configures the properties for Google authentication, including the redirect URI.
        /// </summary>
        public AuthenticationProperties ConfigureGoogleProperties(GoogleProvider provider, string redirectUri, string? userId = null)
        {
            var providerString = provider switch
            {
                GoogleProvider.GoogleWeb => "Google-Web",
                GoogleProvider.GoogleAndroid => "Google-Android",
                _ => throw new ArgumentOutOfRangeException(nameof(provider), "Invalid Google provider.")
            };

            return _signInManager.ConfigureExternalAuthenticationProperties(providerString, redirectUri, userId);
        }

        /// <summary>
        /// Retrieves external login information from the Google provider.
        /// </summary>
        public async Task<ExternalLoginInfo> GetExternalLoginInfoAsync()
        {
            var externalLoginInfo = await _signInManager.GetExternalLoginInfoAsync() ?? throw new InvalidOperationException("External login information could not be retrieved.");
            return externalLoginInfo;
        }

        /// <summary>
        /// Processes the Google login callback, handling user creation or linking.
        /// </summary>
        public async Task<(bool success, string? errorMessage, string? token, User? user)> ProcessGoogleLoginCallback()
        {
            var info = await _signInManager.GetExternalLoginInfoAsync();
            if (info == null)
            {
                return (false, "Error loading external login information.", null, null);
            }

            // Check if user already exists with this external login
            var result = await _signInManager.ExternalLoginSignInAsync(
                info.LoginProvider, info.ProviderKey, isPersistent: false, bypassTwoFactor: true);

            if (result.Succeeded)
            {
                _logger.LogInformation($"User logged in with Google provider.");
                var existingUser = await _userManager.FindByLoginAsync(info.LoginProvider, info.ProviderKey);
                if (existingUser == null)
                {
                    return (false, "User not found.", null, null);
                }
                var existingUserToken = await _jwtService.GenerateJwtToken(existingUser);
                return (true, null, existingUserToken, existingUser);
            }

            // If user doesn't exist, create one using Google information
            var email = info.Principal.FindFirstValue(ClaimTypes.Email);
            if (string.IsNullOrEmpty(email))
            {
                return (false, "Email address not provided by Google.", null, null);
            }

            var newUser = await _userManager.FindByEmailAsync(email);

            if (newUser == null)
            {
                // Create new user
                newUser = new User
                {
                    UserName = string.Concat(email.Split('@')[0], Guid.NewGuid().ToString().AsSpan(0, 4)),  // Generate unique username
                    Email = email,
                    FirstName = info.Principal.FindFirstValue(ClaimTypes.GivenName) ?? "",
                    LastName = info.Principal.FindFirstValue(ClaimTypes.Surname) ?? "",
                    EmailConfirmed = true  // Email verified by Google
                };

                var createResult = await _userManager.CreateAsync(newUser);
                if (!createResult.Succeeded)
                {
                    var errors = string.Join(", ", createResult.Errors.Select(e => e.Description));
                    return (false, $"User creation failed: {errors}", null, null);
                }
            }

            // Link Google account to user
            var (success, errorMessage) = await LinkGoogleAccount(newUser, info);
            if (!success)
            {
                return (false, errorMessage, null, null);
            }

            // Generate JWT token
            var newUserToken = await _jwtService.GenerateJwtToken(newUser);
            return (true, null, newUserToken, newUser);
        }

        /// <summary>
        /// Links a Google account to an existing user.
        /// </summary>
        public async Task<(bool success, string? errorMessage)> LinkGoogleAccount(
            User user, ExternalLoginInfo externalLogin)
        {
            var result = await _userManager.AddLoginAsync(user, externalLogin);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                return (false, $"Failed to link Google account: {errors}");
            }

            return (true, null);
        }

        /// <summary>
        /// Removes a linked Google account from a user.
        /// </summary>
        public async Task<(bool success, string? errorMessage)> RemoveGoogleLogin(
            User user, string providerKey)
        {
            var result = await _userManager.RemoveLoginAsync(user, "Google", providerKey);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                return (false, $"Failed to remove Google login: {errors}");
            }

            return (true, null);
        }

        /// <summary>
        /// Retrieves all Google logins linked to a user.
        /// </summary>
        public async Task<IList<UserLoginInfo>> GetUserGoogleLogins(User user)
        {
            var allLogins = await _userManager.GetLoginsAsync(user);
            return [.. allLogins.Where(l => l.LoginProvider == "Google-Web" ||
                                       l.LoginProvider == "Google-Android")];
        }
    }
}