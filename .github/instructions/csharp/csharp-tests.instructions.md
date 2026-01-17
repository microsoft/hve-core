---
applyTo: '**/*.cs'
description: 'Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
maturity: stable
---

# C# Test Instructions

Conventions for C# test code. All conventions from [csharp.instructions.md](csharp.instructions.md) apply, including member ordering and field naming with underscore prefix.

## Test Framework

Use XUnit with NSubstitute for mocking. Focus on class behaviors rather than implementation details. Follow BDD-style naming and Arrange/Act/Assert structure.

### Mocking Libraries

| Library | Usage |
|---------|-------|
| NSubstitute | Preferred for new projects |
| FakeItEasy | Acceptable alternative |
| Moq | Existing projects only (pin to 4.18.x or 4.20.2+) |

## Test Naming

Test file naming matches the class under test: `PipelineServiceTests`.

Test method format: `GivenContext_WhenAction_ExpectedResult`

```text
WhenValidRequest_ProcessDataAsync_ReturnsParsedResponse
GivenEmptyInput_ProcessDataAsync_ThrowsArgumentException
```

Prefer one assertion per test. Related assertions validating the same behavior are acceptable. Do not verify logger mocks.

Use `[Theory]` with `[InlineData]` for simple parameterized cases or `[MemberData]` for complex test data.

## Test Organization

* Fields at class top, alphabetically by name after underscore (`_httpClient` before `_sut`), `readonly` when possible
* Service under test named `_sut`
* Utility methods after constructor, before test methods
* Test methods grouped by behavior, alphabetically within groups
* Common mock setup in constructor; specific setup in test methods

## NSubstitute Patterns

Common mocking patterns:

```csharp
// Create substitutes
var service = Substitute.For<IDataService>();
var options = Substitute.For<IOptions<Config>>();

// Configure returns
service.GetAsync(Arg.Any<int>()).Returns(Task.FromResult(data));
options.Value.Returns(new Config { Endpoint = "https://api.test" });

// Argument matching
service.Process(Arg.Is<Request>(r => r.Id > 0)).Returns(result);

// Verify calls
await service.Received(1).SaveAsync(Arg.Any<Data>());
service.DidNotReceive().Delete(Arg.Any<int>());
```

## Lifecycle Interfaces

Implement `IAsyncLifetime` for per-test setup and teardown:

* `InitializeAsync` runs before each test
* `DisposeAsync` runs after each test

## Base Classes

Create base classes when multiple test classes share setup logic. Name base class `*TestsBase` and derived class `ClassUnderTest_GivenContext` or `ClassUnderTest_WhenAction`. Define fake classes once in the base class.

## Complete Example

Using NSubstitute:

```csharp
public class EndpointDataProcessorTests
{
    private readonly HttpClient _httpClient;
    private readonly MockHttpMessageHandler _httpHandler = new();
    private readonly IOptions<PipelineOptions> _options;
    private readonly EndpointDataProcessor<FakeSource, FakeSink> _sut;

    public EndpointDataProcessorTests()
    {
        _options = Substitute.For<IOptions<PipelineOptions>>();
        _options.Value.Returns(new PipelineOptions { EndpointUri = "https://test.com/predict" });

        _httpClient = new HttpClient(_httpHandler);
        _sut = new EndpointDataProcessor<FakeSource, FakeSink>(_options, _httpClient);
    }

    [Fact]
    public async Task WhenValidRequest_ProcessDataAsync_ReturnsParsedResponse()
    {
        // Arrange
        var expected = new FakeSink { Result = "Processed", Score = 0.95 };
        _httpHandler.Response = new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(JsonSerializer.Serialize(expected))
        };

        // Act
        var actual = await _sut.ProcessDataAsync(new FakeSource { Id = 1 }, CancellationToken.None);

        // Assert
        Assert.NotNull(actual);
        Assert.Equivalent(expected, actual);
    }

    [Fact]
    public async Task WhenServerError_ProcessDataAsync_ThrowsHttpRequestException()
    {
        // Arrange
        _httpHandler.Response = new HttpResponseMessage(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsAsync<HttpRequestException>(
            () => _sut.ProcessDataAsync(new FakeSource { Id = 1 }, CancellationToken.None));
    }

    public record FakeSource { public int Id { get; init; } }
    public record FakeSink { public string? Result { get; init; } public double Score { get; init; } }

    private class MockHttpMessageHandler : HttpMessageHandler
    {
        public HttpResponseMessage Response { get; set; } = new(HttpStatusCode.OK);
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) => Task.FromResult(Response);
    }
}
```
