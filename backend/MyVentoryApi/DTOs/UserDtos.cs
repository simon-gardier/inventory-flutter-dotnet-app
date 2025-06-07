using System.ComponentModel.DataAnnotations;

namespace MyVentoryApi.DTOs;
public class VerifyPasswordRequestDto
{
    [Required]
    public int UserId { get; set; }

    [Required]
    public string Password { get; set; } = string.Empty;
} 