---
applyTo: '**/*.cs'
description: 'Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
maturity: stable
---

# C# Test Instructions

These instructions define conventions for C# test code. All C# coding conventions from [csharp.instructions.md](csharp.instructions.md) apply to test code.

## Test Framework

* Test projects use XUnit
* Mocking uses the latest Moq library
* Tests follow BDD-style conventions for naming and structure
* Tests focus on class behaviors rather than internal implementation details

## Test Structure

Test file naming matches the class under test (e.g., `PipelineServiceTests`).

Test methods follow the BDD `Given/When/Then` pattern, implemented as `Arrange/Act/Assert` blocks.

Test method naming format: `(GivenSomething)_(WhenSomething)_ActingCall_Assertion`

<!-- <example-test-naming> -->
```text
WhenValidRequest_ProcessDataAsync_ReturnsParsedResponse
GivenEmptyInput_ProcessDataAsync_ThrowsArgumentException
```
<!-- </example-test-naming> -->

* One assertion per test is preferred; related assertions validating the same behavior are acceptable
* Logger mocks are not verified or validated

## Test Organization

* Member fields at the top of the class in alphabetical order
* Fields are `readonly` when possible
* Service under test is named `sut`
* Utility methods appear after the constructor but before test methods
* Test methods grouped logically by behavior, ordered alphabetically within groups
* Mock setup in the constructor for common setup; in individual test methods for specific behavior

## Test Examples

<!-- <example-test-class> -->
```csharp
public class EndpointDataProcessorTests
{
    private readonly string endpointUri = "https://test-endpoint.com/predict";
    private readonly FakeSinkData expectedSinkData;
    private readonly HttpClient httpClient;
    private readonly Mock<HttpMessageHandler> httpMessageHandlerMock;
    private readonly Mock<ILogger<EndpointDataProcessor<FakeSourceData, FakeSinkData>>> loggerMock;
    private readonly Mock<IOptions<InferencePipelineOptions>> optionsMock;
    private readonly FakeSourceData sourceData;
    private readonly EndpointDataProcessor<FakeSourceData, FakeSinkData> sut;

    public EndpointDataProcessorTests()
    {
        loggerMock = new Mock<ILogger<EndpointDataProcessor<FakeSourceData, FakeSinkData>>>();

        optionsMock = new Mock<IOptions<InferencePipelineOptions>>();
        optionsMock.Setup(o => o.Value).Returns(new InferencePipelineOptions
        {
            EndpointUri = endpointUri,
            SourceTopic = "source/topic",
            SinkTopic = "sink/topic"
        });

        httpMessageHandlerMock = new Mock<HttpMessageHandler>();
        httpClient = new HttpClient(httpMessageHandlerMock.Object);

        sourceData = new FakeSourceData { Id = 42, Name = "Test Data" };
        expectedSinkData = new FakeSinkData { Result = "Processed", Score = 0.95 };

        sut = new EndpointDataProcessor<FakeSourceData, FakeSinkData>(
            loggerMock.Object,
            optionsMock.Object,
            httpClient);
    }

    private void SendAsyncSetup(HttpResponseMessage responseMessage)
    {
        httpMessageHandlerMock
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(responseMessage);
    }

    [Fact]
    public async Task WhenValidRequest_ProcessDataAsync_ReturnsParsedResponse()
    {
        // Arrange
        var responseContent = JsonSerializer.Serialize(expectedSinkData);
        SendAsyncSetup(new HttpResponseMessage
        {
            StatusCode = HttpStatusCode.OK,
            Content = new StringContent(responseContent)
        });

        // Act
        var actual = await sut.ProcessDataAsync(sourceData, CancellationToken.None);

        // Assert
        Assert.NotNull(actual);
        Assert.Equivalent(expectedSinkData, actual);
    }

    [Fact]
    public async Task WhenNonSuccessfulStatusCode_ProcessDataAsync_ThrowsHttpRequestException()
    {
        // Arrange
        var errorResponse = "Testing internal server error";
        SendAsyncSetup(new HttpResponseMessage
        {
            StatusCode = HttpStatusCode.InternalServerError,
            Content = new StringContent(errorResponse)
        });

        // Act & Assert
        var exception = await Assert.ThrowsAsync<HttpRequestException>(
            () => sut.ProcessDataAsync(sourceData, CancellationToken.None)
        );

        Assert.Contains("500", exception.Message);
    }

    public class FakeSourceData
    {
        public int Id { get; set; }
        public string? Name { get; set; }
    }

    public class FakeSinkData
    {
        public string? Result { get; set; }
        public double Score { get; set; }
    }
}
```
<!-- </example-test-class> -->

