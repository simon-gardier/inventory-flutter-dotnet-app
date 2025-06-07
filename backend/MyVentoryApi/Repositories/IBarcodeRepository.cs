using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;

public interface IBarcodeRepository
{
    Task<string?> ExtractBarcodeAsync(IFormFile file);
    Task<ExtRequestResponseDto> FormatBarcodeInfoToJsonAsync(string barcode);
}
