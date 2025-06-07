namespace MyVentoryApi.DTOs;
public record LocationRequestDto
{
    public required string Name { get; set; }
    public int Capacity { get; set; }
    public string? Description { get; set; }
    public int OwnerId { get; set; }
    public int? ParentLocationId { get; set; }
    public byte[]? FirstImage { get; set; }
}
public record LocationResponseDto
{
    public int LocationId { get; set; }
    public required string Name { get; set; }
    public int Capacity { get; set; }
    public int UsedCapacity { get; set; }
    public string? Description { get; set; }
    public int OwnerId { get; set; }
    public int? ParentLocationId { get; set; }
    public byte[]? FirstImage { get; set; }
}
public record LocationUpdateDto
{
    public required string? Name { get; set; }
    public int? Capacity { get; set; }
    public string? Description { get; set; }
    public int? OwnerId { get; set; }
    public int? ParentLocationId { get; set; }
    public byte[]? FirstImage { get; set; }
}
