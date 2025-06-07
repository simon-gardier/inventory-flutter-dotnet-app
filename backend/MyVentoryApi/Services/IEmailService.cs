using MyVentoryApi.DTOs;

namespace MyVentoryApi.Services;

public interface IEmailService
{
    Task<bool> SendEmailAsync(string toEmail, string toName, string templateId, Dictionary<string, object> templateData);
    Task<bool> SendVerificationEmailAsync(string toEmail, string toName, string username, string email, string verificationToken);
    Task<bool> SendPasswordResetEmailAsync(string toEmail, string toName, string username, string resetToken);
    Task<bool> SendEndOfLendingEmailAsync(string borrowerEmail, string borrowerName, string lenderName,
        string lenderEmail, string borrowerDisplayName, DateTime dueDate, IEnumerable<LendingItemDto> items);
}