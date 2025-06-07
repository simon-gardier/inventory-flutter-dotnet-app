using MyVentoryApi.Models;
using Attribute = MyVentoryApi.Models.Attribute;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;


public interface IItemRepository
{
    Task<Item> CreateItemAsync(Item item);
    Task<ItemInfoDto> GetItemAsync(int itemId);
    Task UpdateItemAsync(int itemId, Item updatedItem);
    Task AddImagesToItemAsync(int itemId, IEnumerable<byte[]> images);
    Task<IEnumerable<ItemImage>> GetItemImagesAsync(int itemId);
    Task RemoveImagesFromItemAsync(int itemId, IEnumerable<int> imageIds);
    Task DeleteItemAsync(int itemId);
    Task<IEnumerable<(Attribute Attribute, string Value)>> GetItemAttributesAsync(int itemId);
    Task AddAttributesToItemAsync(int itemId, IEnumerable<(string Type, string Name, string Value)> attributes);
    Task RemoveAttributesFromItemAsync(int itemId, IEnumerable<int> attributeIds);
    Task<Item?> GetItemByIdAsync(int itemId);
}
