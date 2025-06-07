namespace MyVentoryApi.DTOs;
public enum AttributesTypesDto
{
    Category,
    Link,
    Date,
    Text,
    Number,
    Currency
}
public record AttributeResponseDto
{
    public int AttributeId { get; set; }
    public required string Type { get; set; }
    public required string Name { get; set; }
    public required string Value { get; set; }
}
public record AttributeRequestDto
{
    public required string Type { get; set; }
    public required string Name { get; set; }
    public required string Value { get; set; }
}
