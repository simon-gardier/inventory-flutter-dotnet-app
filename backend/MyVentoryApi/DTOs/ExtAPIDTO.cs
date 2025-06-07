using System.Drawing;

namespace MyVentoryApi.DTOs;

public record ExtRequestResponseDto
{

    public string Name { get; set; }
    public string? Description { get; set; }
    public string? ImageURL { get; set; }
    public AttributeRequestDto[]? Attributes { get; set; }
    public ExtRequestResponseDto(string name, string? imageUrl = null, AttributeRequestDto[]? attributes = null, string? description = "")
    {
        Name = name;
        Description = description;
        ImageURL = imageUrl;
        Attributes = attributes;
    }
}

public record BookAuthorTitleDto
{

    public string? Author { set; get; }
    public string? Title { set; get; }

    public BookAuthorTitleDto(string? author, string? title)
    {
        Author = author;
        Title = title;
    }
    public bool IsValid()
    {
        if ((Author == null || Author.Length == 0) && (Title == null || Title.Length == 0))
            return false;
        return true;
    }
}