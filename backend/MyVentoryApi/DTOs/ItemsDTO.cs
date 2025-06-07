namespace MyVentoryApi.DTOs;
public record ItemInfoDto
{
    public int ItemId { get; set; }
    public required string Name { get; set; }
    public int Quantity { get; set; }
    public string? Description { get; set; }
    public int OwnerId { get; set; }
    public string? OwnerName { get; set; }
    public string? OwnerEmail { get; set; }
    public LendingState LendingState { get; set; }
    public string? Location { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
public record ItemRequestDto
{
    public required string Name { get; init; }
    public int Quantity { get; init; }
    public string? Description { get; init; }
    public int OwnerId { get; init; }
}
public record ItemsCreationResponseDto
{
    public int ItemId { get; init; }
    public required string Name { get; init; }
    public int Quantity { get; init; }
    public string? Description { get; init; }
    public int OwnerId { get; init; }
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset UpdatedAt { get; init; }
}
public record ItemImageResponseDto
{
    public int ImageId { get; set; }
    public int ItemId { get; set; }
    public byte[]? ImageData { get; set; }
}
