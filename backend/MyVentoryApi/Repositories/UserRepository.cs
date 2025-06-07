using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Models;
using MyVentoryApi.Data;
using MyVentoryApi.DTOs;
using MyVentoryApi.Utilities;
using Attribute = MyVentoryApi.Models.Attribute;
using Microsoft.AspNetCore.Identity;
using MyVentoryApi.Auth;
using MyVentoryApi.Services;
namespace MyVentoryApi.Repositories;

public class UserRepository(MyVentoryDbContext context, ILogger<UserRepository> logger, UserManager<User> userManager, SignInManager<User> _signInManager, JwtTokenService _jwtTokenService, IEmailService emailService) : IUserRepository
{
    private readonly MyVentoryDbContext _context = context ?? throw new ArgumentNullException(nameof(context));
    private readonly ILogger<UserRepository> _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    private readonly UserManager<User> _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
    private readonly SignInManager<User> _signInManager = _signInManager ?? throw new ArgumentNullException(nameof(_signInManager));
    private readonly JwtTokenService _jwtTokenService = _jwtTokenService ?? throw new ArgumentNullException(nameof(_jwtTokenService));
    private readonly IEmailService _emailService = emailService ?? throw new ArgumentNullException(nameof(emailService));
    public async Task<User> CreateUserAsync(UserCreationRequestDto registerRequest, bool sendEmailConfirmation = false)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(registerRequest);

            // check if the Email is already in use
            if (await _userManager.FindByEmailAsync(registerRequest.Email) != null)
                throw new InvalidOperationException($"A user with the email {registerRequest.Email} already exists.");

            // check if the username is already in use
            if (await _userManager.FindByNameAsync(registerRequest.UserName) != null)
                throw new InvalidOperationException($"A user with the username {registerRequest.UserName} already exists.");

            byte[]? profilePicture = null;
            if (registerRequest.Image != null)
            {
                // Validate the image
                var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(registerRequest.Image);
                if (!isValid)
                {
                    throw new InvalidOperationException(errorMessage);
                }

                using var memoryStream = new MemoryStream();
                await registerRequest.Image.CopyToAsync(memoryStream);
                profilePicture = memoryStream.ToArray();
            }

            // Create the user object
            var user = new User
            {
                UserName = registerRequest.UserName,
                Email = registerRequest.Email,
                FirstName = registerRequest.FirstName,
                LastName = registerRequest.LastName,
                ProfilePicture = profilePicture,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                EmailConfirmed = false
            };

            // Create the user using Identity
            var result = await _userManager.CreateAsync(user, registerRequest.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Failed to create user: {errors}");
            }

            // Add the user to the User role
            await _userManager.AddToRoleAsync(user, "User");

            if (sendEmailConfirmation)
            {
                // Generate an email confirmation token
                var verifyMailToken = await _userManager.GenerateEmailConfirmationTokenAsync(user);

                await _emailService.SendVerificationEmailAsync(user.Email!, $"{user.FirstName} {user.LastName}", user.UserName, user.Email, verifyMailToken);
            }

            _logger.LogInformation("🔎  User created successfully. ID: {UserId}", user.Id);

