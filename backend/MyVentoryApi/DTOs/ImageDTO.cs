namespace MyVentoryApi.DTOs
{
    public class ImageDto
    {
        public int ImageId { get; set; }
        public required byte[] ImageBin { get; set; }
    }
}