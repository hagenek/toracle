defmodule TorkacleWeb.TorkelResponseComponent do
  use TorkacleWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex items-start space-x-4">
      <div class="flex-shrink-0">
        <img src="/images/torkel.png" alt="Torkel" class="w-12 h-12 rounded-full shadow-lg ring-2 ring-purple-500/20" />
      </div>
      <div class="flex-grow">
        <div class="relative">
          <div class="absolute -left-2 top-4 transform -translate-y-1/2">
            <div class="w-3 h-3 rotate-45 bg-white/95 border-l border-t border-white/20"></div>
          </div>
          <div class="bg-white/95 rounded-lg p-4 shadow-xl">
            <div class="text-gray-900">
              <p class="font-medium mb-1">Torkel's Estimate</p>
              <p class="text-2xl font-bold text-purple-600"><%= @guess %> kr</p>
              <p class="mt-2 text-sm text-gray-600">
                <%= if @is_higher do %>
                  "Actually, I think it's worth more than that! The market for these items is quite hot right now."
                <% else %>
                  "That seems a bit high to me! Based on what I've seen, I'd value it lower."
                <% end %>
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
