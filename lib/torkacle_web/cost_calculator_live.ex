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
    <div class="max-w-2xl mx-auto p-4" id="cost-calculator">
      <h1 class="text-3xl font-bold mb-6">Hva koster det?</h1>

      <div class="flex flex-col md:flex-row items-start gap-4 mb-6">
        <div class="relative">
          <img
            src="/images/torkel.png"
            alt="Torkel"
            loading="lazy"
            class="w-32 rounded-full border-2 border-gray-300"
          />

          <div class="absolute top-0 left-32 bg-white border border-gray-300 shadow-md p-3 rounded-lg max-w-sm">
            <p class="text-sm font-semibold">
              <%= if @torkel_guess do %>
                "Jeg er ganske sikker på at det koster {@torkel_guess}!"
              <% else %>
                "Hmm, la meg se på bildet først..."
              <% end %>
            </p>
          </div>
        </div>

        <div class="mt-8 ml-20 md:mt-0 max-w-sm text-gray-700">
          <p class="leading-tight">
            Torkel er kjent for å gjette helt feil på priser.
            Ta et bilde av noe, så skal han gjette prisen.
            Etterpå får du se den faktiske estimerte prisen!
          </p>
        </div>
      </div>

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
                  class="bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-4 rounded shadow"
                  onclick="document.getElementById('camera-input').click()"
                >
                  Ta bilde
                </button>
              </div>
            </div>

            <div id="preview-container" class="mt-4 hidden">
              <img id="preview-image" class="mx-auto w-24 border-2 border-gray-200 rounded" />
            </div>
          </div>

          <%= if @processing do %>
            <div class="mt-4">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mx-auto"></div>
              <p class="mt-2 text-gray-700">Torkel studerer bildet...</p>
              <p class="mt-1 text-sm text-gray-600">Han tenker hardt!</p>
            </div>
          <% end %>
        </div>

        <%= if @error_message do %>
          <div class="mt-4 p-4 bg-red-100 rounded-lg border-l-4 border-red-500">
            <p class="text-red-700 font-semibold">{@error_message}</p>
          </div>
        <% end %>

        <%= if @calc_result do %>
          <div class="mt-4">
            <details class="bg-green-100 rounded-lg">
              <summary class="p-4 cursor-pointer hover:bg-green-200">
                Se den faktiske prisen...
              </summary>
              <div class="p-4 pt-2">
                <p class="text-xl font-bold">
                  Den faktiske estimerte prisen er: {@calc_result} kr
                </p>
                <p class="mt-2 text-gray-700">
                  Der bommet Torkel ganske kraftig!
                </p>
              </div>
            </details>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
