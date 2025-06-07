using MyVentoryApi.Models;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories
{
    public interface IUserGroupRepository
    {
        Task<UserGroup> CreateGroupAsync(UserGroup group);
        Task<UserGroup?> GetGroupByIdAsync(int groupId);
        Task<IEnumerable<UserGroup>> GetUserGroupsAsync(int userId);
        Task<IEnumerable<UserGroup>> GetPublicGroupsAsync();
        Task<UserGroup> UpdateGroupAsync(int groupId, UserGroup updatedGroup);
        Task DeleteGroupAsync(int groupId);
        Task<UserGroupMembership> AddMemberToGroupAsync(int groupId, int userId, Role role);
        Task RemoveMemberFromGroupAsync(int groupId, int userId);
        Task<bool> IsUserMemberOfGroupAsync(int groupId, int userId);
        Task<bool> IsUserGroupAdminAsync(int groupId, int userId);

        // New methods for group inventory management
        Task<IEnumerable<Item>> GetGroupInventoryAsync(int groupId);
        Task<ItemUserGroup> AddItemToGroupAsync(int groupId, int itemId);
        Task<IEnumerable<Item>> GetUserSharedItemsInGroupAsync(int groupId, int userId);
        Task RemoveItemFromGroupAsync(int groupId, int itemId);
    }
}
