using MyVentoryApi.Models;
using MyVentoryApi.DTOs;
using Attribute = MyVentoryApi.Models.Attribute;


namespace MyVentoryApi.Repositories
{
    public interface IUserRepository
    {
        Task<User> CreateUserAsync(UserCreationRequestDto registerRequest, bool sendEmailConfirmation = false);
        Task<(User User, string JwtToken, string refreshToken)> LoginUserAsync(UsersLoginRequestDto loginRequest);
        Task<(User User, string JwtToken, string RefreshToken)> RefreshTokenAsync(string refreshToken);
        Task<string?> GetRefreshTokenByUserIdAsync(int userId);
        Task<string> GenerateAndAssignRefreshTokenAsync(int userId);
        Task<bool> ResendVerificationEmailAsync(string email);
        Task<int?> GetUserIdByEmailAsync(string email);
        Task<bool> VerifyEmailAsync(string email, string token);
        Task<bool> VerifyEmailWithoutCheckAsync(int userId); // /!\ This method should only be used for testing purposes
        Task<bool> ClearLockoutAsync(UnlockAccountRequestDto request);
        Task<bool> SendPasswordResetEmailAsync(string email);
        Task<bool> ResetPasswordAsync(string email, string token, string newPassword);
        Task<(User User, string JwtToken)> UpdateUserAsync(int userId, UserUpdateRequestRepositoryDto updateRequest);
        Task DeleteUserAsync(int userId);
        Task<bool> UserHasAccessAsync(int userId, int currentUserId);
        Task<bool> HasRoleAsync(int userId, string roleName);
        Task<(User User, IEnumerable<Item> Items)> GetUserWithItemsAsync(int userId);
        Task<IEnumerable<Location>> GetLocationsByUserIdAsync(int userId);
        Task<IEnumerable<(string Value, Attribute Attributes)>> GetAttributesByUserIdAsync(int userId);
        Task<IEnumerable<Item>> GetItemsByNameByUserAsync(int userId, string nameFilter);
        Task<IEnumerable<Item>> GetItemsFilteredByUserAsync(int userId, InventorySearchFiltersDto filters);
        Task<Item?> GetItemByIdAsync(int itemId);
        Task<User?> GetUserByIdAsync(int userId);
        Task<IEnumerable<User>> GetUsersByUsernameSubstringAsync(string? usernameSubstring);
        Task<bool> VerifyPasswordAsync(int userId, string password);
    }
}
