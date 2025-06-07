using MyVentoryApi.Models;

namespace MyVentoryApi.Repositories
{
    public interface ILocationRepository
    {
        Task<Location> CreateLocationAsync(Location location);
        Task<Location> GetLocationByIdAsync(int locationId);
        Task DeleteLocationAsync(int locationId);
        Task<Location> UpdateLocationAsync(int locationId, Location updatedLocation);
        Task AddImageToLocationAsync(LocationImage image);
        Task RemoveImageFromLocationAsync(int locationId, int imageId);
        Task<IEnumerable<LocationImage>> GetImagesByLocationIdAsync(int locationId);
        Task RemoveItemFromLocationAsync(int locationId, Item item);
        Task<IEnumerable<Item>> GetItemsByLocationIdAsync(int locationId);
        Task MoveItemToLocationAsync(int locationId, Item item);
        Task AddItemToLocationAsync(int locationId, Item item);
        Task<bool> UserHasAccessToLocationAsync(int locationId, int userId, IUserRepository userRepository);
        Task<IEnumerable<Location>> GetSublocationsByParentIdAsync(int parentId);
        Task SetParentLocationAsync(int locationId, int parentLocationId);
        Task<int> GetUsedCapacityByLocationIdAsync(int locationId);
    }
}
