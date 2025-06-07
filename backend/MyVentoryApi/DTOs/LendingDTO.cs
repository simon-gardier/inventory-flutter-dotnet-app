namespace MyVentoryApi.DTOs;
public enum LendingState
{
    Borrowed,
    Lent,
    Due,
    Returned,
    None
}
public record LendingRequestDto
{
    public int LenderId { get; init; }
    public int? BorrowerId { get; init; }
    public string? BorrowerName { get; init; }
    public DateTime DueDate { get; init; }
    public required List<ItemLendingDto> Items { get; init; }
}
public record ItemLendingDto
{
    public int ItemId { get; init; }
    public int Quantity { get; init; }
}
public record LendingResponseDto
{
    public int TransactionId { get; init; }
    public int? BorrowerId { get; init; }
    public string? BorrowerName { get; init; }
    public string? BorrowerEmail { get; init; }
    public int LenderId { get; init; }
    public string LenderName { get; init; } = string.Empty;
    public string? LenderEmail { get; init; }
    public DateTime DueDate { get; init; }
    public DateTime LendingDate { get; init; }
    public DateTime? ReturnDate { get; init; }
    public List<LendingItemResponseDto> Items { get; init; } = [];
}

public record LendingItemResponseDto
{
    public int ItemId { get; init; }
    public string ItemName { get; init; } = string.Empty;
    public int Quantity { get; init; }
    public string? Description { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public List<ItemImageResponseDto> Images { get; init; } = [];
    public List<AttributeResponseDto> Attributes { get; init; } = []; // New field for item attributes
}

public record UserLendingsResponseDto
{
    public int UserId { get; init; }
    public string Username { get; init; } = string.Empty;
    public List<LendingResponseDto> BorrowedItems { get; init; } = [];
    public List<LendingResponseDto> LentItems { get; init; } = [];
}

public class LendingItemDto
{
    public string Name { get; set; } = string.Empty;
    public int Quantity { get; set; }
}