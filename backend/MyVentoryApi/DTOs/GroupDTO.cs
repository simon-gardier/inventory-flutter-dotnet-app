using MyVentoryApi.Models;

namespace MyVentoryApi.DTOs;

public record GroupCreationRequestDto
{
    public required string Name { get; init; }
    public required Privacy Privacy { get; init; }
    public string? Description { get; init; }
    public IFormFile? GroupProfilePicture { get; init; }
}

public record GroupUpdateRequestDto
{
    public string? Name { get; init; }
    public Privacy? Privacy { get; init; }
    public string? Description { get; init; }
    public IFormFile? GroupProfilePicture { get; init; }
}

public record GroupResponseDto
{
    public int GroupId { get; init; }
    public required string Name { get; init; }
    public required Privacy Privacy { get; init; }
    public string? Description { get; init; }
    public byte[]? GroupProfilePicture { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
    public List<GroupMemberDto> Members { get; init; } = [];
}

public record GroupMemberDto
{
    public int UserId { get; init; }
    public required string Username { get; init; }
    public required string FirstName { get; init; }
    public required string LastName { get; init; }
    public required Role Role { get; init; }
}

public record GroupMembershipRequestDto
{
    public required int UserId { get; init; }
}