defmodule TorkacleWeb.PhotoUploadComponent do
  use TorkacleWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <form id="upload-form" phx-submit="process-image" phx-change="validate">
        <div class="space-y-4">
          <div class="flex flex-col items-center justify-center w-full">
            <label for="photo-upload" class="relative w-full h-64 flex flex-col items-center justify-center p-6 border-2 border-purple-300 border-dashed rounded-xl cursor-pointer bg-white/5 hover:bg-white/10 transition-colors group">
              <div class="flex flex-col items-center justify-center">
                <svg class="w-10 h-10 text-purple-400 group-hover:text-purple-300 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <p class="mb-2 text-sm text-purple-300 group-hover:text-purple-200">
                  <span class="font-semibold">Click to upload</span> or drag and drop
                </p>
                <p class="text-xs text-purple-400 group-hover:text-purple-300">
                  PNG, JPG or JPEG (MAX. 10MB)
                </p>
              </div>
              <%= if @preview_url do %>
                <img src={@preview_url} class="absolute inset-0 w-full h-full object-contain rounded-xl opacity-20" />
              <% end %>
              <input
                id="photo-upload"
                type="file"
                class="hidden"
                accept="image/*"
                capture={if @is_mobile, do: "environment", else: nil}
                phx-target={@myself}
              />
            </label>
          </div>

          <%= if @is_mobile do %>
            <div class="flex justify-center">
              <button
                type="button"
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-purple-300 bg-purple-900/30 rounded-lg hover:bg-purple-900/50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
                phx-click="open-camera"
                phx-target={@myself}
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                Take a Photo
              </button>
            </div>
          <% end %>
        </div>
      </form>

      <%= if @processing do %>
        <div class="mt-4 text-center">
          <div class="inline-flex items-center px-4 py-2 font-semibold leading-6 text-sm text-purple-300 transition ease-in-out duration-150 cursor-not-allowed">
            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-purple-300" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Processing...
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     socket
     |> assign(:preview_url, nil)
     |> assign(:is_mobile, is_mobile?())
     |> assign(:processing, false)}
  end

  def handle_event("validate", %{"photo" => photo}, socket) do
    {:noreply, assign(socket, :preview_url, generate_preview_url(photo))}
  end

  def handle_event("open-camera", _params, socket) do
    {:noreply, push_event(socket, "open-camera", %{})}
  end

  defp is_mobile? do
    System.get_env("USER_AGENT", "")
    |> String.downcase()
    |> Kernel.in(["android", "iphone", "ipad", "ipod"])
  end

  defp generate_preview_url(photo) do
    case photo do
      %{path: path} -> "data:image/jpeg;base64,#{Base.encode64(File.read!(path))}"
      _ -> nil
    end
  end
end
