using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Data;
using MyVentoryApi.Repositories;

namespace MyVentoryApi.Services;

public class LendingDueDateNotifier(IServiceProvider serviceProvider, ILogger<LendingDueDateNotifier> logger) : BackgroundService
{
    private readonly IServiceProvider _serviceProvider = serviceProvider;
    private readonly ILogger<LendingDueDateNotifier> _logger = logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            _logger.LogInformation("🔔  Checking for lendings due today...");
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<MyVentoryDbContext>();
                var lendingRepository = scope.ServiceProvider.GetRequiredService<ILendingRepository>();
                var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();

                var today = DateTime.UtcNow.Date;

                var lendings = await db.Lendings
                    .Include(l => l.Borrower)
                    .Include(l => l.Lender)
                    .Where(l => l.DueDate.Date == today && l.ReturnDate == null && l.Borrower != null)
                    .ToListAsync(stoppingToken);


                var userRepo = scope.ServiceProvider.GetRequiredService<IUserRepository>();

                foreach (var lending in lendings)
                {
                    var borrower = lending.Borrower!;
                    var lender = lending.Lender;

                    var items = await lendingRepository.GetLendingItemsAsync(lending.TransactionId);

                    await emailService.SendEndOfLendingEmailAsync(borrower.Email ?? "", borrower.UserName ?? borrower.FirstName ?? "User",
                        lender.UserName ?? lender.FirstName ?? "Lender", lender.Email ?? "",
                        borrower.UserName ?? borrower.FirstName ?? "User", lending.DueDate, items);
                    _logger.LogInformation("End of lending notification sent for lending {Id}", lending.TransactionId);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while sending end of lending notifications");
            }

            // Wait 24h before next check
            await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
        }
    }
}