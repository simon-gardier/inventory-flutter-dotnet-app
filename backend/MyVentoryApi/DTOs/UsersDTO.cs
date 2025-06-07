namespace MyVentoryApi.DTOs;
public record UserCreationRequestDto
{
    public required string UserName { get; set; }
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public required string Email { get; set; }
    public required string Password { get; set; }
    public IFormFile? Image { get; set; }
}
public record UsersCreationResponseDto
{
    public int UserId { get; set; }
    public required string UserName { get; set; }
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public required string Email { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
public record UsersLoginRequestDto
{
    public required string UsernameOrEmail { get; set; }
    public required string Password { get; set; }
}

public record UserLoginWithoutPasswordRequestDto
{
    public required string Email { get; set; }
}

public record UsersLoginResponseDto
{
    public int UserId { get; set; }
    public required string Username { get; set; }
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public required string Email { get; set; }
    public required string Token { get; set; }
    public required string RefreshToken { get; set; }
    public byte[]? ProfilePicture { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public record UsersLoginWithoutPasswordResponseDto
{
    public int UserId { get; set; }
    public required string Username { get; set; }
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public required string Email { get; set; }
    public byte[]? ProfilePicture { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
public record ResetPasswordRequestDto
{
    public required string Email { get; set; }
    public required string Token { get; set; }
    public required string NewPassword { get; set; }
}
public record ForgotPasswordRequestDto
{
    public required string Email { get; set; }
}
public record ResendEmailVerificationRequestDto
{
    public required string Email { get; init; }
}
public record UserUpdateRequestDto
{
    public string? UserName { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? Email { get; set; }
    public IFormFile? Image { get; set; }
}
public record UserUpdateRequestRepositoryDto
{
    public string? UserName { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? Email { get; set; }
    public string? Password { get; set; }
    public IFormFile? Image { get; set; }
}
public record UserItemsResponseDto
{
    public int UserId { get; set; }
    public required string Username { get; set; }
    public List<ItemInfoDto> Items { get; set; } = [];
}
public record InventorySearchFiltersDto
{
    public string? Name { get; init; }
    public DateTime? CreatedBefore { get; init; }
    public DateTime? CreatedAfter { get; init; }
    public LendingState? LendingStatus { get; init; }
    public string? LocationName { get; init; }
    public string? Description { get; init; }
    public string? AttributeName { get; init; }
    public string? AttributeValue { get; init; }
    public string? Quantity { get; init; }
    public string? QuantityMoreThan { get; init; }
    public string? QuantityLessThan { get; init; }


}
public record UserSearchResponseDto
{
    public int UserId { get; init; }
    public required string Username { get; init; }
    public required string FirstName { get; init; }
    public required string LastName { get; init; }
    public string? Email { get; init; }
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset UpdatedAt { get; init; }
}


public record UnlockAccountRequestDto
{
    public required string Email { get; set; }
}

public record VerifyEmailWithoutCheckRequestDto
{
    public required string Email { get; set; }
}

public class RefreshTokenRequestDto
{
    public string RefreshToken { get; set; } = string.Empty;
}

public class RefreshTokenResponseDto
{
    public int UserId { get; set; }
    public string JwtToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
}