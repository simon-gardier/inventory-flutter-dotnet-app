using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using MyVentoryApi.Repositories;
using Microsoft.AspNetCore.Mvc.Testing;
using MyVentoryApi.DTOs;
using System.Text.Json;
using FluentAssertions;

namespace MyVentoryApi.Tests;

using MyVentoryApi.Models;
using MyVentoryApi.Tests.Utilities;

[Collection("ApiFixtureTests")]
public class UserApiTests(ApiFixture fixture) : IClassFixture<ApiFixture>
{
    private readonly JsonSerializerOptions _jsonOptions = TestUtilities.jsonOptions;
    private readonly ApiFixture ApiFixture = fixture;
    /// <summary>
    /// This region contains tests for the user creation functionality of the API.
    /// It includes tests for:
    /// - Basic valid user creation with all required fields.
    /// - User creation with an additional profile picture (with a valid image and an image not valid).
    /// - Handling of missing required fields during user creation.
    /// - Ensuring unique constraint on usernames to prevent duplicates.
    /// - Validation of email format during user creation.
    /// </summary>

    #region Create User Tests

    [Fact]
    public async Task CreateUser_WithValidData_ReturnsCreatedAndUserInfo()
    {
        // Arrange
        var userRequest = new UserCreationRequestDto
        {
            UserName = "testuser1",
            FirstName = "John",
            LastName = "Doe",
            Email = "john.doe@example.com",
            Password = "Password123!"
        };
        var formData = new MultipartFormDataContent
        {
            { new StringContent(userRequest.UserName), "UserName" },
            { new StringContent(userRequest.FirstName), "FirstName" },
            { new StringContent(userRequest.LastName), "LastName" },
            { new StringContent(userRequest.Email), "Email" },
            { new StringContent(userRequest.Password), "Password" }
        };

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsync("/api/users", formData);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<UsersCreationResponseDto>(content, _jsonOptions);


        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(result);
        Assert.Equal(userRequest.UserName, result.UserName);
        Assert.Equal(userRequest.FirstName, result.FirstName);
        Assert.Equal(userRequest.Email, result.Email);
        Assert.NotEqual(default, result.CreatedAt);
        Assert.Contains($"/api/users/{result.UserId}", response.Headers.Location!.ToString());
    }

    [Fact]
    public async Task CreateUser_WithProfilePicture_ReturnsCreated()
    {
        // Arrange
        var userRequest = new UserCreationRequestDto
        {
            UserName = "testuser2",
            FirstName = "Jane",
            LastName = "Smith",
            Email = "jane.smith@example.com",
            Password = "Password123!"
        };
        var formData = new MultipartFormDataContent
        {
            { new StringContent(userRequest.UserName), "UserName" },
            { new StringContent(userRequest.FirstName), "FirstName" },
            { new StringContent(userRequest.LastName), "LastName" },
            { new StringContent(userRequest.Email), "Email" },
            { new StringContent(userRequest.Password), "Password" }
        };

        // Add a real image file from the current directory
        var imageDir = AppContext.BaseDirectory;
        var imagePath = Path.Combine(imageDir, "Images", "clearText.jpg");

        var imageContent = new ByteArrayContent(await File.ReadAllBytesAsync(imagePath));
        imageContent.Headers.ContentType = MediaTypeHeaderValue.Parse("image/jpeg");
        formData.Add(imageContent, "Image", "test_profile.jpg");

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsync("/api/users", formData);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<UsersCreationResponseDto>(content, _jsonOptions);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(result);
        Assert.Equal(userRequest.UserName, result.UserName);
        Assert.NotEqual(default, result.CreatedAt);
    }