            return (user);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while creating the user", ex);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("⚠️  An invalid operation occurred: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while creating the user");
            throw;
        }
    }

    public async Task<(User User, string JwtToken, string refreshToken)> LoginUserAsync(UsersLoginRequestDto loginRequest)
    {
        try
        {
            // Data validation
            ArgumentNullException.ThrowIfNull(loginRequest);

            if (string.IsNullOrWhiteSpace(loginRequest.UsernameOrEmail))
                throw new ArgumentException("  Username or email cannot be empty.", nameof(loginRequest));

            if (string.IsNullOrWhiteSpace(loginRequest.Password))
                throw new ArgumentException("  Password cannot be empty.", nameof(loginRequest));

            // Find the user by username or email
            var user = await _userManager.FindByNameAsync(loginRequest.UsernameOrEmail)
                ?? await _userManager.FindByEmailAsync(loginRequest.UsernameOrEmail)
                ?? throw new UnauthorizedAccessException("  Invalid username or email.");

            // Check if the user is marked as deleted
            if (user.Deleted)
            {
                throw new UnauthorizedAccessException("  This account has been deleted.");
            }

            // Check if the user is locked out
            if (await _userManager.IsLockedOutAsync(user))
            {
                var lockoutEnd = await _userManager.GetLockoutEndDateAsync(user);
                var remainingLockoutTime = lockoutEnd?.Subtract(DateTimeOffset.UtcNow);

                _logger.LogWarning("⚠️  User {Email} is locked out until {LockoutEnd}.", user.Email, lockoutEnd);
                throw new UnauthorizedAccessException($"⚠️  Account is locked. Try again in {remainingLockoutTime?.TotalMinutes:F0} minutes.");
            }

            // Check if the email is confirmed
            if (!await _userManager.IsEmailConfirmedAsync(user))
                throw new UnauthorizedAccessException("  Email not confirmed. Please check your inbox and confirm your email address.");

            // Check the password
            var result = await _signInManager.CheckPasswordSignInAsync(user, loginRequest.Password, lockoutOnFailure: true);

            if (!result.Succeeded)
            {
                if (result.IsLockedOut)
                {
                    _logger.LogWarning("⚠️  User {Email} is locked out due to multiple failed login attempts.", user.Email);
                    throw new UnauthorizedAccessException("  Account is locked due to multiple failed login attempts.");
                }

                throw new UnauthorizedAccessException("  Invalid password.");
            }

            // Reset failed access count on successful login
            await _userManager.ResetAccessFailedCountAsync(user);

            // Generate a JWT token
            var token = await _jwtTokenService.GenerateJwtToken(user);

            var refreshToken = _jwtTokenService.GenerateRefreshToken();

            await userManager.SetAuthenticationTokenAsync(user, "MyVentoryRefreshToken", "RefreshToken", refreshToken);

            _logger.LogInformation("🔎  User updated successfully. ID: {UserId}", user.Id);

            return (user, token, refreshToken);
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("⚠️  Unauthorized access: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while logging in the user");
            throw;
        }
    }


    public async Task<(User User, string JwtToken, string RefreshToken)> RefreshTokenAsync(string refreshToken)
    {
        try
        {
            // Search the refresh token 
            var userToken = await _context.UserTokens
                .Where(t => t.LoginProvider == "MyVentoryRefreshToken" && t.Name == "RefreshToken" && t.Value == refreshToken)
                .FirstOrDefaultAsync();

            if (userToken == null)
            {
                _logger.LogWarning("⚠️  Invalid refresh token");
                throw new UnauthorizedAccessException("Invalid refresh token.");
            }

            var user = await _userManager.FindByIdAsync(userToken.UserId.ToString())
                ?? throw new KeyNotFoundException($"User with ID {userToken.UserId} not found.");

            // Generate new JWT and refresh token
            var newJwtToken = await _jwtTokenService.GenerateJwtToken(user);
            var newRefreshToken = _jwtTokenService.GenerateRefreshToken();

            await _userManager.SetAuthenticationTokenAsync(user, "MyVentoryRefreshToken", "RefreshToken", newRefreshToken);

            _logger.LogInformation("🔎  Refresh token and JWT issued for user {UserId}", user.Id);

            return (user, newJwtToken, newRefreshToken);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("⚠️  Unauthorized refresh attempt: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while refreshing token");
            throw;
        }
    }

    public async Task<string?> GetRefreshTokenByUserIdAsync(int userId)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString());
            if (user == null)
                return null;

            var refreshToken = await _userManager.GetAuthenticationTokenAsync(user, "MyVentoryRefreshToken", "RefreshToken");
            return refreshToken;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving refresh token for user ID {UserId}", userId);
            throw;
        }
    }

    public async Task<string> GenerateAndAssignRefreshTokenAsync(int userId)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString())
                ?? throw new KeyNotFoundException($"User with ID {userId} not found.");

            var refreshToken = _jwtTokenService.GenerateRefreshToken();
            await _userManager.SetAuthenticationTokenAsync(user, "MyVentoryRefreshToken", "RefreshToken", refreshToken);

            _logger.LogInformation("🔎  Generated and assigned new refresh token for user {UserId}", userId);

            return refreshToken;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while generating and assigning refresh token for user {UserId}", userId);
            throw;
        }
    }

    public async Task<bool> ResendVerificationEmailAsync(string email)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email);

            // If the user doesn't exist, we don't tell the client to avoid email enumeration
            if (user == null)
            {
                _logger.LogInformation("🔎  Resend verification email requested for non-existent email: {Email}", email);
                return true;
            }

            // If the email is already confirmed, no need to send a new email
            if (await _userManager.IsEmailConfirmedAsync(user))
            {
                _logger.LogInformation("🔎  Resend verification email requested for already confirmed email: {Email}", email);
                return true;
            }

            var verifyMailToken = await _userManager.GenerateEmailConfirmationTokenAsync(user);

            var result = await _emailService.SendVerificationEmailAsync(user.Email!,
                                                         $"{user.FirstName} {user.LastName}",
                                                          user.UserName!,
                                                          user.Email!,
                                                          verifyMailToken);

            _logger.LogInformation("🔎  Verification email resent to {Email}", email);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resending verification email to {Email}", email);
            throw;
        }
    }

    public async Task<int?> GetUserIdByEmailAsync(string email)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email);
            return user?.Id;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user ID for email {Email}", email);
            throw;
        }
    }

    public async Task<bool> VerifyEmailAsync(string email, string token)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email) ??
                throw new KeyNotFoundException($"User with email {email} not found.");

            var result = await _userManager.ConfirmEmailAsync(user, token);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                _logger.LogWarning("⚠️  Failed to confirm email for user {UserId}: {Errors}", user.Id, errors);
                return false;
            }

            _logger.LogInformation("🔎  Email verified successfully for user {UserId}", user.Id);
            return true;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while verifying email");
            throw;
        }
    }

    public async Task<bool> ClearLockoutAsync(UnlockAccountRequestDto request)
    {
        try
        {
            ArgumentNullException.ThrowIfNull(request);

            var user = await _userManager.FindByEmailAsync(request.Email) ??
                throw new KeyNotFoundException($"User with email {request.Email} not found.");

            await _userManager.SetLockoutEndDateAsync(user, null);
            await _userManager.ResetAccessFailedCountAsync(user);

            _logger.LogInformation("🔎  Lockout cleared successfully for user {UserId}", user.Id);
            return true;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while clearing lockout for user");
            throw;
        }
    }

    public async Task<bool> VerifyEmailWithoutCheckAsync(int userId)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString()) ??
                throw new KeyNotFoundException($"User with ID {userId} not found.");

            user.EmailConfirmed = true;
            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                _logger.LogWarning("⚠️  Failed to verify email for user {UserId}: {Errors}", user.Id, errors);
                return false;
            }

            _logger.LogInformation("🔎  Email verified without token check for user {UserId}", user.Id);
            return true;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while verifying email without token check");
            throw;
        }
    }

    public async Task<bool> SendPasswordResetEmailAsync(string email)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email) ??
                throw new KeyNotFoundException($"User with email {email} not found.");

            var token = await _userManager.GeneratePasswordResetTokenAsync(user);

            var result = await _emailService.SendPasswordResetEmailAsync(
                user.Email!,
                $"{user.FirstName} {user.LastName}",
                user.UserName!,
                token);

            _logger.LogInformation("🔎  Password reset email sent to user {UserId}", user.Id);
            return result;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while sending password reset email");
            throw;
        }
    }

    public async Task<bool> ResetPasswordAsync(string email, string token, string newPassword)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email) ??
                throw new KeyNotFoundException($"User with email {email} not found.");

            var result = await _userManager.ResetPasswordAsync(user, token, newPassword);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                _logger.LogWarning("⚠️  Failed to reset password for user {UserId}: {Errors}", user.Id, errors);
                return false;
            }

            // Clear lockout flag after successful password reset
            await _userManager.SetLockoutEndDateAsync(user, null);
            await _userManager.ResetAccessFailedCountAsync(user);

            _logger.LogInformation("🔎  Password reset successfully for user {UserId}", user.Id);
            return true;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while resetting password");
            throw;
        }
    }

    public async Task<(User User, string JwtToken)> UpdateUserAsync(int userId, UserUpdateRequestRepositoryDto updateRequest)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString()) ??
                throw new KeyNotFoundException($"User with ID {userId} not found.");

            // Check if the email is being updated and if it already exists
            if (!string.IsNullOrEmpty(updateRequest.Email) && user.Email != updateRequest.Email)
            {
                var existingUserByEmail = await _userManager.FindByEmailAsync(updateRequest.Email);
                if (existingUserByEmail != null && existingUserByEmail.Id != userId)
                    throw new InvalidOperationException($"Email {updateRequest.Email} is already in use.");
            }

            // Check if the username is being updated and if it already exists
            if (!string.IsNullOrEmpty(updateRequest.UserName) && user.UserName != updateRequest.UserName)
            {
                var existingUserByUsername = await _userManager.FindByNameAsync(updateRequest.UserName);
                if (existingUserByUsername != null && existingUserByUsername.Id != userId)
                    throw new InvalidOperationException($"Username {updateRequest.UserName} is already in use.");
            }

            // Mettre à jour les propriétés
            if (!string.IsNullOrEmpty(updateRequest.UserName))
                user.UserName = updateRequest.UserName;

            if (!string.IsNullOrEmpty(updateRequest.Email))
                user.Email = updateRequest.Email;

            if (!string.IsNullOrEmpty(updateRequest.FirstName))
                user.FirstName = updateRequest.FirstName;

            if (!string.IsNullOrEmpty(updateRequest.LastName))
                user.LastName = updateRequest.LastName;

            // Handle profile picture
            if (updateRequest.Image != null)
            {
                // Validate the image
                var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(updateRequest.Image);
                if (!isValid)
                {
                    throw new InvalidOperationException(errorMessage);
                }

                using var memoryStream = new MemoryStream();
                await updateRequest.Image.CopyToAsync(memoryStream);
                user.ProfilePicture = memoryStream.ToArray();
            }

            user.UpdatedAt = DateTime.UtcNow;

            // Update the user
            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Failed to update user: {errors}");
            }

            // Update password if provided
            if (!string.IsNullOrEmpty(updateRequest.Password))
            {
                var passwordToken = await _userManager.GeneratePasswordResetTokenAsync(user);
                var passwordResult = await _userManager.ResetPasswordAsync(user, passwordToken, updateRequest.Password);

                if (!passwordResult.Succeeded)
                {
                    var errors = string.Join(", ", passwordResult.Errors.Select(e => e.Description));
                    throw new InvalidOperationException($"Failed to update password: {errors}");
                }
            }

            var token = await _jwtTokenService.GenerateJwtToken(user);

            _logger.LogInformation("🔎  User updated successfully. ID: {UserId}", user.Id);

            return (user, token);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while updating the user", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning("⚠️  An invalid operation occurred: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while updating the user");
            throw;
        }
    }

    public async Task DeleteUserAsync(int userId)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString()) ??
                throw new KeyNotFoundException($"User with ID {userId} not found.");

            user.Deleted = true;
            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Failed to delete user: {errors}");
            }

            _logger.LogInformation("🔎  User deleted successfully. ID: {UserId}", userId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Error while saving to the database");
            throw new Exception("  An error occurred while deleting the user", ex);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while deleting the user");
            throw;
        }
    }

    public async Task<bool> UserHasAccessAsync(int userId, int currentUserId)
    {
        // Check if the user has access (same user or admin)
        if (userId == currentUserId)
            return true;

        var currentUser = await _userManager.FindByIdAsync(currentUserId.ToString());
        if (currentUser == null)
            return false;

        return await _userManager.IsInRoleAsync(currentUser, "Admin");
    }

    public async Task<bool> HasRoleAsync(int userId, string roleName)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString()) ??
                throw new KeyNotFoundException($"User with ID {userId} not found.");

            var hasRole = await _userManager.IsInRoleAsync(user, roleName);
            _logger.LogInformation("🔎 Checked role {Role} for user {UserId}: {HasRole}", roleName, userId, hasRole);
            return hasRole;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️ User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while checking user role");
            throw;
        }
    }

    public async Task<(User User, IEnumerable<Item> Items)> GetUserWithItemsAsync(int userId)
    {
        try
        {
            // Retrieve the user with all their items
            var user = await _context.Users
                .Include(u => u.OwnedItems)
                .ThenInclude(i => i.ItemLocations)
                .ThenInclude(il => il.Location)
                .FirstOrDefaultAsync(u => u.Id == userId)
                ?? throw new KeyNotFoundException($"User with ID {userId} not found.");

            _logger.LogInformation("🔎  User and items retrieved successfully for user ID: {UserId}", userId);

            // Return the user and their items
            return (user, user.OwnedItems);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving user and items");
            throw;
        }
    }

    public async Task<IEnumerable<Location>> GetLocationsByUserIdAsync(int userId)
    {
        try
        {
            var user = await _context.Users
                .Include(u => u.OwnedLocations)
                .FirstOrDefaultAsync(u => u.Id == userId) ?? throw new KeyNotFoundException($"User with ID {userId} not found.");
            _logger.LogInformation("🔎  Locations retrieved successfully for user ID: {UserId}", userId);
            return user.OwnedLocations;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving locations for the user");
            throw;
        }
    }
    public async Task<IEnumerable<(string Value, Attribute Attributes)>> GetAttributesByUserIdAsync(int userId)
    {
        try
        {
            // Find the user with their items and attributes
            var user = await _context.Users
                .Include(u => u.OwnedItems)
                    .ThenInclude(i => i.ItemAttributes)
                    .ThenInclude(ia => ia.Attribute)
                .FirstOrDefaultAsync(u => u.Id == userId) ?? throw new KeyNotFoundException($"User with ID {userId} not found.");

            // Extract the attributes from the user's items
            var attributes = user.OwnedItems
            .SelectMany(item => item.ItemAttributes)
            .Where(itemAttribute => !string.IsNullOrEmpty(itemAttribute.Value))
            .Select(itemAttribute => (itemAttribute.Value ?? string.Empty, itemAttribute.Attribute))
            .ToList();

            _logger.LogInformation("🔎  Attributes retrieved successfully for user ID: {UserId}", userId);
            return attributes;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving attributes for the user");
            throw;
        }
    }

    public async Task<IEnumerable<Item>> GetItemsByNameByUserAsync(int userId, string nameFilter)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(nameFilter))
            {
                throw new ArgumentException("  Name filter cannot be empty", nameof(nameFilter));
            }
            var items = await _context.Items
                .Include(i => i.Owner)
                .Include(i => i.ItemLocations)
                .Where(i => i.OwnerId == userId && i.Name.ToLower().Contains(nameFilter.ToLower()))
                .ToListAsync();

            _logger.LogInformation("🔎  Retrieved {Count} items for user ID: {UserId} matching name filter: {NameFilter}",
                items.Count, userId, nameFilter);

            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving items for user {UserId} with name filter {NameFilter}",
                userId, nameFilter);
            throw new Exception("  An error occurred while retrieving items", ex);
        }
    }

    public async Task<IEnumerable<Item>> GetItemsFilteredByUserAsync(int userId, InventorySearchFiltersDto filters)
    {
        try
        {
            var query = _context.Items
                .Include(i => i.Images)
                .Include(i => i.ItemAttributes)
                    .ThenInclude(ia => ia.Attribute)
                .Include(i => i.ItemLocations)
                    .ThenInclude(il => il.Location)
                .Where(i => i.OwnerId == userId);

            if (!string.IsNullOrEmpty(filters.Name))
            {
                query = query.Where(i => i.Name.ToLower().Contains(filters.Name.ToLower()));
            }

            if (filters.CreatedBefore.HasValue)
            {
                query = query.Where(i => i.CreatedAt < filters.CreatedBefore.Value);
            }

            if (filters.CreatedAfter.HasValue)
            {
                query = query.Where(i => i.CreatedAt > filters.CreatedAfter.Value);
            }

            if (filters.LendingStatus.HasValue)
            {
                switch (filters.LendingStatus.Value)
                {
                    case LendingState.Borrowed:
                        query = query.Where(i => i.ItemLendings.Any(il => il.Lending.BorrowerId == userId));
                        break;

                    case LendingState.Lent:
                        query = query.Where(i => i.ItemLendings.Any(il => il.Lending.LenderId == userId));
                        break;

                    case LendingState.Due:
                        query = query.Where(i => i.ItemLendings.Any(il => il.Lending.DueDate < DateTime.UtcNow));
                        break;

                    case LendingState.None:
                        query = query.Where(i => !i.ItemLendings.Any());
                        break;
                }
            }

            if (!string.IsNullOrEmpty(filters.LocationName))
            {
                query = query.Where(i => i.ItemLocations.Any(il => il.Location.Name.ToLower().Contains(filters.LocationName.ToLower())));
            }

            if (!string.IsNullOrEmpty(filters.Description))
            {
                query = query.Where(i => i.Description.ToLower().Contains(filters.Description.ToLower()));
            }

            if (!string.IsNullOrEmpty(filters.AttributeName))
            {
                query = query.Where(i => i.ItemAttributes.Any(ia => ia.Attribute.Name == filters.AttributeName));

                if (!string.IsNullOrEmpty(filters.AttributeValue))
                {
                    query = query.Where(i => i.ItemAttributes.Any(ia => ia.Attribute.Name == filters.AttributeName && ia.Value.ToLower().Contains(filters.AttributeValue.ToLower())));
                }
            }

            if (!string.IsNullOrEmpty(filters.Quantity) && int.TryParse(filters.Quantity, out var quantity))
            {
                query = query.Where(i => i.Quantity == quantity);
            }

            if (!string.IsNullOrEmpty(filters.QuantityMoreThan) && int.TryParse(filters.QuantityMoreThan, out var quantityMoreThan))
            {
                query = query.Where(i => i.Quantity > quantityMoreThan);
            }

            if (!string.IsNullOrEmpty(filters.QuantityLessThan) && int.TryParse(filters.QuantityLessThan, out var quantityLessThan))
            {
                query = query.Where(i => i.Quantity < quantityLessThan);
            }

            var items = await query.ToListAsync();
            _logger.LogInformation("🔎  Retrieved {Count} items for user ID {UserId} with search criteria", items.Count, userId);
            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while searching items for user ID {UserId}", userId);
            throw new Exception("  An error occurred while filtering items", ex);
        }
    }

    public async Task<User?> GetUserByIdAsync(int userId)
    {
        return await _context.Users.FindAsync(userId);
    }

    public async Task<IEnumerable<User>> GetUsersByUsernameSubstringAsync(string? usernameSubstring)
    {
        try
        {
            var users = await _context.Users
                .OrderBy(u => u.UserName)
                .ToListAsync();

            _logger.LogInformation("🔎  Retrieved {Count} users", users.Count);

            return users;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving users");
            throw new Exception("  An error occurred while retrieving users", ex);
        }
    }

    public async Task<Item?> GetItemByIdAsync(int itemId)
    {
        try
        {
            var item = await _context.Items
                .Include(i => i.Owner)
                .Include(i => i.ItemLocations)
                    .ThenInclude(il => il.Location)
                .FirstOrDefaultAsync(i => i.ItemId == itemId);

            if (item == null)
            {
                _logger.LogWarning("⚠️ Item with ID {ItemId} not found", itemId);
            }
            else
            {
                _logger.LogInformation("🔎 Retrieved item with ID: {ItemId}", itemId);
            }

            return item;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving item with ID: {ItemId}", itemId);
            throw;
        }
    }

    public async Task<bool> VerifyPasswordAsync(int userId, string password)
    {
        try
        {
            var user = await _userManager.FindByIdAsync(userId.ToString()) ??
                throw new KeyNotFoundException($"User with ID {userId} not found.");

            var result = await _signInManager.CheckPasswordSignInAsync(user, password, lockoutOnFailure: false);

            if (!result.Succeeded)
            {
                _logger.LogWarning("⚠️  Password verification failed for user {UserId}", userId);
                return false;
            }

            _logger.LogInformation("🔎  Password verified successfully for user {UserId}", userId);
            return true;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("⚠️  User not found: {Message}", ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while verifying password");
            throw;
        }
    }
}