defmodule TorkacleWeb.ImageAnalyzer do
  require Logger

  # 20MB limit for incoming images (matching OpenAI's limit)
  @max_image_size 20 * 1024 * 1024
  # 1MB target size for compressed images
  @target_size 1 * 1024 * 1024
  @temp_dir "tmp/image_processing"

  def analyze_image(image_data) do
    Logger.debug("Starting image analysis pipeline")
    Logger.debug("Image data prefix: #{String.slice(image_data, 0, 50)}...")

    with {:ok, processed_image} <- process_image(image_data),
         {:ok, response} <- make_api_call(processed_image) do
      Logger.debug("Analysis pipeline completed successfully")
      parse_response(response)
    else
      {:error, reason} = error ->
        Logger.error("Analysis pipeline failed with reason: #{inspect(reason)}")
        error
    end
  end

  defp process_image("data:image/" <> rest) do
    Logger.debug("Processing image data")

    try do
      [type, base64] = String.split(rest, ";base64,")
      Logger.debug("Image type: #{type}")

      case Base.decode64!(base64) do
        decoded when is_binary(decoded) ->
          original_size = byte_size(decoded)
          Logger.debug("Original image size: #{original_size} bytes")

          case original_size do
            size when size > @max_image_size ->
              Logger.warn("Original image too large: #{size} bytes (max: #{@max_image_size})")
              {:error, :file_too_large}

            _ ->
              compressed_image = compress_image(decoded, type)
              compressed_size = byte_size(compressed_image)
              Logger.debug("Compressed image size: #{compressed_size} bytes")
              {:ok, "data:image/#{type};base64,#{Base.encode64(compressed_image)}"}
          end

        _ ->
          Logger.error("Base64 decode failed to produce binary")
          {:error, :invalid_image}
      end
    rescue
      e ->
        Logger.error("Image processing failed with error: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format(:error, e, __STACKTRACE__)}")
        {:error, :invalid_image}
    after
      # Cleanup any temporary files
      cleanup_temp_files()
    end
  end

  defp compress_image(image_data, type) do
    # Ensure temp directory exists
    File.mkdir_p!(@temp_dir)

    # Create temporary file paths
    temp_input = Path.join(@temp_dir, "input_#{:rand.uniform(999_999)}.#{type}")
    temp_output = Path.join(@temp_dir, "output_#{:rand.uniform(999_999)}.#{type}")

    try do
      # Write original image to temp file
      File.write!(temp_input, image_data)

      # Calculate target quality based on file size
      original_size = File.stat!(temp_input).size
      initial_quality = calculate_initial_quality(original_size)

      # Compress the image
      Logger.debug("Compressing image with initial quality: #{initial_quality}")

      Mogrify.open(temp_input)
      |> Mogrify.quality("#{initial_quality}")
      # Resize if larger than 768px on shortest side for high detail mode
      |> Mogrify.resize("2000x768>")
      |> Mogrify.save(path: temp_output)

      # Read the compressed image
      compressed_data = File.read!(temp_output)
      compressed_size = byte_size(compressed_data)

      Logger.debug(
        "Compression complete. Original: #{original_size}, Compressed: #{compressed_size} bytes"
      )

      compressed_data
    rescue
      e ->
        Logger.error("Image compression failed: #{inspect(e)}")
        reraise e, __STACKTRACE__
    after
      # Cleanup temp files
      File.rm(temp_input)
      File.rm(temp_output)
    end
  end

  defp calculate_initial_quality(original_size) do
    cond do
      original_size > @target_size * 5 -> 60
      original_size > @target_size * 3 -> 70
      original_size > @target_size * 2 -> 75
      original_size > @target_size -> 80
      true -> 85
    end
  end

  defp cleanup_temp_files do
    case File.ls(@temp_dir) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          File.rm(Path.join(@temp_dir, file))
        end)

      _ ->
        :ok
    end
  end

  defp make_api_call(processed_image) do
    Logger.debug("Preparing OpenAI API call")

    start_time = System.monotonic_time(:millisecond)

    # Ensure API key is configured
    api_key = Application.get_env(:openai, :api_key)

    if is_nil(api_key) do
      Logger.error("OpenAI API key not configured")
      {:error, :missing_api_key}
    else
      result =
        OpenAI.chat_completion(
          # Updated to new model
          model: "gpt-4o-mini",
          messages: [
            %{
              role: "user",
              content: [
                %{
                  type: "text",
                  text:
                    "What do you estimate this would cost in Norwegian Kroner (NOK)? Reply with ONLY the number, no text or symbols."
                },
                %{
                  type: "image_url",
                  image_url: %{
                    url: processed_image,
                    # Using high detail mode for better accuracy
                    detail: "high"
                  }
                }
              ]
            }
          ],
          max_tokens: 100,
          temperature: 0.7
        )

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      Logger.debug("OpenAI API call completed in #{duration}ms")
      Logger.debug("API Response: #{inspect(result, pretty: true)}")

      result
    end
  end

  defp parse_response({:ok, %{choices: [%{"message" => %{"content" => content}} | _]}} = response)
       when is_binary(content) do
    Logger.debug(
      "Successfully extracted content from response: #{inspect(response, pretty: true)}"
    )

    {:ok, content}
  end

  defp parse_response({:error, :timeout} = error) do
    Logger.error("OpenAI API timeout")
    error
  end

  defp parse_response(error) do
    Logger.error("Unexpected response format: #{inspect(error, pretty: true)}")
    {:error, :invalid_response}
  end
end
