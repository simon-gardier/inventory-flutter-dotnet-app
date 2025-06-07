using Microsoft.EntityFrameworkCore;
using MyVentoryApi.Models;
using MyVentoryApi.Data;

namespace MyVentoryApi.Repositories;

public class UserGroupRepositoryException : Exception
{
    public UserGroupRepositoryException() { }
    public UserGroupRepositoryException(string message) : base(message) { }
    public UserGroupRepositoryException(string message, Exception innerException) : base(message, innerException) { }
}

public class UserGroupRepository(MyVentoryDbContext context, ILogger<UserGroupRepository> logger) : IUserGroupRepository
{
    private readonly MyVentoryDbContext _context = context ?? throw new ArgumentNullException(nameof(context));
    private readonly ILogger<UserGroupRepository> _logger = logger ?? throw new ArgumentNullException(nameof(logger));

    public async Task<UserGroup> CreateGroupAsync(UserGroup group)
    {
        try
        {
            ArgumentNullException.ThrowIfNull(group);

            await _context.UserGroups.AddAsync(group);
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎 Group created successfully. ID: {GroupId}", group.GroupId);
            return group;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while creating group");
            throw new UserGroupRepositoryException(" An error occurred while creating the group", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while creating group");
            throw new UserGroupRepositoryException("Error while creating a group", ex);
        }
    }

    public async Task<UserGroup?> GetGroupByIdAsync(int groupId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);

            var group = await _context.UserGroups
                .Include(g => g.Members)
                    .ThenInclude(m => m.User)
                .FirstOrDefaultAsync(g => g.GroupId == groupId);

            if (group == null)
            {
                _logger.LogWarning("⚠️ Group with ID {GroupId} not found", groupId);
            }
            else
            {
                _logger.LogInformation("🔎 Retrieved group with ID: {GroupId}", groupId);
            }

            return group;
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid group ID provided: {GroupId}", groupId);
            throw new UserGroupRepositoryException($"An error occurred while retrieving group with ID {groupId}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving group with ID: {GroupId}", groupId);
            throw new UserGroupRepositoryException($"An error occurred while retrieving group with ID {groupId}", ex);
        }
    }

    public async Task<IEnumerable<UserGroup>> GetUserGroupsAsync(int userId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

            var groups = await _context.UserGroupMemberships
                .Where(m => m.UserId == userId)
                .Include(m => m.UserGroup)
                    .ThenInclude(g => g.Members)
                        .ThenInclude(m => m.User)
                .Select(m => m.UserGroup)
                .ToListAsync();

            _logger.LogInformation("🔎 Retrieved {Count} groups for user ID: {UserId}", groups.Count, userId);
            return groups;
        }
        catch (ArgumentOutOfRangeException ex)
        {
            _logger.LogWarning(ex, "Invalid user ID provided: {UserId}", userId);
            throw new UserGroupRepositoryException($"An error occurred while retrieving groups for user ID {userId}", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving groups for user ID: {UserId}", userId);
            throw new UserGroupRepositoryException($"An error occurred while retrieving groups for user ID {userId}", ex);
        }
    }

    public async Task<IEnumerable<UserGroup>> GetPublicGroupsAsync()
    {
        try
        {
            var groups = await _context.UserGroups
                .Where(g => g.Privacy == Privacy.Public)
                .Include(g => g.Members)
                    .ThenInclude(m => m.User)
                .ToListAsync();

            _logger.LogInformation("🔎 Retrieved {Count} public groups", groups.Count);
            return groups;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving public groups");
            throw new UserGroupRepositoryException("An error occurred while retrieving public groups", ex);
        }
    }

    public async Task<UserGroup> UpdateGroupAsync(int groupId, UserGroup updatedGroup)
    {
        try
        {
            ArgumentNullException.ThrowIfNull(updatedGroup);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);

            var existingGroup = await _context.UserGroups.FindAsync(groupId)
                ?? throw new KeyNotFoundException($"Group with ID {groupId} not found.");

            existingGroup.Name = updatedGroup.Name;
            existingGroup.Description = updatedGroup.Description;
            existingGroup.Privacy = updatedGroup.Privacy;
            existingGroup.GroupProfilePicture = updatedGroup.GroupProfilePicture;
            existingGroup.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎 Group updated successfully. ID: {GroupId}", groupId);
            return existingGroup;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "Group not found: {Message}", ex.Message);
            throw;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while updating group");
            throw new UserGroupRepositoryException(" An error occurred while updating the group", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while updating group");
            throw new UserGroupRepositoryException("Error while updating group", ex);
        }
    }

    public async Task DeleteGroupAsync(int groupId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);

            // First, delete all items shared in the group
            var sharedItems = await _context.ItemUserGroups
                .Where(iug => iug.GroupId == groupId)
                .ToListAsync();

            if (sharedItems.Any())
            {
                _context.ItemUserGroups.RemoveRange(sharedItems);
                await _context.SaveChangesAsync();
            }

            // Then, delete all memberships to avoid foreign key constraint issues
            var memberships = await _context.UserGroupMemberships
                .Where(m => m.GroupId == groupId)
                .ToListAsync();

            if (memberships.Any())
            {
                _context.UserGroupMemberships.RemoveRange(memberships);
                await _context.SaveChangesAsync();
            }

            // Finally, delete the group
            var group = await _context.UserGroups.FindAsync(groupId);
            if (group == null)
            {
                _logger.LogWarning("Group with ID {GroupId} not found for deletion", groupId);
                throw new KeyNotFoundException($"Group with ID {groupId} not found.");
            }

            _context.UserGroups.Remove(group);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Group {GroupId} and all its dependencies deleted successfully", groupId);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "Group not found for deletion: {Message}", ex.Message);
            throw;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while deleting group {GroupId}: {Message}", groupId, ex.Message);
            throw new UserGroupRepositoryException("An error occurred while deleting the group from the database", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while deleting group {GroupId}: {Message}", groupId, ex.Message);
            throw new UserGroupRepositoryException("An unexpected error occurred while deleting the group", ex);
        }
    }

    public async Task<UserGroupMembership> AddMemberToGroupAsync(int groupId, int userId, Role role)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

            var group = await _context.UserGroups.FindAsync(groupId)
                ?? throw new KeyNotFoundException($"Group with ID {groupId} not found.");

            var user = await _context.Users.FindAsync(userId)
                ?? throw new KeyNotFoundException($"User with ID {userId} not found.");

            var membership = new UserGroupMembership(user, group, role);
            await _context.UserGroupMemberships.AddAsync(membership);
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎 Member added to group successfully. Group ID: {GroupId}, User ID: {UserId}", groupId, userId);
            return membership;
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "Group or user not found: {Message}", ex.Message);
            throw;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while adding member to group");
            throw new UserGroupRepositoryException(" An error occurred while adding member to group", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while adding member to group");
            throw new UserGroupRepositoryException("Error while adding member to group", ex);
        }
    }

    public async Task RemoveMemberFromGroupAsync(int groupId, int userId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

            var membership = await _context.UserGroupMemberships
                .FirstOrDefaultAsync(m => m.GroupId == groupId && m.UserId == userId)
                ?? throw new KeyNotFoundException($"Membership not found for group ID {groupId} and user ID {userId}.");

            _context.UserGroupMemberships.Remove(membership);
            await _context.SaveChangesAsync();

            _logger.LogInformation("🔎 Member removed from group successfully. Group ID: {GroupId}, User ID: {UserId}", groupId, userId);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "Membership not found: {Message}", ex.Message);
            throw;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while removing member from group");
            throw new UserGroupRepositoryException(" An error occurred while removing member from group", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while removing member from group");
            throw new UserGroupRepositoryException("Error while removing member from group", ex);
        }
    }

    public async Task<bool> IsUserMemberOfGroupAsync(int groupId, int userId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

            var isMember = await _context.UserGroupMemberships
                .AnyAsync(m => m.GroupId == groupId && m.UserId == userId);

            _logger.LogInformation("🔎 User {UserId} is member of group {GroupId}: {IsMember}", userId, groupId, isMember);
            return isMember;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking user membership in group");
            throw new UserGroupRepositoryException("Error while checking user membership in group", ex);
        }
    }

    public async Task<bool> IsUserGroupAdminAsync(int groupId, int userId)
    {
        try
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(groupId);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(userId);

            var isAdmin = await _context.UserGroupMemberships
                .AnyAsync(m => m.GroupId == groupId && m.UserId == userId &&
                    (m.Role == Role.Founder || m.Role == Role.Administrator));

            _logger.LogInformation("🔎 User {UserId} is admin of group {GroupId}: {IsAdmin}", userId, groupId, isAdmin);
            return isAdmin;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking user admin status in group");
            throw new UserGroupRepositoryException("Error while checking user admin status in group", ex);
        }
    }

    public async Task<IEnumerable<Item>> GetGroupInventoryAsync(int groupId)
    {
        try
        {
            var group = await _context.UserGroups
                .Include(ug => ug.ItemSharedOnGroup)
                    .ThenInclude(iug => iug.Item)
                        .ThenInclude(i => i.Owner)
                .Include(ug => ug.ItemSharedOnGroup)
                    .ThenInclude(iug => iug.Item)
                        .ThenInclude(i => i.ItemLocations)
                            .ThenInclude(il => il.Location)
                .FirstOrDefaultAsync(ug => ug.GroupId == groupId);

            if (group == null)
            {
                throw new KeyNotFoundException($"Group with ID {groupId} not found");
            }

            var items = group.ItemSharedOnGroup.Select(iug => iug.Item).ToList();
            _logger.LogInformation("🔎  Retrieved {Count} items from group inventory for group ID: {GroupId}", items.Count, groupId);
            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving group inventory for group {GroupId}", groupId);
            throw;
        }
    }

    public async Task<ItemUserGroup> AddItemToGroupAsync(int groupId, int itemId)
    {
        try
        {
            var group = await _context.UserGroups
                .Include(ug => ug.ItemSharedOnGroup)
                .FirstOrDefaultAsync(ug => ug.GroupId == groupId);

            if (group == null)
            {
                throw new KeyNotFoundException($"Group with ID {groupId} not found");
            }

            var item = await _context.Items
                .Include(i => i.Owner)
                .FirstOrDefaultAsync(i => i.ItemId == itemId);

            if (item == null)
            {
                throw new KeyNotFoundException($"Item with ID {itemId} not found");
            }

            // Check if item is already in the group's inventory
            if (group.ItemSharedOnGroup.Any(iug => iug.ItemId == itemId))
            {
                throw new InvalidOperationException($"Item {itemId} is already in group {groupId}'s inventory");
            }

            var itemUserGroup = new ItemUserGroup(item, group);
            await _context.ItemUserGroups.AddAsync(itemUserGroup);
            await _context.SaveChangesAsync();

            _logger.LogInformation("✅  Added item {ItemId} to group {GroupId}", itemId, groupId);
            return itemUserGroup;
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while adding item {ItemId} to group {GroupId}", itemId, groupId);
            throw new InvalidOperationException("An error occurred while saving to the database", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding item {ItemId} to group {GroupId}", itemId, groupId);
            throw;
        }
    }

    public async Task<IEnumerable<Item>> GetUserSharedItemsInGroupAsync(int groupId, int userId)
    {
        try
        {
            var items = await _context.ItemUserGroups
                .Include(iug => iug.Item)
                    .ThenInclude(i => i.Owner)
                .Include(iug => iug.Item)
                    .ThenInclude(i => i.ItemLocations)
                        .ThenInclude(il => il.Location)
                .Where(iug => iug.GroupId == groupId && iug.Item.OwnerId == userId)
                .Select(iug => iug.Item)
                .ToListAsync();

            _logger.LogInformation("🔎  Retrieved {Count} items shared by user {UserId} in group {GroupId}", items.Count, userId, groupId);
            return items;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user's shared items in group {GroupId}", groupId);
            throw;
        }
    }

    public async Task RemoveItemFromGroupAsync(int groupId, int itemId)
    {
        try
        {
            var itemUserGroup = await _context.ItemUserGroups
                .Include(iug => iug.Item)
                    .ThenInclude(i => i.Owner)
                .FirstOrDefaultAsync(iug => iug.GroupId == groupId && iug.ItemId == itemId);

            if (itemUserGroup == null)
            {
                throw new KeyNotFoundException($"Item {itemId} not found in group {groupId}");
            }

            _context.ItemUserGroups.Remove(itemUserGroup);
            await _context.SaveChangesAsync();

            _logger.LogInformation("✅  Removed item {ItemId} from group {GroupId}", itemId, groupId);
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Database error while removing item {ItemId} from group {GroupId}", itemId, groupId);
            throw new InvalidOperationException("An error occurred while saving to the database", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing item {ItemId} from group {GroupId}", itemId, groupId);
            throw;
        }
    }
}