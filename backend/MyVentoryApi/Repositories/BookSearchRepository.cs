using System.Text.Json;
using System.Text.RegularExpressions;
using DotNetEnv;
using MyVentoryApi.DTOs;
using Newtonsoft.Json.Linq;

namespace MyVentoryApi.Repositories;

public partial class BookSearchRepository : IBookSearchRepository
{

    public string BuildUrlFromAuthorTitle(string? title = null, string? author = null)
    {
        string baseUrl = "http://openlibrary.org/search.json";

        var queryParams = new List<string>();
        if (!string.IsNullOrEmpty(title))
        {
            queryParams.Add("title=" + Uri.EscapeDataString(title));
        }
        if (!string.IsNullOrEmpty(author))
        {
            queryParams.Add("author=" + Uri.EscapeDataString(author));
        }
        string queryString = string.Join("&", queryParams);
        string url = baseUrl + "?" + queryString;

        return url;
    }

    public string BuildUrlFromPlainText(string? query = null)
    {
        string baseUrl = "http://openlibrary.org/search.json";

        if (string.IsNullOrEmpty(query))
        {
            return baseUrl;
        }

        string encodedQuery = Uri.EscapeDataString(query);
        string url = $"{baseUrl}?q={encodedQuery}";

        return url;
    }

    public string BuildUrlFromISBN(string isbn)
    {
        return $"http://openlibrary.org/search.json?isbn={Uri.EscapeDataString(isbn)}";
    }

    public ExtRequestResponseDto FormatBookJson(string jsonString)
    {
        using JsonDocument doc = JsonDocument.Parse(jsonString);
        JsonElement root = doc.RootElement;

        if (root.TryGetProperty("docs", out JsonElement docsElement) &&
            docsElement.ValueKind == JsonValueKind.Array)
        {
            JsonElement book;

            try
            {
                book = docsElement.EnumerateArray().First();
            }
            catch (Exception)
            {
                throw new BookNotFoundException("No book found in the response.");
            }
            // Get the cover image URL
            string? imageUrl = null;
            if (book.TryGetProperty("cover_edition_key", out JsonElement olidElement))
            {
                imageUrl = $"https://covers.openlibrary.org/b/olid/{olidElement.GetString()}-M.jpg";
            }
            else if (book.TryGetProperty("edition_key", out JsonElement editionKeyElement) &&
                        editionKeyElement.ValueKind == JsonValueKind.Array)
            {
                JsonElement item = editionKeyElement.EnumerateArray().First();
                if (item.ValueKind == JsonValueKind.String)
                {
                    imageUrl = $"https://covers.openlibrary.org/b/olid/{item.GetString()}-M.jpg";
                }
            }
            imageUrl ??= "No cover available";

            // Get the title
            string name = book.TryGetProperty("title", out JsonElement titleElement)
                ? titleElement.GetString() ?? "Unknown Title"
                : "Unknown Title";

            // Get the autor(s)
            string authors = "Unknown Author";
            if (book.TryGetProperty("author_name", out JsonElement authorsElement) &&
                authorsElement.ValueKind == JsonValueKind.Array)
            {
                authors = string.Join(", ", authorsElement.EnumerateArray().Select(a => a.GetString()));
            }
            string year = "Unknown Year";
            if (book.TryGetProperty("first_publish_year", out JsonElement yearElement))
            {
                year = yearElement.ToString() ?? "Unknown Year";
            }
            // set attributes
            AttributeRequestDto[] attributes = [
                new AttributeRequestDto { Name="Author(s)", Type="Text", Value=authors },
            new AttributeRequestDto { Name="First Publish Year", Type="Number", Value=year },
        ];

            return new ExtRequestResponseDto(name, imageUrl, attributes);

        }
        else
        {
            throw new BookNotFoundException("No book found in the response.");
        }
    }

    public (bool isbnFound, string isbnContent) TryExtractISBN(string text)
    {
        var isbn = string.Empty;

        string pattern = @"\b(97[89][- ]?\d{1,5}[- ]?\d{1,7}[- ]?\d{1,7}[- ]?[\dX])\b|\b(\d{1,5}[- ]?\d{1,7}[- ]?\d{1,7}[- ]?[\dX])\b";
        Regex regex = new(pattern, RegexOptions.Compiled);

        Match match = regex.Match(text);
        if (match.Success)
        {
            isbn = match.Value.Replace(" ", "").Replace("-", ""); // Normalize format
            return (true, isbn);
        }

        return (false, "");
    }

    private static string LoadApiKey(string name)
    {
        Env.Load();
        var apiKey = Environment.GetEnvironmentVariable(name);

        if (string.IsNullOrEmpty(apiKey))
            throw new Exception("API Key not found. Please check your env variables.");
        return apiKey;
    }

    private static string OCR_API_KEY { get; } = LoadApiKey("OCR_API_KEY");

    public async Task<string> ReturnTextFromImg(IFormFile image)
    {
        var apiKey = OCR_API_KEY; // Ensure LoadApiKey is properly implemented
        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
        Directory.CreateDirectory(uploadsFolder); // Ensure directory exists

        var imagePath = Path.Combine(uploadsFolder, image.FileName);

        using (var stream = new FileStream(imagePath, FileMode.Create))
        {
            await image.CopyToAsync(stream);
        }

        string extractedText = "";
        using (var client = new HttpClient())
        {
            using var fileStream = File.OpenRead(imagePath);
            var form = new MultipartFormDataContent
                {
                    { new StringContent(apiKey), "apikey" },
                    { new StringContent("eng"), "language" },
                    { new StreamContent(fileStream), "file", image.FileName }
                };

            var response = await client.PostAsync("https://api.ocr.space/parse/image", form);
            var jsonResponse = await response.Content.ReadAsStringAsync();

            var parsedJson = JObject.Parse(jsonResponse);
            extractedText = parsedJson["ParsedResults"]?[0]?["ParsedText"]?.ToString() ?? "";
            extractedText = MyRegex().Replace(extractedText, "");
        }

        if (File.Exists(imagePath))
        {
            File.Delete(imagePath);
        }
        return extractedText;
    }

    [GeneratedRegex("[^a-zA-Z0-9 -]")]
    private static partial Regex MyRegex();
}

public class BookNotFoundException : Exception
{
    public BookNotFoundException() { }

    public BookNotFoundException(string message) : base(message) { }

    public BookNotFoundException(string message, Exception inner) : base(message, inner) { }
}