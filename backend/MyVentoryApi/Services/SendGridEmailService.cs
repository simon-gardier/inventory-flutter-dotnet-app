using SendGrid;
using SendGrid.Helpers.Mail;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Services;

public class SendGridEmailService : IEmailService
{
    private readonly SendGridClient _client;
    private readonly string _fromEmail;
    private readonly string _fromName;
    private readonly string _verificationTemplateId;
    private readonly string _resetTemplateId;
    private readonly string _borrowerTemplateId;
    private readonly string _backendBaseUrl;
    private readonly string _websiteBaseUrl;
    private readonly ILogger<SendGridEmailService> _logger;

    public SendGridEmailService(ILogger<SendGridEmailService> logger)
    {
        _logger = logger;

        var apiKey = Environment.GetEnvironmentVariable("SENDGRID_API_KEY")
            ?? throw new InvalidOperationException("⚠️  SENDGRID_API_KEY not found in environment variables");
        _fromEmail = Environment.GetEnvironmentVariable("EMAIL_FROM")
            ?? throw new InvalidOperationException("⚠️  EMAIL_FROM not found in environment variables");
        _fromName = Environment.GetEnvironmentVariable("EMAIL_FROM_NAME")
            ?? throw new InvalidOperationException("⚠️  EMAIL_FROM_NAME not found in environment variables");
        _verificationTemplateId = Environment.GetEnvironmentVariable("EMAIL_VERIFICATION_TEMPLATE_ID")
            ?? throw new InvalidOperationException("⚠️  EMAIL_VERIFICATION_TEMPLATE_ID not found in environment variables");
        _resetTemplateId = Environment.GetEnvironmentVariable("PASSWORD_RESET_TEMPLATE_ID")
            ?? throw new InvalidOperationException("⚠️  PASSWORD_RESET_TEMPLATE_ID not found in environment variables");
        _borrowerTemplateId = Environment.GetEnvironmentVariable("EMAIL_LENDING_BORROWER_TEMPLATE_ID")
            ?? throw new InvalidOperationException("EMAIL_LENDING_BORROWER_TEMPLATE_ID not set");
        _backendBaseUrl = Environment.GetEnvironmentVariable("BACKEND_BASE_URL")
            ?? throw new InvalidOperationException("⚠️  BACKEND_BASE_URL not found in environment variables");
        _websiteBaseUrl = Environment.GetEnvironmentVariable("WEBSITE_BASE_URL")
            ?? throw new InvalidOperationException("⚠️  WEBSITE_BASE_URL not found in environment variables");
        _client = new SendGridClient(apiKey);
    }


    public async Task<bool> SendEmailAsync(string toEmail, string toName, string templateId, Dictionary<string, object> templateData)
    {
        try
        {
            var from = new EmailAddress(_fromEmail, _fromName);
            var to = new EmailAddress(toEmail, toName);
            var msg = MailHelper.CreateSingleTemplateEmail(from, to, templateId, templateData);

            var response = await _client.SendEmailAsync(msg);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("🔎  Email sent successfully to {Email} using template {TemplateId}", toEmail, templateId);
                return true;
            }

            var responseBody = await response.Body.ReadAsStringAsync();
            _logger.LogError("❌Failed to send email to {Email}. Status: {Status}, Response: {Response}",
                toEmail, response.StatusCode, responseBody);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending email to {Email}", toEmail);
            return false;
        }
    }

    public async Task<bool> SendVerificationEmailAsync(string toEmail, string toName, string username, string email, string verificationToken)
    {
        var confirmationLink = $"{_backendBaseUrl}/api/users/verify-email?token={verificationToken}&email={Uri.EscapeDataString(toEmail)}";

        var templateData = new Dictionary<string, object>
        {
            { "username", username },
            { "confirmation_link", confirmationLink },
            { "email", email }
        };
        return await SendEmailAsync(toEmail, toName, _verificationTemplateId, templateData);
    }

    public async Task<bool> SendPasswordResetEmailAsync(string toEmail, string toName, string username, string resetToken)
    {
        // the # in the URL is because the frontend uses hash routing with flutter web
        var resetLink = $"{_websiteBaseUrl}/#/reset-password?token={resetToken}&email={Uri.EscapeDataString(toEmail)}";

        var templateData = new Dictionary<string, object>
        {
            { "username", username },
            { "reset_link", resetLink }
        };

        return await SendEmailAsync(toEmail, toName, _resetTemplateId, templateData);
    }

    public async Task<bool> SendEndOfLendingEmailAsync(
    string borrowerEmail, string borrowerName, string lenderName,
    string lenderEmail, string borrowerDisplayName,
    DateTime dueDate, IEnumerable<LendingItemDto> items)
    {
        bool borrowerResult = false, lenderResult = false;
        var itemsArray = items.Select(i => new { name = i.Name, quantity = i.Quantity }).ToList();
        var loginLink = $"{_websiteBaseUrl}/#/login";

        // Email to borrower
        var borrowerTemplateData = new Dictionary<string, object>
    {
        { "borrower_name", borrowerName },
        { "lender_name", lenderName },
        { "due_date", dueDate.ToString("yyyy-MM-dd") },
        { "items", itemsArray },
        { "login_link", loginLink }
    };
        borrowerResult = await SendEmailAsync(borrowerEmail, borrowerName, _borrowerTemplateId, borrowerTemplateData);

        // Email to lender
        var lenderTemplateData = new Dictionary<string, object>
    {
        { "lender_name", borrowerName },
        { "borrower_name", lenderName },
        { "due_date", dueDate.ToString("yyyy-MM-dd") },
        { "items", itemsArray },
        { "login_link", loginLink }
    };
        lenderResult = await SendEmailAsync(lenderEmail, lenderName, _borrowerTemplateId, borrowerTemplateData);

        return borrowerResult && lenderResult;
    }
}