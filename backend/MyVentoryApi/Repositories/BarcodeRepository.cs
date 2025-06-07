using ZXing;
using System.Drawing;
using System.IO;
using Microsoft.AspNetCore.Http;
using ZXing.QrCode;
using ZXing.SkiaSharp;
using SkiaSharp;
using MyVentoryApi.DTOs;
using System.Text.Json;

namespace MyVentoryApi.Repositories;

public class BarcodeRepository : IBarcodeRepository
{
    public async Task<string?> ExtractBarcodeAsync(IFormFile file)
    {
        return await Task.Run(() =>
        {
            using var stream = file.OpenReadStream();
            using var skBitmap = SKBitmap.Decode(stream);

            if (skBitmap == null)
            {
                return null;
            }

            var luminanceSource = new SKBitmapLuminanceSource(skBitmap);
            var hybridBinarizer = new ZXing.Common.HybridBinarizer(luminanceSource);

            var barcodeReader = new BarcodeReader
            {
                AutoRotate = true,
                Options = new ZXing.Common.DecodingOptions
                {
                    PossibleFormats = new List<ZXing.BarcodeFormat>
                    {
                        ZXing.BarcodeFormat.QR_CODE,
                        ZXing.BarcodeFormat.All_1D
                    },
                    TryHarder = true,
                    TryInverted = true,
                    PureBarcode = false,
                }
            };

            var result = barcodeReader.Decode(skBitmap);
            return result?.Text;
        });
    }

    public async Task<ExtRequestResponseDto> FormatBarcodeInfoToJsonAsync(string barcode)
    {
        var apiKey = Environment.GetEnvironmentVariable("BARCODELOOKUP_API_KEY") ??
                        throw new InvalidOperationException("⚠️  You need to add a BARCODELOOKUP_API_KEY in your environment variables (e.g. in a .env file).");
        var apiUrl = $"https://api.barcodelookup.com/v3/products?barcode={barcode}&formatted=y&key={apiKey}";

        using var httpClient = new HttpClient();
        var response = await httpClient.GetAsync(apiUrl);
        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException($"Failed to fetch data from barcodelookup. Status code: {response.StatusCode}");
        }
        var responseContent = await response.Content.ReadAsStringAsync();
        Console.WriteLine("Response Content: " + responseContent);

        using var document = JsonDocument.Parse(responseContent);
        var jsonData = document.RootElement;
        var productData = jsonData.GetProperty("products")[0];

        var name = productData.GetProperty("title").GetString();
        var description = productData.GetProperty("description").GetString();
        var imageUrl = productData.GetProperty("images").EnumerateArray().FirstOrDefault().GetString();
        var attributes = new List<AttributeRequestDto>();

        attributes.Add(new AttributeRequestDto { Name = "Barcode", Type = "Text", Value = barcode });

        var category = productData.GetProperty("category").GetString()?.Split('>').LastOrDefault()?.Trim();
        if (category != null && category.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = category, Type = "Category", Value = "" });
        }

        var brand = productData.GetProperty("brand").GetString();
        if (brand != null && brand.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Brand", Type = "Text", Value = brand });
        }

        var color = productData.GetProperty("color").GetString();
        if (color != null && color.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Color", Type = "Text", Value = color });
        }

        var releaseDate = productData.GetProperty("release_date").GetString();
        if (releaseDate != null && releaseDate.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Release date", Type = "Date", Value = releaseDate });
        }

        var ingredients = productData.GetProperty("ingredients").GetString();
        if (ingredients != null && ingredients.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Ingredients", Type = "Text", Value = ingredients });
        }

        var nutritionalFacts = productData.GetProperty("nutrition_facts").GetString();
        if (nutritionalFacts != null && nutritionalFacts.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Nutritional facts", Type = "Text", Value = nutritionalFacts });
        }

        var manufacturer = productData.GetProperty("manufacturer").GetString();
        if (manufacturer != null && manufacturer.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Manufacturer", Type = "Text", Value = manufacturer });
        }

        string? contributors = null;
        if (productData.TryGetProperty("contributors", out var contributorsArray) && contributorsArray.ValueKind == JsonValueKind.Array)
        {
            contributors = string.Join(", ", contributorsArray.EnumerateArray().Select(c => c.GetString()));
        }
        if (contributors != null && contributors.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Contributors", Type = "Text", Value = contributors });
        }

        var model = productData.GetProperty("model").GetString();
        if (model != null && model.Length > 0)
        {
            attributes.Add(new AttributeRequestDto { Name = "Model", Type = "Text", Value = model });
        }

        var itemData = new ExtRequestResponseDto
        (
            name: name!,
            imageUrl: imageUrl,
            description: description ?? "No description",
            attributes: attributes.ToArray()
        );
        return await Task.FromResult(itemData);
    }
}
