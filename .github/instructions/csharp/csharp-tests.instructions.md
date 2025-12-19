---
applyTo: '**/*.cs'
description: 'Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating'
---

# C# (csharp) Tests Instructions

Must follow all csharp related conventions provided in #file:./csharp.instructions.md
All tests for C# must go in a `*.Tests` project that's next to the project being tested.
All tests must always use `XUnit`.
Tests must use the latest `Moq` library when needed for mocking out functionality.
All tests must follow `BDD` style conventions for test naming and structure, examples provided below.
Tests should only focus on the behaviors of the class and not internal functionality unless otherwise specified.

## C# (csharp) Test Structure

The structure of the tests will look like the following:

* The name of the test file will match the class that's being tested. As an example `PipelineServiceTests`.
* Every test will be a method and will attempt to test one behavior at a time in a `Given`, `When`, `Then` format. In
  the tests themselves this will be `arrange`, `act`, `assert`.
* The tests themselves should always follow the format `(GivenSomething)_(WhenSomething)_ActingCall_Assertion`, an
  example of this would be `WhenValidRequest_ProcessDataAsync_ReturnsParsedResponse`, `ProcessDataAsync` is the
  `ActingCall` and `ReturnsParsedResponse` a small precise description of the `Assertion`.
* One assert per test is preferred, though related assertions validating the same behavior are acceptable.
* `logger` is **never** tested or validated.

## Test Organization

* Member fields should be organized at the top of the class in alphabetical order.
* Fields should be `readonly` when possible.
* The service under test should always be named `sut`.
* Utility methods should appear after the constructor but before test methods.
* Test methods should be grouped logically by behavior and ordered alphabetically within those groups.
* Mock setup should typically be done in the constructor for common setup and in individual test methods for specific
  behavior.

## Test Examples

An example test class looks similar to this:

```csharp
// Always include the name of the class/service under test when naming your test classes.
public class EndpointDataProcessorTests
{
    // Mocks and test data should be near the top of the class and alphabetically sorted.
    private readonly string endpointUri = "https://test-endpoint.com/predict";
    private readonly FakeSinkData expectedSinkData;
    private readonly HttpClient httpClient;
    private readonly Mock<HttpMessageHandler> httpMessageHandlerMock;
    private readonly Mock<ILogger<EndpointDataProcessor<FakeSourceData, FakeSinkData>>> loggerMock;
    private readonly Mock<IOptions<InferencePipelineOptions>> optionsMock;
    private readonly FakeSourceData sourceData;
    private readonly EndpointDataProcessor<FakeSourceData, FakeSinkData> sut;

    // Constructors should always be used for any common test initialization.
    public EndpointDataProcessorTests()
    {
        loggerMock = new Mock<ILogger<EndpointDataProcessor<FakeSourceData, FakeSinkData>>>();

        // Always keep the Setup for Mocks as close to the Mock as possible.
        optionsMock = new Mock<IOptions<InferencePipelineOptions>>();
        optionsMock.Setup(o => o.Value).Returns(new InferencePipelineOptions
        {
            EndpointUri = endpointUri,
            SourceTopic = "source/topic",
            SinkTopic = "sink/topic"
        });

        httpMessageHandlerMock = new Mock<HttpMessageHandler>();
        httpClient = new HttpClient(httpMessageHandlerMock.Object);

        // Always initialize test data in constructor when used in multiple tests.
        sourceData = new FakeSourceData { Id = 42, Name = "Test Data" };
        expectedSinkData = new FakeSinkData { Result = "Processed", Score = 0.95 };

        // Always create the service under test (sut) in the constructor.
        sut = new EndpointDataProcessor<FakeSourceData, FakeSinkData>(
            loggerMock.Object,
            optionsMock.Object,
            httpClient);
    }

    // Utility methods should be placed between constructor and test methods.
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
        // Utility methods should always be preferred when creating the same/similar logic for testing.
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

    // Fake models should be in the class that's using them for testing.
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

## Lifecycle Interfaces in Test Classes

* When a test class needs setup/teardown before and after each test, implement the `IAsyncLifetime` interface.
* The `InitializeAsync` method is called before each test to set up prerequisites.
* The `DisposeAsync` method is called after each test for cleanup.

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
        // Setup async code that runs before each test.
        await sut.StartAsync(cancellationTokenSource.Token);
    }

    public ValueTask DisposeAsync()
    {
        // Cleanup async code that runs after each test.
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
                // Verify only what's needed for the assertion.
                It.Is<FakeSinkData>(actual => sinkData == actual),
                It.IsAny<Dictionary<string, string>>(),
                It.IsAny<MqttQualityOfServiceLevel>(),
                It.IsAny<TimeSpan?>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }
}
```

## Reusing Test Context

* A test can have a base class that contains common test setup and test data.
* When a base class is needed then the base class will always have `*TestsBase` as a class name.
* There will always be an implementing class for the test base class that has at least one test.
* A base class for tests will only ever be created when there are more than one implementing test classes.
* Additional implementing test class will always have the format `ClassUnderTest_(Given/When)Something`, the test class
  should provide additional setup for when something is `Given` about a series of tests or `When` the same thing happens
  to a series of tests. An example would be `PipelineService_WhenReceivingOneMessage`, `PipelineService` is the
  `ClassUnderTest` and `When` `ReceivingOneMessage` is something that is happening to all the tests in this class.

## Test Base Classes

* Base classes should contain shared setup logic and utility methods used by multiple derived test classes.
* The base class should have protected members that derived classes can access.
* Fields in the base class should be ordered alphabetically for consistency.

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
        // Common setup code used by derived test classes.
    }

    // Utility methods available to all derived test classes.
    protected async Task OnTelemetryReceived(FakeSourceData sourceData, string senderId = "test-sender-id")
    {
        // Implementation of utility method.
    }

    // Fake models for testing also used by derived classes when needed.
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