## Lifecycle Interfaces

For setup/teardown before and after each test, implement `IAsyncLifetime`:

* `InitializeAsync` runs before each test
* `DisposeAsync` runs after each test

<!-- <example-async-lifecycle> -->
```csharp
public class PipelineService_WhenReceivingOneTests : PipelineServiceTestsBase, IAsyncLifetime
{
    private readonly CancellationTokenSource cancellationTokenSource;
    private readonly FakeSinkData sinkData;
    private readonly FakeSourceData sourceData;

    public PipelineService_WhenReceivingOneTests()
    {
        sourceData = new FakeSourceData { Id = 1, Name = "Test" };
        sinkData = new FakeSinkData { Result = "Processed", Score = 0.95 };
        cancellationTokenSource = new CancellationTokenSource();
    }

    public async ValueTask InitializeAsync()
    {
        await sut.StartAsync(cancellationTokenSource.Token);
    }

    public ValueTask DisposeAsync()
    {
        return ValueTask.CompletedTask;
    }

    [Fact]
    public async Task WhenValidData_OnTelemetryReceived_SendsToSink()
    {
        // Arrange
        dataProcessorMock
            .Setup(p =>
                p.ProcessDataAsync(It.IsAny<FakeSourceData?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sinkData);

        // Act
        await OnTelemetryReceived(sourceData);

        // Assert
        sinkSenderMock.Verify(s => s.SendTelemetryAsync(
                It.Is<FakeSinkData>(actual => sinkData == actual),
                It.IsAny<Dictionary<string, string>>(),
                It.IsAny<MqttQualityOfServiceLevel>(),
                It.IsAny<TimeSpan?>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }
}
```
<!-- </example-async-lifecycle> -->

## Test Base Classes

Base classes contain shared setup logic and utility methods for multiple derived test classes.

Naming conventions:

* Base class: `*TestsBase` (e.g., `PipelineServiceTestsBase`)
* Derived class: `ClassUnderTest_(Given/When)Something` (e.g., `PipelineService_WhenReceivingOneMessage`)

Base class structure:

* Protected members for derived class access
* Fields ordered alphabetically
* Create a base class only when more than one implementing test class exists

<!-- <example-test-base-class> -->
```csharp
public abstract class PipelineServiceTestsBase
{
    protected readonly Mock<IPipelineDataProcessor<FakeSourceData, FakeSinkData>> dataProcessorMock;
    protected readonly Mock<IHostApplicationLifetime> lifetimeMock;
    protected readonly Mock<ILogger<PipelineService<FakeSourceData, FakeSinkData>>> loggerMock;
    protected readonly Mock<ISinkSenderFactory<FakeSinkData>> sinkSenderFactoryMock;
    protected readonly Mock<ISinkSender<FakeSinkData>> sinkSenderMock;
    protected readonly Mock<ISourceReceiverFactory<FakeSourceData>> sourceReceiverFactoryMock;
    protected readonly Mock<ISourceReceiver<FakeSourceData>> sourceReceiverMock;
    protected readonly PipelineService<FakeSourceData, FakeSinkData> sut;

    protected Func<string, FakeSourceData, IncomingTelemetryMetadata, Task> capturedOnTelemetryReceived =
        (_, _, _) => Task.CompletedTask;

    protected PipelineServiceTestsBase()
    {
        // Common setup code
    }

    protected async Task OnTelemetryReceived(FakeSourceData sourceData, string senderId = "test-sender-id")
    {
        // Implementation
    }

    public class FakeSourceData
    {
        public int Id { get; set; }
        public string? Name { get; set; }
    }

    public class FakeSinkData
    {
        public string? Result { get; set; }
        public double Score { get; set; }
    }
}
```
<!-- </example-test-base-class> -->
