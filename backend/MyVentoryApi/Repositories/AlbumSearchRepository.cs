using System;
using System.Net.Http;
using System.Text.Json;
using Bogus.DataSets;
using DotNetEnv;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;
public class AlbumSearchRepository : IAlbumSearchRepository
{
    // see documentation on XWiki https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/API%20Reasseach/LastfmSearch%20Documentation/#HDocumentation

    private static string Lastfm_API_Key { get; } = Environment.GetEnvironmentVariable("LASTFM_API_KEY")
        ?? throw new InvalidOperationException("You need to add a LASTFM_API_KEY in your environment variables (e.g. in a .env file).");


    public static string BuildUrlFromAlbumSearch(string query, byte limit = 30)
    {
        string url = $"http://ws.audioscrobbler.com/2.0/?method=album.search&album={query}&api_key={Lastfm_API_Key}&format=json&limit={limit}";
        return url;
    }

    public async Task<JsonElement> SearchAlbum(string query)
    {

        try
        {
            using HttpClient client = new();
            string url = BuildUrlFromAlbumSearch(query, 1);
            HttpResponseMessage response = await client.GetAsync(url);
            response.EnsureSuccessStatusCode();
            string jsonString = await response.Content.ReadAsStringAsync();

            using JsonDocument doc = JsonDocument.Parse(jsonString);
            JsonElement root = doc.RootElement;

            // get album found list
            JsonElement results = root.GetProperty("results");

            string? number_found = results.GetProperty("opensearch:totalResults").GetString();
            if (number_found == null || uint.Parse(number_found) < 1)
            {
                throw new AlbumNotFoundException($"Lastfm API couldn't find any album for: {query}");
            }
            JsonElement album_matches = results.GetProperty("albummatches");
            JsonElement albums = album_matches.GetProperty("album");

            // return 1st album data
            JsonElement album = albums.EnumerateArray().First();
            return album.Clone(); // doc will be deleted
        }
        catch (HttpRequestException)
        {
            throw new ExternalApiResponseException("An error occured with Last.fm API");
        }
        catch (TaskCanceledException)
        {
            throw new ExternalApiResponseException("Timeout for response from Last.fm API");
        }
        catch (KeyNotFoundException)
        {
            throw new AlbumParsingException("Couldn't Parse response");
        }
    }

    public ExtRequestResponseDto FormatAlbum(JsonElement album)
    {
        // Get the cover image URL
        string imageUrl = "No cover available";
        if (album.TryGetProperty("image", out JsonElement images) && images.ValueKind == JsonValueKind.Array)
        {
            foreach (var image in images.EnumerateArray())
            {
                // the last one is the largest but go trough all if last ones are erroneous
                imageUrl = image.TryGetProperty("#text", out JsonElement text)
                    ? text.GetString() ?? imageUrl
                    : imageUrl;
            }
        }

        string name = "Unknown Name";
        // Get the title
        if (album.TryGetProperty("name", out JsonElement titleElement))
        {
            name = titleElement.GetString() ?? name;
        }
        // Get the artist(s)
        string authors = "Unknown Artist(s)";
        if (album.TryGetProperty("artist", out JsonElement authorsElement))
        {
            authors = authorsElement.ValueKind == JsonValueKind.Array
                ? string.Join(", ", authorsElement.EnumerateArray().Select(a => a.GetString() ?? "Unknown Artist(s)"))
                : authorsElement.GetString() ?? authors;
        }
        // Get the MBID
        string mbid = "Unknown MBID";
        if (album.TryGetProperty("mbid", out JsonElement mbidElement))
        {
            mbid = mbidElement.ToString() ?? mbid;
        }

        // set the attributes
        AttributeRequestDto[] attributes = [
            new AttributeRequestDto { Name="Artist(s)", Type="Text", Value=authors },
            new AttributeRequestDto { Name="MBID", Type="Number", Value=mbid },
        ];
        return new ExtRequestResponseDto(name, imageUrl, attributes);
    }
}

public class AlbumNotFoundException : Exception
{
    public AlbumNotFoundException() { }

    public AlbumNotFoundException(string message) : base(message) { }

    public AlbumNotFoundException(string message, Exception inner) : base(message, inner) { }
}
public class AlbumParsingException : Exception
{
    public AlbumParsingException() { }
    public AlbumParsingException(string message) : base(message) { }

    public AlbumParsingException(string message, Exception inner) : base(message, inner) { }
}
public class ExternalApiResponseException : Exception
{
    public ExternalApiResponseException() { }

    public ExternalApiResponseException(string message) : base(message) { }

    public ExternalApiResponseException(string message, Exception inner) : base(message, inner) { }
}
