defmodule TorkacleWeb.CostCalculatorLive do
  use TorkacleWeb, :live_view
  require Logger
  alias TorkacleWeb.ImageAnalyzer
  alias TorkacleWeb.PhotoUploadComponent

  @retry_delays [2_000, 5_000, 10_000]

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("Mounting CostCalculatorLive")

    {:ok,
     socket
     |> assign(:calc_result, nil)
     |> assign(:processing, false)
     |> assign(:error_message, nil)
     |> assign(:torkel_guess, nil)}
  end

  @impl true
  def handle_event("process-image", %{"image" => image_data} = params, socket) do
    Logger.debug("Process image event received")
    Logger.debug("Parameters: #{inspect(Map.drop(params, ["image"]))}")
    Logger.debug("Image data size: #{byte_size(image_data)} bytes")

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
    Logger.debug("Received task result")
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:ok, cost_str} ->
          Logger.debug("Analysis successful, received cost_str: #{inspect(cost_str)}")

          # Convert cost string to integer more safely
          {cost, _} =
            case cost_str do
              str when is_binary(str) ->
                case Integer.parse(str) do
                  {num, _} -> {num, ""}
                  :error -> {0, ""}
                end

              num when is_integer(num) ->
                {num, ""}

              _ ->
                {0, ""}
            end

          Logger.debug("Parsed cost as integer: #{inspect(cost)}")

          # Calculate Torkel's guess with explicit conversion to float
          {multiplier, operation} =
            if cost < 10000 do
              # 5-10x too high
              {5 + :rand.uniform(5), :multiply}
            else
              # 5-10x too low
              {5 + :rand.uniform(5), :divide}
            end

          Logger.debug(
            "Using multiplier: #{inspect(multiplier)}, operation: #{inspect(operation)}"
          )

          torkel_guess =
            case operation do
              :multiply -> cost * multiplier
              :divide -> cost / multiplier
            end
            # Use trunc instead of round for safer integer conversion
            |> trunc()

          Logger.debug("Calculated torkel_guess: #{inspect(torkel_guess)}")

          formatted_torkel =
            torkel_guess
            |> Integer.to_string()
            |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ".")
            |> Kernel.<>(" kr")

          formatted_cost =
            cost
            |> Integer.to_string()
            |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ".")
            |> Kernel.<>(" kr")

          Logger.debug("Formatted values - cost: #{formatted_cost}, torkel: #{formatted_torkel}")

          socket
          |> assign(:calc_result, formatted_cost)
          |> assign(:torkel_guess, formatted_torkel)
          |> assign(:processing, false)
          |> assign(:error_message, nil)

        {:error, :timeout} ->
          Logger.error("Analysis timed out after all retries")

          socket
          |> assign(:processing, false)
          |> assign(
            :error_message,
            "Forespørselen tok for lang tid. Vennligst prøv igjen med et mindre eller tydeligere bilde."
          )

        {:error, :max_retries_exceeded} ->
          Logger.error("Analysis failed after maximum retries")

          socket
          |> assign(:processing, false)
          |> assign(
            :error_message,
            "Kunne ikke analysere bildet etter flere forsøk. Vennligst prøv igjen."
          )

        {:error, :file_too_large} ->
          Logger.error("File size exceeds limit")

          socket
          |> assign(:processing, false)
          |> assign(:error_message, "Bildefilen er for stor. Vennligst bruk et bilde under 20MB.")

        {:error, :invalid_image} ->
          Logger.error("Invalid image format")

          socket
          |> assign(:processing, false)
          |> assign(
            :error_message,
            "Ugyldig bildeformat. Vennligst prøv igjen med et annet bilde."
          )

        {:error, reason} ->
          Logger.error("Analysis failed with reason: #{inspect(reason)}")

          socket
          |> assign(:processing, false)
          |> assign(:error_message, "Kunne ikke analysere bildet. Vennligst prøv igjen.")
      end

    {:noreply, socket}
  end

  # Handle task crashes
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    Logger.error("Analysis task crashed: #{inspect(reason)}")

    socket =
      socket
      |> assign(:processing, false)
      |> assign(:error_message, "Analysen feilet uventet. Vennligst prøv igjen.")

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

  defp analyze_with_retry(_image_data, []) do
    Logger.error("All retry attempts exhausted")
    {:error, :max_retries_exceeded}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="mb-8 text-center">
        <h1 class="text-3xl font-bold text-white mb-2">Torkacle</h1>
        <p class="text-lg text-purple-200">Upload a photo and let Torkel guess the price!</p>
      </div>

      <div class="space-y-8">
        <.live_component
          module={PhotoUploadComponent}
          id="photo-upload"
          processing={@processing}
        />

        <%= if @calc_result do %>
          <div class="rounded-xl bg-white/95 p-6 shadow-lg">
            <div class="space-y-4">
              <div class="text-gray-900">
                <h3 class="text-lg font-semibold mb-1">Your Estimate</h3>
                <p class="text-3xl font-bold text-purple-600"><%= @calc_result %> kr</p>
              </div>

              <%= if @torkel_guess do %>
                <div class="border-t border-gray-200 pt-4 text-gray-900">
                  <h3 class="text-lg font-semibold mb-1">Torkel's Guess</h3>
                  <p class="text-3xl font-bold text-purple-600"><%= @torkel_guess %> kr</p>
                  <p class="mt-2 text-sm text-gray-600">
                    <%= if String.to_integer(String.replace(@calc_result, ~r/[^\d]/, "")) > String.to_integer(String.replace(@torkel_guess, ~r/[^\d]/, "")) do %>
                      "That seems a bit high to me! I think it's worth less."
                    <% else %>
                      "Actually, I think it's worth more than that!"
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @error_message do %>
          <div class="rounded-lg bg-red-50 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-800">Error Processing Image</h3>
                <p class="mt-2 text-sm text-red-700"><%= @error_message %></p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <script>
    window.addEventListener("phx:open-camera", (e) => {
      const input = document.querySelector("#photo-upload");
      if (input) {
        input.click();
      }
    });
    </script>
    """
  end
end
