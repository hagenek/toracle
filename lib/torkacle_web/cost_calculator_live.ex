defmodule TorkacleWeb.CostCalculatorLive do
  use TorkacleWeb, :live_view
  require Logger
  alias TorkacleWeb.ImageAnalyzer

  @retry_delays [2_000, 5_000, 10_000]

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("Mounting CostCalculatorLive")

    {:ok,
     socket
     |> assign(:calc_result, nil)
     |> assign(:processing, false)
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("process-image", %{"image" => image_data} = params, socket) do
    Logger.debug("Process image event received")
    Logger.debug("Parameters: #{inspect(Map.drop(params, ["image"]))}")
    Logger.debug("Image data size: #{byte_size(image_data)} bytes")
    Logger.debug("Image data prefix: #{String.slice(image_data, 0, 50)}...")

    socket =
      socket
      |> assign(:processing, true)
      |> assign(:calc_result, nil)
      |> assign(:error_message, nil)

    Logger.debug("Starting async analysis task")

    Task.async(fn ->
      Logger.metadata(task: "image_analysis")
      analyze_with_retry(image_data, @retry_delays)
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, result} = message, socket) when is_reference(ref) do
    Logger.debug("Received task result: #{inspect(message)}")
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:ok, cost} ->
          Logger.debug("Analysis successful, cost: #{cost}")

          socket
          |> assign(:calc_result, cost)
          |> assign(:processing, false)
          |> assign(:error_message, nil)

        {:error, :timeout} ->
          Logger.error("Analysis timed out after all retries")

          socket
          |> assign(:processing, false)
          |> assign(
            :error_message,
            "Request timed out. Please try again with a smaller or clearer image."
          )

        {:error, :file_too_large} ->
          Logger.error("File size exceeds limit")

          socket
          |> assign(:processing, false)
          |> assign(:error_message, "Image file is too large. Please use an image under 20MB.")

        {:error, :invalid_image} ->
          Logger.error("Invalid image format")

          socket
          |> assign(:processing, false)
          |> assign(
            :error_message,
            "Invalid image format. Please try again with a different image."
          )

        {:error, reason} ->
          Logger.error("Analysis failed with reason: #{inspect(reason)}")

          socket
          |> assign(:processing, false)
          |> assign(:error_message, "Could not analyze image. Please try again.")
      end

    Logger.debug("Socket assigns after processing: #{inspect(socket.assigns)}")
    {:noreply, socket}
  end

  defp analyze_with_retry(image_data, [delay | remaining_delays] = delays) do
    attempt_number = length(@retry_delays) - length(delays) + 1
    Logger.debug("Starting analysis attempt #{attempt_number}/#{length(@retry_delays)}")

    case ImageAnalyzer.analyze_image(image_data) do
      {:ok, result} = success ->
        Logger.debug("Analysis succeeded on attempt #{attempt_number}")
        success

      {:error, :timeout} when remaining_delays != [] ->
        Logger.warn("Attempt #{attempt_number} failed with timeout, retrying in #{delay}ms")
        Process.sleep(delay)
        analyze_with_retry(image_data, remaining_delays)

      error ->
        Logger.error("Attempt #{attempt_number} failed with error: #{inspect(error)}")
        error
    end
  end

  defp analyze_with_retry(image_data, []) do
    Logger.error("All retry attempts exhausted")
    Logger.debug("Failed image data prefix: #{String.slice(image_data, 0, 50)}...")
    {:error, :max_retries_exceeded}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4" id="cost-calculator">
      <h1 class="text-3xl font-bold mb-4">Hva koster det?</h1>

      <div class="space-y-4">
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
          <div phx-hook="ImageHook" id="image-hook" phx-update="ignore">
            <div class="space-y-4">
              <div class="flex flex-col items-center gap-4">
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  class="hidden"
                  id="camera-input"
                  onchange="handleImageSelect(this, 'image-hook')"
                />

                <button
                  type="button"
                  class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
                  onclick="document.getElementById('camera-input').click()"
                >
                  Take Photo
                </button>
              </div>
            </div>

            <div id="preview-container" class="mt-4 hidden">
              <img id="preview-image" class="mx-auto max-w-xs" />
            </div>
          </div>

          <%= if @processing do %>
            <div class="mt-4">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mx-auto"></div>
              <p class="mt-2">Analyzing image...</p>
            </div>
          <% end %>
        </div>

        <%= if @error_message do %>
          <div class="mt-4 p-4 bg-red-100 rounded-lg">
            <p class="text-red-700">{@error_message}</p>
          </div>
        <% end %>

        <%= if @calc_result do %>
          <div class="mt-4 p-4 bg-green-100 rounded-lg">
            <p class="text-xl font-bold">Cost: {@calc_result} kr</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