    [Fact]
    public async Task CreateUser_WithInvalidImage_ReturnsBadRequest()
    {
        // Arrange
        var userRequest = new UserCreationRequestDto
        {
            UserName = "badimageuser",
            FirstName = "Bad",
            LastName = "Image",
            Email = "badimage@example.com",
            Password = "Password123!"
        };
        var formData = new MultipartFormDataContent
        {
            { new StringContent(userRequest.UserName), "UserName" },
            { new StringContent(userRequest.FirstName), "FirstName" },
            { new StringContent(userRequest.LastName), "LastName" },
            { new StringContent(userRequest.Email), "Email" },
            { new StringContent(userRequest.Password), "Password" }
        };

        // Add an invalid "image" file (text file with image extension)
        byte[] invalidImageData = Encoding.UTF8.GetBytes("This is not a valid image file");
        var imageContent = new ByteArrayContent(invalidImageData);
        imageContent.Headers.ContentType = MediaTypeHeaderValue.Parse("image/jpeg");
        formData.Add(imageContent, "Image", "invalid.jpg");

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsync("/api/users", formData);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateUser_WithMissingRequiredField_ReturnsBadRequest()
    {
        // Arrange - Missing FirstName
        var formData = new MultipartFormDataContent
        {
            { new StringContent("testuser3"), "UserName" },
            // FirstName is missing
            { new StringContent("Johnson"), "LastName" },
            { new StringContent("test@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsync("/api/users", formData);
        var content = await response.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("The following fields are required", content, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CreateUser_WithDuplicateUsername_ReturnsBadRequest()
    {
        // Arrange
        // First create a user
        var user1 = new UserCreationRequestDto
        {
            UserName = "duplicateuser",
            FirstName = "Duplicate",
            LastName = "User",
            Email = "duplicate@example.com",
            Password = "Password123!"
        };
        var formData1 = new MultipartFormDataContent
        {
            { new StringContent(user1.UserName), "UserName" },
            { new StringContent(user1.FirstName), "FirstName" },
            { new StringContent(user1.LastName), "LastName" },
            { new StringContent(user1.Email), "Email" },
            { new StringContent(user1.Password), "Password" }
        };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData1);

        // Try to create another user with the same username
        var user2 = new UserCreationRequestDto
        {
            UserName = "duplicateuser",
            FirstName = "Another",
            LastName = "Person",
            Email = "another@example.com",
            Password = "Password123!"
        };
        var formData2 = new MultipartFormDataContent
        {
            { new StringContent(user2.UserName), "UserName" },
            { new StringContent(user2.FirstName), "FirstName" },
            { new StringContent(user2.LastName), "LastName" },
            { new StringContent(user2.Email), "Email" },
            { new StringContent(user2.Password), "Password" }
        };

        // Act
        var response = await client.PostAsync("/api/users", formData2);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateUser_WithInvalidEmail_ReturnsBadRequest()
    {
        // Arrange
        var userRequest = new UserCreationRequestDto
        {
            UserName = "badEmailUser",
            FirstName = "Bad",
            LastName = "Email",
            Email = "not-an-email",
            Password = "Password123!"
        };

        var formData = new MultipartFormDataContent
        {
            { new StringContent(userRequest.UserName), "UserName" },
            { new StringContent(userRequest.FirstName), "FirstName" },
            { new StringContent(userRequest.LastName), "LastName" },
            { new StringContent(userRequest.Email), "Email" },
            { new StringContent(userRequest.Password), "Password" }
        };

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsync("/api/users", formData);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    #endregion

    #region Login User Tests

    [Fact]
    public async Task LoginUser_WithValidCredentials_ReturnsOkAndToken()
    {
        // Arrange - First create a user
        var username = "logintest";
        var email = "login@example.com";
        var password = "Password123!";

        var formData = new MultipartFormDataContent
        {
            { new StringContent(username), "UserName" },
            { new StringContent("Login"), "FirstName" },
            { new StringContent("Test"), "LastName" },
            { new StringContent(email), "Email" },
            { new StringContent(password), "Password" }
        };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        await TestUtilities.ConfirmUserEmailAsync("logintest", ApiFixture);

        // Try to login with username
        var loginRequest1 = new UsersLoginRequestDto
        {
            UsernameOrEmail = username,
            Password = password
        };

        // Act
        var response1 = await client.PostAsJsonAsync("/api/users/login", loginRequest1);
        var content1 = await response1.Content.ReadAsStringAsync();
        var result1 = JsonSerializer.Deserialize<UsersLoginResponseDto>(content1, _jsonOptions);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response1.StatusCode);
        Assert.NotNull(result1);
        Assert.Equal(username, result1.Username);
        Assert.NotNull(result1.Token);
        Assert.NotEmpty(result1.Token);
        Assert.NotEqual(0, result1.UserId);
        Assert.Equal("Login", result1.FirstName);
        Assert.Equal("Test", result1.LastName);
        Assert.Equal(email, result1.Email);
        Assert.NotEqual(default, result1.CreatedAt);
        Assert.NotEqual(default, result1.UpdatedAt);

        // Try to login with email
        var loginRequest2 = new UsersLoginRequestDto
        {
            UsernameOrEmail = email,
            Password = password
        };

        // Act
        var response2 = await client.PostAsJsonAsync("/api/users/login", loginRequest2);
        var content2 = await response2.Content.ReadAsStringAsync();
        var result2 = JsonSerializer.Deserialize<UsersLoginResponseDto>(content2, _jsonOptions);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response2.StatusCode);
        Assert.NotNull(result2);
        Assert.NotNull(result2.Token);
        Assert.NotEmpty(result2.Token);
    }

    [Fact]
    public async Task LoginUser_WithValidCredentials_TokenWorksForAuthenticatedEndpoints()
    {
        // Arrange - First create a user
        var username = "tokentest";
        var email = "token@example.com";
        var password = "Password123!";

        var formData = new MultipartFormDataContent
        {
            { new StringContent(username), "UserName" },
            { new StringContent("Token"), "FirstName" },
            { new StringContent("Test"), "LastName" },
            { new StringContent(email), "Email" },
            { new StringContent(password), "Password" }
        };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        await TestUtilities.ConfirmUserEmailAsync("tokentest", ApiFixture);

        // Login to get token
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = username,
            Password = password
        };

        var response = await client.PostAsJsonAsync("/api/users/login", loginRequest);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<UsersLoginResponseDto>(content, _jsonOptions);

        // Extract token and userId
        var token = result!.Token;
        var userId = result.UserId;

        // Act - Try to access a protected endpoint (update user)
        // Create a simple update request
        var updateData = new MultipartFormDataContent
        {
            { new StringContent("Updated FirstName"), "FirstName" }
        };

        // Set the authorization header
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Send the request
        var protectedResponse = await client.PutAsync($"/api/users/{userId}", updateData);

        // Assert
        Assert.Equal(HttpStatusCode.OK, protectedResponse.StatusCode);

        // Clean up
        client.DefaultRequestHeaders.Authorization = null;
    }

    [Fact]
    public async Task LoginUser_WithInvalidPassword_ReturnsUnauthorized()
    {
        // Arrange - First create a user
        var username = "wrongpasstest";
        var password = "CorrectPassword123!";

        var formData = new MultipartFormDataContent
        {
            { new StringContent(username), "UserName" },
            { new StringContent("Wrong"), "FirstName" },
            { new StringContent("Password"), "LastName" },
            { new StringContent("wrong@example.com"), "Email" },
            { new StringContent(password), "Password" }
        };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        await TestUtilities.ConfirmUserEmailAsync("wrongpasstest", ApiFixture);

        // Try to login with wrong password
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = username,
            Password = "WrongPassword123!"
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/users/login", loginRequest);

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LoginUser_WithNonexistentUser_ReturnsUnauthorized()
    {
        // Arrange
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = "nonexistentuser",
            Password = "Password123!"
        };

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsJsonAsync("/api/users/login", loginRequest);

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LoginUser_WithMissingCredentials_ReturnsBadRequest()
    {
        // Arrange - Missing password
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = "someuser",
            Password = ""
        };

        // Act
        var client = ApiFixture.CreateClient();
        var response = await client.PostAsJsonAsync("/api/users/login", loginRequest);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        // Arrange - Missing username/email
        loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = "",
            Password = "somepassword"
        };

        // Act
        response = await client.PostAsJsonAsync("/api/users/login", loginRequest);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    #endregion

    #region Update User Tests

    [Fact]
    public async Task UpdateUser_WithValidData_ReturnsOk()
    {
        // Arrange - First create a user
        var formData = new MultipartFormDataContent
    {
        { new StringContent("updatetest"), "UserName" },
        { new StringContent("Update"), "FirstName" },
        { new StringContent("Test"), "LastName" },
        { new StringContent("update@example.com"), "Email" },
        { new StringContent("Password123!"), "Password" }
    };

        // Create user and capture token from response
        var client = ApiFixture.CreateClient();
        var createResponse = await client.PostAsync("/api/users", formData);
        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createResult = JsonSerializer.Deserialize<UsersCreationResponseDto>(createContent, _jsonOptions);
        var userId = createResult!.UserId;

        await TestUtilities.ConfirmUserEmailAsync("updatetest", ApiFixture);

        // Login to get token
        var (token, _) = await TestUtilities.GetAuthTokenAsync("updatetest", "Password123!", client, _jsonOptions);

        // Prepare update data
        var updateFormData = new MultipartFormDataContent
    {
        { new StringContent("updatetestnew"), "UserName" },
        { new StringContent("UpdatedFirst"), "FirstName" },
        { new StringContent("UpdatedLast"), "LastName" },
        { new StringContent("updated@example.com"), "Email" },
    };

        // Set authorization header with JWT token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var updateResponse = await client.PutAsync($"/api/users/{userId}", updateFormData);

        // Assert
        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

        // Parse response and verify updates
        var updateContent = await updateResponse.Content.ReadAsStringAsync();
        var updateResult = JsonSerializer.Deserialize<UsersLoginResponseDto>(updateContent, _jsonOptions);

        Assert.NotNull(updateResult);
        Assert.Equal("UpdatedFirst", updateResult.FirstName);
        Assert.Equal("UpdatedLast", updateResult.LastName);
        Assert.Equal("updated@example.com", updateResult.Email);
        Assert.NotNull(updateResult.Token);
        Assert.NotEmpty(updateResult.Token);

        // Verify the update by logging in with the new credentials
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = "updatetestnew",
            Password = "Password123!"
        };

        var loginResponse = await client.PostAsJsonAsync("/api/users/login", loginRequest);
        var loginContent = await loginResponse.Content.ReadAsStringAsync();
        var loginResult = JsonSerializer.Deserialize<UsersLoginResponseDto>(loginContent, _jsonOptions);

        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
        Assert.Equal("UpdatedFirst", loginResult!.FirstName);
        Assert.Equal("UpdatedLast", loginResult.LastName);
        Assert.Equal("updated@example.com", loginResult.Email);

        // Clean up - remove authorization header
        client.DefaultRequestHeaders.Authorization = null;
    }

    [Fact]
    public async Task UpdateUser_WithNonexistentUserId_ReturnsForbidden()
    {
        // Arrange - First create a user to get a valid token
        var formData = new MultipartFormDataContent
        {
            { new StringContent("existinguser"), "UserName" },
            { new StringContent("Existing"), "FirstName" },
            { new StringContent("User"), "LastName" },
            { new StringContent("existing@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var client = ApiFixture.CreateClient();
        var createResponse = await client.PostAsync("/api/users", formData);
        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createResult = JsonSerializer.Deserialize<UsersCreationResponseDto>(createContent, _jsonOptions);

        await TestUtilities.ConfirmUserEmailAsync("existinguser", ApiFixture);
        var (token, _) = await TestUtilities.GetAuthTokenAsync("existinguser", "Password123!", client, _jsonOptions);

        // Set authorization header with JWT token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Prepare nonexistent ID and update data
        var nonExistentUserId = 99999;
        var updateFormData = new MultipartFormDataContent
        {
            { new StringContent("nonexistent"), "UserName" },
            { new StringContent("Non"), "FirstName" },
            { new StringContent("Existent"), "LastName" },
            { new StringContent("nonexistent@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        // Act
        var response = await client.PutAsync($"/api/users/{nonExistentUserId}", updateFormData);

        // Assert
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        // Clean up
        client.DefaultRequestHeaders.Authorization = null;
    }

    [Fact]
    public async Task UpdateUser_WithInvalidData_ReturnsBadRequest()
    {
        // Arrange - First create a user
        var formData = new MultipartFormDataContent
        {
            { new StringContent("badupdatetest"), "UserName" },
            { new StringContent("Bad"), "FirstName" },
            { new StringContent("Update"), "LastName" },
            { new StringContent("badupdate@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var client = ApiFixture.CreateClient();
        var createResponse = await client.PostAsync("/api/users", formData);
        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createResult = JsonSerializer.Deserialize<UsersCreationResponseDto>(createContent, _jsonOptions);
        var userId = createResult!.UserId;

        await TestUtilities.ConfirmUserEmailAsync("badupdatetest", ApiFixture);
        var (token, _) = await TestUtilities.GetAuthTokenAsync("badupdatetest", "Password123!", client, _jsonOptions);


        // Set authorization header with JWT token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Prepare update data with missing required field
        var updateFormData = new MultipartFormDataContent
        {
            { new StringContent("badupdatetest"), "UserName" },
            { new StringContent("trytoreach"), "FirstName" },
            { new StringContent("UpdatedLast"), "LastName" },
            { new StringContent("badupdate.example.com"), "Email" }, // mail adress should contain an @
            { new StringContent("NewPassword123!"), "Password" }
        };

        // Act
        var response = await client.PutAsync($"/api/users/{userId}", updateFormData);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        // Clean up
        client.DefaultRequestHeaders.Authorization = null;
    }

    [Fact]
    public async Task UpdateUser_WithDuplicateEmail_ReturnsBadRequest()
    {
        // Arrange - Create first user
        var formData1 = new MultipartFormDataContent
        {
            { new StringContent("emailuser1"), "UserName" },
            { new StringContent("Email"), "FirstName" },
            { new StringContent("User1"), "LastName" },
            { new StringContent("emailuser1@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };
        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData1);
        await TestUtilities.ConfirmUserEmailAsync("emailuser1", ApiFixture);

        // Create second user
        var formData2 = new MultipartFormDataContent
        {
            { new StringContent("emailuser2"), "UserName" },
            { new StringContent("Email"), "FirstName" },
            { new StringContent("User2"), "LastName" },
            { new StringContent("emailuser2@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };
        client = ApiFixture.CreateClient();
        var createResponse2 = await client.PostAsync("/api/users", formData2);
        var createContent2 = await createResponse2.Content.ReadAsStringAsync();
        var createResult2 = JsonSerializer.Deserialize<UsersCreationResponseDto>(createContent2, _jsonOptions);
        var userId2 = createResult2!.UserId;
        await TestUtilities.ConfirmUserEmailAsync("emailuser2", ApiFixture);
        var (token2, _) = await TestUtilities.GetAuthTokenAsync("emailuser2", "Password123!", client, _jsonOptions);
        // Set authorization header with JWT token of the second user
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token2);

        // Try to update second user with first user's email
        var updateFormData = new MultipartFormDataContent
        {
            { new StringContent("emailuser2"), "UserName" },
            { new StringContent("Updated"), "FirstName" },
            { new StringContent("User2"), "LastName" },
            { new StringContent("emailuser1@example.com"), "Email" }, // Duplicate email
            { new StringContent("Password123!"), "Password" }
        };

        // Act
        var response = await client.PutAsync($"/api/users/{userId2}", updateFormData);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task UpdateUser_WithoutAuthorization_ReturnsUnauthorized()
    {
        // Arrange - No authorization header
        var client = ApiFixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = null;

        var userId = 1; // Any user ID
        var updateFormData = new MultipartFormDataContent
        {
            { new StringContent("someuser"), "UserName" },
            { new StringContent("Some"), "FirstName" },
            { new StringContent("User"), "LastName" },
            { new StringContent("some@example.com"), "Email" }
        };

        // Act
        var response = await client.PutAsync($"/api/users/{userId}", updateFormData);

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UpdateUser_WithWrongUser_ReturnsForbidden()
    {
        // Arrange - Create two users
        var formData1 = new MultipartFormDataContent
        {
            { new StringContent("authuser1"), "UserName" },
            { new StringContent("Auth"), "FirstName" },
            { new StringContent("User1"), "LastName" },
            { new StringContent("auth1@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var client = ApiFixture.CreateClient();
        var createResponse1 = await client.PostAsync("/api/users", formData1);
        var createResult1 = JsonSerializer.Deserialize<UsersCreationResponseDto>(
            await createResponse1.Content.ReadAsStringAsync(), _jsonOptions);

        await TestUtilities.ConfirmUserEmailAsync("authuser1", ApiFixture);
        var (token1, _) = await TestUtilities.GetAuthTokenAsync("authuser1", "Password123!", client, _jsonOptions);


        // Create second user
        var formData2 = new MultipartFormDataContent
        {
            { new StringContent("authuser2"), "UserName" },
            { new StringContent("Auth"), "FirstName" },
            { new StringContent("User2"), "LastName" },
            { new StringContent("auth2@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var createResponse2 = await client.PostAsync("/api/users", formData2);
        var createResult2 = JsonSerializer.Deserialize<UsersCreationResponseDto>(
            await createResponse2.Content.ReadAsStringAsync(), _jsonOptions);
        var userId2 = createResult2!.UserId;

        await TestUtilities.ConfirmUserEmailAsync("authuser2", ApiFixture);

        // Set authorization header with JWT token of the first user
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token1);

        // Try to update second user with first user's token
        var updateFormData = new MultipartFormDataContent
        {
            { new StringContent("authuser2"), "UserName" },
            { new StringContent("Hacked"), "FirstName" },
            { new StringContent("User2"), "LastName" },
            { new StringContent("auth2@example.com"), "Email" }
        };

        // Act
        var response = await client.PutAsync($"/api/users/{userId2}", updateFormData);

        // Assert - Regular user can't update another user's profile
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        // Clean up
        client.DefaultRequestHeaders.Authorization = null;
    }

    #endregion

    #region Delete User Tests

    [Fact]
    public async Task DeleteUser_WithValidId_ReturnsNoContent()
    {
        // Arrange - First create a user
        var formData = new MultipartFormDataContent
        {
            { new StringContent("deletetest"), "UserName" },
            { new StringContent("Delete"), "FirstName" },
            { new StringContent("Test"), "LastName" },
            { new StringContent("delete@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        // Create user and get the token for authorization
        var client = ApiFixture.CreateClient();
        var createResponse = await client.PostAsync("/api/users", formData);
        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createResult = JsonSerializer.Deserialize<UsersCreationResponseDto>(createContent, _jsonOptions);
        var userId = createResult!.UserId;

        await TestUtilities.ConfirmUserEmailAsync("deletetest", ApiFixture);

        var (token, _) = await TestUtilities.GetAuthTokenAsync("deletetest", "Password123!", client, _jsonOptions);

        // Set authorization header with the token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.DeleteAsync($"/api/users/{userId}");

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        // Verify the user is deleted by trying to login
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = "deletetest",
            Password = "Password123!"
        };

        // Clear the authorization header before trying to login
        client.DefaultRequestHeaders.Authorization = null;

        var loginResponse = await client.PostAsJsonAsync("/api/users/login", loginRequest);

        Assert.Equal(HttpStatusCode.Unauthorized, loginResponse.StatusCode);
    }

    [Fact]
    public async Task DeleteUser_WithoutAuthorization_ReturnsUnauthorized()
    {
        // Arrange - Create a user but don't set the authorization token
        var formData = new MultipartFormDataContent
        {
            { new StringContent("deleteauthtest"), "UserName" },
            { new StringContent("Delete"), "FirstName" },
            { new StringContent("Auth"), "LastName" },
            { new StringContent("deleteauth@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var client = ApiFixture.CreateClient();
        var createResponse = await client.PostAsync("/api/users", formData);
        var createContent = await createResponse.Content.ReadAsStringAsync();
        var createResult = JsonSerializer.Deserialize<UsersCreationResponseDto>(createContent, _jsonOptions);
        var userId = createResult!.UserId;

        await TestUtilities.ConfirmUserEmailAsync("deleteauthtest", ApiFixture);

        // Clear any authorization header
        client.DefaultRequestHeaders.Authorization = null;

        // Act - Try to delete without authentication
        var response = await client.DeleteAsync($"/api/users/{userId}");

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DeleteUser_WithWrongUser_ReturnsForbidden()
    {
        // Arrange - Create two users
        var formData1 = new MultipartFormDataContent
        {
            { new StringContent("deleteuser1"), "UserName" },
            { new StringContent("Delete"), "FirstName" },
            { new StringContent("User1"), "LastName" },
            { new StringContent("deleteuser1@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var client = ApiFixture.CreateClient();
        var createResponse1 = await client.PostAsync("/api/users", formData1);
        var createResult1 = JsonSerializer.Deserialize<UsersCreationResponseDto>(
            await createResponse1.Content.ReadAsStringAsync(), _jsonOptions);


        await TestUtilities.ConfirmUserEmailAsync("deleteuser1", ApiFixture);

        var (token1, _) = await TestUtilities.GetAuthTokenAsync("deleteuser1", "Password123!", client, _jsonOptions);

        // Create second user
        var formData2 = new MultipartFormDataContent
        {
            { new StringContent("deleteuser2"), "UserName" },
            { new StringContent("Delete"), "FirstName" },
            { new StringContent("User2"), "LastName" },
            { new StringContent("deleteuser2@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var createResponse2 = await client.PostAsync("/api/users", formData2);
        var createResult2 = JsonSerializer.Deserialize<UsersCreationResponseDto>(
            await createResponse2.Content.ReadAsStringAsync(), _jsonOptions);
        var userId2 = createResult2!.UserId;

        await TestUtilities.ConfirmUserEmailAsync("deleteuser2", ApiFixture);

        // Set authorization header with JWT token of the first user
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token1);

        // Act - Try to delete second user with first user's token
        var response = await client.DeleteAsync($"/api/users/{userId2}");

        // Assert - Regular user can't delete another user's profile
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task DeleteUser_WithNonexistentId_ReturnsNotFound()
    {
        // Arrange - First create a user to get a valid token
        var formData = new MultipartFormDataContent
        {
            { new StringContent("deletenonexist"), "UserName" },
            { new StringContent("Delete"), "FirstName" },
            { new StringContent("NonExist"), "LastName" },
            { new StringContent("deletenonexist@example.com"), "Email" },
            { new StringContent("Password123!"), "Password" }
        };

        var client = ApiFixture.CreateClient();
        var createResponse = await client.PostAsync("/api/users", formData);
        var createContent = await createResponse.Content.ReadAsStringAsync();

        var (token, _) = await TestUtilities.GetAuthTokenAsync("deletenonexist", "Password123!", client, _jsonOptions);

        await TestUtilities.ConfirmUserEmailAsync("deletenonexist", ApiFixture);

        // Set authorization header with JWT token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act - Try to delete a non-existent user
        var nonExistentUserId = 99999;
        var response = await client.DeleteAsync($"/api/users/{nonExistentUserId}");

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    #region Search User Items By Name Tests
    [Fact]
    public async Task GetItemsByNameByUser_WithValidUserIdAndName_ReturnsOkAndItems()
    {
        int userId = 1;
        string name = "a";

        var client = ApiFixture.CreateClient();
        var (token, _) = await TestUtilities.GetAuthTokenAsync("alexander.smith@example.com", "Alexander123!", client, _jsonOptions);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var response = await client.GetAsync($"/api/users/{userId}/items/searchByName?name={name}");
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<List<ItemInfoDto>>(content, _jsonOptions);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(result);
        Assert.True(result.Any());
        Assert.All(result, item => Assert.Contains(name, item.Name));

        client.DefaultRequestHeaders.Authorization = null;

        Assert.True(true);
    }

    [Fact]
    public async Task GetItemsByNameByUser_WithNoMatchingItems_ReturnsNotFound()
    {
        int userId = 1;
        string name = "nonexistentitem";

        var client = ApiFixture.CreateClient();
        var (token, _) = await TestUtilities.GetAuthTokenAsync("alexander.smith@example.com", "Alexander123!", client, _jsonOptions);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var response = await client.GetAsync($"/api/users/{userId}/items/searchByName?name={name}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetItemsByNameByUser_WithInvalidUserId_ReturnsUnautorized()
    {
        int userId = 999;
        string name = "item";

        var client = ApiFixture.CreateClient();
        var (token, _) = await TestUtilities.GetAuthTokenAsync("alexander.smith@example.com", "Alexander123!", client, _jsonOptions);
        var response = await client.GetAsync($"/api/users/{userId}/items/searchByName?name={name}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.True(true);
    }
    #endregion

    #region Filter User Items Tests
    [Fact]
    public async Task GetItemsFilteredByUser_WithNameFilter_ReturnsOkAndMatchingItems()
    {
        int userId = 1;
        var filter = new InventorySearchFiltersDto { Name = "Tablet" };

        var client = ApiFixture.CreateClient();
        var (token, _) = await TestUtilities.GetAuthTokenAsync("alexander.smith@example.com", "Alexander123!", client, _jsonOptions);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var response = await client.PostAsJsonAsync($"/api/users/{userId}/items/filter", filter);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<List<ItemInfoDto>>(content, _jsonOptions);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(result);
        Assert.Single(result);
        Assert.Equal("Tablet", result[0].Name);
        Assert.True(true);
    }

    [Fact]
    public async Task GetItemsFilteredByUser_WithBrandFilter_ReturnsOkAndMatchingItems()
    {
        int userId = 1;
        var filter = new InventorySearchFiltersDto { AttributeName = "Brand" };

        var client = ApiFixture.CreateClient();
        var (token, _) = await TestUtilities.GetAuthTokenAsync("alexander.smith@example.com", "Alexander123!", client, _jsonOptions);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var response = await client.PostAsJsonAsync($"/api/users/{userId}/items/filter", filter);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<List<ItemInfoDto>>(content, _jsonOptions);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(result);
        Assert.Equal("Projector", result[0].Name);
        Assert.True(true);
    }
    #endregion

    #region User Lockout Tests

    [Fact]
    public async Task LoginUser_WithMultipleFailedAttempts_LocksAccount()
    {
        var numberOfFailedAttempts = 3;
        // Create a user
        var username = "lockouttest";
        var email = "lockout@example.com";
        var password = "CorrectPassword123!";

        var formData = new MultipartFormDataContent
    {
        { new StringContent(username), "UserName" },
        { new StringContent("Lockout"), "FirstName" },
        { new StringContent("Test"), "LastName" },
        { new StringContent(email), "Email" },
        { new StringContent(password), "Password" }
    };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        await TestUtilities.ConfirmUserEmailAsync(username, ApiFixture);

        // Attempt to log in with the wrong password multiple times
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = username,
            Password = "WrongPassword123!"
        };

        for (int i = 0; i < numberOfFailedAttempts; i++)
        {
            var response = await client.PostAsJsonAsync("/api/users/login", loginRequest);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }

        // Attempt to log in again after lockout
        var lockedOutResponse = await client.PostAsJsonAsync("/api/users/login", loginRequest);
        var lockedOutContent = await lockedOutResponse.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, lockedOutResponse.StatusCode);
        Assert.Contains("Account is locked", lockedOutContent, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Admin_UnlocksLockedAccount_Successfully()
    {
        var numberOfFailedAttempts = 3;
        // Create a user and lock the account
        var username = "unlocktest";
        var email = "unlock@example.com";
        var password = "CorrectPassword123!";

        var formData = new MultipartFormDataContent
    {
        { new StringContent(username), "UserName" },
        { new StringContent("Unlock"), "FirstName" },
        { new StringContent("Test"), "LastName" },
        { new StringContent(email), "Email" },
        { new StringContent(password), "Password" }
    };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        await TestUtilities.ConfirmUserEmailAsync(username, ApiFixture);

        // Lock the account by exceeding failed login attempts
        var loginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = username,
            Password = "WrongPassword123!"
        };

        for (int i = 0; i < numberOfFailedAttempts; i++)
        {
            await client.PostAsJsonAsync("/api/users/login", loginRequest);
        }

        // Verify the account is locked
        var lockedOutResponse = await client.PostAsJsonAsync("/api/users/login", loginRequest);
        Assert.Equal(HttpStatusCode.Unauthorized, lockedOutResponse.StatusCode);

        //  Unlock the account as an admin
        var adminToken = await TestUtilities.GetAdminAuthTokenAsync(client); // Utility to get admin token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);

        var unlockRequest = new UnlockAccountRequestDto
        {
            Email = email
        };

        var unlockResponse = await client.PostAsJsonAsync("/api/users/admin/unlock-account", unlockRequest);

        // Assert
        Assert.Equal(HttpStatusCode.OK, unlockResponse.StatusCode);

        // Attempt to log in again after unlocking
        client.DefaultRequestHeaders.Authorization = null; // Clear admin token
        var successfulLoginRequest = new UsersLoginRequestDto
        {
            UsernameOrEmail = username,
            Password = password
        };

        var successfulLoginResponse = await client.PostAsJsonAsync("/api/users/login", successfulLoginRequest);
        var successfulLoginContent = await successfulLoginResponse.Content.ReadAsStringAsync();
        var loginResult = JsonSerializer.Deserialize<UsersLoginResponseDto>(successfulLoginContent, _jsonOptions);

        // Assert
        Assert.Equal(HttpStatusCode.OK, successfulLoginResponse.StatusCode);
        Assert.NotNull(loginResult);
        Assert.NotEmpty(loginResult.Token);
    }

    #endregion

    #region Email Verification Tests

    [Fact]
    public async Task Admin_VerifiesUserEmail_Successfully()
    {
        // Create a user
        var username = "verifyemailtest";
        var email = "verifyemail@example.com";
        var password = "Password123!";

        var formData = new MultipartFormDataContent
    {
        { new StringContent(username), "UserName" },
        { new StringContent("Verify"), "FirstName" },
        { new StringContent("Email"), "LastName" },
        { new StringContent(email), "Email" },
        { new StringContent(password), "Password" }
    };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        // Verify the email is not confirmed initially
        var user = await TestUtilities.GetUserByEmailAsync(email, ApiFixture);
        Assert.False(user.EmailConfirmed);

        // Verify the email as an admin
        var adminToken = await TestUtilities.GetAdminAuthTokenAsync(client); // Utility to get admin token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);

        var verifyEmailRequest = new VerifyEmailWithoutCheckRequestDto
        {
            Email = email
        };

        var response = await client.PostAsJsonAsync("/api/users/admin/verify-email", verifyEmailRequest);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        // Verify the email is now confirmed
        user = await TestUtilities.GetUserByEmailAsync(email, ApiFixture);

        Assert.True(user.EmailConfirmed);
    }

    [Fact]
    public async Task Admin_VerifiesNonexistentUserEmail_ReturnsNotFound()
    {
        //Nonexistent email
        var email = "nonexistent@example.com";

        var client = ApiFixture.CreateClient();
        var adminToken = await TestUtilities.GetAdminAuthTokenAsync(client); // Utility to get admin token
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);

        var verifyEmailRequest = new VerifyEmailWithoutCheckRequestDto
        {
            Email = email
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/users/admin/verify-email", verifyEmailRequest);

        // Assert
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UnauthorizedUser_TriesToVerifyEmail_ReturnsForbidden()
    {
        //Create a user
        var username = "unauthorizedtest";
        var email = "unauthorized@example.com";
        var password = "Password123!";

        var formData = new MultipartFormDataContent
    {
        { new StringContent(username), "UserName" },
        { new StringContent("Unauthorized"), "FirstName" },
        { new StringContent("Test"), "LastName" },
        { new StringContent(email), "Email" },
        { new StringContent(password), "Password" }
    };

        var client = ApiFixture.CreateClient();
        await client.PostAsync("/api/users", formData);

        // Try to verify email without admin privileges
        var verifyEmailRequest = new VerifyEmailWithoutCheckRequestDto
        {
            Email = email
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/users/admin/verify-email", verifyEmailRequest);

        // Assert
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion
}
