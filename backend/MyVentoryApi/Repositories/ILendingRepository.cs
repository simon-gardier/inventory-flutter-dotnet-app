using MyVentoryApi.Models;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;
public interface ILendingRepository
{
    Task<Lending> CreateLendingAsync(Lending lending);
    Task<(IEnumerable<Lending> LentItems, IEnumerable<Lending> BorrowedItems)> GetLendingsByUserIdAsync(int userId);
    Task<Lending> EndLendingAsync(int transactionId);
    Task<IEnumerable<Lending>> GetUserBorrowingsAsync(int userId);
    Task<Lending?> GetLendingByIdAsync(int lendingId);
    Task<bool> UserIsLenderAsync(int lendingId, int userId, IUserRepository userRepository);
    Task<bool> UserIsBorrowerAsync(int lendingId, int userId, IUserRepository userRepository);
    Task<IEnumerable<LendingItemDto>> GetLendingItemsAsync(int lendingId);

}
