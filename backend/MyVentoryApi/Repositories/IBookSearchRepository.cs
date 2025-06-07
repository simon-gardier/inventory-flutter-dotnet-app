using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;

public interface IBookSearchRepository {
    string BuildUrlFromAuthorTitle(string? title = null, string? author = null);
    string BuildUrlFromPlainText(string? query = null);
    string BuildUrlFromISBN(string isbn);
    (bool isbnFound, string isbnContent) TryExtractISBN(string text);
    Task<string> ReturnTextFromImg(IFormFile image);
    ExtRequestResponseDto FormatBookJson(string jsonString);
}