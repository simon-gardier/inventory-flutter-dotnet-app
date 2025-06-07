using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Models;
using MyVentoryApi.Data;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;

public class LendingRepositoryException : Exception
{
    public LendingRepositoryException() { }

    public LendingRepositoryException(string message) : base(message) { }

    public LendingRepositoryException(string message, Exception innerException) : base(message, innerException) { }
}

public class LendingRepository(MyVentoryDbContext context, ILogger<UserRepository> logger) : ILendingRepository
{
    private readonly MyVentoryDbContext _context = context ?? throw new ArgumentNullException(nameof(context));
    private readonly ILogger<UserRepository> _logger = logger ?? throw new ArgumentNullException(nameof(logger));

    public async Task<Lending> CreateLendingAsync(Lending lending)
    {
        try
        {
            ArgumentNullException.ThrowIfNull(lending);

            await _context.Lendings.AddAsync(lending);
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎  Lending created successfully. ID: {LendingId}", lending.TransactionId);
            return lending;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while creating lending");
            throw new LendingRepositoryException("  An error occurred while creating the lending", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while creating lending");
            throw new LendingRepositoryException("Error while creating a lending", ex);
        }
    }

    public async Task<(IEnumerable<Lending> LentItems, IEnumerable<Lending> BorrowedItems)> GetLendingsByUserIdAsync(int userId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

            var lentItems = await _context.Lendings
                .Include(l => l.Borrower)
                .Include(l => l.LendItems)
                    .ThenInclude(il => il.Item)
                .Where(l => l.LenderId == userId)
                .ToListAsync();

            var borrowedItems = await _context.Lendings
                .Include(l => l.Lender)
                .Include(l => l.LendItems)
                    .ThenInclude(il => il.Item)
                .Where(l => l.BorrowerId == userId)
                .ToListAsync();

            _logger.LogInformation("🔎  Retrieved lending information for user ID: {UserId}. Lent: {LentCount}, Borrowed: {BorrowedCount}",
                userId, lentItems.Count, borrowedItems.Count);

            return (lentItems, borrowedItems);
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid user ID provided: {UserId}", userId);
            throw new LendingRepositoryException($"An error occurred while retrieving lendings for user ID {userId}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving lendings for user ID: {UserId}", userId);
            throw new LendingRepositoryException($"An error occurred while retrieving lendings for user ID {userId}", ex);
        }
    }

