using SkiaSharp;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace MyVentoryApi.Utilities;

public static class ImageValidator
{
    // Acceptable MIME types
    private static readonly string[] validMimeTypes = ["image/jpeg", "image/png", "image/gif", "image/bmp", "image/tiff"];

    public static async Task<(bool isValid, string? errorMessage)> ValidateImageAsync(IFormFile? image)
    {
        if (image == null)
            return (true, null);

        // Check MIME type
        if (!validMimeTypes.Contains(image.ContentType))
            return (false, $"Invalid image format: {image.ContentType}. Accepted formats: JPEG, PNG, GIF, BMP, TIFF");

        try
        {
            using var stream = new MemoryStream();
            await image.CopyToAsync(stream);
            stream.Position = 0;

            // Try decoding
            using var codec = SKCodec.Create(stream);
            if (codec == null)
                return (false, "Invalid or corrupted image format.");

            return (true, null);
        }
        catch (Exception ex)
        {
            return (false, $"Error during validation: {ex.Message}");
        }
    }
    public static async Task<byte[]> CompressImageAsync(IFormFile file)
    {
        using var image = await Image.LoadAsync(file.OpenReadStream());

        int maxWidth = 1000;
        int maxHeight = 1000;
        image.Mutate(x => x.Resize(new ResizeOptions
        {
            Mode = ResizeMode.Max,
            Size = new Size(maxWidth, maxHeight)
        }));

        using var outputStream = new MemoryStream();
        await image.SaveAsync(outputStream, new JpegEncoder { Quality = 90 });

        return outputStream.ToArray();
    }
}
