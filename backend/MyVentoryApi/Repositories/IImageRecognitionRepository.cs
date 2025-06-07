using System.Text.Json;
using MyVentoryApi.DTOs;
using Google.Cloud.Vision.V1;

namespace MyVentoryApi.Repositories;

public interface IImageRecognitionRepository {

    ExtRequestResponseDto RandomResponse();
    JsonElement GetLabels(Image image);
}