    public async Task<Lending?> GetLendingByIdAsync(int lendingId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(lendingId);

            var lending = await _context.Lendings
                .Include(l => l.Borrower)
                .Include(l => l.Lender)
                .Include(l => l.LendItems)
                    .ThenInclude(il => il.Item)
                .FirstOrDefaultAsync(l => l.TransactionId == lendingId);

            if (lending == null)
            {
                _logger.LogWarning("⚠️  Lending with ID {LendingId} not found", lendingId);
            }
            else
            {
                _logger.LogInformation("🔎  Retrieved lending with ID: {LendingId}", lendingId);
            }

            return lending;
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid lending ID provided: {LendingId}", lendingId);
            throw new LendingRepositoryException($"An error occurred while retrieving lending with ID {lendingId}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving lending with ID: {LendingId}", lendingId);
            throw new LendingRepositoryException($"An error occurred while retrieving lending with ID {lendingId}", ex);
        }
    }

    public async Task<bool> UserIsLenderAsync(int lendingId, int userId, IUserRepository userRepository)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(lendingId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);
            ArgumentNullException.ThrowIfNull(userRepository);

            var lending = await _context.Lendings
                .FirstOrDefaultAsync(l => l.TransactionId == lendingId);

            if (lending == null)
            {
                _logger.LogWarning("⚠️  Lending with ID {LendingId} not found while checking if user {UserId} is lender",
                    lendingId, userId);
                return false;
            }

            // Check if the user is the lender
            bool isLender = await userRepository.UserHasAccessAsync(lending.LenderId, userId);

            _logger.LogInformation("🔎  User {UserId} is lender for lending {LendingId}: {IsLender}",
                userId, lendingId, isLender);

            return isLender;
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid parameters while checking lender. Lending ID: {LendingId}, User ID: {UserId}",
                lendingId, userId);
            throw new LendingRepositoryException($"An error occurred while checking if user is lender for lending ID {lendingId}", ex);
        }
        catch (ArgumentNullException ex)
        {
            _logger.LogError(ex, "Required dependency missing while checking if user is lender");
            throw new LendingRepositoryException($"An error occurred while checking if user is lender for lending ID {lendingId}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking if user {UserId} is lender for lending {LendingId}", userId, lendingId);
            throw new LendingRepositoryException($"An error occurred while checking if user is lender for lending ID {lendingId}", ex);
        }
    }

    public async Task<bool> UserIsBorrowerAsync(int lendingId, int userId, IUserRepository userRepository)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(lendingId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);
            ArgumentNullException.ThrowIfNull(userRepository);

            var lending = await _context.Lendings
                .FirstOrDefaultAsync(l => l.TransactionId == lendingId);

            if (lending == null)
            {
                _logger.LogWarning("⚠️  Lending with ID {LendingId} not found while checking if user {UserId} is borrower",
                    lendingId, userId);
                return false;
            }

            // Check if the user is the borrower
            bool isBorrower = lending.BorrowerId.HasValue &&
                await userRepository.UserHasAccessAsync(lending.BorrowerId.Value, userId);

            _logger.LogInformation("🔎  User {UserId} is borrower for lending {LendingId}: {IsBorrower}",
                userId, lendingId, isBorrower);

            return isBorrower;
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid parameters while checking borrower. Lending ID: {LendingId}, User ID: {UserId}", lendingId, userId);
            throw new LendingRepositoryException($"An error occurred while checking if user is borrower for lending ID {lendingId}", ex);
        }
        catch (ArgumentNullException ex)
        {
            _logger.LogError(ex, "Required dependency missing while checking if user is borrower");
            throw new LendingRepositoryException($"An error occurred while checking if user is borrower for lending ID {lendingId}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking if user {UserId} is borrower for lending {LendingId}", userId, lendingId);
            throw new LendingRepositoryException($"An error occurred while checking if user is borrower for lending ID {lendingId}", ex);
        }
    }

    public async Task<Lending> EndLendingAsync(int transactionId)
    {
        var lending = await _context.Lendings
            .Include(l => l.LendItems)
                .ThenInclude(il => il.Item)
            .FirstOrDefaultAsync(l => l.TransactionId == transactionId)
            ?? throw new KeyNotFoundException($"Lending with ID {transactionId} not found.");

        if (lending.ReturnDate.HasValue)
        {
            throw new InvalidOperationException($"Lending with ID {transactionId} has already been returned on {lending.ReturnDate}.");
        }

        // Return all items by restoring their quantities
        foreach (var itemLending in lending.LendItems)
        {
            itemLending.Item.Quantity += itemLending.Quantity;
        }

        lending.ReturnDate = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return lending;
    }

    public async Task<IEnumerable<Lending>> GetUserBorrowingsAsync(int userId)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

        return await _context.Lendings
            .Include(l => l.Lender)
            .Include(l => l.LendItems)
                .ThenInclude(il => il.Item)
            .Where(l => l.BorrowerId == userId)
            .OrderByDescending(l => l.LendingDate)
            .ToListAsync();
    }

    public async Task<IEnumerable<LendingItemDto>> GetLendingItemsAsync(int lendingId)
    {
        return await _context.ItemLendings
            .Where(il => il.TransactionId == lendingId)
            .Select(il => new LendingItemDto
            {
                Name = il.Item.Name,
                Quantity = il.Quantity
            })
            .ToListAsync();
    }
}
