using MyVentoryApi.DTOs;
using MyVentoryApi.Repositories;
using MyVentoryApi.Utilities;
using System.Net.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication;
using System.Security.Cryptography;


namespace MyVentoryApi.Endpoints;

public static class ExternalApiEndpoints
{
    public static void MapExternalApiEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/external");

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/

        group.MapPost("/image", ScanImageAsync)
            .Accepts<IFormFile>("multipart/form-data")
            .DisableAntiforgery()
            .WithName("ScanImage")
            .WithTags("External")
            .Produces<ExtRequestResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("CURRENTLY MOCKED: MOCK API RETURNING RANDOM RESPONSE. Try to recognize an item by its picture. Returns the found item with a 200 status code if successful.")
            .WithSummary("Scan an item")
            .RequireAuthorization();

        group.MapPost("/barcode", ScanBarcodeAsync)
            .Accepts<IFormFile>("multipart/form-data")
            .DisableAntiforgery()
            .WithName("ScanBarcode")
            .WithTags("External")
            .Produces<ExtRequestResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Try to recognize an item by a picture of its barcode. Returns the found item with a 200 status code if successful.")
            .WithSummary("Scan a barcode")
            .RequireAuthorization();

        group.MapPost("/books/image", ScanBookAsync)
            .Accepts<IFormFile>("multipart/form-data")
            .DisableAntiforgery()
            .WithName("ScanBook")
            .WithTags("External")
            .Produces<ExtRequestResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Try to recognize a book by its picture. Returns the found item with a 200 status code if successful.")
            .WithSummary("Scan a book")
            .RequireAuthorization();

        group.MapPost("/books/author_title", SearchBookAuthorTitleAsync)
            .WithName("SearchBookByAuthorTitle")
            .WithTags("External")
            .Produces<ExtRequestResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Try to recognize a book by its title and/or author. Returns the found item with a 200 status code if successful.")
            .WithSummary("Search for a book")
            .RequireAuthorization();

        group.MapPost("/albums/image", ScanAlbumAsync)
            .Accepts<IFormFile>("multipart/form-data")
            .DisableAntiforgery()
            .WithName("ScanAlbum")
            .WithTags("External")
            .Produces<ExtRequestResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Try to recognize an album by its picture. Returns the found item with a 200 status code if successful.")
            .WithSummary("Scan an album")
            .RequireAuthorization();

