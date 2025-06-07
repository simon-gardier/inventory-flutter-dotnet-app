using MyVentoryApi.DTOs;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using System.Net;

namespace MyVentoryApi.Tests.Utilities;

public static class TestUtilities
{
    public const string TestUserName = "alexander";
    public const string TestFirstName = "Alexander";
    public const string TestLastName = "Smith";
    public const string TestPassword = "Alexander123!";
    public const string TestEmail = "alexander.smith@example.com";

    public const string TestUserName2 = "emily";
    public const string TestFirstName2 = "Emily";
    public const string TestLastName2 = "Johnson";
    public const string TestPassword2 = "Emily123!";
    public const string TestEmail2 = "emily.johnson@example.com";

    public const string TestUserName3 = "michael";
    public const string TestFirstName3 = "Michael";
    public const string TestLastName3 = "Williams";
    public const string TestPassword3 = "Michael123!";
    public const string TestEmail3 = "michael.williams@example.com";

    public static JsonSerializerOptions jsonOptions = new() { PropertyNameCaseInsensitive = true };
    public static async Task<(string Token, int UserId)> GetAuthTokenAsync(string usernameOrEmail, string password, HttpClient client, JsonSerializerOptions jsonOptions)
    {
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = usernameOrEmail,
            Password = password
        };

        var response = await client.PostAsJsonAsync("/api/users/login", loginRequest);

        if (!response.IsSuccessStatusCode)
        {
            return (string.Empty, 0);
        }

        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<UsersLoginResponseDto>(content, jsonOptions);

        return (result?.Token ?? string.Empty, result?.UserId ?? 0);
    }

    public static void AddAuthHeader(HttpClient client, string token)
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    public static async Task ConfirmUserEmailAsync(string username, ApiFixture fixture)
    {
        // Get UserManager directly
        var userManager = ApiFixture.GetUserManager();
        // Find the user
        var user = await userManager.FindByNameAsync(username) ?? throw new Exception($"User {username} not found");
        // Mark the email as confirmed
        user.EmailConfirmed = true;

        // Update the user in the database
        var result = await userManager.UpdateAsync(user);

        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            throw new Exception($"Failed to confirm email for user {username}: {errors}");
        }
    }

    public static async Task<(string UserName, string Password, int UserId)> CreateTestUser(HttpClient client)
    {
        var faker = new Bogus.Faker();
        var randomUserName = faker.Internet.UserName();
        var randomFirstName = faker.Name.FirstName();
        var randomLastName = faker.Name.LastName();
        var randomEmail = faker.Internet.Email();
        var randomPassword = faker.Internet.Password();

        var formData = new MultipartFormDataContent
        {
            { new StringContent(randomUserName), "UserName" },
            { new StringContent(randomFirstName), "FirstName" },
            { new StringContent(randomLastName), "LastName" },
            { new StringContent(randomEmail), "Email" },
            { new StringContent(randomPassword), "Password" }
        };
        var response = await client.PostAsync("/api/users", formData);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<UsersCreationResponseDto>(content, jsonOptions);
        if (result == null)
        {
            throw new Exception("Failed to create test user. Response content is null.");
        }
        return (randomUserName, randomPassword, result.UserId);
    }

    public static async Task<string> GetAdminAuthTokenAsync(HttpClient client)
    {
        var adminEmail = "admin.user@example.com";
        var adminPassword = "Admin123!";

        var (token, _) = await GetAuthTokenAsync(adminEmail, adminPassword, client, jsonOptions);

        if (!string.IsNullOrEmpty(token))
        {
            return token;
        }

        throw new InvalidOperationException("Failed to retrieve admin token. Ensure the admin user exists and credentials are correct.");
    }

    public static async Task<User> GetUserByEmailAsync(string email, ApiFixture fixture)
    {
        var userManager = ApiFixture.GetUserManager();
        var dbContext = ApiFixture.GetDbContext();

        var user = await userManager.FindByEmailAsync(email) ?? throw new Exception($"User with email {email} not found");

        await dbContext.Entry(user).ReloadAsync();

        return user;
    }

    public static async Task<HttpClient> CreateConnectionAsync(ApiFixture fixture, string user, string password)
    {
        var client = fixture.CreateClient();
        var (token, _) = await TestUtilities.GetAuthTokenAsync(user, password, client, TestUtilities.jsonOptions);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }
}
