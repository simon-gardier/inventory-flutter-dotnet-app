using System.Text.Json;
using MyVentoryApi.DTOs;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Vision.V1;
using System.Security.Cryptography;
using Google.Protobuf.WellKnownTypes;

namespace MyVentoryApi.Repositories;

class ImageRecognitionRepository : IImageRecognitionRepository
{

    public ExtRequestResponseDto RandomResponse()
    {

        ExtRequestResponseDto[] choices = [
            new ExtRequestResponseDto(
                "Harry Potter and the Pilosopher Stone",
                "https://covers.openlibrary.org/b/id/8494529-M.jpg",
                [
                    new AttributeRequestDto { Name="Author(s)",Type="Text", Value="J. K. Rowling " },
                    new AttributeRequestDto { Name="First Published", Type="Number", Value="1997" },
                ]
            ),
            new ExtRequestResponseDto(
                "Harry Potter and the Prisonner of Askaban",
                "https://covers.openlibrary.org/b/id/12728911-M.jpg",
                [
                    new AttributeRequestDto { Name="Author(s)",Type="Text", Value="J. K. Rowling " },
                    new AttributeRequestDto { Name="First Published", Type="Number", Value="1999" },

                ]
            ),
            new ExtRequestResponseDto(
                "Thriller",
                "https://lastfm.freetls.fastly.net/i/u/770x0/a6a876bd5f927ac2ca5b72a4826f62c7.jpg#a6a876bd5f927ac2ca5b72a4826f62c7",
                [
                    new AttributeRequestDto { Name="Artist(s)",Type="Text", Value="Michael Jackson" },
                    new AttributeRequestDto { Name="MBID", Type="Text", Value="Unknown MBID" }
                ]
            ),
            new ExtRequestResponseDto(
                "Unknown Name",
                "No Cover Available",
                []
            )
        ];

        return choices[RandomNumberGenerator.GetInt32(choices.Length)];
    }

    private static GoogleCredential Credentials { get; } = LoadCredentials();
    private static GoogleCredential LoadCredentials()
    {
        string? jsonCredentials = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS_JSON")
            ?? throw new InvalidOperationException("⚠️  You need to add a GOOGLE_APPLICATION_CREDENTIALS_JSON in your environment variables (e.g. in a .env file).");
        try
        {
            var credentials = GoogleCredential.FromJson(jsonCredentials).CreateScoped(ImageAnnotatorClient.DefaultScopes);
            return credentials;
        }
        catch (Exception e)
        {
            throw new InvalidOperationException("⚠️  Couldn't load GOOGLE_APPLICATION_CREDENTIALS from GOOGLE_APPLICATION_CREDENTIALS_JSON: ", e);
        }
    }

    public JsonElement GetLabels(Image image)
    {
        try
        {
            var client = new ImageAnnotatorClientBuilder { Credential = Credentials }.Build();
            var response = client.DetectLabels(image);

            var results = new Dictionary<string, float>();
            foreach (var label in response)
            {
                results[label.Description] = label.Score;
            }
            using var jsonDoc = JsonDocument.Parse(JsonSerializer.Serialize(results));
            return jsonDoc.RootElement.Clone(); // jsonDoc will be deleted
        }
        catch (Google.GoogleApiException e)
        {
            throw new ExternalApiResponseException("Exception from Google Clous Vision API: ", e);
        }
        catch (Grpc.Core.RpcException e)
        {
            throw new ConnexionException("Connection issue or Google Vision server unavailable: ", e);
        }
    }
}

public class ConnexionException : Exception
{
    public ConnexionException() { }

    public ConnexionException(string message) : base(message) { }

    public ConnexionException(string message, Exception inner) : base(message, inner) { }
}
