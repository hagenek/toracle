defmodule TorkacleWeb.CostCalculatorLive do
  use TorkacleWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:calc_result, nil)
     |> assign(:processing, false)}
  end

  @impl true
  def handle_event("process-image", %{"image" => "data:image/" <> rest}, socket) do
    [type, base64] = String.split(rest, ";base64,")

    socket =
      socket
      |> assign(:processing, true)
      |> assign(:calc_result, nil)

    # Call OpenAI API
    case analyze_image(base64) do
      {:ok, cost} ->
        {:noreply, socket |> assign(:calc_result, cost) |> assign(:processing, false)}

      {:error, reason} ->
        Logger.error("OpenAI API error: #{inspect(reason)}")
        {:noreply, socket |> assign(:processing, false)}
    end
  end

  defp analyze_image(base64_image) do
    # We'll implement this next - placeholder for now
    {:ok, "1000"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4">
      <h1 class="text-3xl font-bold mb-4">Hva koster det?</h1>

      <div class="space-y-4">
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
          <form phx-change="noop">
            <div class="space-y-4">
              <div class="flex flex-col items-center gap-4">
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  class="hidden"
                  id="camera-input"
                  onchange="handleImageSelect(this)"
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
          </form>

          <div id="preview-container" class="mt-4 hidden">
            <img id="preview-image" class="mx-auto max-w-xs" />
          </div>

          <%= if @processing do %>
            <div class="mt-4">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 mx-auto"></div>
              <p class="mt-2">Analyzing image...</p>
            </div>
          <% end %>
        </div>

        <%= if @calc_result do %>
          <div class="mt-4 p-4 bg-green-100 rounded-lg">
            <p class="text-xl font-bold">Cost: {@calc_result} kr</p>
          </div>
        <% end %>
      </div>
    </div>

    <script>
      function handleImageSelect(input) {
        const file = input.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = function(e) {
            const previewContainer = document.getElementById('preview-container');
            const previewImage = document.getElementById('preview-image');

            previewImage.src = e.target.result;
            previewContainer.classList.remove('hidden');

            // Send to LiveView
            window.pushEvent("process-image", {image: e.target.result});
          }
          reader.readAsDataURL(file);
        }
      }
    </script>
    """
  end
end