        group.MapPost("/albums/search", SearchAlbumAsync)
           .WithName("SearchAlbum")
           .WithTags("External")
           .Produces<ExtRequestResponseDto>(StatusCodes.Status200OK)
           .Produces(StatusCodes.Status400BadRequest)
           .Produces(StatusCodes.Status401Unauthorized)
           .Produces(StatusCodes.Status404NotFound)
           .Produces(StatusCodes.Status500InternalServerError)
           .WithDescription("Try to recognize an album by its title and/or artist. Returns the found item with a 200 status code if successful.")
           .WithSummary("Search for an album")
           .RequireAuthorization();
    }

    /********************************************************/
    /*                Endpoints implementation              */
    /********************************************************/

    private async static Task<string> GetHttpResponseAsync(string url, IHttpClientFactory httpClientFactory)
    {
        var httpClient = httpClientFactory.CreateClient();
        return await httpClient.GetStringAsync(url);
    }

    private static IResult? CheckAuth(HttpContext httpContext)
    {
        var authResult = JwtAuthorizationHelper.CheckAuthenticated(httpContext);
        return authResult;
    }

    private static async Task<IResult> ScanImageAsync(IFormFile image, IImageRecognitionRepository repo, HttpContext httpContext)
    {
        var authResult = CheckAuth(httpContext);
        if (authResult != null)
            return authResult;

        if (image == null || image.Length == 0)
            return Results.BadRequest(new { message = "No image uploaded" });

        var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(image);
        if (!isValid)
            return Results.BadRequest(new { message = $"Image {image.FileName} is invalid: {errorMessage}" });

        int roll = RandomNumberGenerator.GetInt32(10);
        if (roll == 0)
            return Results.InternalServerError(new { message = "Mock a 500 error" });
        else if (roll <= 2)
            return Results.NotFound(new { message = "Mock a 404 error" });

        return Results.Ok(repo.RandomResponse());
    }

    private static async Task<IResult> ScanBookAsync(IFormFile image, IBookSearchRepository repo, IHttpClientFactory httpClientFactory, HttpContext httpContext)
    {
        var authResult = CheckAuth(httpContext);
        if (authResult != null)
            return authResult;

        if (image == null || image.Length == 0)
            return Results.BadRequest(new { message = "No image uploaded" });

        var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(image);
        if (!isValid)
            return Results.BadRequest(new { message = $"Image {image.FileName} is invalid: {errorMessage}" });

        // scan text from image (try extact isbn or a title/author/...)
        string q = await repo.ReturnTextFromImg(image);
        if (q == null || q.Length == 0)
            return Results.NotFound(new { message = "Failed to extract text from the image" });

        string url;
        var (isbnFound, isbnContent) = repo.TryExtractISBN(q); // Check if the image contains an ISBN
        if (isbnFound && isbnContent != null)
        {
            // Use the scanned ISBN for the request
            url = repo.BuildUrlFromISBN(isbnContent);
        }
        else
            url = repo.BuildUrlFromPlainText(q);

        var response = await GetHttpResponseAsync(url, httpClientFactory);

        // Format and return the response
        try
        {
            var formattedBook = repo.FormatBookJson(response);
            return Results.Ok(formattedBook);
        }
        catch (BookNotFoundException)
        {
            return Results.NotFound(new { message = $"No book found for {q}" });
        }
        catch (ExternalApiResponseException e)
        {
            return Results.InternalServerError(new { message = e.Message });
        }
    }

    private static async Task<IResult> ScanBarcodeAsync(IFormFile image, bool dummyResponse, IBarcodeRepository repo, IImageRecognitionRepository imageRepo, IHttpClientFactory httpClientFactory, HttpContext httpContext)
    {
        var authResult = CheckAuth(httpContext);
        if (authResult != null)
            return authResult;

        if (image == null || image.Length == 0)
            return Results.BadRequest(new { message = "No image uploaded" });

        if (dummyResponse)
        {
            return Results.Ok(imageRepo.RandomResponse());
        }

        var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(image);
        if (!isValid)
            return Results.BadRequest(new { message = $"Image {image.FileName} is invalid: {errorMessage}" });

        // scan text from image (try extact text)
        var barcode = await repo.ExtractBarcodeAsync(image);
        if (barcode == null || barcode.Length == 0)
            return Results.NotFound(new { message = "No barcode found. Try closer." });

        var itemData = await repo.FormatBarcodeInfoToJsonAsync(barcode);

        return Results.Ok(itemData);
    }

    private static async Task<IResult> SearchBookAuthorTitleAsync(BookAuthorTitleDto query, IBookSearchRepository repo, IHttpClientFactory httpClientFactory, HttpContext httpContext)
    {
        var authResult = CheckAuth(httpContext);
        if (authResult != null)
            return authResult;

        if (!query.IsValid())
            return Results.BadRequest(new { message = "Author or title must be provided" });

        string? author = query.Author;
        string? title = query.Title;
        string url = repo.BuildUrlFromAuthorTitle(title, author);
        var response = await GetHttpResponseAsync(url, httpClientFactory);
        // Format and return the response
        try
        {
            var formattedBooks = repo.FormatBookJson(response);
            return Results.Ok(formattedBooks);
        }
        catch (BookNotFoundException e)
        {
            return Results.NotFound(new { message = e.Message });
        }
        catch (ExternalApiResponseException e)
        {
            return Results.InternalServerError(new { message = e.Message });
        }
    }

    private static async Task<IResult> ScanAlbumAsync(IFormFile image, IAlbumSearchRepository album_repo, IBookSearchRepository book_repo, HttpContext httpContext)
    {
        var authResult = CheckAuth(httpContext);
        if (authResult != null)
            return authResult;

        if (image == null || image.Length == 0)
            return Results.BadRequest(new { message = "No image uploaded" });

        var (isValid, errorMessage) = await ImageValidator.ValidateImageAsync(image);
        if (!isValid)
            return Results.BadRequest(new { message = $"Image {image.FileName} is invalid: {errorMessage}" });

        string query = await book_repo.ReturnTextFromImg(image); // reuse the text extraction from ocr api to extract text from image
        // format and return the response
        if (query == null || query.Length == 0)
            return Results.NotFound(new { message = "Failed to extract text from the image" });

        // format and return the response
        try
        {
            var response = await album_repo.SearchAlbum(query);
            var formattedAlbum = album_repo.FormatAlbum(response);
            return Results.Ok(formattedAlbum);

        }
        catch (AlbumNotFoundException e)
        {
            return Results.NotFound(new { message = e.Message });
        }
        catch (AlbumParsingException e)
        {
            return Results.InternalServerError(new { message = e.Message });
        }
        catch (ExternalApiResponseException e)
        {
            return Results.InternalServerError(new { message = e.Message });
        }
    }

    private static async Task<IResult> SearchAlbumAsync(string query, IAlbumSearchRepository repo, HttpContext httpContext)
    {
        var authResult = CheckAuth(httpContext);
        if (authResult != null)
            return authResult;

        if (query == null || query.Length == 1)
            return Results.BadRequest("No query provided.");

        // format and return the response
        try
        {
            var response = await repo.SearchAlbum(query);
            var formattedAlbum = repo.FormatAlbum(response);
            return Results.Ok(formattedAlbum);
        }
        catch (AlbumNotFoundException e)
        {
            return Results.NotFound(new { message = e.Message });
        }
        catch (AlbumParsingException e)
        {
            return Results.InternalServerError(new { message = e.Message });
        }
        catch (ExternalApiResponseException e)
        {
            return Results.InternalServerError(new { message = e.Message });
        }
    }
}
