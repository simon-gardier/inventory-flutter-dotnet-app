using System.Text.Json;
using MyVentoryApi.DTOs;

namespace MyVentoryApi.Repositories;

public interface IAlbumSearchRepository
{

   Task<JsonElement> SearchAlbum(string query);
   ExtRequestResponseDto FormatAlbum(JsonElement album);

}