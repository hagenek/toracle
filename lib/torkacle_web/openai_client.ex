defmodule TorkacleWeb.OpenAIClient do
  require Logger

  @api_base "https://api.openai.com/v1"
  @default_headers [
    {"Content-Type", "application/json"},
    {"Accept", "application/json"}
  ]

  def chat_completion(opts \\ []) do
    api_key = Application.get_env(:openai, :api_key)

    if is_nil(api_key) do
      Logger.error("OpenAI API key not configured")
      {:error, :missing_api_key}
    else
      url = "#{@api_base}/chat/completions"
      headers = [{"Authorization", "Bearer #{api_key}"} | @default_headers]

      payload = %{
        model: Keyword.get(opts, :model, "gpt-4o-mini"),
        messages: Keyword.get(opts, :messages, []),
        max_tokens: Keyword.get(opts, :max_tokens, 300),
        temperature: Keyword.get(opts, :temperature, 0.7)
      }

      Logger.debug("Making request to OpenAI API: #{inspect(payload, pretty: true)}")

      case HTTPoison.post(url, Jason.encode!(payload), headers, recv_timeout: 30_000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]} = response}
            when is_binary(content) ->
              Logger.debug("Received successful response: #{inspect(response, pretty: true)}")
              {:ok, content}

            {:ok, response} ->
              Logger.error("Unexpected response format: #{inspect(response, pretty: true)}")
              {:error, :invalid_response}

            {:error, error} ->
              Logger.error("Failed to decode response: #{inspect(error)}")
              {:error, :invalid_response}
          end

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("API request failed with status #{status_code}: #{body}")
          {:error, {:api_error, status_code, body}}

        {:error, %HTTPoison.Error{reason: :timeout}} ->
          Logger.error("API request timed out")
          {:error, :timeout}

        {:error, error} ->
          Logger.error("API request failed: #{inspect(error)}")
          {:error, :request_failed}
      end
    end
  end

  @doc """
  Helper function to create a message with both text and image content.
  The image can be either a URL or base64-encoded data.
  """
  def create_vision_message(text, image, detail \\ "auto") do
    %{
      role: "user",
      content: [
        %{
          type: "text",
          text: text
        },
        %{
          type: "image_url",
          image_url:
            case image do
              "data:image/" <> _ = data_uri ->
                %{url: data_uri, detail: detail}

              url when is_binary(url) ->
                %{url: url, detail: detail}
            end
        }
      ]
    }
  end
end
